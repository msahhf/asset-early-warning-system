const Device = require("../models/Device");
const SensorLog = require("../models/SensorLog");
const Alert = require("../models/Alert");
const NotificationService = require("../services/notificationService");
const RedisService = require("../services/redisService");
const logger = require("../utils/logger");

// ── Middleware: IoT ApiKey Doğrulama ──────────────────
exports.verifyApiKey = async (req, res, next) => {
  try {
    const apiKey = req.headers["x-api-key"];

    if (!apiKey) {
      return res.status(401).json({ success: false, message: "API anahtarı eksik." });
    }

    // Gerçekte Redis'ten cihaz getirmek performans artırır ancak apiKey güvenliği DB gerektirebilir
    const device = await Device.findOne({ apiKey }).select("+apiKey").populate("owner contacts");

    if (!device) {
      return res.status(401).json({ success: false, message: "Geçersiz API anahtarı." });
    }

    req.device = device;
    next();
  } catch (error) {
    next(error);
  }
};

// ── POST /api/sensors/heartbeat ────────────────────────
exports.heartbeat = async (req, res, next) => {
  try {
    const device = req.device;
    const { batteryLevel } = req.body;

    // Redis ile heartbeat güncellemesi gerçekleştirilir (DB'yi yormamak için çok önemli)
    await RedisService.updateDeviceStatus(device.deviceId, { 
      isOnline: true, 
      batteryLevel: batteryLevel || device.batteryLevel 
    });

    const wasOffline = !device.isOnline;
    if (wasOffline) {
      device.isOnline = true;
      device.lastHeartbeat = new Date();
      if (batteryLevel !== undefined) device.batteryLevel = batteryLevel;
      await device.save();

      // Socket.io ile dashboard'a bildir
      const io = req.app.get("io");
      if (io) {
        io.to(device._id.toString()).emit("device_status", {
          deviceId: device.deviceId,
          isOnline: true,
          lastHeartbeat: device.lastHeartbeat,
          batteryLevel
        });
      }
      logger.info(`🟢 Cihaz çevrimiçi: ${device.name}`);
    }

    res.json({ success: true, message: "Heartbeat alındı." });
  } catch (error) {
    next(error);
  }
};

// ── POST /api/sensors/data ─────────────────────────────
exports.uploadSensorData = async (req, res, next) => {
  try {
    const device = req.device;
    const { mq2Value, temperature, humidity, batteryLevel } = req.body;

    if (mq2Value === undefined || mq2Value === null) {
      return res.status(400).json({ success: false, message: "mq2Value zorunludur." });
    }

    const gasStatus = SensorLog.calculateGasStatus(mq2Value);

    // 1. Redis Tamponlama ve Canlı Güncelleme
    await RedisService.updateDeviceStatus(device.deviceId, {
      mq2Value, temperature, humidity, batteryLevel, gasStatus, isOnline: true
    });

    // 2. Veritabanına Log Yazma (Tarihçe)
    const log = await SensorLog.create({
      device: device._id,
      mq2Value, temperature, humidity, gasStatus, rawPayload: req.body,
    });

    // ── Gelişmiş Alarm Mantığı (Sadece Yangın/Gaz) ──────
    const io = req.app.get("io");

    if (gasStatus === "danger") {
      const type = "fire";
      const existingAlert = await Alert.findOne({
        device: device._id,
        type,
        resolvedAt: null,
      });

      if (!existingAlert) {
        const message = `🔥 YANGIN! Yüksek gaz/duman (MQ-2: ${mq2Value}) — ${device.name} (${device.location})`;

        const alert = await Alert.create({
          device: device._id,
          type,
          message,
          triggerValue: mq2Value,
          sensorSnapshot: { mq2Value, temperature, humidity }
        });

        device.hasActiveAlert = true;
        await device.save();

        // ── Push Notification (FCM) Gönderimi ──
        const usersToNotify = [device.owner, ...(device.contacts || [])];
        const pushUsers = usersToNotify.filter(u => u && u.fcmToken);
        
        if (pushUsers.length > 0) {
          let successCount = 0;
          for (const user of pushUsers) {
            const success = await NotificationService.sendPushNotification(
              user.fcmToken,
              "🔥 YANGIN ALARMI",
              message,
              { alertId: alert._id.toString(), deviceId: device.deviceId, type }
            );
            if (success) successCount++;
          }
          alert.notificationStatus = successCount > 0 ? "sent" : "failed";
          alert.notifiedUsers = pushUsers.map(u => u._id);
          await alert.save();
        }

        // TODO: Twilio SMS Gönderimi ileride buraya eklenebilir (NotificationService.sendSMS)
        
        // Socket Yayını
        if (io) {
          io.to(device._id.toString()).emit("alert_triggered", {
            deviceId: device.deviceId,
            type,
            message,
            timestamp: alert.createdAt,
          });
        }
        logger.warn(`${message}`);
      }
    } else if (gasStatus === "safe" && device.hasActiveAlert) {
      // Yangın kalmadı, aktif alarmları kapat
      const openAlerts = await Alert.find({ device: device._id, resolvedAt: null });
      if (openAlerts.length > 0) {
        await Alert.updateMany(
          { device: device._id, resolvedAt: null },
          { resolvedAt: new Date() }
        );
        device.hasActiveAlert = false;
        await device.save();

        if (io) {
          io.to(device._id.toString()).emit("alert_triggered", {
            deviceId: device.deviceId,
            type: "recovered",
            message: `✅ Tehlike geçti — ${device.name}`,
            timestamp: new Date(),
          });
        }
      }
    }

    // Socket.io Canlı Dashboard Yayını
    if (io) {
      io.to(device._id.toString()).emit("sensor_update", {
        deviceId: device.deviceId,
        mq2Value,
        temperature,
        humidity,
        gasStatus,
        batteryLevel,
        timestamp: log.timestamp,
      });
    }

    res.json({ success: true, message: "Veri alındı ve işlendi.", gasStatus, logId: log._id });
  } catch (error) {
    next(error);
  }
};
