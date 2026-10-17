const express = require("express");
const router = express.Router();
const { requireAdminKey, simulateGuard } = require("../middleware/adminAuth");
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

// ── IoT device and PC bridge routes ────────────────────
router.post("/heartbeat", verifyApiKey, heartbeat);
router.post("/data", verifyApiKey, uploadSensorData);
router.post("/ingest", verifyApiKey, ingestPacket);

// ── Dashboard and threshold calibration routes (admin key required) ──
router.get("/thresholds", requireAdminKey, getThresholds);
router.put("/thresholds", requireAdminKey, updateThresholds);
router.get("/nodes-overview", requireAdminKey, getNodesOverview);

// ── Simulation routes (admin key + production lock) ──
router.post("/simulate-scenario", requireAdminKey, simulateGuard, simulateScenario);
router.post("/simulate", requireAdminKey, simulateGuard, simulateScenario);

module.exports = router;
