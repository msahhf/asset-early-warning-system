const express = require("express");
const router = express.Router();
const {
  verifyApiKey,
  heartbeat,
  uploadSensorData,
  ingestPacket,
  getThresholds,
  updateThresholds,
  getNodesOverview,
  simulateScenario,
} = require("../controllers/sensorController");

// ── IoT Cihaz & PC Bridge Rotaları ────────────────────
router.post("/heartbeat", verifyApiKey, heartbeat);
router.post("/data", verifyApiKey, uploadSensorData);
router.post("/ingest", verifyApiKey, ingestPacket);

// ── Dashboard & Eşik Kalibrasyon Rotaları ───────────────
router.get("/thresholds", getThresholds);
router.put("/thresholds", updateThresholds);
router.get("/nodes-overview", getNodesOverview);

// ── Simülasyon Rotaları ───────────────────────────────
router.post("/simulate-scenario", simulateScenario);
router.post("/simulate", simulateScenario);

module.exports = router;
