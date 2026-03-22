const jwt = require("jsonwebtoken");
const User = require("../models/User");

// JWT Üretici yardımcı fonksiyon
exports.generateToken = (id) => {
  return jwt.sign({ id }, process.env.JWT_SECRET || "default_secret", {
    expiresIn: "30d",
  });
};

// Korumalı rotalar için middleware
exports.protect = async (req, res, next) => {
  let token;

  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith("Bearer")
  ) {
    token = req.headers.authorization.split(" ")[1];
  }

  if (!token) {
    return res.status(401).json({ success: false, message: "Bu rotaya erişmek için yetkilendirme (Token) gerekli." });
  }

  try {
    const decoded = jwt.verify(token, process.env.JWT_SECRET || "default_secret");

    req.user = await User.findById(decoded.id);
    if (!req.user) {
      return res.status(401).json({ success: false, message: "Bu token'a sahip bir kullanıcı bulunamadı." });
    }

    next();
  } catch (error) {
    return res.status(401).json({ success: false, message: "Yetkilendirme reddedildi veya token süresi doldu." });
  }
};
