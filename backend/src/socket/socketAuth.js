const logger = require("../utils/logger");
const { isAdminKeyConfigured, verifyAdminKeyCandidate } = require("../middleware/adminAuth");

/**
 * Socket.IO oda isimleri:
 * - ADMIN_ROOM: connections that validate ADMIN_API_KEY during the handshake.
 *   All protected broadcasts (alert:*, node:*, sensor:update, config:updated,
 *   device_status) are sent only to this room.
 * - PUBLIC_ROOM: keyless connections; receive only the public fire summary
 *   (public:fire) No node identity/location, measurements, or administrative events
 *   are ever broadcast to this room.
 */
const ADMIN_ROOM = "admin";
const PUBLIC_ROOM = "public-summary";

let warnedMissingKey = false;
let warnedInvalidKey = false;

/**
 * Handshake authentication middleware.
 * - If ADMIN_API_KEY is unset: ALL connections are rejected;
 *   no connection can be established without a configured key.
 * - If the `key` field in the auth payload is valid, the socket joins ADMIN_ROOM.
 * - If NO key is sent, the connection is treated as a public client
 *   (public:fire summary only); it cannot receive protected events.
 * - If a key IS sent but is invalid, the connection is rejected (the error message
 *   does not contain the key itself).
 * - CORS is not used as authentication; authorization is provided by this
 *   middleware and room separation.
 */
function adminSocketAuth(socket, next) {
  if (!isAdminKeyConfigured()) {
    if (!warnedMissingKey) {
      logger.error("ADMIN_API_KEY is not set: Socket.IO connections are rejected in all environments.");
      warnedMissingKey = true;
    }
    return next(new Error("Server configuration error: ADMIN_API_KEY is not set; Socket.IO access is disabled."));
  }

  // The key is read from the handshake auth payload; URL/query parameters are not used.
  const provided = (socket.handshake?.auth?.key || "").toString().trim();

  if (!provided) {
    socket.data.authed = false;
    socket.join(PUBLIC_ROOM);
    return next();
  }

  if (verifyAdminKeyCandidate(provided)) {
    socket.data.authed = true;
    socket.join(ADMIN_ROOM);
    return next();
  }

  if (!warnedInvalidKey) {
    logger.warn("Socket.IO handshake rejected: invalid admin key (connection denied).");
    warnedInvalidKey = true;
  }
  return next(new Error("Unauthorized: invalid admin key."));
}

module.exports = { adminSocketAuth, ADMIN_ROOM, PUBLIC_ROOM };
