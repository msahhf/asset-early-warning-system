const logger = require("../utils/logger");

const initSocket = (io) => {
  io.on("connection", (socket) => {
    logger.info(`🟢 Yeni Dashboard Socket bağlantısı: ${socket.id}`);

    socket.emit("connected", {
      status: "connected",
      time: new Date(),
      message: "ASSET NOC Core Socket.io bağlı.",
    });

    // Cihaz odaya katılma talebi (Örn: dashboard izleme)
    socket.on("join_device_room", (deviceId) => {
      socket.join(deviceId);
      logger.debug(`Socket ${socket.id} joined room: ${deviceId}`);
    });

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
