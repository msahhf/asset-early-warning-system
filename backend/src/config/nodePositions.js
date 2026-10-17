/**
 * ASSET 2.1 — Merkezi Node Konum / Zon Konfigürasyonu
 *
 * Node koordinatları ve hangar konumu buradan okunur.
 * Saha değişikliği için sadece bu dosyayı (veya .env'e eklenecek
 * NODE_POSITIONS_JSON değişkenini) düzenlemek yeterlidir —
 * fusionEngine.js ve sensorController.js bu dosyaya bağımlıdır.
 *
 * .env üzerinden geçersiz kılmak için:
 *   NODE_POSITIONS_JSON='{"1":{"lat":...,"lng":...,"zoneId":"zone-alpha","name":"Node 1"},...}'
 *   HANGAR_LAT=39.9220
 *   HANGAR_LNG=32.8520
 *   HANGAR_NAME="Drone Hangar Alpha"
 */

/**
 * @typedef {{ lat: number, lng: number, zoneId: string, name: string }} NodePosition
 * @typedef {{ lat: number, lng: number, name: string }} HangarPosition
 */

/** @type {Object.<string, NodePosition>} */
const DEFAULT_NODE_POSITIONS = {
  "1": { lat: 39.9208, lng: 32.8541, zoneId: "zone-alpha", name: "ASSET Node #1" },
  "2": { lat: 39.9212, lng: 32.8548, zoneId: "zone-alpha", name: "ASSET Node #2" },
  "3": { lat: 39.9205, lng: 32.8555, zoneId: "zone-alpha", name: "ASSET Node #3" },
  "4": { lat: 39.9195, lng: 32.8530, zoneId: "zone-bravo", name: "ASSET Node #4" },
  "5": { lat: 39.9190, lng: 32.8538, zoneId: "zone-bravo", name: "ASSET Node #5" },
};

/** @type {HangarPosition} */
const DEFAULT_HANGAR = {
  lat: parseFloat(process.env.HANGAR_LAT) || 39.9220,
  lng: parseFloat(process.env.HANGAR_LNG) || 32.8520,
  name: process.env.HANGAR_NAME || "Drone Hangar Alpha",
};

// .env'den JSON override desteği
let NODE_POSITIONS = DEFAULT_NODE_POSITIONS;
if (process.env.NODE_POSITIONS_JSON) {
  try {
    const parsed = JSON.parse(process.env.NODE_POSITIONS_JSON);
    NODE_POSITIONS = parsed;
    console.log("[nodePositions] .env üzerinden konum override yüklendi.");
  } catch (e) {
    console.warn("[nodePositions] NODE_POSITIONS_JSON parse hatası, varsayılan kullanılıyor:", e.message);
  }
}

/**
 * Verilen deviceId için konum bilgisi döner.
 * Bilinmeyen node için zone-alpha merkezine yakın fallback döner.
 * @param {string} deviceId
 * @returns {NodePosition}
 */
function getNodePosition(deviceId) {
  return NODE_POSITIONS[String(deviceId)] || {
    lat: DEFAULT_HANGAR.lat - 0.002,
    lng: DEFAULT_HANGAR.lng + 0.003,
    zoneId: "zone-alpha",
    name: `ASSET Node #${deviceId}`,
  };
}

module.exports = {
  NODE_POSITIONS,
  HANGAR: DEFAULT_HANGAR,
  getNodePosition,
};
