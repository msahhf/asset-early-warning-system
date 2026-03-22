const Alert = require("../models/Alert");
const Device = require("../models/Device");

// @desc    Kullanıcının cihazlarına ait tüm alarmları getirir
// @route   GET /api/alerts
// @access  Private
exports.getMyAlerts = async (req, res) => {
  try {
    // Önce kullanıcının cihazlarını bul
    const devices = await Device.find({ owner: req.user.id }).select("_id");
    const deviceIds = devices.map((d) => d._id);

    // Bu cihazlara ait alarmları getir
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
