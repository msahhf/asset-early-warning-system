const express = require("express");
const router = express.Router();
const { getDevices, getDeviceHistory } = require("../controllers/deviceController");
const { protect } = require("../middleware/auth");

router.get("/", protect, getDevices);
router.get("/:deviceId/history", protect, getDeviceHistory);

module.exports = router;
