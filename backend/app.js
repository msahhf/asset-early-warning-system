require("dotenv").config();
const express = require("express");
const cors = require("cors");
const helmet = require("helmet");
const morgan = require("morgan");
const rateLimit = require("express-rate-limit");

const { errorHandler, notFound } = require("./src/utils/errorHandler");
const logger = require("./src/utils/logger");
const path = require("path");

const app = express();

// ── Güvenlik başlıkları ────────────────────────────────
app.use(helmet());

// ── CORS ──────────────────────────────────────────────
const allowedOrigins = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(",").map((o) => o.trim())
  : ["http://localhost:3000", "http://localhost:5173"];

app.use(
  cors({
    origin: (origin, callback) => {
      if (!origin || allowedOrigins.includes(origin)) {
        callback(null, true);
      } else {
        callback(new Error(`CORS: '${origin}' izin verilmiyor.`));
      }
    },
    credentials: true,
  })
);

// ── Genel rate limiting ────────────────────────────────
app.use(
  "/api",
  rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 500,
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, message: "Çok fazla istek. Lütfen bekleyin." },
  })
);

// ── Body parsing ──────────────────────────────────────
app.use(express.json({ limit: "10kb" }));
app.use(express.urlencoded({ extended: false }));

// ── Bellek İçi İstek Günlüğü (Dashboard için) ─────────
const requestLogs = [];
app.use((req, res, next) => {
  // Frontend/Dashboard isteklerini kütükten gizle
  if (req.path !== "/" && req.path !== "/api/sysinfo" && !req.path.startsWith("/favicon")) {
    requestLogs.unshift({
      time: new Date().toISOString(),
      method: req.method,
      url: req.originalUrl,
      ip: req.ip || req.connection.remoteAddress || "Unknown"
    });
    // Sadece son 50 isteği tut
    if (requestLogs.length > 50) requestLogs.pop();
  }
  next();
});

// ── HTTP loglama ──────────────────────────────────────
if (process.env.NODE_ENV !== "test") {
  app.use(
    morgan("combined", {
      stream: { write: (message) => logger.info(message.trim()) },
    })
  );
}

const mongoose = require("mongoose");
const { getRedisClient } = require("./src/config/redis");

// ── Sağlık kontrolü (UptimeRobot Endpoint) ────────────────
app.get("/api/health", async (_req, res) => {
  let dbStatus = "disconnected";
  if (mongoose.connection && mongoose.connection.readyState === 1) {
    dbStatus = "connected";
  }

  let redisConnection = "disconnected";
  try {
    const client = getRedisClient();
    if (client.isReady) {
      redisConnection = "connected";
    }
  } catch (e) {
    // Client is not initialized yet
  }

  const isHealthy = dbStatus === "connected" && redisConnection === "connected";

  res.status(isHealthy ? 200 : 503).json({
    success: isHealthy,
    status: isHealthy ? "ok" : "error",
    service: "ASSET Backend API v2",
    timestamp: new Date().toISOString(),
    uptime: Math.floor(process.uptime()),
    database: dbStatus,
    redis: redisConnection
  });
});

// ── Karşılama (Root Dashboard) ────────────────────────
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

// Dashboard için verileri döndüren endpoint
app.get("/api/sysinfo", (req, res) => {
  res.status(200).json({
    uptime: process.uptime(),
    memoryUsage: process.memoryUsage(),
    requests: requestLogs,
  });
});

// ── API Rotaları ──────────────────────────────────────
const sensorRoutes = require("./src/routes/sensorRoutes");
app.use("/api/sensors", sensorRoutes);
// app.use("/api/devices", require("./src/routes/deviceRoutes")); // TODO
// app.use("/api/alerts", require("./src/routes/alertRoutes"));   // TODO

// ── 404 ve Hata yakalayıcılar ────────────────────────
app.use(notFound);
app.use(errorHandler);

module.exports = app;
