const crypto = require("crypto");
const logger = require("../utils/logger");

let warnedMissingKey = false;

/**
 * Constant-time string comparison (timing-safe).
 * Length leakage is acceptable; content leakage is prevented.
 */
function safeEqual(a, b) {
  const bufA = Buffer.from(String(a));
  const bufB = Buffer.from(String(b));
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

/**
 * Whether ADMIN_API_KEY is configured on the server (the shared decision point
 * for Socket.IO and HTTP middleware: unset means a configuration error).
 */
function isAdminKeyConfigured() {
  return Boolean(process.env.ADMIN_API_KEY);
}

/**
 * Constant-time validates a candidate key against the server's ADMIN_API_KEY.
 * Socket.IO handshake and HTTP admin endpoints use the SAME comparison logic
 * (safeEqual); validation lives here once, with no duplicate implementation.
 * Empty or unset candidate → false.
 */
function verifyAdminKeyCandidate(candidate) {
  const expected = process.env.ADMIN_API_KEY;
  if (!expected) return false;
  const provided = (candidate || "").toString().trim();
  if (!provided) return false;
  return safeEqual(provided, expected);
}

/**
 * Admin panel protection middleware.
 * - If ADMIN_API_KEY is unset: access is denied in ALL environments (including development)
 *   with 503; key validation is never bypassed.
 * - The key is read from the `x-admin-key` header (or `Authorization: Bearer`)
 *   header; missing or invalid keys return 401.
 */
function requireAdminKey(req, res, next) {
  if (!isAdminKeyConfigured()) {
    if (!warnedMissingKey) {
      logger.error("ADMIN_API_KEY is unset: protected endpoints are disabled in all environments.");
      warnedMissingKey = true;
    }
    return res.status(503).json({
      success: false,
      message: "Server configuration error: ADMIN_API_KEY is unset; this endpoint is disabled.",
    });
  }

  const provided =
    (req.headers["x-admin-key"] || "").toString().trim() ||
    (req.headers["authorization"] || "").toString().replace(/^Bearer\s+/i, "").trim();

  if (!provided) {
    return res.status(401).json({
      success: false,
      message: "Unauthorized (401): x-admin-key header is required.",
    });
  }

  if (!verifyAdminKeyCandidate(provided)) {
    return res.status(401).json({
      success: false,
      message: "Unauthorized (401): Invalid admin key.",
    });
  }

  return next();
}

/**
 * Production lock for simulation endpoints: when NODE_ENV=production,
 * return 403 even if the key is correct (test endpoints are disabled in the field).
 * Add after requireAdminKey in the middleware chain.
 */
function simulateGuard(req, res, next) {
  if (process.env.NODE_ENV === "production") {
    return res.status(403).json({
      success: false,
      message: "Simulation endpoints are disabled in production.",
    });
  }
  return next();
}

module.exports = { requireAdminKey, simulateGuard, isAdminKeyConfigured, verifyAdminKeyCandidate };
