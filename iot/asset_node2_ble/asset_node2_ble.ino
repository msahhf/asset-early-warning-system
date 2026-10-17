/**
 * ASSET 2.0 — Sensör Düğümü Firmware (Node Firmware)
 * Donanım: Deneyap Kart 1A v2 (ESP32-S3 / ESP32)
 * Sensörler: MQ-2 (Analog A0), DHT22 (D4)
 * İletişim: BLE Advertising (Manufacturer Specific Data - GATT bağlantısı yok)
 * Yayın Sıklığı: 5 Saniyede Bir
 *
 * Eşik Senkronizasyonu:
 *   Bridge servisi bağlantı kurulduğunda ve backend'den eşik değiştiğinde
 *   seri porta "THRESHOLD:<N>\n" komutu yazar. Firmware bu komutu alır ve
 *   smokeThresholdLocal değişkenini runtime'da günceller.
 *   Bu sayede tek bir yer (backend ThresholdConfig) tüm eşikleri yönetir;
 *   firmware ve backend senkronsuz kalmaz.
 */

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEAdvertising.h>
#include <DHT.h>

// ── Yapılandırma ──
#define NODE_DEVICE_ID 2       // 1 - 5 arasında her karta özel ayarlanır!
#define MQ2_ANALOG_PIN A0
#define DHT_PIN D4
#define DHT_TYPE DHT11
#define ALARM_PIN D1           // IRF5210 MOSFET Gate pini (Active-LOW: LOW=ON, HIGH=OFF)

#define BLE_BEACON_INTERVAL_MS 5000 // 5 saniyede bir yayın

// ── Eşik Değeri (Runtime'da bridge üzerinden güncellenebilir) ──
// Başlangıç değeri 1000'dir (x2 gerilim bölücü telafisi sonrası).
// Backend ThresholdConfig.smokeThreshold default=850; bridge başlangıçta
// "THRESHOLD:850\n" göndererek bu değeri senkronize eder.
// Bu iki değerin ayrı çalışmasını önlemek için lütfen burayı elle değiştirme;
// eşik değişikliklerini yalnızca backend/dashboard üzerinden yap.
volatile int smokeThresholdLocal = 1000;

// ── Seri Port Komut Tamponu ──
String serialCmdBuffer = "";

// ── 13 Baytlık Paketlenmiş Struct ──
struct __attribute__((packed)) AssetPacket {
  uint8_t  schema_version;   // 0x01
  uint8_t  device_id;        // 1 - 5
  uint16_t temp_c_x10;       // Sıcaklık * 10 (örn. 245 = 24.5°C)
  uint8_t  humidity_pct;     // %0 - 100
  uint16_t smoke_raw;        // MQ-2 0 - 4095
  uint32_t seq_no;           // Paket sıra numarası
  uint8_t  battery_pct;      // %0 - 100
  uint8_t  crc8;             // Bütünlük denetimi
};

DHT dht(DHT_PIN, DHT_TYPE);
BLEAdvertising *pAdvertising;
uint32_t packetSeqNo = 0;

// ── CRC-8 (Dallas/Maxim) Hesaplayıcı ──
uint8_t calculateCRC8(const uint8_t *data, size_t len) {
  uint8_t crc = 0x00;
  for (size_t i = 0; i < len; i++) {
    crc ^= data[i];
    for (uint8_t j = 0; j < 8; j++) {
      if (crc & 0x80) {
        crc = (crc << 1) ^ 0x07;
      } else {
        crc <<= 1;
      }
    }
  }
  return crc;
}

uint8_t readBatteryPct() {
  // Basit voltaj bölücü veya varsayılan %95
  return 95;
}

/**
 * Seri porttan gelen komutları işler.
 * Desteklenen komutlar:
 *   THRESHOLD:<N>  — smokeThresholdLocal değerini N olarak günceller.
 *                    Bridge tarafından backend ThresholdConfig ile senkronize edilir.
 */
