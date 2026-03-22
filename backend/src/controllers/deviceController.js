const Device = require("../models/Device");
const SensorLog = require("../models/SensorLog");

// ── Tüm Cihazları Getir (Kullanıcıya ait) ──
exports.getDevices = async (req, res, next) => {
  try {
    // Sadece oturum açan kullanıcıya ait (veya owner olan) cihazları alıyoruz.
    // Biz 'User' modelinde 'devices' dizisi tutuyorsak, req.user üzerinden dönebiliriz.
    // Vektörel bir yaklaşım olarak Device.find({ owner: req.user._id }) kullanılabilir:
    let devices = await Device.find({}); // FIXME: Owner filtrelemesi yapın : { owner: req.user._id }
    
    // Geçici olarak tüm DB'den çekiyoruz, user model auth logiğine göre kısıtlanmalı
    res.status(200).json({
      success: true,
      count: devices.length,
      data: devices
    });
  } catch (error) {
    next(error);
  }
};

// ── Cihaz Geçmişini (Sensör verisi) Getir ──
exports.getDeviceHistory = async (req, res, next) => {
  try {
    const { deviceId } = req.params;
    const limit = parseInt(req.query.limit, 10) || 20;

    // Sensör verilerini timestamp sırasına (en yeniden eskiye) göre çekiyoruz
    const logs = await SensorLog.find({ deviceId })
      .sort("-timestamp")
      .limit(limit);

    // Uygulama grafiği soldan sağa kronolojik okur, ters çevirelim
    logs.reverse();

    res.status(200).json({
      success: true,
      data: logs
    });
  } catch (error) {
    next(error);
  }
};
