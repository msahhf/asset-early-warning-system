const jwt = require("jsonwebtoken");
const User = require("../models/User");

// JWT doğrulama middleware
exports.protect = async (req, res, next) => {
  let token;

  if (
    req.headers.authorization &&
    req.headers.authorization.startsWith("Bearer")
  ) {
    token = req.headers.authorization.split(" ")[1];
  }

  if (!token) {
    return res.status(401).json({
      success: false,
      message: "Yetkisiz erişim. Token bulunamadı.",
    });
  }

  try {
    // Token'ı doğrula
    const decoded = jwt.verify(token, process.env.JWT_SECRET || "default_secret");

    // Kullanıcıyı bul
    const user = await User.findById(decoded.id);

    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Bu token'a ait kullanıcı artık mevcut değil.",
      });
    }

    req.user = user;
    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: "Yetksiz erişim. Token geçersiz veya süresi dolmuş.",
    });
  }
};
