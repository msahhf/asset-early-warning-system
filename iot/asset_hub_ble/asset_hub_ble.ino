/**
 * ASSET 2.1 — Merkezi Hub Firmware (BLE Central Hub)
 * Donanım: Deneyap Kart 1A v2 (ESP32-S3 / ESP32)
 * İletişim: BLE Central (Eş zamanlı tarama) -> USB Seri Port (115200 Baud) -> PC Bridge
 */

#include <Arduino.h>
#include <BLEDevice.h>
#include <BLEUtils.h>
#include <BLEScan.h>
#include <BLEAdvertisedDevice.h>

#define SCAN_INTERVAL_MS 100
#define SCAN_WINDOW_MS 90

// 13 Baytlık Paketlenmiş Struct
struct __attribute__((packed)) AssetPacket {
  uint8_t  schema_version;
  uint8_t  device_id;
  uint16_t temp_c_x10;
  uint8_t  humidity_pct;
  uint16_t smoke_raw;
  uint32_t seq_no;
  uint8_t  battery_pct;
  uint8_t  crc8;
};

// CRC-8 Dallas/Maxim Hesaplayıcı
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

BLEScan* pBLEScan;

class MyAdvertisedDeviceCallbacks: public BLEAdvertisedDeviceCallbacks {
  void onResult(BLEAdvertisedDevice advertisedDevice) {
    if (!advertisedDevice.haveManufacturerData()) return;

    String mfg = advertisedDevice.getManufacturerData();
    // 2 bayt company id (0xFFFF) + 13 bayt AssetPacket = 15 bayt
    if (mfg.length() < 15) return;

    const uint8_t* raw = (const uint8_t*)mfg.c_str();
    // Company ID kontrolü (0xFF 0xFF)
    if (raw[0] != 0xFF || raw[1] != 0xFF) return;

    const AssetPacket* packet = (const AssetPacket*)(raw + 2);
    if (packet->schema_version != 0x01) return;

    // CRC Denetimi
    uint8_t computedCrc = calculateCRC8((const uint8_t*)packet, sizeof(AssetPacket) - 1);
    if (computedCrc != packet->crc8) {
      // Bozuk paket, atla
      return;
    }

    // BLE reklamı saniyede birden çok kez tekrarlanır; aynı seq_no tekrarını süz
    static uint32_t lastSeq[16] = {0};
    if (packet->device_id < 16) {
      if (packet->seq_no != 0 && packet->seq_no == lastSeq[packet->device_id]) {
        return; // Tekrarlanan paket, Seri Port'u boğma
      }
      lastSeq[packet->device_id] = packet->seq_no;
    }

    // Doğrulanmış paketi Seri Porta JSON olarak bas
    float temp = packet->temp_c_x10 / 10.0f;
    Serial.printf("{\"deviceId\":%d,\"tempC\":%.1f,\"humidityPct\":%d,\"smokeRaw\":%d,\"seqNo\":%u,\"batteryPct\":%d,\"rssi\":%d}\n",
                  packet->device_id,
                  temp,
                  packet->humidity_pct,
                  packet->smoke_raw,
                  packet->seq_no,
                  packet->battery_pct,
                  advertisedDevice.getRSSI());
  }
};

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n🛰️ ASSET 2.1 Central Hub Dinleyici Başlatılıyor...");

  BLEDevice::init("ASSET-HUB-CENTRAL");
  pBLEScan = BLEDevice::getScan();
  pBLEScan->setAdvertisedDeviceCallbacks(new MyAdvertisedDeviceCallbacks(), true);
  pBLEScan->setActiveScan(true); // Hızlı ve aktif tarama
  pBLEScan->setInterval(SCAN_INTERVAL_MS);
  pBLEScan->setWindow(SCAN_WINDOW_MS);

  Serial.println("✅ Eş zamanlı BLE taraması aktif. Paketler Seri Port'a iletilecek.");
}

void loop() {
  // Sürekli kesintisiz arka plan taraması
  pBLEScan->start(0, nullptr, false);
  delay(5000);
}
