const logger = require("../utils/logger");

const initSocket = (io) => {
  io.on("connection", (socket) => {
    logger.info(`🟢 Yeni Socket bağlantısı: ${socket.id}`);

    // Cihaz odaya katılma talebi (Örn: dashboard izleme)
    socket.on("join_device_room", (deviceId) => {
      socket.join(deviceId);
      logger.debug(`Socket ${socket.id} joined room: ${deviceId}`);
    });

    // Cihaz odasından ayrılma
    socket.on("leave_device_room", (deviceId) => {
      socket.leave(deviceId);
      logger.debug(`Socket ${socket.id} left room: ${deviceId}`);
    });

    socket.on("disconnect", () => {
      logger.info(`🔴 Socket ayrıldı: ${socket.id}`);
    });
  });
};

module.exports = initSocket;
