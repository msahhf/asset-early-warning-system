require("dotenv").config();
const http = require("http");
const { Server } = require("socket.io");
const app = require("./app");
const connectDB = require("./src/config/db");
const { connectRedis } = require("./src/config/redis");
const initSocket = require("./src/socket/socketHandler");
const { adminSocketAuth } = require("./src/socket/socketAuth");
const fusionEngine = require("./src/services/fusionEngine");
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

// Handshake kimlik doğrulama: anahtarlı bağlantı ADMIN_ROOM'a, anahtarsız
// bağlantı PUBLIC_ROOM'a alınır; anahtarsız/yapılandırmamış sunucuda tüm
// bağlantılar reddedilir. Koruma CORS değil, bu middleware + oda ayrımıdır.
io.use(adminSocketAuth);

app.set("io", io);

const { initFirebase } = require("./src/config/firebase");

// ── Başlatma ──────────────────────────────────────────
const REHYDRATE_ATTEMPTS = 3;
const REHYDRATE_RETRY_MS = 2000;

/**
 * Rehydration'ı sınırlı sayıda dener; tüm denemeler başarısız olursa
 * hatayı fırlatır ve start()'ın catch'i process.exit(1) ile sunucuyu
 * istek almadan kapatır. (Retry sürecin yaşam döngüsü kararıdır;
 * fusionEngine saf iş birimi kalır.)
 */
async function rehydrateWithRetry() {
  for (let attempt = 1; attempt <= REHYDRATE_ATTEMPTS; attempt++) {
    try {
      await fusionEngine.rehydrateOnStartup();
      return;
    } catch (error) {
      if (attempt === REHYDRATE_ATTEMPTS) {
        throw error;
      }
      logger.warn(
        `⚠️ Rehydrate deneme ${attempt}/${REHYDRATE_ATTEMPTS} başarısız, ${
          REHYDRATE_RETRY_MS / 1000
        } sn sonra tekrar deneniyor:`,
        error.message
      );
      await new Promise((resolve) => setTimeout(resolve, REHYDRATE_RETRY_MS));
    }
  }
}

const start = async () => {
  try {
    initFirebase();
    await connectDB();

    // Restart sonrası açık alarm + cooldown durumunu geri yükle.
    // server.listen'den ÖNCE çalışır; başarısız olursa sunucu istek almaz.
    await rehydrateWithRetry();

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
