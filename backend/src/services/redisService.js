const { getRedisClient } = require("../config/redis");
const logger = require("../utils/logger");

/**
 * Stores device status in Redis (heartbeat/cache buffer).
 * This prevents per-second sensor logs from overloading MongoDB.
 */
class RedisService {
  /**
   * @param {string} deviceId Device UUID
   * @param {object} sensorData Sensor data (gas_mq2, temperature, etc.)
   */
  static async updateDeviceStatus(deviceId, sensorData) {
    try {
      const client = getRedisClient();
      const key = `device:${deviceId}:status`;

      const payload = {
        lastSeen: Date.now(),
        ...sensorData,
      };

      // After five minutes, the device expires from Redis and can be considered offline
      // or it could be kept permanently and checked via lastSeen. Use a five-minute TTL:
      await client.set(key, JSON.stringify(payload), {
        EX: 300, 
      });

      return true;
    } catch (err) {
      logger.error(`Redis updateDeviceStatus error: ${err.message}`);
      return false;
    }
  }

  /**
   * Gets the device's last known status from Redis
   */
  static async getDeviceStatus(deviceId) {
    try {
      const client = getRedisClient();
      const key = `device:${deviceId}:status`;
      const data = await client.get(key);
      return data ? JSON.parse(data) : null;
    } catch (err) {
      logger.error(`Redis getDeviceStatus error: ${err.message}`);
      return null;
    }
  }

  /**
   * Gets all online devices (scans keys; sets/hashes are preferable in production)
   */
  static async getAllOnlineDevices() {
    try {
      const client = getRedisClient();
      // Uses a key pattern for this simple prototype (use SCAN with many devices)
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
      logger.error(`Redis getAllOnlineDevices error: ${err.message}`);
      return [];
    }
  }
}

module.exports = RedisService;
