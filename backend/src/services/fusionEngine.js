const Device = require("../models/Device");
const SensorLog = require("../models/SensorLog");
const Alert = require("../models/Alert");
const ThresholdConfig = require("../models/ThresholdConfig");
const logger = require("../utils/logger");
const { getNodePosition, HANGAR } = require("../config/nodePositions");
const { emitAdmin, emitPublicFire } = require("../socket/broadcast");

class FusionEngine {
  constructor() {
    // Per-device buffer of the latest N readings: { [deviceId]: [ { timestamp, tempC, humidityPct, smokeRaw, seqNo } ] }
    this.deviceWindows = new Map();
    // Active node warning state and timestamp: { [deviceId]: { timestamp, zoneId, flags } }
    this.activeNodeWarnings = new Map();
    // Last FIRE alert timestamp per zone: { [zoneId]: timestamp }
    this.zoneCooldowns = new Map();
    // Active open fire alerts: { [zoneId]: alertDoc }
    this.activeZoneFireAlerts = new Map();
  }

  /**
   * Clears warning state before scenario tests.
   * If an optional deviceIds list is provided, clears warnings only for those nodes;
   * otherwise clears all active warnings.
   * @param {string[] | undefined} deviceIds
   */
  clearNodeWarnings(deviceIds) {
    if (deviceIds && deviceIds.length > 0) {
      deviceIds.forEach((id) => this.activeNodeWarnings.delete(String(id)));
      logger.info(`[FusionEngine] Warning state temizlendi: [${deviceIds.join(", ")}]`);
    } else {
      const count = this.activeNodeWarnings.size;
      this.activeNodeWarnings.clear();
      logger.info(`[FusionEngine] All warning states cleared (${count} records).`);
    }
  }

  /**
   * Restore state after restart (rehydration):
   * In-memory Maps are cleared, but resolved:false alert records remain in MongoDB.
   * If these records are not restored, the dashboard continues to show
   * "FIRE" even when engine memory is empty (getNodesOverview reads from the DB).
   * - The NEWEST open alert for each zone is loaded into activeZoneFireAlerts.
   * - zoneCooldowns is restored from the alert's createdAt time so
   *   an alert is not resolved prematurely while cooldown is still active, and
   *   the normal resolution flow resumes when cooldown ends.
   * Fail-fast: errors are not swallowed; they are thrown to the caller. server.js start()
   * runs it before listen, so if rehydration fails,
   * the server never starts accepting requests (startup error -> process.exit(1)).
   */
  async rehydrateOnStartup() {
    const openAlerts = await Alert.find({ resolved: false }).sort({ createdAt: -1 });
    const seenZones = new Set();
    let rehydrated = 0;

    for (const alert of openAlerts) {
      if (!alert.zoneId || seenZones.has(alert.zoneId)) continue; // newest record per zone
      seenZones.add(alert.zoneId);
      this.activeZoneFireAlerts.set(alert.zoneId, alert);
      if (alert.severity === "fire") {
        // Matches the semantics at L153: cooldown is measured from when the alert opened
        this.zoneCooldowns.set(alert.zoneId, new Date(alert.createdAt).getTime());
      }
      rehydrated++;
      logger.info(
        `[FusionEngine] Rehydrate: zone=${alert.zoneId} alert=${alert.alertId} severity=${alert.severity}`
      );
    }

    if (rehydrated > 0) {
      logger.info(`[FusionEngine] Restored ${rehydrated} open alerts after restart.`);
    }
  }

  /**
   * Updates the device moving window and stores recent readings
   */
  _updateDeviceBuffer(deviceId, sample, maxSamples = 10) {
    if (!this.deviceWindows.has(deviceId)) {
      this.deviceWindows.set(deviceId, []);
    }
    const buffer = this.deviceWindows.get(deviceId);
    buffer.push(sample);
    if (buffer.length > maxSamples) {
      buffer.shift();
    }
    return buffer;
  }

