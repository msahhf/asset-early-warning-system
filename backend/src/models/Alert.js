const mongoose = require("mongoose");

const alertSchema = new mongoose.Schema(
  {
    alertId: {
      type: String,
      default: () => require("uuid").v4(),
      index: true,
    },
    zoneId: {
      type: String,
      trim: true,
      index: true,
    },
    severity: {
      type: String,
      enum: ["warning", "fire"],
      default: "warning",
      index: true,
    },
    triggeringDeviceIds: [
      {
        type: String,
      },
    ],
    coordinates: {
      lat: { type: Number, default: 39.92077 },
      lng: { type: Number, default: 32.85411 },
    },
    device: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Device",
      required: false,
      index: true,
    },
    type: {
      type: String,
      enum: ["fire", "gas_warning", "warning", "offline", "recovered", "lowBattery"],
      default: "fire",
    },
    message: {
      type: String,
      required: true,
      maxlength: 500,
    },
    notifiedUsers: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
      },
    ],
    // Notification status (may use FCM or multiple channels instead of Twilio)
    notificationStatus: {
      type: String,
      enum: ["pending", "sent", "failed", "skipped"],
      default: "pending",
    },
    // Sensor snapshot data (smoke level and other values when the fire was triggered)
    sensorSnapshot: {
      type: Object,
      default: {},
    },
    triggerValue: {
      type: Number,
      default: null,
    },
    resolved: {
      type: Boolean,
      default: false,
      index: true,
    },
    resolvedAt: {
      type: Date,
      default: null,
    },
    resolvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null,
    },
  },
  {
    timestamps: true,
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

alertSchema.virtual("isActive").get(function () {
  return this.resolvedAt === null;
});

alertSchema.index({ device: 1, createdAt: -1 });
alertSchema.index({ resolvedAt: 1 });

module.exports = mongoose.model("Alert", alertSchema);
