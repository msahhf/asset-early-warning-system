const Alert = require("../models/Alert");
const Device = require("../models/Device");

// @desc    Returns all alerts for the user's devices
// @route   GET /api/alerts
// @access  Private
exports.getMyAlerts = async (req, res) => {
  try {
    // Find the user's devices first
    const devices = await Device.find({ owner: req.user.id }).select("_id");
    const deviceIds = devices.map((d) => d._id);

    // Get alerts for these devices
    const alerts = await Alert.find({ device: { $in: deviceIds } })
      .sort({ createdAt: -1 })
      .populate("device", "name location");

    res.status(200).json({
      success: true,
      count: alerts.length,
      data: alerts,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