  /**
   * Node-level fusion analysis:
   * 1. Moving average smoke
   * 2. Heat rise rate (Delta T / Delta t)
   * 3. Sudden humidity drop
   */
  _analyzeNodeFusion(buffer, config) {
    const n = buffer.length;
    if (n === 0) {
      return {
        movingAvgSmoke: 0,
        smokeFlag: false,
        heatRateFlag: false,
        humidityDropFlag: false,
        isWarning: false,
      };
    }

    // 1. Moving average smoke (last movingAverageSize samples)
    const windowSize = Math.min(n, config.movingAverageSize || 3);
    const recentSamples = buffer.slice(-windowSize);
    const sumSmoke = recentSamples.reduce((acc, s) => acc + s.smokeRaw, 0);
    const movingAvgSmoke = Math.round(sumSmoke / windowSize);

    // Smoke flag: was the threshold exceeded in recent samples?
    const smokeFlag = movingAvgSmoke >= config.smokeThreshold;

    // 2. Heat rise rate (Delta T / Delta t - °C / second)
    let heatRateFlag = false;
    let heatRateVal = 0;
    if (n >= 2) {
      const oldest = buffer[0];
      const newest = buffer[n - 1];
      const deltaTSeconds = (newest.timestamp - oldest.timestamp) / 1000;
      if (deltaTSeconds > 0) {
        const deltaTemp = newest.tempC - oldest.tempC;
        heatRateVal = deltaTemp / deltaTSeconds;
        if (heatRateVal >= config.heatRateThresholdCPerSec) {
          heatRateFlag = true;
        }
      }
    }

    // 3. Sudden humidity drop (% Delta H)
    let humidityDropFlag = false;
    if (n >= 2) {
      const oldest = buffer[0];
      const newest = buffer[n - 1];
      const deltaHum = oldest.humidityPct - newest.humidityPct;
      if (deltaHum >= config.humidityDropThresholdPct) {
        humidityDropFlag = true;
      }
    }

    // Node-level WARNING rule:
    // smoke_flag == true VE (heat_rate_flag VEYA humidity_drop_flag)
    const isWarning = smokeFlag && (heatRateFlag || humidityDropFlag);

    return {
      movingAvgSmoke,
      smokeFlag,
      heatRateFlag,
      humidityDropFlag,
      heatRateVal,
      isWarning,
    };
  }

