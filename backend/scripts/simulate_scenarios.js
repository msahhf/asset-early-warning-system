/**
 * ASSET 2.0 / 2.1 Sensör Ağı Simülatörü
 * 5 Node için 5 saniyede bir gerçekçi sensör verisi üretir ve Ingest API'ye gönderir.
 * 
 * Kullanım:
 * node simulate_scenarios.js --mode=interactive
 * node simulate_scenarios.js --scenario=consensus_fire
 * node simulate_scenarios.js --scenario=single_warning
 * node simulate_scenarios.js --scenario=normal
 */

const http = require("http");

const BACKEND_URL = process.env.BACKEND_URL || "http://localhost:5000";
const INGEST_PATH = "/api/sensors/ingest";

// 5 Node başlangıç durumları
const nodes = [
  { deviceId: "1", zoneId: "zone-alpha", tempC: 23.0, humidityPct: 52, smokeRaw: 260, seqNo: 1, batteryPct: 98 },
  { deviceId: "2", zoneId: "zone-alpha", tempC: 23.4, humidityPct: 51, smokeRaw: 270, seqNo: 1, batteryPct: 96 },
  { deviceId: "3", zoneId: "zone-alpha", tempC: 22.8, humidityPct: 53, smokeRaw: 250, seqNo: 1, batteryPct: 95 },
  { deviceId: "4", zoneId: "zone-bravo", tempC: 23.1, humidityPct: 50, smokeRaw: 240, seqNo: 1, batteryPct: 92 },
  { deviceId: "5", zoneId: "zone-bravo", tempC: 22.9, humidityPct: 54, smokeRaw: 255, seqNo: 1, batteryPct: 90 },
];

let activeScenario = process.argv.find(arg => arg.startsWith("--scenario="))?.split("=")[1] || "normal";

console.log(`\n======================================================`);
console.log(`🚀 ASSET 2.0 / 2.1 Çoklu Node Simülatörü Başlatıldı`);
console.log(`📡 Hedef Backend: ${BACKEND_URL}${INGEST_PATH}`);
console.log(`🎯 Aktif Senaryo: ${activeScenario.toUpperCase()}`);
console.log(`======================================================\n`);

async function sendPacket(node) {
  return new Promise((resolve) => {
    const postData = JSON.stringify(node);
    const url = new URL(BACKEND_URL + INGEST_PATH);

    const req = http.request(
      {
        hostname: url.hostname,
        port: url.port,
        path: url.pathname,
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Content-Length": Buffer.byteLength(postData),
        },
      },
      (res) => {
        let responseBody = "";
        res.on("data", (chunk) => (responseBody += chunk));
        res.on("end", () => {
          try {
            const parsed = JSON.parse(responseBody);
            resolve({ status: res.statusCode, data: parsed });
          } catch (e) {
            resolve({ status: res.statusCode, data: responseBody });
          }
        });
      }
    );

    req.on("error", (e) => {
      resolve({ status: 500, error: e.message });
    });

    req.write(postData);
    req.end();
  });
}

let tickCount = 0;

async function tick() {
  tickCount++;
  console.log(`\n⏱️ [Döngü #${tickCount}] 5 Node için 5 saniyelik veri yayını yapılıyor...`);

  for (const node of nodes) {
    node.seqNo++;

    if (activeScenario === "normal") {
      // Normal çevresel dalgalanma
      node.smokeRaw = Math.max(180, Math.min(420, node.smokeRaw + Math.floor(Math.random() * 21 - 10)));
      node.tempC = parseFloat((node.tempC + (Math.random() * 0.4 - 0.2)).toFixed(1));
      node.humidityPct = Math.max(30, Math.min(80, node.humidityPct + Math.floor(Math.random() * 3 - 1)));
    } 
    else if (activeScenario === "single_warning") {
      // SADECE Node 1'de anomali var (Konsensüs sağlanmaz)
      if (node.deviceId === "1") {
        node.smokeRaw = Math.min(3200, node.smokeRaw + 350); // Eşik (850) aşılır
        node.tempC = parseFloat((node.tempC + 1.2).toFixed(1)); // Ani sıcaklık artışı
        node.humidityPct = Math.max(15, node.humidityPct - 4); // Ani nem düşüşü
      } else {
        node.smokeRaw = 250 + Math.floor(Math.random() * 40);
        node.tempC = 23.0;
        node.humidityPct = 52;
      }
    } 
    else if (activeScenario === "consensus_fire") {
      // Node 1 VE Node 2 aynı anda yangın sinyali verir (Zone-Alpha konsensüsü!)
      if (node.deviceId === "1" || node.deviceId === "2") {
        node.smokeRaw = Math.min(3800, node.smokeRaw + 450);
        node.tempC = parseFloat((node.tempC + 1.8).toFixed(1));
        node.humidityPct = Math.max(10, node.humidityPct - 6);
      } else {
        node.smokeRaw = 280 + Math.floor(Math.random() * 50);
        node.tempC = 23.5;
        node.humidityPct = 50;
      }
    }

    const res = await sendPacket(node);
    const nodeStatus = res.data?.nodeStatus || "bilinmiyor";
    console.log(`  └─ Node #${node.deviceId} (${node.zoneId}): Duman=${node.smokeRaw} | Sıcaklık=${node.tempC}°C | Nem=%${node.humidityPct} | Durum=${nodeStatus}`);
  }
}

// 5 saniyede bir yayın döngüsü
setInterval(tick, 5000);
// İlk çalıştırma
tick();
