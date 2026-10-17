require("dotenv").config();
const http = require("http");
const { Server } = require("socket.io");
const app = require("./app");
const connectDB = require("./src/config/db");
const { connectRedis } = require("./src/config/redis");
const initSocket = require("./src/socket/socketHandler");
const logger = require("./src/utils/logger");

const PORT = process.env.PORT || 5000;

// ── HTTP Sunucusu ─────────────────────────────────────
const server = http.createServer(app);

// ── Socket.io ─────────────────────────────────────────
const io = new Server(server, {
  cors: {
    origin: (origin, callback) => {
      if (!origin) return callback(null, true);
      const allowed = process.env.ALLOWED_ORIGINS
        ? process.env.ALLOWED_ORIGINS.split(",").map((o) => o.trim())
        : ["http://localhost:3000"];
      if (allowed.includes(origin) || allowed.includes("*") || process.env.NODE_ENV === "development") {
        return callback(null, true);
      }
      return callback(new Error("CORS policy violation"), false);
    },
    methods: ["GET", "POST"],
    credentials: true,
  },
  pingTimeout: 60000,
  pingInterval: 25000,
});

app.set("io", io);

const { initFirebase } = require("./src/config/firebase");

// ── Başlatma ──────────────────────────────────────────
const start = async () => {
  try {
    initFirebase();
    await connectDB();
    await connectRedis(); 
    
    initSocket(io);

    server.listen(PORT, () => {
      logger.info(`🚀 ASSET Backend API çalışıyor: http://localhost:${PORT}`);
      logger.info(`🌍 Ortam: ${process.env.NODE_ENV}`);
    });
  } catch (error) {
    logger.error("Başlatma hatası:", error);
    process.exit(1);
  }
};

// ── Graceful Shutdown ─────────────────────────────────
const shutdown = (signal) => {
  logger.info(`${signal} sinyali alındı. Sunucu kapatılıyor...`);
  server.close(() => {
    logger.info("✅ HTTP sunucusu kapatıldı.");
    process.exit(0);
  });
};

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

start();
