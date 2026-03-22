const express = require("express");
const router = express.Router();
const { getMyAlerts } = require("../controllers/alertController");
const { protect } = require("../middleware/authMiddleware");

router.route("/").get(protect, getMyAlerts);

module.exports = router;
