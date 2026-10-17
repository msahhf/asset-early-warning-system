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

const { requireAdminKey } = require("./src/middleware/adminAuth");

// ── Security headers (configured for dashboard maps and CDNs) ──
app.use(
  helmet({
    contentSecurityPolicy: false,
    crossOriginEmbedderPolicy: false,
  })
);

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
        callback(new Error(`CORS: '${origin}' is not allowed.`));
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
    skip: (req) => req.originalUrl.startsWith("/api/sensors/ingest") || req.originalUrl.startsWith("/api/sensors/heartbeat"),
    standardHeaders: true,
    legacyHeaders: false,
    message: { success: false, message: "Too many requests. Please wait." },
  })
);

// ── Body parsing ──────────────────────────────────────
app.use(express.json({ limit: "10kb" }));
app.use(express.urlencoded({ extended: false }));

// ── Redact sensitive query values from logs ─────
// Keys are not accepted in URL query strings; as defense in depth,
// any legacy or accidental use that reaches logs is redacted as well.
const SENSITIVE_QUERY_KEYS = ["api_key", "apikey", "admin_key", "adminkey", "token", "password"];
function sanitizeUrl(rawUrl) {
  if (!rawUrl || !rawUrl.includes("?")) return rawUrl;
  const [path, query] = rawUrl.split("?");
  const masked = query
    .split("&")
    .map((pair) => {
      const name = (pair.split("=")[0] || "").toLowerCase();
      return SENSITIVE_QUERY_KEYS.includes(name) ? `${name}=<REDACTED>` : pair;
    })
    .join("&");
  return `${path}?${masked}`;
}

// ── In-memory request log (for the dashboard) ─────────
const requestLogs = [];
app.use((req, res, next) => {
  // Exclude frontend/dashboard requests from the log
  if (req.path !== "/" && req.path !== "/api/sysinfo" && !req.path.startsWith("/favicon")) {
    requestLogs.unshift({
      time: new Date().toISOString(),
      method: req.method,
      url: sanitizeUrl(req.originalUrl),
      ip: req.ip || req.connection.remoteAddress || "Unknown"
    });
    // Keep only the latest 50 requests
    if (requestLogs.length > 50) requestLogs.pop();
  }
  next();
});

// ── HTTP loglama ──────────────────────────────────────
// :url token is overridden; Morgan's "combined" output query string
// is redacted (the combined format uses the :url token).
morgan.token("url", (req) => sanitizeUrl(req.originalUrl));
if (process.env.NODE_ENV !== "test") {
  app.use(
    morgan("combined", {
      stream: { write: (message) => logger.info(message.trim()) },
    })
  );
}

const mongoose = require("mongoose");
const { getRedisClient } = require("./src/config/redis");

// ── Health check (UptimeRobot endpoint) ────────────────
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

// ── Landing page and UI routing ─────────────────
// admin.airdusremote.com veya /admin -> admin.html (Taktik NOC Dashboard)
// / -> index.html (public landing page, onboarding, registration/login)
app.get("/admin", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "admin.html"));
});

app.get("/", (req, res) => {
  const host = (req.headers.host || "").toLowerCase();
  if (host.startsWith("admin.")) {
    return res.sendFile(path.join(__dirname, "public", "admin.html"));
  }
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

// Endpoint returning dashboard data (protected by ADMIN_API_KEY;
// uptime, memory, and the latest 50 requests must not be exposed to unauthorized users)
app.get("/api/sysinfo", requireAdminKey, (req, res) => {
  res.status(200).json({
    uptime: process.uptime(),
    memoryUsage: process.memoryUsage(),
    requests: requestLogs,
  });
});

// ── API routes ──────────────────────────────────────
const sensorRoutes = require("./src/routes/sensorRoutes");
const apiRoutes = require("./src/routes/apiRoutes");
const { getThresholds, updateThresholds, getPublicStatus } = require("./src/controllers/sensorController");

app.get("/api/config/thresholds", requireAdminKey, getThresholds);
app.put("/api/config/thresholds", requireAdminKey, updateThresholds);
// Public aggregate status badge (contains no coordinates, measurements, thresholds, or alert details)
app.get("/api/public/status", getPublicStatus);

app.use("/api/sensors", sensorRoutes);
app.use("/api", apiRoutes);

// ── 404 and error handlers ────────────────────────
app.use(notFound);
app.use(errorHandler);

module.exports = app;
