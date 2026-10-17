const mongoose = require("mongoose");
const { v4: uuidv4 } = require("uuid");

const deviceSchema = new mongoose.Schema(
  {
    name: {
      type: String,
      required: [true, "Device name is required."],
      trim: true,
      maxlength: [80, "Device name must be shorter than 80 characters."],
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
      required: false,
      default: null,
    },
    contacts: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
    zoneId: {
      type: String,
      trim: true,
      default: "zone-alpha",
      index: true,
    },
    coordinates: {
      lat: { type: Number, default: 39.92077 },
      lng: { type: Number, default: 32.85411 },
    },
    location: {
      type: String,
      trim: true,
      default: "ASSET Sector 1",
    },
    isOnline: {
      type: Boolean,
      default: false,
    },
    status: {
      type: String,
      enum: ["online", "offline", "warning", "fire"],
      default: "offline",
    },
    lastHeartbeat: {
      type: Date,
      default: null,
    },
    lastSeen: {
      type: Date,
      default: null,
    },
    lastSeq: {
      type: Number,
      default: 0,
    },
    totalPacketsReceived: {
      type: Number,
      default: 0,
    },
    totalPacketsLost: {
      type: Number,
      default: 0,
    },
    wifiSSID: {
      type: String,
      trim: true,
      default: null,
    },
    firmwareVersion: {
      type: String,
      default: "2.0.0",
    },
    batteryLevel: {
      type: Number,
      default: 100,
    },
    batteryPct: {
      type: Number,
      default: 100,
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
