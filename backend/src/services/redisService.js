const { getRedisClient } = require("../config/redis");
const logger = require("../utils/logger");

/**
 * Cihazın durumunu Redis'e kaydeder (Heartbeat/Cache buffer).
 * Böylece saniyede gelen sensör logları MongoDB'yi yormaz.
 */
class RedisService {
  /**
   * @param {string} deviceId Cihazın UUID'si
   * @param {object} sensorData Sensör verisi (gas_mq2, temperature, vb.)
   */
  static async updateDeviceStatus(deviceId, sensorData) {
    try {
      const client = getRedisClient();
      const key = `device:${deviceId}:status`;

      const payload = {
        lastSeen: Date.now(),
        ...sensorData,
      };

      // 5 dakika süresi dolarsa cihaz ofline sayılmak üzere Redis'ten düşer
      // veya kalıcı tutup lastSeen'e bakabiliriz. Biz 5 dk TTL koyalım:
      await client.set(key, JSON.stringify(payload), {
        EX: 300, 
      });

      return true;
    } catch (err) {
      logger.error(`Redis updateDeviceStatus hatası: ${err.message}`);
      return false;
    }
  }

  /**
   * Cihazın son bilinen durumunu Redis'ten getirir
   */
  static async getDeviceStatus(deviceId) {
    try {
      const client = getRedisClient();
      const key = `device:${deviceId}:status`;
      const data = await client.get(key);
      return data ? JSON.parse(data) : null;
    } catch (err) {
      logger.error(`Redis getDeviceStatus hatası: ${err.message}`);
      return null;
    }
  }

  /**
   * Bütün online cihazların listesini alır (Keys tarayarak, production'da sets/hashes daha iyidir)
   */
  static async getAllOnlineDevices() {
    try {
      const client = getRedisClient();
      // Basit prototip için keys pattern kullanımı (Çok cihazda SCAN kullanılmalı)
      const keys = await client.keys("device:*:status");
      const devices = [];

      for (const key of keys) {
        const data = await client.get(key);
        if (data) {
          const deviceId = key.split(":")[1];
          devices.push({ deviceId, ...JSON.parse(data) });
        }
      }
      return devices;
    } catch (err) {
      logger.error(`Redis getAllOnlineDevices hatası: ${err.message}`);
      return [];
    }
  }
}

module.exports = RedisService;
