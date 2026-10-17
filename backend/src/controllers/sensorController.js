const Device = require("../models/Device");
const SensorLog = require("../models/SensorLog");
const Alert = require("../models/Alert");
const ThresholdConfig = require("../models/ThresholdConfig");
const fusionEngine = require("../services/fusionEngine");
const RedisService = require("../services/redisService");
const logger = require("../utils/logger");
const { NODE_POSITIONS, HANGAR, getNodePosition } = require("../config/nodePositions");
const { emitAdmin } = require("../socket/broadcast");

if (!process.env.INGEST_API_KEY) {
  logger.error("INGEST_API_KEY is not set; check your environment configuration.");
  process.exit(1);
}

// ── CRC-8 (Dallas/Maxim) helper ──────────────────
function calculateCrc8(buffer) {
  let crc = 0x00;
  for (let i = 0; i < buffer.length; i++) {
    crc ^= buffer[i];
    for (let j = 0; j < 8; j++) {
      if (crc & 0x80) {
        crc = ((crc << 1) ^ 0x07) & 0xff;
      } else {
        crc = (crc << 1) & 0xff;
      }
    }
  }
  return crc;
}

// ── Binary AssetPacket Parser (13 Bayt) ───────────────
function parseAssetPacketHex(hexString) {
  const cleanHex = hexString.replace(/\s+/g, "");
  const buf = Buffer.from(cleanHex, "hex");
  if (buf.length < 13) {
    throw new Error(`Invalid packet length: ${buf.length} bytes (at least 13 bytes expected)`);
  }

  const payloadBuf = buf.subarray(0, 12);
  const receivedCrc = buf[12];
  const computedCrc = calculateCrc8(payloadBuf);

  if (receivedCrc !== computedCrc) {
    logger.warn(`⚠️ CRC-8 mismatch! Received: 0x${receivedCrc.toString(16)}, calculated: 0x${computedCrc.toString(16)}`);
  }

  const schemaVersion = buf.readUInt8(0);
  const deviceId = buf.readUInt8(1);
  const tempCx10 = buf.readUInt16LE(2);
  const tempC = parseFloat((tempCx10 / 10.0).toFixed(1));
  const humidityPct = buf.readUInt8(4);
  const smokeRaw = buf.readUInt16LE(5);
  const seqNo = buf.readUInt32LE(7);
  const batteryPct = buf.readUInt8(11);

  return {
    schemaVersion,
    deviceId: String(deviceId),
    tempC,
    humidityPct,
    smokeRaw,
    seqNo,
    batteryPct,
    crcOk: receivedCrc === computedCrc,
  };
}

// ── Middleware: IoT & bridge API key validation ──
exports.verifyApiKey = async (req, res, next) => {
  try {
    // The key is read only from the header. Query-string support
    // was intentionally removed: keys in URLs can leak into Morgan HTTP logs and
    // the request log. (bridge.js and simulate_scenarios.js already
    // use the x-api-key header.)
    const apiKey = req.headers["x-api-key"];
    const masterKey = process.env.INGEST_API_KEY;

    // 1. Check the master ingest key (bridge or authorized hardware request)
    if (apiKey && apiKey === masterKey) {
      req.isMasterIngest = true;
      return next();
    }

    // 2. Check the device-specific API key (MongoDB Device)
    if (apiKey) {
      const device = await Device.findOne({ apiKey }).select("+apiKey").populate("owner contacts");
      if (device) {
        req.device = device;
        return next();
      }
    }

    // 3. Invalid or missing key
    return res.status(401).json({
      success: false,
      message: "Unauthorized (401): A valid X-API-KEY header is required.",
    });
  } catch (error) {
    next(error);
  }
};

