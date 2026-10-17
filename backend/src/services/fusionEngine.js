const Device = require("../models/Device");
const SensorLog = require("../models/SensorLog");
const Alert = require("../models/Alert");
const ThresholdConfig = require("../models/ThresholdConfig");
const logger = require("../utils/logger");
const { getNodePosition, HANGAR } = require("../config/nodePositions");
const { emitAdmin, emitPublicFire } = require("../socket/broadcast");

class FusionEngine {
  constructor() {
    // Cihaz bazlı son N okuma tamponu: { [deviceId]: [ { timestamp, tempC, humidityPct, smokeRaw, seqNo } ] }
    this.deviceWindows = new Map();
    // Aktif node warning durumu ve zamanı: { [deviceId]: { timestamp, zoneId, flags } }
    this.activeNodeWarnings = new Map();
    // Zon bazlı son FIRE alarm zamanı: { [zoneId]: timestamp }
    this.zoneCooldowns = new Map();
    // Aktif açık yangın alarmları: { [zoneId]: alertDoc }
    this.activeZoneFireAlerts = new Map();
  }

  /**
   * Senaryo testleri başlamadan önce warning state'ini temizler.
   * İsteğe bağlı deviceIds listesi verilirse sadece o node'ların warning'lerini siler;
   * verilmezse tüm aktif warning'leri temizler.
   * @param {string[] | undefined} deviceIds
   */
  clearNodeWarnings(deviceIds) {
    if (deviceIds && deviceIds.length > 0) {
      deviceIds.forEach((id) => this.activeNodeWarnings.delete(String(id)));
      logger.info(`[FusionEngine] Warning state temizlendi: [${deviceIds.join(", ")}]`);
    } else {
      const count = this.activeNodeWarnings.size;
      this.activeNodeWarnings.clear();
      logger.info(`[FusionEngine] Tüm warning state'leri temizlendi (${count} kayıt).`);
    }
  }

  /**
   * Restart sonrası durum geri yükleme (rehydration):
   * Bellek Map'leri boşalır ama MongoDB'de resolved:false alarm kayıtları kalır.
   * Bu kayıtlar geri yüklenmezse dashboard, motor belleği temiz olsa bile
   * "FIRE" göstermeye devam eder (getNodesOverview DB'den okur).
   * - Her zon için EN YENİ açık alarm activeZoneFireAlerts'a yüklenir.
   * - zoneCooldowns, alarmın createdAt zamanından geri kurulur; böylece
   *   cooldown hâlâ sürüyorsa alarm yanlışlıkla anında çözülmez ve
   *   cooldown bittiğinde mevcut normal çözülme akışı devreye girer.
   * Fail-fast: hata yutulmaz, çağırana fırlatılır; server.js start()
   * zincirinde listen'den ÖNCE koştuğu için rehydration başarısızsa
   * sunucu istek almaya başlamaz (Başlatma hatası -> process.exit(1)).
   */
  async rehydrateOnStartup() {
    const openAlerts = await Alert.find({ resolved: false }).sort({ createdAt: -1 });
    const seenZones = new Set();
    let rehydrated = 0;

    for (const alert of openAlerts) {
      if (!alert.zoneId || seenZones.has(alert.zoneId)) continue; // zon başına en yeni kayıt
      seenZones.add(alert.zoneId);
      this.activeZoneFireAlerts.set(alert.zoneId, alert);
      if (alert.severity === "fire") {
        // L153 semantiğiyle birebir: cooldown, alarmın açıldığı andan itibaren
        this.zoneCooldowns.set(alert.zoneId, new Date(alert.createdAt).getTime());
      }
      rehydrated++;
      logger.info(
        `[FusionEngine] Rehydrate: zone=${alert.zoneId} alert=${alert.alertId} severity=${alert.severity}`
      );
    }

    if (rehydrated > 0) {
      logger.info(`[FusionEngine] Restart sonrası ${rehydrated} açık alarm geri yüklendi.`);
    }
  }

