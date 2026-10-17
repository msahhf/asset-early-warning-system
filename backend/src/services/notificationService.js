const { getMessaging } = require("../config/firebase");
const logger = require("../utils/logger");

class NotificationService {
  /**
   * Sends a push notification to the mobile app.
   * The mobile app already includes the "flutter_local_notifications" infrastructure;
   * the FCM data payload will be processed there.
   *
   * @param {string} token User's FCM token
   * @param {string} title Notification title
   * @param {string} body Bildirim metni
   * @param {object} data Additional data (e.g. alertId, alarmType)
   */
  static async sendPushNotification(token, title, body, data = {}) {
    try {
      if (!token) {
        logger.warn("⚠️ FCM token is empty. Push notification was not sent.");
        return false;
      }

      const messaging = getMessaging();
      if (!messaging) {
        logger.warn("⚠️ Notification skipped because FCM is not configured.");
        // Returning true may be useful during development.
        return true;
      }

      const message = {
        notification: {
          title,
          body,
        },
        data: {
          ...data,
          // Values must be strings
          click_action: "FLUTTER_NOTIFICATION_CLICK"
        },
        token,
        android: {
          priority: "high",
          notification: {
            // Use the v3 channel ID configured in the mobile app to enable sound/vibration
            channelId: "asset_alarm_channel_v3",
            sound: "default",
          }
        }
      };

      const response = await messaging.send(message);
      logger.info(`✅ FCM notification sent: ${response}`);
      return true;

    } catch (error) {
      logger.error(`❌ FCM send error: ${error.message}`);
      return false;
    }
  }
}

module.exports = NotificationService;
