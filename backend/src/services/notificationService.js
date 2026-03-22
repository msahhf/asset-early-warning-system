const { getMessaging } = require("../config/firebase");
const logger = require("../utils/logger");

class NotificationService {
  /**
   * Mobil uygulamaya Push Notification gönderir.
   * Mobile uygulamada "flutter_local_notifications" altyapısı zaten var, 
   * FCM üzerinden gelen data payload'unu orada işleyeceğiz.
   * 
   * @param {string} token Kullanıcının FCM tokeni
   * @param {string} title Bildirim başlığı
   * @param {string} body Bildirim metni
   * @param {object} data Ek veriler (örn: alertId, alarmType)
   */
  static async sendPushNotification(token, title, body, data = {}) {
    try {
      if (!token) {
        logger.warn("⚠️ FCM Token boş. Push notification gönderilemedi.");
        return false;
      }

      const messaging = getMessaging();
      if (!messaging) {
        logger.warn("⚠️ FCM yapılandırılmadığı için bildirim atlandı.");
        // Geliştirme kolaylığı için true dönülebilir.
        return true; 
      }

      const message = {
        notification: {
          title,
          body,
        },
        data: {
          ...data,
          // Değerlerin string olması gerekiyor
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        },
        token,
        android: {
          priority: "high",
          notification: {
            // Mobil uygulamada kurduğumuz v3 kanal ID'sini vererek ses/titreşim istiyoruz
            channelId: "asset_alarm_channel_v3",
            sound: "default", 
          }
        }
      };

      const response = await messaging.send(message);
      logger.info(`✅ FCM Bildirimi Gönderildi: ${response}`);
      return true;

    } catch (error) {
      logger.error(`❌ FCM Gönderim Hatası: ${error.message}`);
      return false;
    }
  }
}

module.exports = NotificationService;
