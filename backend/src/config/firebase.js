const admin = require("firebase-admin");
const logger = require("../utils/logger");

const initFirebase = () => {
  try {
    // Proje geliştirme aşamasında lokalde test edebilmek için 
    // serviceAccountKey.json dosyasına ihtiyaç vardır.
    // Şimdilik mock initialize yapıyoruz veya json var mı diye kontrol ediyoruz:
    if (!process.env.FIREBASE_PROJECT_ID) {
      logger.warn("⚠️ Firebase kimlik bilgileri eksik (FIREBASE_PROJECT_ID). FCM modülü pasif başlatılıyor.");
      return;
    }

    admin.initializeApp({
      credential: admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        // Satır sonu karakterlerini düzeltmek için:
        privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, "\n"),
      }),
    });

    logger.info("✅ Firebase Admin SDK başlatıldı.");
  } catch (error) {
    logger.error(`❌ Firebase başlatma hatası: ${error.message}`);
  }
};

const getMessaging = () => {
  if (!admin.apps.length) {
    return null;
  }
  return admin.messaging();
};

module.exports = { initFirebase, getMessaging };
