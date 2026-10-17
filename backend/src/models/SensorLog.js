const mongoose = require("mongoose");

const sensorLogSchema = new mongoose.Schema(
  {
    device: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Device",
      required: false,
      index: true,
    },
    deviceId: {
      type: String,
      required: true,
      index: true,
    },
    // Core sensors (supports both new and legacy field names)
    tempC: {
      type: Number,
      default: null,
    },
    temperature: {
      type: Number,
      default: null,
    },
    humidityPct: {
      type: Number,
      default: null,
    },
    humidity: {
      type: Number,
      default: null,
    },
    smokeRaw: {
      type: Number,
      required: true,
      min: 0,
    },
    mq2Value: {
      type: Number,
      min: 0,
    },
    movingAvgSmoke: {
      type: Number,
      default: null,
    },
    // Fusion flags
    smokeFlag: {
      type: Boolean,
      default: false,
    },
    heatRateFlag: {
      type: Boolean,
      default: false,
    },
    humidityDropFlag: {
      type: Boolean,
      default: false,
    },
    rawSeqNo: {
      type: Number,
      default: 0,
    },
    // Status analysis (safe, warning, danger/fire)
    gasStatus: {
      type: String,
      enum: ["safe", "warning", "danger", "fire"],
      default: "safe",
    },
    // Data source: 'hardware' (real BLE node), 'mock' (bridge --mock), 'sim' (simulate_scenarios / dashboard test)
    // This field prevents real and simulated data from being mixed in dashboard or database queries.
    source: {
      type: String,
      enum: ["hardware", "mock", "sim"],
      default: "hardware",
      index: true,
    },
    rawPayload: {
      type: Object,
      default: {},
    },
    timestamp: {
      type: Date,
      default: Date.now,
    },
  },
  {
    // Use timestamp because queries need the measurement time; auto-createdAt is not sufficient.
    timestamps: false, 
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Static helper: determine status from the MQ-2 value
sensorLogSchema.statics.calculateGasStatus = function (mq2Value) {
  if (mq2Value < 300) return "safe";
  if (mq2Value < 800) return "warning";
  return "danger";
};

// TTL index for automatic log cleanup (e.g. delete after 30 days)
sensorLogSchema.index({ timestamp: 1 }, { expireAfterSeconds: 30 * 24 * 60 * 60 });

module.exports = mongoose.model("SensorLog", sensorLogSchema);