  /**
   * Cihazın hareketli penceresini günceller ve son okumaları saklar
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
   * Node-seviyesi füzyon analizi:
   * 1. Kayan ortalama duman
   * 2. Isı artış hızı (Delta T / Delta t)
   * 3. Ani nem düşüşü
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

    // 1. Hareketli ortalama duman (son movingAverageSize kadar örnek)
    const windowSize = Math.min(n, config.movingAverageSize || 3);
    const recentSamples = buffer.slice(-windowSize);
    const sumSmoke = recentSamples.reduce((acc, s) => acc + s.smokeRaw, 0);
    const movingAvgSmoke = Math.round(sumSmoke / windowSize);

    // Duman bayrağı: Eşik aşımı son örneklerde var mı?
    const smokeFlag = movingAvgSmoke >= config.smokeThreshold;

    // 2. Isı artış hızı (Delta T / Delta t - °C / saniye)
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

    // 3. Ani nem düşüşü (% Delta H)
    let humidityDropFlag = false;
    if (n >= 2) {
      const oldest = buffer[0];
      const newest = buffer[n - 1];
      const deltaHum = oldest.humidityPct - newest.humidityPct;
      if (deltaHum >= config.humidityDropThresholdPct) {
        humidityDropFlag = true;
      }
    }

    // Node seviyesi WARNING kuralı:
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
   * Zon seviyesi konsensüs analizi:
   * Aynı zoneId'ye sahip node'ların son windowSeconds içindeki warning durumlarını inceler.
   * FIRE için aynı zon içinde en az minNodesForFire adet node WARNING'de olmalıdır.
   */
  async _evaluateZoneConsensus(zoneId, config, io) {
    const now = Date.now();
    const windowMs = (config.windowSeconds || 45) * 1000;

    // Zon içindeki ve zaman penceresinde geçerli olan warning'leri bul
    const triggeringDeviceIds = [];
    for (const [dId, warningData] of this.activeNodeWarnings.entries()) {
      if (warningData.zoneId === zoneId && now - warningData.timestamp <= windowMs) {
        triggeringDeviceIds.push(dId);
      } else if (now - warningData.timestamp > windowMs) {
        // Süresi dolan warning'i temizle
        this.activeNodeWarnings.delete(dId);
      }
    }

    const minNodes = config.minNodesForFire || 2;
    const cooldownMs = (config.cooldownSeconds || 180) * 1000;
    const lastFireTime = this.zoneCooldowns.get(zoneId) || 0;
    const isInCooldown = now - lastFireTime < cooldownMs;

    logger.debug(
      `[Consensus] Zone: ${zoneId}, Aktif Warning: ${triggeringDeviceIds.length}/${minNodes} (gerekli), Cooldown: ${isInCooldown}`
    );

    // KONSENSÜS: En az minNodes adet node WARNING verdiyse -> FIRE
    if (triggeringDeviceIds.length >= minNodes) {
      if (!isInCooldown) {
        // Yeni FIRE Alarmı Tetikle!
        this.zoneCooldowns.set(zoneId, now);

        // Zon merkez koordinatını nodePositions'dan hesapla
        const zoneDevices = await Device.find({ zoneId });
        let centerLat = HANGAR.lat;
        let centerLng = HANGAR.lng;
        if (zoneDevices.length > 0) {
          const fallback = getNodePosition("1");
          centerLat = zoneDevices.reduce((acc, d) => acc + (d.coordinates?.lat || fallback.lat), 0) / zoneDevices.length;
          centerLng = zoneDevices.reduce((acc, d) => acc + (d.coordinates?.lng || fallback.lng), 0) / zoneDevices.length;
        }

        const alertMessage = `🚨 YANGIN ALARMI! ${zoneId.toUpperCase()} bölgesinde ${triggeringDeviceIds.length} node konsensüsü ile yangın doğrulandı!`;

        // Yeni alarm açılmadan önce aynı zondaki eski açık (resolved:false)
        // kayıtları kapat; aksi halde restart/rehydrate sonrası yetim kayıtlar
        // nodes-overview'da açık kalır.
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

        // İlgili cihazların durumunu "fire" yap
        await Device.updateMany(
          { deviceId: { $in: triggeringDeviceIds } },
          { status: "fire", hasActiveAlert: true }
        );

        // Socket.io: alert:fire yayını (Drone simülasyonunu ve kırmızı alarmı tetikler)
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
          // Korumalı olay yalnız admin odasına; public tarafına yalnız özet gider.
          emitAdmin(io, "alert:fire", payload);
          const fireAlertCount = await Alert.countDocuments({ resolved: false, severity: "fire" });
          emitPublicFire(io, { fireActive: fireAlertCount > 0, fireAlertZoneCount: fireAlertCount });
          logger.warn(`🔥 KONSENSÜS FIRE ALARMI YAYILDI: ${zoneId} (${triggeringDeviceIds.join(", ")})`);
        }

        return { status: "fire", alert: alertDoc };
      } else {
        logger.info(`⏳ Cooldown süresi devrede (${zoneId}), tekrar alarm oluşturulmadı.`);
        return { status: "fire_cooldown" };
      }
    } else {
      // Yangın şartı sağlanmadı veya söndü/normale döndü
      const activeAlert = this.activeZoneFireAlerts.get(zoneId);
      if (activeAlert && !isInCooldown) {
        // Cooldown bitti ve konsensüs düştü -> Normale dön (RESOLVED)
        const resolvedAt = new Date();
        activeAlert.resolved = true;
        activeAlert.resolvedAt = resolvedAt;
        await activeAlert.save();

        // Aynı zondaki diğer tüm açık (resolved:false) kayıtları da kapat:
        // birden fazla açık alarm varsa (ör. çift tetikleme veya eski yetim
        // kayıtlar) hiçbiri nodes-overview yanıtında açık kalmasın.
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
            message: `✅ ${zoneId.toUpperCase()} bölgesinde tehlike geçti, durum normale döndü.`,
            resolvedAt,
          });
          // Çözüm sonrası güncel aktif yangın sayısı: çok bölgeli alarmlarda
          // özet doğru düşsün (semantik /api/public/status ile aynı).
          const fireAlertCount = await Alert.countDocuments({ resolved: false, severity: "fire" });
          emitPublicFire(io, { fireActive: fireAlertCount > 0, fireAlertZoneCount: fireAlertCount });
        }
        logger.info(`✅ Yangın alarmı çözüldü: ${zoneId}`);
      }
      return { status: triggeringDeviceIds.length > 0 ? "warning" : "normal" };
    }
  }

  /**
   * Ana Veri İşleme Noktası (Hub veya Bridge üzerinden gelen paket)
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

    // 1. Cihazı bul veya otomatik oluştur (Self-register)
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

    // Paket kaybı hesabı (seqNo üzerinden)
    let packetsLostIncrement = 0;
    if (device.lastSeq > 0 && seqNo > device.lastSeq + 1) {
      packetsLostIncrement = seqNo - device.lastSeq - 1;
    }

    // 2. Hareketli pencereyi güncelle ve Node füzyon analizi yap
    const buffer = this._updateDeviceBuffer(String(deviceId), {
      timestamp: timestamp.getTime(),
      tempC: Number(tempC),
      humidityPct: Number(humidityPct),
      smokeRaw: Number(smokeRaw),
      seqNo: Number(seqNo),
    });

    const fusion = this._analyzeNodeFusion(buffer, config);

    // 3. Node durumu güncelleme
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

      // Socket.io: node:warning yayını
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

    // 4. Zon Seviyesi Konsensüs Denetimi
    const consensusResult = await this._evaluateZoneConsensus(device.zoneId, config, io);
    if (consensusResult.status === "fire" || consensusResult.status === "fire_cooldown") {
      nodeStatus = "fire";
    }

    // 5. Cihaz dokümanını güncelle
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

    // 6. SensorLog oluştur
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

    // 7. Socket.io: sensor:update (Tüm dashboard grafiklerini ve göstergelerini besler)
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
