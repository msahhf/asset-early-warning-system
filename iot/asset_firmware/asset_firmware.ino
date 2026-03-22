#include <WiFi.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// ── PİN TANIMLAMALARI (Deneyap Kart 1A v2) ──
#define MQ2_PIN A0
#define BATT_PIN A1
#define SIREN_RELAY D0
#define WATER_RELAY D1
#define BUTTON_TEST D2
#define BUTTON_SILENCE D3

// ── BLE UUIDs (Mobil Uygulama ile Birebir Aynı) ──
#define SERVICE_UUID           "12345678-1234-5678-1234-56789abcdef0"
#define CHAR_UUID_SSID         "12345678-1234-5678-1234-56789abcdef1"
#define CHAR_UUID_PASS         "12345678-1234-5678-1234-56789abcdef2"
#define CHAR_UUID_STATUS       "12345678-1234-5678-1234-56789abcdef3"

// ── AYARLAR VE SABİTLER ──
// Backend yerel ağdaysa (örneğin bilgisayar Android Emulator IP'si veya lokal ağ IP'si) düzeltilmelidir (örn: 192.168.1.100)
const String API_URL_DATA = "http://192.168.1.100:5000/api/sensors/data"; 
const String API_URL_HEARTBEAT = "http://192.168.1.100:5000/api/sensors/heartbeat";

// Cihazın sisteme kendini tanıtması için gereken gizli API Key (Backend'de cihaz oluşturulunca veritabanından alınır)
const String API_KEY = "demo-api-key-from-backend"; 

const int FIRE_THRESHOLD = 3000;
const int POST_INTERVAL_MS = 5000;
const int HEARTBEAT_INTERVAL_MS = 60000;
const int MOVING_AVERAGE_SIZE = 10;
const int DOUBLE_VERIFICATION_COUNT = 3; // 3 ölçüm dönemi eşik aşılırsa (Çift Doğrulama Algoritması)

// ── GLOBAL DEĞİŞKENLER ──
Preferences preferences;
String ssid = "";
String password = "";
bool isProvisioned = false;
bool bleConnected = false;

// Kayan Ortalama Değişkenleri
int mq2Readings[MOVING_AVERAGE_SIZE];
int readIndex = 0;
long totalMq2 = 0;
int averageMq2 = 0;

// Çift Doğrulama (Alarm state) Değişkenleri
int fireVerificationWait = 0;
bool isAlarmActive = false;

// Zamanlayıcılar
unsigned long lastPostTime = 0;
unsigned long lastHeartbeatTime = 0;

// BLE Objesi
BLECharacteristic *pStatusCharacteristic;
BLEServer *pServer;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
        bleConnected = true;
        Serial.println("Mobil Cihaz BLE ile bağlandı.");
    }
    void onDisconnect(BLEServer* pServer) {
        bleConnected = false;
        if (!isProvisioned) {
            BLEDevice::startAdvertising();
            Serial.println("Bağlantı koptu. Tekrar yayın yapılıyor...");
        }
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
        String value = pCharacteristic->getValue().c_str();
        String uuid = pCharacteristic->getUUID().toString().c_str();

        if (uuid == CHAR_UUID_SSID) {
            ssid = value;
            Serial.println("SSID Alındı: " + ssid);
        } 
        else if (uuid == CHAR_UUID_PASS) {
            password = value;
            Serial.println("Şifre Alındı: ***");
            
            // SSP ve Wi-fi alındıysa tercihleri (EEPROM) içine göm
            if (ssid.length() > 0 && password.length() > 0) {
                preferences.putString("ssid", ssid);
                preferences.putString("pass", password);
                
                if(pStatusCharacteristic) {
                    pStatusCharacteristic->setValue("Provisioned. Rebooting...");
                    pStatusCharacteristic->notify();
                }

                Serial.println("Ayarlar Kalıcı Belleğe Yazıldı! Cihaz yeniden başlatılıyor...");
                delay(2000);
                ESP.restart();
            }
        }
    }
};

