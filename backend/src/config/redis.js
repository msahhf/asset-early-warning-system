const redis = require("redis");
const logger = require("../utils/logger");

// Başlangıçta null tanımlıyoruz, connectRedis fonksiyonu ile initialize edilecek.
let redisClient = null;

const connectRedis = async () => {
  if (redisClient) return redisClient;

  redisClient = redis.createClient({
    url: process.env.REDIS_URI || "redis://localhost:6379",
  });

  redisClient.on("error", (err) => {
    logger.error(`❌ Redis bağlantı hatası: ${err.message}`);
  });

  redisClient.on("connect", () => {
    logger.info("✅ Redis bağlandı.");
  });

  redisClient.on("reconnecting", () => {
    logger.warn("⚠️  Redis yeniden bağlanıyor...");
  });

  try {
    await redisClient.connect();
    return redisClient;
  } catch (err) {
    logger.error(`❌ Redis'e bağlanılamadı: ${err.message}`);
    // Uygulamayı durdurmak yerine loglayıp devam edebiliriz veya durdurabiliriz.
    // Redis kritik bir önbellek olduğu için bağlamayı zorluyoruz:
    process.exit(1);
  }
};

const getRedisClient = () => {
  if (!redisClient) {
    throw new Error("Redis henüz başlatılmadı. Lütfen önce connectRedis() çağırın.");
  }
  return redisClient;
};

module.exports = { connectRedis, getRedisClient };
