const { ADMIN_ROOM, PUBLIC_ROOM } = require("./socketAuth");

/**
 * Oda-farkında Socket.IO yayın yardımcıları.
 *
 * emitAdmin: korumalı olayları yalnız handshake'te geçerli ADMIN_API_KEY
 * doğrulamış (ADMIN_ROOM) bağlantılara gönderir. Yetkisiz (public) socketler
 * bunlara asla iştirak edemez — koruma CORS'a değil, oda ayrımına dayanır.
 *
 * emitPublicFire: public yangın ÖZETİNİ (fireActive/fireAlertZoneCount)
 * yalnız anahtarsız PUBLIC_ROOM socketlerine gönderir. Payload düğüm
 * kimliği/konumu, sensör ölçümü veya yönetim bilgisi İÇERMEZ.
 *
 * io parametresi null/undefined ise sessizce atlanır (HTTP olmayan çağrı
 * yolları ile aynı davranış: `if (io)`).
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
