const { ADMIN_ROOM, PUBLIC_ROOM } = require("./socketAuth");

/**
 * Room-aware Socket.IO broadcast helpers.
 *
 * emitAdmin: sends protected events only to connections that validated ADMIN_API_KEY
 * during the handshake (ADMIN_ROOM). Unauthorized public sockets
 * cannot receive them; protection relies on room separation, not CORS.
 *
 * emitPublicFire: sends the public fire summary (fireActive/fireAlertZoneCount)
 * only to keyless PUBLIC_ROOM sockets. The payload contains no node
 * identity/location, sensor measurements, or administrative information.
 *
 * Silently skips when the io parameter is null/undefined (same behavior as
 * non-HTTP call paths: `if (io)`).
 */
const emitAdmin = (io, event, payload) => {
  if (!io) return;
  io.to(ADMIN_ROOM).emit(event, payload);
};

const emitPublicFire = (io, summary) => {
  if (!io) return;
  io.to(PUBLIC_ROOM).emit("public:fire", summary);
};

module.exports = { emitAdmin, emitPublicFire };
