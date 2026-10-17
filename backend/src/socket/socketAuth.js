const logger = require("../utils/logger");
const { isAdminKeyConfigured, verifyAdminKeyCandidate } = require("../middleware/adminAuth");

/**
 * Socket.IO oda isimleri:
 * - ADMIN_ROOM: handshake'te geçerli ADMIN_API_KEY doğrulayan bağlantılar.
 *   Tüm korumalı yayınlar (alert:*, node:*, sensor:update, config:updated,
 *   device_status) yalnız bu odaya gider.
 * - PUBLIC_ROOM: anahtarsız bağlantılar; yalnız public yangın özeti
 *   (public:fire) alır. Düğüm kimliği/konumu, ölçüm ve yönetim olayları
 *   bu odaya ASLA yayınlanmaz.
 */
const ADMIN_ROOM = "admin";
const PUBLIC_ROOM = "public-summary";

let warnedMissingKey = false;
let warnedInvalidKey = false;

/**
 * Handshake kimlik doğrulama middleware'i.
 * - ADMIN_API_KEY tanımsızsa: TÜM bağlantılar reddedilir;
 *   anahtar tanımsızken hiçbir bağlantı kurulamaz.
 * - auth payload'ındaki `key` alanı doğrulanırsa ADMIN_ROOM'a alınır.
 * - Anahtar GÖNDERİLMEDİĞİNDE bağlantı public istemci olarak kabul edilir
 *   (yalnız public:fire özeti); korumalı olaylara iştirak edemez.
 * - Anahtar GÖNDERİLDİĞİNDE geçersizse bağlantı reddedilir (hata metni
 *   anahtarın kendisini içermez).
 * - CORS bu kimlik doğrulama yerine kullanılmaz; yetki tamamen bu
 *   middleware + oda ayrımından gelir.
 */
function adminSocketAuth(socket, next) {
  if (!isAdminKeyConfigured()) {
    if (!warnedMissingKey) {
      logger.error("ADMIN_API_KEY tanımlı değil: Socket.IO bağlantıları tüm ortamlarda reddediliyor.");
      warnedMissingKey = true;
    }
    return next(new Error("Sunucu yapılandırma hatası: ADMIN_API_KEY tanımlı değil, Socket.IO erişimi kapalı."));
  }

  // Anahtar handshake'teki auth payload'ından okunur; URL/query kullanılmaz.
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
    logger.warn("Socket.IO handshake reddi: geçersiz admin anahtarı (bağlantı reddedildi).");
    warnedInvalidKey = true;
  }
  return next(new Error("Yetkisiz Erişim: Geçersiz admin anahtarı."));
}

module.exports = { adminSocketAuth, ADMIN_ROOM, PUBLIC_ROOM };