void processSerialCommand(const String &cmd) {
  String trimmed = cmd;
  trimmed.trim();

  if (trimmed.startsWith("THRESHOLD:")) {
    String valStr = trimmed.substring(10); // "THRESHOLD:" = 10 karakter
    int newVal = valStr.toInt();
    if (newVal > 0 && newVal <= 4095) {
      smokeThresholdLocal = newVal;
      Serial.printf("[CONFIG] smokeThresholdLocal güncellendi: %d\n", smokeThresholdLocal);
      // Bridge'e onay gönder
      Serial.printf("THRESHOLD_ACK:%d\n", smokeThresholdLocal);
    } else {
      Serial.printf("[CONFIG] Geçersiz THRESHOLD değeri: %s\n", valStr.c_str());
    }
  }
  // Buraya ileride başka komutlar eklenebilir (örn. REBOOT, STATUS)
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.printf("\n🌲 ASSET 2.0 Node #%d Başlatılıyor...\n", NODE_DEVICE_ID);
  Serial.printf("[CONFIG] Başlangıç smokeThresholdLocal: %d (bridge senkronizasyonu bekleniyor)\n", smokeThresholdLocal);

  pinMode(MQ2_ANALOG_PIN, INPUT);

  // D1 boot glitch önleme: Önce HIGH seviyesine çek, ardından OUTPUT yap (Active-LOW MOSFET: HIGH=OFF)
  digitalWrite(ALARM_PIN, HIGH);
  pinMode(ALARM_PIN, OUTPUT);

  dht.begin();

  // BLE Başlat
  char deviceName[32];
  snprintf(deviceName, sizeof(deviceName), "ASSET-NODE-%d", NODE_DEVICE_ID);
  BLEDevice::init(deviceName);

  pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->setScanResponse(false);
  pAdvertising->setMinPreferred(0x06); // Düşük güç / hızlı reklam
  pAdvertising->setMaxPreferred(0x12);
  pAdvertising->start(); // BLE reklamını setup içinde bir kez başlat (döngüde sürekli aç/kapa yapılmaz)

  Serial.println("✅ BLE Advertising Hazır. 5 saniyede bir veri güncellenecek.");
}

void loop() {
  // ── Seri Port Komut Okuma (Non-blocking) ──
  // Bridge'den gelen THRESHOLD:<N> gibi komutları satır satır işle.
  while (Serial.available() > 0) {
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') {
      if (serialCmdBuffer.length() > 0) {
        processSerialCommand(serialCmdBuffer);
        serialCmdBuffer = "";
      }
    } else {
      serialCmdBuffer += c;
    }
  }

  packetSeqNo++;

  // Sensörleri Oku
  // NOT: MQ-2 çıkışı 10k:10k gerilim bölücüsünden geçmektedir (A0 gerilimi MQ-2'nin yaklaşık yarısıdır).
  // x2 katsayısı ppm veya gerçek fiziksel gaz konsantrasyonu DEĞİLDİR; gerilim bölücüyü telafi eden bağıl ADC ölçeklemesidir.
  int rawA0 = analogRead(MQ2_ANALOG_PIN);
  int smokeCompensated = constrain(rawA0 * 2, 0, 4095);

  float temp = dht.readTemperature();
  float hum = dht.readHumidity();

  if (isnan(temp)) temp = 23.5;
  if (isnan(hum)) hum = 50.0;

  AssetPacket packet;
  packet.schema_version = 0x01;
  packet.device_id = NODE_DEVICE_ID;
  packet.temp_c_x10 = (uint16_t)(temp * 10.0f);
  packet.humidity_pct = (uint8_t)constrain((int)hum, 0, 100);
  packet.smoke_raw = (uint16_t)smokeCompensated;
  packet.seq_no = packetSeqNo;
  packet.battery_pct = readBatteryPct();

  // CRC-8 Hesapla (İlk 12 bayt)
  packet.crc8 = calculateCRC8((const uint8_t *)&packet, sizeof(AssetPacket) - 1);

  // Manufacturer Specific Data formatına paketle (0xFFFF test Company ID)
  std::string mfgData = "";
  mfgData += (char)0xFF;
  mfgData += (char)0xFF;
  mfgData.append((const char *)&packet, sizeof(AssetPacket));

  BLEAdvertisementData advData;
  advData.setManufacturerData(String(mfgData.data(), mfgData.length()));

  // Reklam verisini güncelle (Radyo arka planda kesintisiz yayına devam eder)
  pAdvertising->setAdvertisementData(advData);

  Serial.printf("[Seq #%u] A0 Ham: %d | Telafili Duman: %d | Sıcaklık: %.1f°C | Nem: %.0f%% | CRC: 0x%02X | Eşik: %d\n",
                packet.seq_no, rawA0, packet.smoke_raw, temp, hum, packet.crc8, smokeThresholdLocal);
  // Seri port köprüsü (bridge) için doğrudan JSON çıktısı:
  Serial.printf("{\"deviceId\":%d,\"tempC\":%.1f,\"humidityPct\":%d,\"smokeRaw\":%d,\"seqNo\":%u,\"batteryPct\":%d}\n",
                packet.device_id, temp, packet.humidity_pct, packet.smoke_raw, packet.seq_no, packet.battery_pct);

  // ── Lokal Tehlike Uyarısı ──
  // smokeThresholdLocal değeri bridge üzerinden backend ThresholdConfig ile senkronize edilir.
  // Başlangıç değeri 1000'dir; bridge bağlandıktan sonra backend değerine güncellenir.
  // Bu eşiği elle düzenleme — dashboard'daki Eşik Kalibrasyonu modalını kullan.
  if (smokeCompensated > smokeThresholdLocal) {
    digitalWrite(ALARM_PIN, LOW);   // IRF5210 ON -> LED Yanar, Buzzer Çalar
  } else {
    digitalWrite(ALARM_PIN, HIGH);  // IRF5210 OFF -> Sessiz ve Sönük
  }

  // 5 saniyelik periyot beklemesi
  delay(BLE_BEACON_INTERVAL_MS);
}
