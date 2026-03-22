const User = require("../models/User");
const Device = require("../models/Device");
const { generateToken } = require("../middleware/auth"); // TODO: create a jwt helper

// ── Kullanıcı Kaydı (Register) ──
exports.register = async (req, res, next) => {
  try {
    const { name, email, password } = req.body;

    // Email kullanımda mı kontrol et
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(400).json({ success: false, message: "Bu e-posta adresi kullanımda." });
    }

    const user = await User.create({
      name,
      email,
      password,
      role: "user"
    });

    const token = generateToken(user._id);

    res.status(201).json({
      success: true,
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    next(error);
  }
};

// ── Kullanıcı Girişi (Login) ──
exports.login = async (req, res, next) => {
  try {
    const { email, password, fcmToken } = req.body;

    // Kullanıcıyı ve parolayı kontrol et
    const user = await User.findOne({ email }).select("+password"); // Şema ayarlarınıza göre password gizliyse seçiyoruz
    if (!user) {
      return res.status(401).json({ success: false, message: "Geçersiz kimlik bilgileri." });
    }

    const isMatch = await user.matchPassword(password);
    if (!isMatch) {
      return res.status(401).json({ success: false, message: "Geçersiz kimlik bilgileri." });
    }

    // FCM token güncellenirse kaydet
    if (fcmToken) {
      user.fcmToken = fcmToken;
      await user.save();
    }

    const token = generateToken(user._id);

    res.status(200).json({
      success: true,
      token,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        role: user.role
      }
    });
  } catch (error) {
    next(error);
  }
};

// ── Mevcut Kullanıcıyı Getir (Me) ──
exports.getMe = async (req, res, next) => {
  try {
    const user = await User.findById(req.user.id).populate("devices");
    
    res.status(200).json({
      success: true,
      user
    });
  } catch (error) {
    next(error);
  }
};
