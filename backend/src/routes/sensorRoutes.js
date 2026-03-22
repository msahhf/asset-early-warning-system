const express = require("express");
const router = express.Router();
const {
  verifyApiKey,
  heartbeat,
  uploadSensorData,
} = require("../controllers/sensorController");
// const { protect } = require("../middleware/auth"); // TODO auth

// ── IoT cihaz rotaları (ApiKey korumalı) ──────────────
router.post("/heartbeat", verifyApiKey, heartbeat);
router.post("/data", verifyApiKey, uploadSensorData);

module.exports = router;
