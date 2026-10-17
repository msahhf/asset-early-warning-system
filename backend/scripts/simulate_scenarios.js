/**
 * ASSET 2.0 / 2.1 Sensor Network Simulator
 * Generates realistic sensor readings for five nodes every five seconds and sends them to the Ingest API.
 * 
 * Usage:
 * node simulate_scenarios.js --mode=interactive
 * node simulate_scenarios.js --scenario=consensus_fire
 * node simulate_scenarios.js --scenario=single_warning
 * node simulate_scenarios.js --scenario=normal
 */

require("dotenv").config();
const http = require("http");

const BACKEND_URL = process.env.BACKEND_URL || "http://localhost:5000";
const INGEST_PATH = "/api/sensors/ingest";
const INGEST_API_KEY = process.env.INGEST_API_KEY;

if (!INGEST_API_KEY) {
  console.error("\n❌ ERROR: INGEST_API_KEY is not set.");
  console.error("   The script calls /api/sensors/ingest with the x-api-key header.");
  console.error("   Run from the backend directory (backend/.env is loaded automatically)");
  console.error("   or pass it as INGEST_API_KEY=... node scripts/simulate_scenarios.js.\n");
  process.exit(1);
}

// 5 Initial state for nodes
const nodes = [
  { deviceId: "1", zoneId: "zone-alpha", tempC: 23.0, humidityPct: 52, smokeRaw: 260, seqNo: 1, batteryPct: 98 },
  { deviceId: "2", zoneId: "zone-alpha", tempC: 23.4, humidityPct: 51, smokeRaw: 270, seqNo: 1, batteryPct: 96 },
  { deviceId: "3", zoneId: "zone-alpha", tempC: 22.8, humidityPct: 53, smokeRaw: 250, seqNo: 1, batteryPct: 95 },
  { deviceId: "4", zoneId: "zone-bravo", tempC: 23.1, humidityPct: 50, smokeRaw: 240, seqNo: 1, batteryPct: 92 },
  { deviceId: "5", zoneId: "zone-bravo", tempC: 22.9, humidityPct: 54, smokeRaw: 255, seqNo: 1, batteryPct: 90 },
];

let activeScenario = process.argv.find(arg => arg.startsWith("--scenario="))?.split("=")[1] || "normal";

console.log(`\n======================================================`);
console.log(`🚀 ASSET 2.0 / 2.1 Multi-Node Simulator Started`);
console.log(`📡 Backend target: ${BACKEND_URL}${INGEST_PATH}`);
console.log(`🎯 Active scenario: ${activeScenario.toUpperCase()}`);
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
          "x-api-key": INGEST_API_KEY,
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
  console.log(`\n⏱️ [Cycle #${tickCount}] Publishing data for five nodes every five seconds...`);

  for (const node of nodes) {
    node.seqNo++;

    if (activeScenario === "normal") {
      // Normal environmental variation
      node.smokeRaw = Math.max(180, Math.min(420, node.smokeRaw + Math.floor(Math.random() * 21 - 10)));
      node.tempC = parseFloat((node.tempC + (Math.random() * 0.4 - 0.2)).toFixed(1));
      node.humidityPct = Math.max(30, Math.min(80, node.humidityPct + Math.floor(Math.random() * 3 - 1)));
    } 
    else if (activeScenario === "single_warning") {
      // ONLY Node 1 has an anomaly (no consensus)
      if (node.deviceId === "1") {
        node.smokeRaw = Math.min(3200, node.smokeRaw + 350); // Threshold (850) exceeded
        node.tempC = parseFloat((node.tempC + 1.2).toFixed(1)); // Rapid temperature increase
        node.humidityPct = Math.max(15, node.humidityPct - 4); // Rapid humidity decrease
      } else {
        node.smokeRaw = 250 + Math.floor(Math.random() * 40);
        node.tempC = 23.0;
        node.humidityPct = 52;
      }
    } 
    else if (activeScenario === "consensus_fire") {
      // Nodes 1 AND 2 signal fire simultaneously (Zone-Alpha consensus!)
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
    const nodeStatus = res.data?.nodeStatus || "unknown";
    console.log(`  └─ Node #${node.deviceId} (${node.zoneId}): Smoke=${node.smokeRaw} | Temperature=${node.tempC}°C | Humidity=${node.humidityPct}% | Status=${nodeStatus}`);
  }
}

// Publish loop runs every five seconds
setInterval(tick, 5000);
// Initial run
tick();
