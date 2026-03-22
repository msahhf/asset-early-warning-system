const mongoose = require("mongoose");

const alertSchema = new mongoose.Schema(
  {
    device: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Device",
      required: true,
      index: true,
    },
    type: {
      type: String,
      // Faz 2 Eklemesi: lowBattery eklendi (earthquake kaldırıldı)
      enum: ["fire", "gas_warning", "offline", "recovered", "lowBattery"],
      required: true,
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
    // Bildirim durumu (Artık Twilio yerine FCM veya çok kanallı olabilir)
    notificationStatus: {
      type: String,
      enum: ["pending", "sent", "failed", "skipped"],
      default: "pending",
    },
    // Sensör snapshot verisi (Yangın tetiklendiğindeki duman miktarı vs.)
    sensorSnapshot: {
      type: Object,
      default: {},
    },
    triggerValue: {
      type: Number,
      default: null,
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
