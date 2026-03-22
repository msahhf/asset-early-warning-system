const express = require("express");
const router = express.Router();

const authRoutes = require("./authRoutes");
const deviceRoutes = require("./deviceRoutes");
const alertRoutes = require("./alertRoutes");

router.use("/auth", authRoutes);
router.use("/devices", deviceRoutes);
router.use("/alerts", alertRoutes);

module.exports = router;
