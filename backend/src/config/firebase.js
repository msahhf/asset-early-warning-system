const admin = require("firebase-admin");
const logger = require("../utils/logger");

const initFirebase = () => {
  try {
    // To test locally during development,
    // the serviceAccountKey.json file is required.
    // For now, initialize a mock or check whether the JSON file exists:
    if (!process.env.FIREBASE_PROJECT_ID) {
      logger.warn("⚠️ Firebase credentials missing (FIREBASE_PROJECT_ID). FCM module is starting inactive.");
      return;
    }

    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        // To normalize line endings:
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n"),
      }),
    });

    logger.info("✅ Firebase Admin SDK initialized.");
  } catch (error) {
    logger.error(`❌ Firebase startup error: ${error.message}`);
  }
};

const getMessaging = () => {
  if (!admin.apps.length) {
    return null;
  }
  return admin.messaging();
};

module.exports = { initFirebase, getMessaging };
