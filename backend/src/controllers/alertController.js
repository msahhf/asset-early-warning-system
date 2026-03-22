const Alert = require("../models/Alert");

// ── Kullanıcıya ait Alarmları Getir (Mevcut Cihazlar İçin) ──
exports.getAlerts = async (req, res, next) => {
  try {
    // Tüm cihazların alarmlarını çekiyoruz veya limitli şekilde
    const alerts = await Alert.find({}) // TODO: filtrelemek isterseniz { deviceId: { $in: userDeviceIds } } yapınız
      .sort("-createdAt")
      .limit(50);
      
    res.status(200).json({
      success: true,
      data: alerts
    });
  } catch (error) {
    next(error);
  }
};
