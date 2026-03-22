const mongoose = require("mongoose");
const { v4: uuidv4 } = require("uuid");

const deviceSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "Cihaz adı zorunludur."],
      trim: true,
      maxlength: [80, "Cihaz adı 80 karakterden kısa olmalıdır."],
    },
    deviceId: {
      type: String,
      required: true,
      unique: true,
      default: () => uuidv4(),
    },
    apiKey: {
      type: String,
      required: true,
      select: false,
      default: () => uuidv4().replace(/-/g, ""),
    },
    owner: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    contacts: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
    location: {
      type: String,
      trim: true,
      default: "Belirtilmedi",
    },
    isOnline: {
      type: Boolean,
      default: false,
    },
    lastHeartbeat: {
      type: Date,
      default: null,
    },
    wifiSSID: {
      type: String,
      trim: true,
      default: null,
    },
    firmwareVersion: {
      type: String,
      default: "1.0.0",
    },
    batteryLevel: {
      type: Number,
      default: 0,
    },
    hasActiveAlert: {
      type: Boolean,
      default: false,
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

deviceSchema.virtual("offlineSince").get(function () {
  if (!this.lastHeartbeat) return null;
  return Math.floor((Date.now() - this.lastHeartbeat.getTime()) / 1000);
});

module.exports = mongoose.model("Device", deviceSchema);