// ── POST /api/sensors/heartbeat ────────────────────────
exports.heartbeat = async (req, res, next) => {
  try {
    const { deviceId, batteryLevel } = req.body;
    const targetDeviceId = req.device?.deviceId || deviceId || "1";

    const device = await Device.findOne({ deviceId: String(targetDeviceId) });
    if (device) {
      device.isOnline = true;
      device.lastHeartbeat = new Date();
      if (batteryLevel !== undefined) {
        device.batteryLevel = batteryLevel;
        device.batteryPct = batteryLevel;
      }
      await device.save();

      const io = req.app.get("io");
      if (io) {
        emitAdmin(io, "device_status", {
          deviceId: device.deviceId,
          isOnline: true,
          status: device.status,
          lastHeartbeat: device.lastHeartbeat,
          batteryPct: device.batteryPct,
        });
      }
    }

    res.json({ success: true, message: "Heartbeat received." });
  } catch (error) {
    next(error);
  }
};

// ── POST /api/sensors/ingest (PC bridge / hub ingestion) ─
exports.ingestPacket = async (req, res, next) => {
  try {
    const io = req.app.get("io");
    let packet = req.body;

    // Parse the payload if binary hex was provided
    if (req.body.rawHex) {
      packet = parseAssetPacketHex(req.body.rawHex);
    }

    // Reject packets with a calculated but invalid CRC.
    // The condition must be === false: crcOk is produced only on the binary path
    // (rawHex or the bridge binary JSON); JSON without CRC data,
    // simulation and text-fallback flows (crcOk === undefined) are unaffected.
    if (packet.crcOk === false) {
      logger.warn(
        `🚫 [Ingest CRC Rejected] deviceId=${packet.deviceId} seq=${packet.seqNo} — CRC-8 mismatch; packet was not passed to fusion.`
      );
      return res.status(422).json({
        success: false,
        message: "CRC-8 validation failed: packet rejected.",
      });
    }

    if (!packet.deviceId) {
      return res.status(400).json({ success: false, message: "deviceId is required." });
    }

    // Send to the fusion and consensus engines
    const result = await fusionEngine.processPacket({
      deviceId: String(packet.deviceId),
      tempC: packet.tempC !== undefined ? Number(packet.tempC) : (packet.temperature || 24.0),
      humidityPct: packet.humidityPct !== undefined ? Number(packet.humidityPct) : (packet.humidity || 50.0),
      smokeRaw: packet.smokeRaw !== undefined ? Number(packet.smokeRaw) : (packet.mq2Value || 350),
      seqNo: packet.seqNo !== undefined ? Number(packet.seqNo) : 0,
      batteryPct: packet.batteryPct !== undefined ? Number(packet.batteryPct) : (packet.batteryLevel || 100),
      // Preserve the data source: bridge --mock and simulation packets specify a source
      source: packet.source || "hardware",
    }, io);

    res.json(result);
  } catch (error) {
    logger.error("Ingest packet error:", error);
    next(error);
  }
};

// ── POST /api/sensors/data (backward compatibility) ─────
exports.uploadSensorData = async (req, res, next) => {
  try {
    const io = req.app.get("io");
    const { deviceId = "1", mq2Value, temperature, humidity, batteryLevel, seqNo } = req.body;

    const result = await fusionEngine.processPacket({
      deviceId: String(deviceId),
      tempC: temperature || 24.5,
      humidityPct: humidity || 50.0,
      smokeRaw: mq2Value || 350,
      seqNo: seqNo || 0,
      batteryPct: batteryLevel || 100,
    }, io);

    res.json(result);
  } catch (error) {
    next(error);
  }
};

// ── GET /api/config/thresholds (get thresholds) ───────────
exports.getThresholds = async (req, res, next) => {
  try {
    const config = await ThresholdConfig.getActiveConfig();
    res.json({ success: true, data: config });
  } catch (error) {
    next(error);
  }
};

