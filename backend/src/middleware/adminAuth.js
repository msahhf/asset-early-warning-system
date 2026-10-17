const crypto = require("crypto");
const logger = require("../utils/logger");

let warnedMissingKey = false;

/**
 * Sabit-zamanlı string karşılaştırma (timing-safe).
 * Uzunluk sızıntısı kabul edilebilir; içerik sızıntısı önlenir.
 */
function safeEqual(a, b) {
  const bufA = Buffer.from(String(a));
  const bufB = Buffer.from(String(b));
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

/**
 * ADMIN_API_KEY'in sunucuda tanımlı olup olmadığı (Socket.IO middleware'i
 * ile HTTP middleware'inin ortak ayrım noktası: tanımsızsa yapılandırma hatası).
 */
function isAdminKeyConfigured() {
  return Boolean(process.env.ADMIN_API_KEY);
}

/**
 * Aday anahtarı sunucuda tanımlı ADMIN_API_KEY ile sabit-zamanlı doğrular.
 * Socket.IO handshake'i ile HTTP admin uçları AYNI karşılaştırma mantığını
 * (safeEqual) kullanır; doğrulama burada tek yerde, kopyası yoktur.
 * Boş/tanımsız aday → false.
 */
function verifyAdminKeyCandidate(candidate) {
  const expected = process.env.ADMIN_API_KEY;
  if (!expected) return false;
  const provided = (candidate || "").toString().trim();
  if (!provided) return false;
  return safeEqual(provided, expected);
}

/**
 * Admin paneli koruma middleware'i.
 * - ADMIN_API_KEY tanımsızsa: TÜM ortamlarda (development dahil) erişim
 *   503 ile reddedilir; anahtar doğrulaması hiçbir ortamda atlanmaz.
 * - Anahtar `x-admin-key` başlığından (alternatif: `Authorization: Bearer`)
 *   okunur; eksik/yanlışsa 401 döner.
 */
function requireAdminKey(req, res, next) {
  if (!isAdminKeyConfigured()) {
    if (!warnedMissingKey) {
      logger.error("ADMIN_API_KEY tanımlı değil: korunan uçlar tüm ortamlarda erişime kapalı.");
      warnedMissingKey = true;
    }
    return res.status(503).json({
      success: false,
      message: "Sunucu yapılandırma hatası: ADMIN_API_KEY tanımlı değil, bu uç erişime kapalı.",
    });
  }

  const provided =
    (req.headers["x-admin-key"] || "").toString().trim() ||
    (req.headers["authorization"] || "").toString().replace(/^Bearer\s+/i, "").trim();

  if (!provided) {
    return res.status(401).json({
      success: false,
      message: "Yetkisiz Erişim (401): x-admin-key başlığı gereklidir.",
    });
  }

  if (!verifyAdminKeyCandidate(provided)) {
    return res.status(401).json({
      success: false,
      message: "Yetkisiz Erişim (401): Geçersiz admin anahtarı.",
    });
  }

  return next();
}

/**
 * Simülasyon uçları için üretim kilidi: NODE_ENV=production iken
 * anahtar doğru olsa bile 403 döner (test uçları sahada kapalıdır).
 * requireAdminKey'den SONRA zincire eklenir.
 */
function simulateGuard(req, res, next) {
  if (process.env.NODE_ENV === "production") {
    return res.status(403).json({
      success: false,
      message: "Simülasyon uçları production ortamında kapalıdır.",
    });
  }
  return next();
}

module.exports = { requireAdminKey, simulateGuard, isAdminKeyConfigured, verifyAdminKeyCandidate };
