const express = require("express");
const router = express.Router();
const {
  getMyDevices,
  createDevice,
  addContact,
  removeContact,
  getDeviceHistory,
} = require("../controllers/deviceController");
const { protect } = require("../middleware/authMiddleware");

router.route("/").get(protect, getMyDevices).post(protect, createDevice);

router.post("/:id/contacts", protect, addContact);
router.delete("/:id/contacts/:contactId", protect, removeContact);
router.get("/:id/history", protect, getDeviceHistory);

module.exports = router;