// ── PUT /api/config/thresholds (update thresholds) ────────
exports.updateThresholds = async (req, res, next) => {
  try {
    const {
      smokeThreshold,
      heatRateThresholdCPerSec,
      humidityDropThresholdPct,
      windowSeconds,
      minNodesForFire,
      cooldownSeconds,
      movingAverageSize,
    } = req.body;

    const config = await ThresholdConfig.getActiveConfig();
    if (smokeThreshold !== undefined) config.smokeThreshold = smokeThreshold;
    if (heatRateThresholdCPerSec !== undefined) config.heatRateThresholdCPerSec = heatRateThresholdCPerSec;
    if (humidityDropThresholdPct !== undefined) config.humidityDropThresholdPct = humidityDropThresholdPct;
    if (windowSeconds !== undefined) config.windowSeconds = windowSeconds;
    if (minNodesForFire !== undefined) config.minNodesForFire = minNodesForFire;
    if (cooldownSeconds !== undefined) config.cooldownSeconds = cooldownSeconds;
    if (movingAverageSize !== undefined) config.movingAverageSize = movingAverageSize;

    await config.save();

    const io = req.app.get("io");
    if (io) {
      emitAdmin(io, "config:updated", config);
    }

    logger.info("⚙️ Threshold values updated:", config.toJSON());
    res.json({ success: true, message: "Threshold values updated.", data: config });
  } catch (error) {
    next(error);
  }
};

// ── GET /api/devices/nodes-overview (all dashboard nodes) ─
exports.getNodesOverview = async (req, res, next) => {
  try {
    // The number of registered nodes varies; all node IDs in NODE_POSITIONS are included
    const nodeIds = Object.keys(NODE_POSITIONS);
    const nodes = [];

    for (const sId of nodeIds) {
      let d = await Device.findOne({ deviceId: sId });
      if (!d) {
        const pos = getNodePosition(sId);
        const idx = parseInt(sId) || 1;
        d = await Device.create({
          deviceId: sId,
          name: pos.name,
          zoneId: pos.zoneId,
          coordinates: { lat: pos.lat, lng: pos.lng },
          isOnline: true,
          status: "online",
          batteryPct: Math.max(80, 98 - idx * 2),
          lastSeen: new Date(),
        });
      }

      // Latest 20 sensor records (for charts) — real hardware data only
      const logs = await SensorLog.find({ deviceId: sId })
        .sort({ timestamp: -1 })
        .limit(20)
        .lean();

      nodes.push({
        device: d,
        recentLogs: logs.reverse(),
      });
    }

    // Active alerts
    const activeAlerts = await Alert.find({ resolved: false })
      .sort({ createdAt: -1 })
      .limit(5);

    const config = await ThresholdConfig.getActiveConfig();

    // Hangar coordinates come from the central config (no longer hard-coded in the frontend)
    res.json({
      success: true,
      nodes,
      activeAlerts,
      config,
      hangarCoordinates: HANGAR,
    });
  } catch (error) {
    next(error);
  }
};

// ── GET /api/public/status (public aggregate status; no key required) ──
// Returns only aggregate information needed for the badge: node counts and active
// fire alert count. Coordinates, sensor readings, thresholds, and alert
// details (message/location/temperature, etc.) are NOT included in the response.
exports.getPublicStatus = async (req, res, next) => {
  try {
    const devices = await Device.find({}, { status: 1, isOnline: 1, _id: 0 }).lean();
    const nodesOnline = devices.filter((d) => d.status === "online" || d.isOnline).length;
    const fireAlertCount = await Alert.countDocuments({ resolved: false, severity: "fire" });

    res.json({
      success: true,
      nodesTotal: devices.length,
      nodesOnline,
      fireAlertActive: fireAlertCount > 0,
      fireAlertZoneCount: fireAlertCount,
    });
  } catch (error) {
    next(error);
  }
};

