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

// ── HTTP Server ─────────────────────────────────────
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

// Handshake authentication: connections with a key join ADMIN_ROOM; keyless
// connections join PUBLIC_ROOM; if the key is missing or the server is unconfigured, all
// connections are rejected. Protection comes from this middleware and room separation, not CORS.
io.use(adminSocketAuth);

app.set("io", io);

const { initFirebase } = require("./src/config/firebase");

// ── Startup ──────────────────────────────────────────
const REHYDRATE_ATTEMPTS = 3;
const REHYDRATE_RETRY_MS = 2000;

/**
 * Retries rehydration a limited number of times; if all attempts fail,
 * it throws. start() catches the error and exits with process.exit(1), so the server
 * shuts down before accepting requests. (Retry is a process lifecycle decision;
 * fusionEngine remains a pure unit of work.)
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
        `⚠️ Rehydration attempt ${attempt}/${REHYDRATE_ATTEMPTS} failed, ${
          REHYDRATE_RETRY_MS / 1000
        } seconds before retry:`,
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

    // Restore open alerts and cooldown state after restart.
    // Runs BEFORE server.listen; if it fails, the server does not accept requests.
    await rehydrateWithRetry();

    await connectRedis();

    initSocket(io);

    server.listen(PORT, () => {
      logger.info(`🚀 ASSET Backend API is running: http://localhost:${PORT}`);
      logger.info(`🌍 Ortam: ${process.env.NODE_ENV}`);
    });
  } catch (error) {
    logger.error("Startup error:", error);
    process.exit(1);
  }
};

// ── Graceful Shutdown ─────────────────────────────────
const shutdown = (signal) => {
  logger.info(`Received ${signal}. Shutting down the server...`);
  server.close(() => {
    logger.info("✅ HTTP server closed.");
    process.exit(0);
  });
};

process.on("SIGTERM", () => shutdown("SIGTERM"));
process.on("SIGINT", () => shutdown("SIGINT"));

start();
