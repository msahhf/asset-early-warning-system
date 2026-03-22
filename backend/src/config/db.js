const mongoose = require("mongoose");
const logger = require("../utils/logger");

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI, {
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
    });

    logger.info(`✅ MongoDB bağlandı: ${conn.connection.host}`);

    mongoose.connection.on("disconnected", () => {
      logger.warn("⚠️  MongoDB bağlantısı kesildi. Yeniden bağlanılıyor...");
    });

    mongoose.connection.on("reconnected", () => {
      logger.info("✅ MongoDB yeniden bağlandı.");
    });
  } catch (error) {
    logger.error(`❌ MongoDB bağlantı hatası: ${error.message}`);
    process.exit(1);
  }
};

module.exports = connectDB;
