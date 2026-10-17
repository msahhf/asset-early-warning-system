const mongoose = require("mongoose");

const thresholdConfigSchema = new mongoose.Schema(
  {
    key: {
      type: String,
      default: "default_config",
      unique: true,
    },
    // 1. Smoke threshold (MQ-2 0-4095 ADC)
    smokeThreshold: {
      type: Number,
      default: 850,
      required: true,
    },
    // 2. Heat rise rate threshold (Delta T / Delta t - °C / second)
    heatRateThresholdCPerSec: {
      type: Number,
      default: 0.15,
      required: true,
    },
    // 3. Sudden humidity drop threshold (% relative humidity)
    humidityDropThresholdPct: {
      type: Number,
      default: 5.0,
      required: true,
    },
    // 4. Consensus time window (seconds)
    windowSeconds: {
      type: Number,
      default: 45,
      required: true,
    },
    // 5. Minimum number of nodes required for a fire alarm (FIRE) in the same zone
    minNodesForFire: {
      type: Number,
      default: 2,
      required: true,
    },
    // 6. Post-fire cooldown duration (seconds)
    cooldownSeconds: {
      type: Number,
      default: 180,
      required: true,
    },
    // 7. Moving average window size (number of samples)
    movingAverageSize: {
      type: Number,
      default: 3,
      required: true,
    },
  },
  {
    timestamps: true,
  }
);

// Helper to get the singleton config instance
thresholdConfigSchema.statics.getActiveConfig = async function () {
  let config = await this.findOne({ key: "default_config" });
  if (!config) {
    config = await this.create({ key: "default_config" });
  }
  return config;
};

module.exports = mongoose.model("ThresholdConfig", thresholdConfigSchema);