// ── POST /api/sensors/simulate-scenario (dashboard quick scenario test) ─
exports.simulateScenario = async (req, res, next) => {
  try {
    const io = req.app.get("io");
    const { scenario } = req.body; // 'normal', 'single_warning', 'consensus_fire', 'cooldown'

    logger.info(`🧪 Test scenario started: ${scenario}`);

    // Clear all node warning states before the scenario starts.
    // This prevents activeNodeWarnings left over from a previous test session from
    // incorrectly triggering consensus (state-leakage fix).
    fusionEngine.clearNodeWarnings();

    if (scenario === "normal") {
      // Send normal clean-air readings to all nodes
      const nodeIds = Object.keys(NODE_POSITIONS);
      for (const sId of nodeIds) {
        await fusionEngine.processPacket({
          deviceId: sId,
          tempC: 22.5 + Math.random() * 1.5,
          humidityPct: 55 - Math.random() * 3,
          smokeRaw: 250 + Math.floor(Math.random() * 80),
          seqNo: Date.now() % 100000,
          batteryPct: 95,
          source: "sim",
        }, io);
      }
      return res.json({ success: true, message: "Normal scenario applied. All nodes are green." });
    }

    if (scenario === "single_warning") {
      // Only Node 1 reports high smoke and a temperature rise -> WARNING (yellow)
      // Other nodes remain normal -> NO CONSENSUS (minNodesForFire >= 2); the drone does not launch!
      const nodeIds = Object.keys(NODE_POSITIONS);
      for (const sId of nodeIds.filter((id) => id !== "1")) {
        await fusionEngine.processPacket({
          deviceId: sId,
          tempC: 22.0,
          humidityPct: 55,
          smokeRaw: 260,
          seqNo: 100 + parseInt(sId),
          batteryPct: 95,
          source: "sim",
        }, io);
      }

      // Node 1 triggers WARNING with three consecutive samples; since the other nodes are clean,
      // zone-alpha has only one WARNING -> minNodesForFire (2) is not met -> no FIRE.
      for (let step = 0; step < 3; step++) {
        await fusionEngine.processPacket({
          deviceId: "1",
          tempC: 24.0 + step * 2.5, // Rapid temperature increase!
          humidityPct: 52 - step * 4, // Rapid humidity decrease!
          smokeRaw: 1400 + step * 200, // Smoke above threshold!
          seqNo: 200 + step,
          batteryPct: 94,
          source: "sim",
        }, io);
      }

      return res.json({
        success: true,
        message: "Single-warning scenario applied: Node 1 entered WARNING (yellow), but consensus was not reached — minNodesForFire=2 and only one node issued WARNING. The drone did not launch.",
      });
    }

    if (scenario === "consensus_fire") {
      // Nodes 1 AND 2 report high smoke and a temperature rise simultaneously (Zone-Alpha)
      // -> two WARNINGs in zone-alpha -> minNodesForFire=2 -> CONSENSUS -> FIRE -> drone!
      const nodeIds = Object.keys(NODE_POSITIONS);
      for (const sId of nodeIds.filter((id) => id !== "1" && id !== "2")) {
        await fusionEngine.processPacket({
          deviceId: sId,
          tempC: 23.0,
          humidityPct: 50,
          smokeRaw: 280,
          seqNo: 300 + parseInt(sId),
          batteryPct: 93,
          source: "sim",
        }, io);
      }

      // Nodes 1 and 2 send high readings in three consecutive samples -> both enter WARNING
      for (let step = 0; step < 3; step++) {
        await fusionEngine.processPacket({
          deviceId: "1",
          tempC: 25.0 + step * 3.0,
          humidityPct: 50 - step * 5,
          smokeRaw: 1800 + step * 250,
          seqNo: 400 + step,
          batteryPct: 92,
          source: "sim",
        }, io);

        await fusionEngine.processPacket({
          deviceId: "2",
          tempC: 26.0 + step * 3.2,
          humidityPct: 48 - step * 5,
          smokeRaw: 1950 + step * 200,
          seqNo: 500 + step,
          batteryPct: 91,
          source: "sim",
        }, io);
      }

      return res.json({
        success: true,
        message: "Consensus-fire scenario applied: Nodes 1 and 2 issued WARNING in zone-alpha simultaneously (2/2 = minNodesForFire met) → Red FIRE alert triggered; simulated drone launch started!",
      });
    }

    res.status(400).json({ success: false, message: "Unknown scenario. Options: normal, single_warning, consensus_fire" });
  } catch (error) {
    next(error);
  }
};

// Backward compatibility for the legacy simulate method
exports.simulateData = exports.simulateScenario;
