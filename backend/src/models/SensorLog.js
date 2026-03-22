const mongoose = require("mongoose");

const sensorLogSchema = new mongoose.Schema(
  {
    device: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Device",
      required: true,
      index: true,
    },
    // Temel Sensörler
    mq2Value: {
      type: Number,
      required: true,
      // 0-4095 ESP32 ADC çözünürlüğü
      min: 0,
    },
    temperature: {
      type: Number,
      default: null,
    },
    humidity: {
      type: Number,
      default: null,
    },
    // Durum analizi (safe, warning, danger)
    gasStatus: {
      type: String,
      enum: ["safe", "warning", "danger"],
      default: "safe",
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
