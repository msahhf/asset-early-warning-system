const mongoose = require("mongoose");
const logger = require("../utils/logger");

const connectDB = async () => {
  try {
    const conn = await mongoose.connect(process.env.MONGODB_URI, {
      serverSelectionTimeoutMS: 5000,
      socketTimeoutMS: 45000,
    });

    logger.info(`✅ Connected to MongoDB: ${conn.connection.host}`);

    mongoose.connection.on("disconnected", () => {
      logger.warn("⚠️  MongoDB connection lost. Reconnecting...");
    });

    mongoose.connection.on("reconnected", () => {
      logger.info("✅ Reconnected to MongoDB.");
    });
  } catch (error) {
    logger.error(`❌ MongoDB connection error: ${error.message}`);
    process.exit(1);
  }
};

module.exports = connectDB;
