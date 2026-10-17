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
    // Temel Sensörler (Hem yeni hem eski alan adlarını destekler)
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
    // Füzyon Bayrakları
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
    // Durum analizi (safe, warning, danger/fire)
    gasStatus: {
      type: String,
      enum: ["safe", "warning", "danger", "fire"],
      default: "safe",
    },
    // Veri kaynağı: 'hardware' (gerçek BLE node), 'mock' (bridge --mock), 'sim' (simulate_scenarios / dashboard testi)
    // Bu alan gerçek ve simüle verinin dashboard veya DB sorgularında karışmasını önler.
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
    // Oluşturulma zamanı üzerinden sorgu yapılabileceği için auto createdAt yeterli değil, timestamp kullanıldı
    timestamps: false, 
    toJSON: { virtuals: true },
    toObject: { virtuals: true },
  }
);

// Statik yardımcı fonksiyon: MQ-2 değerine göre durum
sensorLogSchema.statics.calculateGasStatus = function (mq2Value) {
  if (mq2Value < 300) return "safe";
  if (mq2Value < 800) return "warning";
  return "danger";
};

// Logları otomatik silmek için TTL indeksi (Örn: 30 gün sonra sil)
sensorLogSchema.index({ timestamp: 1 }, { expireAfterSeconds: 30 * 24 * 60 * 60 });

module.exports = mongoose.model("SensorLog", sensorLogSchema);
