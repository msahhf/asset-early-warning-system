const express = require("express");
const router = express.Router();
const {
  verifyApiKey,
  heartbeat,
  uploadSensorData,
  simulateData
} = require("../controllers/sensorController");

// ── IoT cihaz rotaları (ApiKey korumalı) ──────────────
router.post("/heartbeat", verifyApiKey, heartbeat);
router.post("/data", verifyApiKey, uploadSensorData);

// ── Simülatör (Web Dashboard'dan tetiklenir) ─────────
router.post("/simulate", simulateData);

module.exports = router;
