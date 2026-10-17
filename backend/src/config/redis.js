const redis = require("redis");
const logger = require("../utils/logger");

let redisClient = null;
let isInMemoryFallback = false;
const memoryStore = new Map();

// Mock Redis client for fallback
const mockRedisClient = {
  isReady: true,
  async connect() { return true; },
  async set(key, value, options) {
    memoryStore.set(key, value);
    if (options && options.EX) {
      setTimeout(() => memoryStore.delete(key), options.EX * 1000);
    }
    return "OK";
  },
  async get(key) {
    return memoryStore.get(key) || null;
  },
  async keys(pattern) {
    const regex = new RegExp("^" + pattern.replace(/\*/g, ".*") + "$");
    const matched = [];
    for (const k of memoryStore.keys()) {
      if (regex.test(k)) matched.push(k);
    }
    return matched;
  },
  async del(key) {
    return memoryStore.delete(key);
  },
};

const connectRedis = async () => {
  if (redisClient) return redisClient;

  // REDIS_URI belirtilmemişse veya 'memory'/'none' ise doğrudan bellek içi fallback kullan
  if (!process.env.REDIS_URI || process.env.REDIS_URI === "none" || process.env.REDIS_URI === "memory") {
    logger.info("ℹ️ Redis URI ayarlanmadı, bellek içi (In-Memory Map) önbellek aktif.");
    isInMemoryFallback = true;
    redisClient = mockRedisClient;
    return redisClient;
  }

  try {
    const client = redis.createClient({
      url: process.env.REDIS_URI,
      socket: {
        connectTimeout: 1000,
        reconnectStrategy: false,
      },
    });

    client.on("error", (err) => {
      if (!isInMemoryFallback) {
        logger.warn(`⚠️ Redis bağlantı uyarısı: ${err.message}`);
      }
    });

    await client.connect();
    logger.info("✅ Redis bağlandı.");
    redisClient = client;
    return redisClient;
  } catch (err) {
    logger.warn(`⚠️ Redis'e bağlanılamadı (${err.message}). Bellek içi (In-Memory) önbellek moduna geçiliyor.`);
    isInMemoryFallback = true;
    redisClient = mockRedisClient;
    return redisClient;
  }
};

const getRedisClient = () => {
  if (!redisClient) {
    return mockRedisClient;
  }
  return redisClient;
};

module.exports = { connectRedis, getRedisClient };
