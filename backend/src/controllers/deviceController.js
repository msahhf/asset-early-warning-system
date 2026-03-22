const Device = require("../models/Device");
const User = require("../models/User");

// @desc    Kullanıcının sahip olduğu cihazları getirir
// @route   GET /api/devices
// @access  Private
exports.getMyDevices = async (req, res) => {
  try {
    const devices = await Device.find({ owner: req.user.id }).populate(
      "contacts",
      "name email phone"
    );
    res.status(200).json({
      success: true,
      count: devices.length,
      data: devices,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Yeni cihaz kaydet/bağla (Sadece test ve mock için)
// @route   POST /api/devices
// @access  Private
exports.createDevice = async (req, res) => {
  try {
    const { name, location } = req.body;
    const device = await Device.create({
      name,
      location,
      owner: req.user.id,
    });

    // Kullanıcının devices dizisine ekle
    await User.findByIdAndUpdate(req.user.id, {
      $push: { devices: device._id },
    });

    res.status(201).json({ success: true, data: device });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Cihaza acil durum kişisi ekle
// @route   POST /api/devices/:id/contacts
// @access  Private
exports.addContact = async (req, res) => {
  try {
    const device = await Device.findOne({ _id: req.params.id, owner: req.user.id });
    if (!device) {
      return res.status(404).json({ success: false, message: "Cihaz bulunamadı." });
    }

    const { email } = req.body;
    const contactUser = await User.findOne({ email });
    
    if (!contactUser) {
      return res.status(404).json({ success: false, message: "Eklenmek istenen e-posta adresine ait ASSET kullanıcısı bulunamadı." });
    }

    if (device.contacts.includes(contactUser._id)) {
      return res.status(400).json({ success: false, message: "Bu kullanıcı zaten acil durum listesinde." });
    }

    device.contacts.push(contactUser._id);
    await device.save();

    res.status(200).json({ success: true, message: "Kişi eklendi." });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Cihazdan acil durum kişisi sil
// @route   DELETE /api/devices/:id/contacts/:contactId
// @access  Private
exports.removeContact = async (req, res) => {
  try {
    const device = await Device.findOne({ _id: req.params.id, owner: req.user.id });
    if (!device) {
      return res.status(404).json({ success: false, message: "Cihaz bulunamadı." });
    }

    device.contacts = device.contacts.filter((c) => c.toString() !== req.params.contactId);
    await device.save();

    res.status(200).json({ success: true, message: "Kişi silindi." });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

// @desc    Cihazın geçmiş sensör verilerini çeker
// @route   GET /api/devices/:id/history
// @access  Private
exports.getDeviceHistory = async (req, res) => {
  try {
    // Sadece ilişkili cihaza sahipse veri çekebilir
    const device = await Device.findOne({ _id: req.params.id, owner: req.user.id });
    if (!device) return res.status(404).json({ success: false, message: "Cihaz bulunamadı." });

    const SensorLog = require("../models/SensorLog");
    const logs = await SensorLog.find({ device: device._id })
      .sort({ createdAt: -1 })
      .limit(20);

    // İlk sıradaki en yeni olduğu için grafikte soldan sağa doğru görünmesini isterseniz .reverse() yapılabilir
    res.json({ success: true, data: logs.reverse() });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