void initBLE() {
    BLEDevice::init("ASSET-Detector");
    pServer = BLEDevice::createServer();
    pServer->setCallbacks(new MyServerCallbacks());

    BLEService *pService = pServer->createService(SERVICE_UUID);

    BLECharacteristic *pSSIDChar = pService->createCharacteristic(
        CHAR_UUID_SSID,
        BLECharacteristic::PROPERTY_WRITE
    );
    pSSIDChar->setCallbacks(new MyCallbacks());

    BLECharacteristic *pPassChar = pService->createCharacteristic(
        CHAR_UUID_PASS,
        BLECharacteristic::PROPERTY_WRITE
    );
    pPassChar->setCallbacks(new MyCallbacks());

    pStatusCharacteristic = pService->createCharacteristic(
        CHAR_UUID_STATUS,
        BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY
    );
    pStatusCharacteristic->addDescriptor(new BLE2902());
    pStatusCharacteristic->setValue("Waiting for WiFi Configuration...");

    pService->start();

    BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
    pAdvertising->addServiceUUID(SERVICE_UUID);
    pAdvertising->setScanResponse(true);
    BLEDevice::startAdvertising();
    Serial.println("BLE Reklam Yayını Başlatıldı. Cihaz Mobil Uygulamadan Bekleniyor.");
}

void setup() {
    Serial.begin(115200);
    delay(1000);

    pinMode(SIREN_RELAY, OUTPUT);
    digitalWrite(SIREN_RELAY, LOW);

    pinMode(WATER_RELAY, OUTPUT);
    digitalWrite(WATER_RELAY, LOW);

    pinMode(BUTTON_TEST, INPUT_PULLUP);
    pinMode(BUTTON_SILENCE, INPUT_PULLUP);
    
    // Filtre için diziyi sıfırla
    for (int i = 0; i < MOVING_AVERAGE_SIZE; i++) {
        mq2Readings[i] = 0;
    }

    // Flash belleği (preferences) başlat
    preferences.begin("asset_cfg", false);
    ssid = preferences.getString("ssid", "");
    password = preferences.getString("pass", "");

    if (ssid == "" || password == "") {
        Serial.println("Kayıtlı WiFi Modemi bulunamadı. Eşleştirme moduna (BLE) geçiliyor...");
        isProvisioned = false;
        initBLE();
    } else {
        Serial.println("Sistem daha önce ayarlanmış. Wi-Fi'ye otomatik bağlanılıyor: " + ssid);
        WiFi.mode(WIFI_STA);
        WiFi.begin(ssid.c_str(), password.c_str());
        
        int attempt = 0;
        // 20 saniye bağlantı denemesi
        while (WiFi.status() != WL_CONNECTED && attempt < 20) {
            delay(1000);
            Serial.print(".");
            attempt++;
        }
        
        if(WiFi.status() != WL_CONNECTED) {
            Serial.println("\nWiFi Ağına Bağlanılamadı! BLE kurtarma modu başlatılıyor...");
            preferences.clear(); // Hatalı pass/ssid'yi sil
            isProvisioned = false;
            initBLE();
        } else {
            Serial.println("\nWiFi ONAYLANDI! Modül IP: " + WiFi.localIP().toString());
            isProvisioned = true;
        }
    }
}

// ── SENSÖR YARDIMCI FONKSİYONLAR ──
int readMovingAverageMQ2() {
    totalMq2 = totalMq2 - mq2Readings[readIndex];
    mq2Readings[readIndex] = analogRead(MQ2_PIN);
    totalMq2 = totalMq2 + mq2Readings[readIndex];
    readIndex = (readIndex + 1) % MOVING_AVERAGE_SIZE;
    return totalMq2 / MOVING_AVERAGE_SIZE;
}

int readBatteryLevel() {
    // ADC'den batarya voltajı tahmini
    int raw = analogRead(BATT_PIN);
    // Donanımda 10k/10k gerilim bölücü varsa hesaplamalar 3.3v'ye göre yapılır.
    // Şimdilik % sabit dönülüyor (Gerçek implementasyonda voltaj eğrisi yansıtılır)
    return 85; 
}

