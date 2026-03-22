const mongoose = require("mongoose");
const bcrypt = require("bcryptjs");

const userSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "İsim zorunludur."],
      trim: true,
      maxlength: [100, "İsim 100 karakterden kısa olmalıdır."],
    },
    email: {
      type: String,
      required: [true, "E-posta zorunludur."],
      unique: true,
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, "Geçerli bir e-posta adresi girin."],
    },
    phone: {
      type: String,
      trim: true,
      match: [/^\+\d{10,15}$/, "Geçerli bir telefon numarası girin (+905....)."],
    },
    // FCM push notification için cihaz tokeni (Faz 2 eklemesi)
    fcmToken: {
      type: String,
      default: null,
    },
    passwordHash: {
      type: String,
      required: true,
      select: false,
    },
    role: {
      type: String,
      enum: ["owner", "contact", "admin"],
      default: "owner",
    },
    isApproved: {
      type: Boolean,
      default: false,
    },
    devices: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "Device",
      },
    ],
    resetPasswordToken: String,
    resetPasswordExpires: Date,
    lastLoginAt: Date,
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

userSchema.pre("save", async function (next) {
  if (!this.isModified("passwordHash")) return next();
  const salt = await bcrypt.genSalt(12);
  this.passwordHash = await bcrypt.hash(this.passwordHash, salt);
  next();
});

userSchema.methods.comparePassword = async function (candidatePassword) {
  return bcrypt.compare(candidatePassword, this.passwordHash);
};

userSchema.methods.toSafeObject = function () {
  const obj = this.toObject();
  delete obj.passwordHash;
  delete obj.resetPasswordToken;
  delete obj.resetPasswordExpires;
  delete obj.__v;
  return obj;
};

module.exports = mongoose.model("User", userSchema);