  /**
   * Zone-level consensus analysis:
   * Checks warning states within windowSeconds for nodes with the same zoneId.
   * FIRE requires at least minNodesForFire nodes in the same zone to be in WARNING.
   */
  async _evaluateZoneConsensus(zoneId, config, io) {
    const now = Date.now();
    const windowMs = (config.windowSeconds || 45) * 1000;

    // Find valid warnings in the zone and time window
    const triggeringDeviceIds = [];
    for (const [dId, warningData] of this.activeNodeWarnings.entries()) {
      if (warningData.zoneId === zoneId && now - warningData.timestamp <= windowMs) {
        triggeringDeviceIds.push(dId);
      } else if (now - warningData.timestamp > windowMs) {
        // Clear expired warnings
        this.activeNodeWarnings.delete(dId);
      }
    }

    const minNodes = config.minNodesForFire || 2;
    const cooldownMs = (config.cooldownSeconds || 180) * 1000;
    const lastFireTime = this.zoneCooldowns.get(zoneId) || 0;
    const isInCooldown = now - lastFireTime < cooldownMs;

    logger.debug(
      `[Consensus] Zone: ${zoneId}, Active warnings: ${triggeringDeviceIds.length}/${minNodes} (required), Cooldown: ${isInCooldown}`
    );

    // CONSENSUS: if at least minNodes nodes issue WARNING -> FIRE
    if (triggeringDeviceIds.length >= minNodes) {
      if (!isInCooldown) {
        // Trigger a new FIRE alert!
        this.zoneCooldowns.set(zoneId, now);

        // Calculate the zone center coordinates from nodePositions
        const zoneDevices = await Device.find({ zoneId });
        let centerLat = HANGAR.lat;
        let centerLng = HANGAR.lng;
        if (zoneDevices.length > 0) {
          const fallback = getNodePosition("1");
          centerLat = zoneDevices.reduce((acc, d) => acc + (d.coordinates?.lat || fallback.lat), 0) / zoneDevices.length;
          centerLng = zoneDevices.reduce((acc, d) => acc + (d.coordinates?.lng || fallback.lng), 0) / zoneDevices.length;
        }

        const alertMessage = `🚨 FIRE ALERT! Fire confirmed in ${zoneId.toUpperCase()} by consensus from ${triggeringDeviceIds.length} nodes!`;

        // Before opening a new alert, close older open (resolved:false) alerts in the same zone
        // to prevent orphaned records from remaining open in nodes-overview after
        // restart/rehydration.
        await Alert.updateMany(
          { zoneId, resolved: false },
          { $set: { resolved: true, resolvedAt: new Date() } }
        );

        const alertDoc = await Alert.create({
          zoneId,
          severity: "fire",
          type: "fire",
          message: alertMessage,
          triggeringDeviceIds,
          coordinates: { lat: centerLat, lng: centerLng },
          notificationStatus: "sent",
          resolved: false,
        });

        this.activeZoneFireAlerts.set(zoneId, alertDoc);

        // Set the relevant devices' status to "fire"
        await Device.updateMany(
          { deviceId: { $in: triggeringDeviceIds } },
          { status: "fire", hasActiveAlert: true }
        );

        // Socket.io: alert:fire broadcast (triggers the drone simulation and red alert)
        if (io) {
          const payload = {
            alertId: alertDoc.alertId,
            zoneId,
            severity: "fire",
            message: alertMessage,
            triggeringDeviceIds,
            coordinates: { lat: centerLat, lng: centerLng },
            timestamp: alertDoc.createdAt || new Date(),
            cooldownSeconds: config.cooldownSeconds,
          };
          // Protected events go only to the admin room; only the summary goes to the public room.
          emitAdmin(io, "alert:fire", payload);
          const fireAlertCount = await Alert.countDocuments({ resolved: false, severity: "fire" });
          emitPublicFire(io, { fireActive: fireAlertCount > 0, fireAlertZoneCount: fireAlertCount });
          logger.warn(`🔥 CONSENSUS FIRE ALERT BROADCAST: ${zoneId} (${triggeringDeviceIds.join(", ")})`);
        }

        return { status: "fire", alert: alertDoc };
      } else {
        logger.info(`⏳ Cooldown is active (${zoneId}); no new alert was created.`);
        return { status: "fire_cooldown" };
      }
    } else {
      // Fire conditions are no longer met, or the fire has ended/returned to normal
      const activeAlert = this.activeZoneFireAlerts.get(zoneId);
      if (activeAlert && !isInCooldown) {
        // Cooldown ended and consensus dropped -> return to normal (RESOLVED)
        const resolvedAt = new Date();
        activeAlert.resolved = true;
        activeAlert.resolvedAt = resolvedAt;
        await activeAlert.save();

        // Close all other open (resolved:false) records in the same zone as well:
        // if multiple alerts are open (e.g. duplicate triggers or old orphaned
        // records), none should remain open in the nodes-overview response.
        await Alert.updateMany(
          { zoneId, resolved: false },
          { $set: { resolved: true, resolvedAt } }
        );

        this.activeZoneFireAlerts.delete(zoneId);

        await Device.updateMany({ zoneId }, { status: "online", hasActiveAlert: false });

        if (io) {
          emitAdmin(io, "alert:resolved", {
            alertId: activeAlert.alertId,
            zoneId,
            message: `✅ Hazard cleared in ${zoneId.toUpperCase()}; status returned to normal.`,
            resolvedAt,
          });
          // Current active fire count after resolution; important for multi-zone alerts
          // so the summary updates correctly (same semantics as /api/public/status).
          const fireAlertCount = await Alert.countDocuments({ resolved: false, severity: "fire" });
          emitPublicFire(io, { fireActive: fireAlertCount > 0, fireAlertZoneCount: fireAlertCount });
        }
        logger.info(`✅ Fire alert resolved: ${zoneId}`);
      }
      return { status: triggeringDeviceIds.length > 0 ? "warning" : "normal" };
    }
  }