void processAlarmLogic(int mq2) {
    bool testPressed = digitalRead(BUTTON_TEST) == LOW; // PULLUP direnç old. LOW=Basılı

    // 1) Yangın tehlikesi mevcut mu?
    if (mq2 >= FIRE_THRESHOLD || testPressed) {
        if (!isAlarmActive) {
            fireVerificationWait++;
            if (fireVerificationWait >= DOUBLE_VERIFICATION_COUNT || testPressed) {
                Serial.println("🔥 ÇİFT DOĞRULAMA GEÇİLDİ: YANGIN/GAZ ALARMI AKTİF 🔥");
                isAlarmActive = true;
                digitalWrite(SIREN_RELAY, HIGH);
                digitalWrite(WATER_RELAY, HIGH); // Söndürücü tetiklendi
            } else {
                Serial.printf("Tehlike İhtimali (%d/%d)... Analiz ediliyor\n", fireVerificationWait, DOUBLE_VERIFICATION_COUNT);
            }
        }
    } else {
        // Altına düşünce sayaç sıfırlansın ki sonra tekrar çıkarsa baştan saysın
        fireVerificationWait = 0;
    }

    // 2) Alarm Susturma/Resetleme Şartı
    bool silencePressed = digitalRead(BUTTON_SILENCE) == LOW;
    if (silencePressed && isAlarmActive) {
        Serial.println("🔔 Sistem manuel test olarak SUSTURULDU.");
        isAlarmActive = false;
        digitalWrite(SIREN_RELAY, LOW);
        digitalWrite(WATER_RELAY, LOW);
        fireVerificationWait = 0; // Doğrulama sıfırlandı
        delay(1000); // 1 saniye debounce koruması
    }
}

void loop() {
    // Hala Provision edilmediyse (SSID bilgileri bekleniyorsa) döngüyü yavaşça bekle
    if (!isProvisioned) {
        delay(100);
        return;
    }

    // Cihaz Çalışır Modda
    unsigned long currentMillis = millis();

    // Analog sinyalden filtre geçirilmiş değer
    averageMq2 = readMovingAverageMQ2();
    int battery = readBatteryLevel();
    // Sıcaklık-Nem modülü varsa (DHT11 vb.) eklenebilir
    float temp = 25.5; 
    float hum = 60.0;

    // Röle ve Çift Doğrulama mekaniği
    processAlarmLogic(averageMq2);

    // Node.JS Backend Sunucusuna Periyodik Snapshot Gönderimi (Her 5 San.)
    if (currentMillis - lastPostTime >= POST_INTERVAL_MS) {
        lastPostTime = currentMillis;
        
        if (WiFi.status() == WL_CONNECTED) {
            HTTPClient http;
            http.begin(API_URL_DATA);
            http.addHeader("Content-Type", "application/json");
            http.addHeader("x-api-key", API_KEY);
            
            // JSON paketini inşa et
            String payload = "{\"mq2Value\":" + String(averageMq2) + 
                             ",\"temperature\":" + String(temp) + 
                             ",\"humidity\":" + String(hum) + 
                             ",\"batteryLevel\":" + String(battery) + "}";
            
            int httpResponseCode = http.POST(payload);
            if (httpResponseCode > 0) {
                // Sadece debug modunda görmek için println olabilir, ancak stabilite için sessizde çalışabilir
                Serial.println("Sensör Akışı (POST): " + String(httpResponseCode));
            } else {
                Serial.println("HTTP Data POST Hatası!: " + http.errorToString(httpResponseCode));
            }
            http.end();
        }
    }

    // Sistemin Canlı Olduğunu Belirten HeartBeat Yayını (Her 60 San.)
    if (currentMillis - lastHeartbeatTime >= HEARTBEAT_INTERVAL_MS) {
        lastHeartbeatTime = currentMillis;
        
        if (WiFi.status() == WL_CONNECTED) {
            HTTPClient http;
            http.begin(API_URL_HEARTBEAT);
            http.addHeader("Content-Type", "application/json");
            http.addHeader("x-api-key", API_KEY);
            
            String payload = "{\"batteryLevel\":" + String(battery) + "}";
            http.POST(payload);
            http.end();
            Serial.println("💓 Heartbeat Pulsed.");
        }
    }

    // Önemli loop beklemesi (Watchdog timeout engellemek için)
    delay(20); 
}
