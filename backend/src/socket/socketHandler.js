const logger = require("../utils/logger");

const initSocket = (io) => {
  io.on("connection", (socket) => {
    if (socket.data.authed) {
      logger.info(`🟢 Yetkili Dashboard Socket bağlantısı: ${socket.id}`);

      socket.emit("connected", {
        status: "connected",
        time: new Date(),
        message: "ASSET NOC Core Socket.io bağlı.",
      });

      // Cihaz odaya katılma talebi (Örn: dashboard izleme).
      // Oda yönetimi yalnız anahtar doğrulamış bağlantılara açıktır.
      socket.on("join_device_room", (deviceId) => {
        socket.join(deviceId);
        logger.debug(`Socket ${socket.id} joined room: ${deviceId}`);
      });

      socket.on("leave_device_room", (deviceId) => {
        socket.leave(deviceId);
        logger.debug(`Socket ${socket.id} left room: ${deviceId}`);
      });
    } else {
      // Public (anahtarsız) bağlantı: yalnız public yangın özeti (public:fire)
      // kanalına üyedir; korumalı olay dinleyicileri ve oda yönetimi verilmez.
      logger.debug(`🟢 Public Socket bağlantısı: ${socket.id}`);
    }

    socket.on("disconnect", () => {
      logger.info(`🔴 Socket ayrıldı: ${socket.id}`);
    });
  });
};

module.exports = initSocket;
