const User = require("../models/User");
const jwt = require("jsonwebtoken");

const generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET || "default_secret", {
    expiresIn: "30d",
  });
};

exports.register = async (req, res) => {
  try {
    const { name, email, password, phone } = req.body;

    const userExists = await User.findOne({ email });
    if (userExists) {
      return res.status(400).json({ success: false, message: "Bu e-posta adresi zaten kullanımda." });
    }

    // Doğrudan passwordHash içerisine şifre aktarılır. models/User.js içerisindeki pre-save kancası şifreyi otomatik hash'ler.
    const user = await User.create({
      name,
      email,
      passwordHash: password,
      phone,
      isApproved: true, // Hızlı test için varsayılan olarak onaylı.
    });

    res.status(201).json({
      success: true,
      token: generateToken(user._id),
      user: user.toSafeObject(),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email }).select("+passwordHash");
    if (!user || !(await user.comparePassword(password))) {
      return res.status(401).json({ success: false, message: "Geçersiz e-posta veya parola." });
    }

    res.json({
      success: true,
      token: generateToken(user._id),
      user: user.toSafeObject(),
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};

exports.getMe = async (req, res) => {
  try {
    const user = await User.findById(req.user.id).populate("devices");
    if (!user) {
      return res.status(404).json({ success: false, message: "Kullanıcı bulunamadı." });
    }
    res.json({ success: true, user: user.toSafeObject() });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
