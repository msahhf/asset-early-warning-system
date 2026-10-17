const logger = require("../utils/logger");

const initSocket = (io) => {
  io.on("connection", (socket) => {
    if (socket.data.authed) {
      logger.info(`🟢 Authorized dashboard socket connected: ${socket.id}`);

      socket.emit("connected", {
        status: "connected",
        time: new Date(),
        message: "ASSET NOC Core Socket.io connected.",
      });

      // Device room join request (e.g. dashboard monitoring).
      // Room management is available only to connections with a verified key.
      socket.on("join_device_room", (deviceId) => {
        socket.join(deviceId);
        logger.debug(`Socket ${socket.id} joined room: ${deviceId}`);
      });

      socket.on("leave_device_room", (deviceId) => {
        socket.leave(deviceId);
        logger.debug(`Socket ${socket.id} left room: ${deviceId}`);
      });
    } else {
      // Public (keyless) connection: receives only the public fire summary (public:fire)
      // channel; protected event listeners and room management are unavailable.
      logger.debug(`🟢 Public socket connected: ${socket.id}`);
    }

    socket.on("disconnect", () => {
      logger.info(`🔴 Socket disconnected: ${socket.id}`);
    });
  });
};

module.exports = initSocket;
