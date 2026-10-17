const mongoose = require("mongoose");

const thresholdConfigSchema = new mongoose.Schema(
  {
    key: {
      type: String,
      default: "default_config",
      unique: true,
    },
    // 1. Duman eşik değeri (MQ-2 0-4095 ADC)
    smokeThreshold: {
      type: Number,
      default: 850,
      required: true,
    },
    // 2. Isı artış hızı eşiği (Delta T / Delta t - °C / saniye)
    heatRateThresholdCPerSec: {
      type: Number,
      default: 0.15,
      required: true,
    },
    // 3. Ani nem düşüşü eşiği (% bağıl nem)
    humidityDropThresholdPct: {
      type: Number,
      default: 5.0,
      required: true,
    },
    // 4. Konsensüs zaman penceresi (saniye)
    windowSeconds: {
      type: Number,
      default: 45,
      required: true,
    },
    // 5. Aynı zon içinde yangın alarmı (FIRE) için gereken minimum node sayısı
    minNodesForFire: {
      type: Number,
      default: 2,
      required: true,
    },
    // 6. Yangın sonrası soğuma süresi (saniye)
    cooldownSeconds: {
      type: Number,
      default: 180,
      required: true,
    },
    // 7. Hareketli ortalama pencere boyutu (örnek sayısı)
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

// Tekil config instance getirme yardımcı fonksiyonu
thresholdConfigSchema.statics.getActiveConfig = async function () {
  let config = await this.findOne({ key: "default_config" });
  if (!config) {
    config = await this.create({ key: "default_config" });
  }
  return config;
};

module.exports = mongoose.model("ThresholdConfig", thresholdConfigSchema);
