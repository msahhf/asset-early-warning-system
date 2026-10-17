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
  logger.error("INGEST_API_KEY tanımlı değil, .env dosyasını kontrol edin.");
  process.exit(1);
}

// ── CRC-8 (Dallas/Maxim) Yardımcısı ──────────────────
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
    throw new Error(`Geçersiz paket uzunluğu: ${buf.length} bayt (En az 13 bayt bekleniyor)`);
  }

  const payloadBuf = buf.subarray(0, 12);
  const receivedCrc = buf[12];
  const computedCrc = calculateCrc8(payloadBuf);

  if (receivedCrc !== computedCrc) {
    logger.warn(`⚠️ CRC-8 Uyuşmazlığı! Gelen: 0x${receivedCrc.toString(16)}, Hesaplanan: 0x${computedCrc.toString(16)}`);
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

// ── Middleware: IoT & Bridge ApiKey Doğrulama ──
exports.verifyApiKey = async (req, res, next) => {
  try {
    // Anahtar yalnızca başlıktan okunur. Sorgu dizesi (query) desteği
    // bilinçli kaldırıldı: URL'de taşınan anahtar morgan HTTP loglarına ve
    // istek günlüğüne sızar. (bridge.js ve simulate_scenarios.js zaten
    // x-api-key başlığı kullanır — alt ajan incelemesi doğruladı.)
    const apiKey = req.headers["x-api-key"];
    const masterKey = process.env.INGEST_API_KEY;

    // 1. Master Ingest Key kontrolü (Bridge veya yetkili donanım çağrısı)
    if (apiKey && apiKey === masterKey) {
      req.isMasterIngest = true;
      return next();
    }

    // 2. Cihaza özel API anahtarı kontrolü (MongoDB Device)
    if (apiKey) {
      const device = await Device.findOne({ apiKey }).select("+apiKey").populate("owner contacts");
      if (device) {
        req.device = device;
        return next();
      }
    }

    // 3. Geçersiz veya eksik anahtar
    return res.status(401).json({
      success: false,
      message: "Yetkisiz Erişim (401): Geçerli bir X-API-KEY başlığı gereklidir.",
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

    res.json({ success: true, message: "Heartbeat alındı." });
  } catch (error) {
    next(error);
  }
};

// ── POST /api/sensors/ingest (PC Bridge / Hub Veri Alma) ─
exports.ingestPacket = async (req, res, next) => {
  try {
    const io = req.app.get("io");
    let packet = req.body;

    // Eğer binary hex geldiyse parse et
    if (req.body.rawHex) {
      packet = parseAssetPacketHex(req.body.rawHex);
    }

    // CRC bilgisi HESAPLANMIŞ ve HATALI olan paketleri reddet.
    // Koşul kesin === false: crcOk alanı yalnızca binary yolda üretilir
    // (rawHex veya bridge'in binary-JSON'ı); CRC bilgisi taşımayan JSON,
    // sim ve metin-fallback akışları (crcOk === undefined) etkilenmez.
    if (packet.crcOk === false) {
      logger.warn(
        `🚫 [Ingest CRC Reddi] deviceId=${packet.deviceId} seq=${packet.seqNo} — CRC-8 uyuşmazlığı, paket füzyona iletilmedi.`
      );
      return res.status(422).json({
        success: false,
        message: "CRC-8 doğrulaması başarısız: paket reddedildi.",
      });
    }

    if (!packet.deviceId) {
      return res.status(400).json({ success: false, message: "deviceId zorunludur." });
    }

    // Fusion ve Consensus motoruna gönder
    const result = await fusionEngine.processPacket({
      deviceId: String(packet.deviceId),
      tempC: packet.tempC !== undefined ? Number(packet.tempC) : (packet.temperature || 24.0),
      humidityPct: packet.humidityPct !== undefined ? Number(packet.humidityPct) : (packet.humidity || 50.0),
      smokeRaw: packet.smokeRaw !== undefined ? Number(packet.smokeRaw) : (packet.mq2Value || 350),
      seqNo: packet.seqNo !== undefined ? Number(packet.seqNo) : 0,
      batteryPct: packet.batteryPct !== undefined ? Number(packet.batteryPct) : (packet.batteryLevel || 100),
      // Veri kaynağını koru: bridge --mock veya sim paketleri kaynak belirtir
      source: packet.source || "hardware",
    }, io);

    res.json(result);
  } catch (error) {
    logger.error("Ingest Packet Hatası:", error);
    next(error);
  }
};

// ── POST /api/sensors/data (Geriye Dönük Uyumluluk) ─────
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

// ── GET /api/config/thresholds (Eşikleri Getir) ───────────
exports.getThresholds = async (req, res, next) => {
  try {
    const config = await ThresholdConfig.getActiveConfig();
    res.json({ success: true, data: config });
  } catch (error) {
    next(error);
  }
};

// ── PUT /api/config/thresholds (Eşikleri Güncelle) ────────
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

    logger.info("⚙️ Eşik değerleri güncellendi:", config.toJSON());
    res.json({ success: true, message: "Eşik değerleri güncellendi.", data: config });
  } catch (error) {
    next(error);
  }
};

// ── GET /api/devices/nodes-overview (Dashboard İçin Tüm Node'lar) ─
exports.getNodesOverview = async (req, res, next) => {
  try {
    // Kayıtlı node sayısı değişkendir; NODE_POSITIONS'daki tüm node ID'leri garanti edilir
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

      // Son 20 sensör kaydı (grafikler için) — sadece gerçek donanım verisi
      const logs = await SensorLog.find({ deviceId: sId })
        .sort({ timestamp: -1 })
        .limit(20)
        .lean();

      nodes.push({
        device: d,
        recentLogs: logs.reverse(),
      });
    }

    // Aktif alarmlar
    const activeAlerts = await Alert.find({ resolved: false })
      .sort({ createdAt: -1 })
      .limit(5);

    const config = await ThresholdConfig.getActiveConfig();

    // Hangar koordinatı merkezi config'den gelir (artık frontend hardcode değil)
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

// ── GET /api/public/status (Herkese Açık Toplu Durum; Anahtarsız) ──
// Yalnızca rozet için gereken toplu bilgi döner: düğüm sayıları ve aktif
// yangın alarmı var/yok sayısı. Koordinat, sensör ölçümü, eşik ve alarm
// ayrıntısı (mesaj/konum/sıcaklık vb.) yanıtla İÇERİLMEZ.
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

// ── POST /api/sensors/simulate-scenario (Dashboard Hızlı Senaryo Testi) ─
exports.simulateScenario = async (req, res, next) => {
  try {
    const io = req.app.get("io");
    const { scenario } = req.body; // 'normal', 'single_warning', 'consensus_fire', 'cooldown'

    logger.info(`🧪 Test Senaryosu Başlatıldı: ${scenario}`);

    // Senaryo başlamadan önce tüm node warning state'lerini temizle.
    // Bu, önceki test oturumundan kalan activeNodeWarnings'in yanlış
    // konsensüs tetiklemesini önler (state-leakage fix).
    fusionEngine.clearNodeWarnings();

    if (scenario === "normal") {
      // Tüm node'lara normal temiz hava verisi gönder
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
      return res.json({ success: true, message: "Senaryo Normal uygulandı. Tüm node'lar yeşil." });
    }

    if (scenario === "single_warning") {
      // Sadece Node 1 yüksek duman ve sıcaklık artışı verir -> WARNING (Sarı)
      // Diğerleri normal kalır -> KONSENSÜS SAĞLANMAZ (minNodesForFire >= 2), Drone kalkmaz!
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

      // Node 1 ardışık 3 örnekle WARNING tetikler; diğer node'lar temiz olduğu için
      // zone-alpha'da sadece 1 WARNING var -> minNodesForFire (2) karşılanmaz -> FIRE yok.
      for (let step = 0; step < 3; step++) {
        await fusionEngine.processPacket({
          deviceId: "1",
          tempC: 24.0 + step * 2.5, // Hızlı sıcaklık artışı!
          humidityPct: 52 - step * 4, // Hızlı nem düşüşü!
          smokeRaw: 1400 + step * 200, // Eşik üstü duman!
          seqNo: 200 + step,
          batteryPct: 94,
          source: "sim",
        }, io);
      }

      return res.json({
        success: true,
        message: "Senaryo Tekli Uyarı uygulandı: Node 1 WARNING (Sarı) oldu ancak konsensüs sağlanamadı — minNodesForFire=2, sadece 1 node WARNING verdi. Drone kalkmadı.",
      });
    }

    if (scenario === "consensus_fire") {
      // Node 1 VE Node 2 aynı anda (Zone-Alpha) yüksek duman ve sıcaklık artışı verir
      // -> zone-alpha'da 2 WARNING -> minNodesForFire=2 -> KONSENSÜS -> FIRE -> Drone!
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

      // Node 1 ve Node 2 ardışık 3 örnekle yüksek değer gönderir -> her ikisi WARNING olur
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
        message: "Senaryo Konsensüs Yangın uygulandı: Node 1 & Node 2 aynı anda zone-alpha'da WARNING verdi (2/2 = minNodesForFire karşılandı) → Kırmızı FIRE alarmı tetiklendi, simüle drone kalkışı başladı!",
      });
    }

    res.status(400).json({ success: false, message: "Bilinmeyen senaryo. Seçenekler: normal, single_warning, consensus_fire" });
  } catch (error) {
    next(error);
  }
};

// Eski simulate metodu uyumluluğu
exports.simulateData = exports.simulateScenario;