  /**
   * Main data processing entry point (packet received from hub or bridge)
   * @param {object} packetData
   * @param {import('socket.io').Server | null} io
   */
  async processPacket(packetData, io) {
    const {
      deviceId,
      tempC,
      humidityPct,
      smokeRaw,
      seqNo = 0,
      batteryPct = 100,
      source = "hardware",
    } = packetData;

    const timestamp = new Date();
    const config = await ThresholdConfig.getActiveConfig();

    // 1. Find or automatically create the device (self-register)
    let device = await Device.findOne({ deviceId });
    if (!device) {
      // Konumu merkezi nodePositions.js'den al
      const pos = getNodePosition(deviceId);

      device = await Device.create({
        deviceId: String(deviceId),
        name: pos.name,
        zoneId: pos.zoneId,
        coordinates: { lat: pos.lat, lng: pos.lng },
        isOnline: true,
        status: "online",
        batteryPct,
        batteryLevel: batteryPct,
        lastSeen: timestamp,
        lastHeartbeat: timestamp,
        lastSeq: seqNo,
        totalPacketsReceived: 1,
        totalPacketsLost: 0,
      });
    }

    // Packet loss calculation (using seqNo)
    let packetsLostIncrement = 0;
    if (device.lastSeq > 0 && seqNo > device.lastSeq + 1) {
      packetsLostIncrement = seqNo - device.lastSeq - 1;
    }

    // 2. Update the moving window and run node fusion analysis
    const buffer = this._updateDeviceBuffer(String(deviceId), {
      timestamp: timestamp.getTime(),
      tempC: Number(tempC),
      humidityPct: Number(humidityPct),
      smokeRaw: Number(smokeRaw),
      seqNo: Number(seqNo),
    });

    const fusion = this._analyzeNodeFusion(buffer, config);

    // 3. Update node status
    let nodeStatus = "online";
    if (fusion.isWarning) {
      nodeStatus = "warning";
      this.activeNodeWarnings.set(String(deviceId), {
        timestamp: timestamp.getTime(),
        zoneId: device.zoneId,
        flags: {
          smokeFlag: fusion.smokeFlag,
          heatRateFlag: fusion.heatRateFlag,
          humidityDropFlag: fusion.humidityDropFlag,
        },
      });

      // Socket.io: node:warning broadcast
      if (io) {
        emitAdmin(io, "node:warning", {
          deviceId: String(deviceId),
          zoneId: device.zoneId,
          tempC,
          humidityPct,
          smokeRaw,
          movingAvgSmoke: fusion.movingAvgSmoke,
          flags: {
            smokeFlag: fusion.smokeFlag,
            heatRateFlag: fusion.heatRateFlag,
            humidityDropFlag: fusion.humidityDropFlag,
          },
          timestamp,
          source,
        });
      }
    } else {
      this.activeNodeWarnings.delete(String(deviceId));
    }

    // 4. Zone-level consensus check
    const consensusResult = await this._evaluateZoneConsensus(device.zoneId, config, io);
    if (consensusResult.status === "fire" || consensusResult.status === "fire_cooldown") {
      nodeStatus = "fire";
    }

    // 5. Update the device document
    device.isOnline = true;
    device.status = nodeStatus;
    device.batteryPct = batteryPct;
    device.batteryLevel = batteryPct;
    device.lastSeen = timestamp;
    device.lastHeartbeat = timestamp;
    device.lastSeq = seqNo;
    device.totalPacketsReceived = (device.totalPacketsReceived || 0) + 1;
    device.totalPacketsLost = (device.totalPacketsLost || 0) + packetsLostIncrement;
    await device.save();

    // 6. Create SensorLog
    const gasStatus = nodeStatus === "fire" ? "fire" : (nodeStatus === "warning" ? "warning" : "safe");
    const log = await SensorLog.create({
      device: device._id,
      deviceId: String(deviceId),
      tempC: Number(tempC),
      temperature: Number(tempC),
      humidityPct: Number(humidityPct),
      humidity: Number(humidityPct),
      smokeRaw: Number(smokeRaw),
      mq2Value: Number(smokeRaw),
      movingAvgSmoke: fusion.movingAvgSmoke,
      smokeFlag: fusion.smokeFlag,
      heatRateFlag: fusion.heatRateFlag,
      humidityDropFlag: fusion.humidityDropFlag,
      rawSeqNo: seqNo,
      gasStatus,
      source,
      timestamp,
    });

    // 7. Socket.io: sensor:update (feeds all dashboard charts and indicators)
    if (io) {
      emitAdmin(io, "sensor:update", {
        deviceId: String(deviceId),
        name: device.name,
        zoneId: device.zoneId,
        coordinates: device.coordinates,
        tempC,
        humidityPct,
        smokeRaw,
        movingAvgSmoke: fusion.movingAvgSmoke,
        flags: {
          smokeFlag: fusion.smokeFlag,
          heatRateFlag: fusion.heatRateFlag,
          humidityDropFlag: fusion.humidityDropFlag,
        },
        status: nodeStatus,
        batteryPct,
        seqNo,
        packetsLost: device.totalPacketsLost,
        source,
        timestamp,
      });
    }

    return {
      success: true,
      deviceId: String(deviceId),
      nodeStatus,
      fusion,
      consensusResult,
      logId: log._id,
    };
  }
}

// Singleton instance
const instance = new FusionEngine();
module.exports = instance;
