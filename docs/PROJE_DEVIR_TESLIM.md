# 📋 ASSET Projesi Kapsamlı Devir Teslim Dokümanı
**Gelişmiş Akıllı Algılama ve Söndürme Teknolojisi (ASSET)**  
**Son Güncelleme / Analiz Tarihi:** 17 Ekim 2026  
**Doküman Sürümü:** 2.1.0  
**Geliştirme Ortamı:** Linux (CachyOS x86_64) / Deneyap Teknoloji Atölyeleri

---

## ⚠️ ÖNEMLİ: REPO İÇİNDEKİ İKİ FARKLI DONANIM NESLİ (v1 vs v2)

Kod tabanı ve dokümanlar incelendiğinde projede iki farklı nesil bulunduğu tespit edilmiştir:
1. **Eski Nesil (asset-aydem v1 / ASSET 1.0):**
   * **Odak:** Ev/ofis tipi tekil akıllı duman/yangın dedektörü.
   * **İletişim:** Doğrudan Wi-Fi STA modu üzerinden backend'e HTTP POST (`/api/sensors/data`, `/api/sensors/heartbeat`).
   * **İlk Kurulum:** BLE GATT servisi üzerinden SSID/Şifre aktarımı (Wi-Fi Provisioning).
   * **Fiziksel Aktüatörler:** Siren Rölesi (`D0`), Sulu Söndürme Rölesi (`D1`), Test Butonu (`D2`), Susturma Butonu (`D3`).
   * **İstemciler:** Flutter tabanlı mobil uygulama (`mobileApp/`) ve Firebase FCM bildirimleri.
   * **İlgili Dosyalar:** `iot/asset_firmware/asset_firmware.ino`, `docs/KURULUM_REHBERI.md`, `docs/AR-GE_Raporu.md`, `mobileApp/`.

2. **Yeni Nesil (ASSET 2.0 Sensör Düğümü + ASSET 2.1 BLE Hub) — GÜNCEL AKTİF SİSTEM:**
   * **Odak:** Ormanlık ve açık alan erken yangın algılama ve taktik sensör ağı (5 düğüm).
   * **İletişim:** Wi-Fi kullanılmaz. Pille çalışan düğümler BLE Manufacturer Specific Data (`0xFFFF`, 13 bayt binary struct) ile tek yönlü beacon yayını yapar.
   * **Merkezi Toplayıcı (Hub):** Deneyap Kart tabanlı BLE Central Hub (`asset_hub_ble.ino`) paketleri havadan yakalar, CRC8 doğrulaması yapar ve USB seri portu üzerinden JSON akıtır.
   * **Köprü (Bridge):** PC üzerinde koşan `backend/bridge/bridge.js` seri portu dinler, tekilleştirir (`seqNo`) ve backend Ingest API'sine (`/api/sensors/ingest`) iletir.
   * **Karar Motoru:** `backend/src/services/fusionEngine.js` ile çoklu sensör füzyonu (Duman + $\Delta T/\Delta t$ + $\Delta H$) ve zon konsensüsü (en az 2 düğümün eşzamanlı uyarısı).
   * **Fiziksel Aktüatörler:** Röleler kaldırılmıştır. Düğüm üzerinde `D1` pinine bağlı IRF5210 P-Kanal Güç MOSFET ile sürülen yerel LED ve buzzer (Active-LOW tetikleme).
   * **İstemciler:** Web tabanlı Taktik NOC Harita Paneli (`public/admin.html`) ve Tanıtım Portalı (`public/index.html`). Flutter uygulaması bu mimaride devre dışıdır.
   * **İlgili Dosyalar:** `iot/asset_node_ble/`, `iot/asset_node2_ble/`, `iot/asset_hub_ble/`, `backend/bridge/bridge.js`, `backend/src/services/fusionEngine.js`, `docs/ASSET_2.0_PIN_SEMASI.md`, `docs/ASSET_2.0_PIN_SEMASI v2.md`.

---

## 1. PROJE NEDİR

### 1.1. Projenin Amacı ve Çıkış Noktası
Geleneksel yangın ve duman dedektörleri çoğunlukla kapalı alanlarda çalışan, yalnızca lokal sesli siren (buzzer) üreten ve geniş alanlarda yangının yayılma dinamiğini takip edemeyen izole cihazlardır. **ASSET**, bu zafiyeti ortadan kaldırmak; algılama, telemetri, izleme, karar alma ve müdahale koordinasyonunu uçtan uca dijitalleştirmek amacıyla geliştirilmiştir.

### 1.2. Ev Tipinden Ormanlık Alan Versiyonuna Geçiş
* **Başlangıç Hedefi:** Ev ve binalarda Wi-Fi altyapısını kullanan, elektrik kesintisine karşı 18650 lityum pille desteklenen (UPS), duman veya gaz algılandığında sulu/gazlı solenoid vanaları röleyle tetikleyen ve ev sahibine Flutter mobil uygulaması üzerinden bildirim atan bir akıllı cihaz (`asset_firmware.ino`).
* **Mevcut / Güncel Hedef:** Altyapının (Wi-Fi, 220V şebeke) bulunmadığı ormanlık arazilerde, pil ve güneş paneli ile bağımsız çalışabilen, düşük güç tüketimli (BLE) çoklu sensör düğümlerinden meydana gelen taktik bir sensör ağı. Sistem tek bir dedektörün üflemeden veya güneş ısınmasından kaynaklı hatalı alarm (false-positive) vermesini önlemek için **sensör füzyonu** ve **zon konsensüsü** prensibini benimsemiştir.

### 1.3. Hedef Kullanıcı Profili
* **Operasyonel:** Orman Genel Müdürlüğü (OGM) kriz merkezleri, yangın gözetleme kulesi operatörleri, acil durum müdahale ekipleri (SOC/NOC operatörleri).
* **Yönetimsel:** Saha mühendisleri ve sistem yöneticileri (eşik değerlerini kalibre eden, sensör konumlarını harita üzerinde yöneten birimler).
* *(Eski ev tipi versiyonda hedef kullanıcı: Ev/ofis sahibi bireysel kullanıcılar).*

### 1.4. Drone (İHA) Durumu ve Koddaki Kalıntıları
* **Proje Durumu:** Fiziksel otonom söndürme İHA'sı (drone) donanım ve yazılım planından **çıkarılmıştır**.
* **Koddaki Kalıntıları:**
  1. `backend/public/admin.html` (Satır 231-285, 638-662, 978-1055): Leaflet haritası üzerinde "Drone Hangar Alpha" konumu tanımlıdır (`HANGAR_POS`). Kırmızı `alert:fire` alarmı tetiklendiğinde `dispatchSimulatedDrone()` fonksiyonu çalışır; hangar koordinatından yangın bölgesine uçan animasyonlu bir drone ikonu, irtifa simülasyonu (40m - 120m), hız göstergesi (60-68 km/s) ve tahmini varış süresi (ETA) sayacı barındıran **Drone Telemetry HUD Overlay** arayüzü görsel bir simülasyon olarak kodda yaşamaktadır.
  2. `backend/src/config/nodePositions.js` (Satır 30-35): `DEFAULT_HANGAR` (`HANGAR_LAT`, `HANGAR_LNG`, `HANGAR_NAME`) değişkenleri tutulmaktadır.
  3. `backend/src/controllers/sensorController.js` (Satır 317, 347, 353, 392): Test senaryolarında *"Drone kalkmaz"*, *"Simüle drone kalkışı başladı"* log ve açıklamaları yer almaktadır.
  4. **Donanımsal Durum:** Kod tabanında herhangi bir MAVLink, PX4, ArduPilot veya fiziksel drone telemetri alıcısı/kütüphanesi **bulunmamaktadır**. Drone tamamen görsel bir dashboard simülasyonudur.

---

## 2. SİSTEM MİMARİSİ VE VERİ AKIŞI

Sistem 5 katmandan oluşmaktadır:
1. **Sensör Katmanı (ASSET 2.0 Node):** Ortam verilerini toplar, paketler ve BLE ile yayınlar.
2. **Toplayıcı Katmanı (ASSET 2.1 Hub):** BLE paketlerini havadan toplar ve USB-UART üzerinden PC'ye döker.
3. **Köprü Katmanı (`bridge.js`):** Seri port verisini ayrıştırır, CRC doğrular, yerel REST Ingest API'sine iletir. Eşik güncellemelerini USB üzerinden karta geri besler.
4. **Backend & Karar Katmanı (Node.js Express / Socket.io / MongoDB Atlas / Redis):** Paketleri işler, hareketli pencerede analiz eder, zon konsensüsünü hesaplar, veritabanına yazar ve WebSocket ile dağıtır.
5. **Görselleştirme & Taktik Katman (`admin.html` / `index.html`):** Harita üzerinde nodeları, duman eğrilerini ve alarmları canlı gösterir.

### 2.1. Metin Tabanlı Uçtan Uca Veri Akış Şeması

```text
+-----------------------+     +-----------------------+
|  ASSET 2.0 Node #1    |     |  ASSET 2.0 Node #2    |
|  [MQ-2 + DHT11]       |     |  [MQ-2 + DHT11]       |
|  (Pilden Beslemeli)   |     |  (Pilden Beslemeli)   |
+-----------+-----------+     +-----------+-----------+
            |                             |
     BLE Adv (5 sn)                BLE Adv (5 sn)
  Mfg Data (13 Bayt Struct)     Mfg Data (13 Bayt Struct)
            |                             |
            +--------------+--------------+
                           |
                           v
            +-------------------------------+
            |  ASSET 2.1 BLE Central Hub    |
            |  (Deneyap Kart 1A v2 - USB)   |
            |  - Sürekli BLE Tarama (90ms)  |
            |  - CRC-8 Sağlama Kontrolü     |
            |  - SeqNo Tekilleştirme        |
            +---------------+---------------+
                            |
                   USB Seri Port (115200 Baud)
                   JSON / Hex Karakter Dizisi
                            |
                            v
            +-------------------------------+
            |  PC Seri Port Köprüsü         |
            |  (backend/bridge/bridge.js)   |
            |  - Çoklu Port Otomatik Algı   |
            |  - CRC-8 Doğrulama            |
            |  - HTTP POST + x-api-key      |
            +---------------+---------------+
                            |
             HTTP POST /api/sensors/ingest
             (x-api-key Doğrulamalı)
                            |
                            v
            +-------------------------------+
            |  ASSET 2.1 Backend Sunucusu   |
            |  (Node.js / Express 5.x)      |
            +---------------+---------------+
                            |
            +---------------+---------------+
            |                               |
            v                               v
+-----------------------+       +-----------------------+
| fusionEngine.js       |       | Veri Depolama         |
| 1. Düğüm Füzyonu      |       | - MongoDB Atlas       |
|   (Duman + ΔT + ΔH)   |       |   (Device, SensorLog, |
| 2. Zon Konsensüsü     |       |    Alert, Config)     |
|   (minNodes >= 2)     |       | - Redis (Opsiyonel /  |
| 3. Cooldown (180 sn)  |       |   In-Memory Map)      |
+-----------+-----------+       +-----------------------+
            |
    Socket.io Eventleri
    (sensor:update, node:warning, alert:fire, alert:resolved)
            |
            +-------------------------------+
            |                               |
            v                               v
+-------------------------------+ +-------------------------------+
| Taktik NOC Harita Paneli      | | Cloudflare Tunnel             |
| (public/admin.html)           | | admin.airdusremote.com        |
| - Leaflet & CARTO Vector      | | api.airdusremote.com          |
| - Canlı Chart.js Duman Eğrisi | +-------------------------------+
| - Drone Simülasyon HUD        |
| - Eşik Kalibrasyon Modalı     |
+-------------------------------+
```

---

## 3. KLASÖR VE DOSYA YAPISI

```text
/home/sah/Belgeler/Deneyap/asset-aydem/asset/
├── backend/                       # Node.js REST API & WebSocket Sunucusu
│   ├── app.js                     # Express konfigürasyonu, CORS, Helmet, Rate-Limit ve yönlendirme
│   ├── server.js                  # HTTP server & Socket.io başlatıcı, Graceful Shutdown
│   ├── package.json               # Bağımlılıklar (Express 5, Mongoose 9, Socket.io 4, Serialport 13)
│   ├── .env                       # Aktif çevre değişkenleri (MongoDB URI, API Key vb.)
│   ├── .env.example               # Örnek çevre değişkenleri şablonu
│   ├── bridge/
│   │   └── bridge.js              # ASSET 2.1 PC Seri Port - Backend köprü servisi
│   ├── scripts/
│   │   └── simulate_scenarios.js  # 5 Node için konsol tabanlı test senaryosu simülatörü
│   ├── public/
│   │   ├── admin.html             # ASSET NOC Taktik Yangın Komuta Haritası ve Dashboard
│   │   └── index.html             # AIRDUS Remote resmi tanıtım, onboarding ve kullanıcı portali
│   └── src/
│       ├── config/
│       │   ├── db.js              # Mongoose MongoDB bağlantı havuzu
│       │   ├── redis.js           # Redis client ve bellek içi (In-Memory Map) fallback katmanı
│       │   ├── firebase.js        # Firebase Admin SDK başlatıcı
│       │   └── nodePositions.js   # 5 Node ve Drone Hangarının statik GPS/Zon koordinat konfigürasyonu
│       ├── controllers/
│       │   ├── alertController.js # Alarm geçmişi sorgulama API'leri
│       │   ├── authController.js  # Kullanıcı kayıt, giriş ve profil işlemleri (JWT)
│       │   ├── deviceController.js# Cihaz ekleme, acil durum kişileri bağlama, telemetri geçmişi
│       │   └── sensorController.js# Ingest, heartbeat, eşik yönetimi ve senaryo simülasyon metodları
│       ├── middleware/
│       │   └── authMiddleware.js  # JWT doğrulama ara yazılımı
│       ├── models/
│       │   ├── Alert.js           # Yangın ve uyarı alarmları MongoDB şeması
│       │   ├── Device.js          # IoT cihazları şeması (UUID, zon, batarya, konum, paket kaybı)
│       │   ├── SensorLog.js       # Zaman serisi ölçüm logları (30 gün TTL indeksli)
│       │   ├── ThresholdConfig.js # Dinamik eşik ve konsensüs parametreleri şeması
│       │   └── User.js            # Kullanıcı hesapları ve acil durum rehberi şeması
│       ├── routes/
│       │   ├── alertRoutes.js     # /api/alerts rota tanımları
│       │   ├── apiRoutes.js       # Ana API router birleştirici
│       │   ├── authRoutes.js      # /api/auth rota tanımları
│       │   ├── deviceRoutes.js    # /api/devices rota tanımları
│       │   └── sensorRoutes.js    # /api/sensors (ingest, heartbeat, thresholds, overview)
│       ├── services/
│       │   ├── fusionEngine.js    # Çoklu sensör füzyonu ve zon konsensüs motoru (Singleton)
│       │   ├── notificationService.js # FCM Push Notification servisi
│       │   └── redisService.js    # Cihaz yaşam (TTL) ve durum tamponlama servisi
│       ├── socket/
│       │   └── socketHandler.js   # Canlı telemetri yayınlayan Socket.io odaları
│       └── utils/
│           ├── errorHandler.js    # Global hata yakalayıcı (404 ve 500)
│           └── logger.js          # Winston tabanlı kütükleme servisi
├── iot/                           # Gömülü Yazılımlar (Firmware)
│   ├── asset_firmware/            # [ESKİ NESİL] Wi-Fi + Röleli v1 ev prototipi firmware'i
│   │   └── asset_firmware.ino
│   ├── asset_hub_ble/             # [GÜNCEL] ASSET 2.1 BLE Central Hub dinleyici firmware'i
│   │   └── asset_hub_ble.ino
│   ├── asset_node_ble/            # [GÜNCEL] ASSET 2.0 Sensör Düğümü (Node #1) firmware'i
│   │   └── asset_node_ble.ino
│   └── asset_node2_ble/           # [GÜNCEL] ASSET 2.0 Sensör Düğümü (Node #2) firmware'i
│       └── asset_node2_ble.ino
├── mobileApp/                     # [ESKİ NESİL] Flutter tabanlı mobil uygulama
│   ├── lib/                       # Flutter ekran, servis ve provider kodları
│   └── pubspec.yaml               # Flutter paket bağımlılıkları
├── docs/                          # Proje Dokümantasyonu
│   ├── AR-GE_Raporu.md            # [ESKİ NESİL] v1 AR-GE ve donanım raporu
│   ├── KURULUM_REHBERI.md         # [ESKİ NESİL] v1 Wi-Fi + Flutter kurulum kılavuzu
│   ├── ASSET_2.0_PIN_SEMASI.md    # [GÜNCEL] ASSET 2.0 MOSFET & Sensör bağlantı şeması
│   ├── ASSET_2.0_PIN_SEMASI v2.md # [GÜNCEL] ASSET 2.0 Hızlı kurulum ve checklist
│   └── PROJE_DEVIR_TESLIM.md      # Bu kapsamlı devir teslim dokümanı
└── 3d_files/                      # 3D Kapsül ve Kutu Tasarımları (.scad / .stl)
```

---

## 4. DONANIM VE FIRMWARE ANALİZİ

### 4.1. Mikrodenetleyici Kartı ve İsim Tutarsızlığı
* **Doğru Donanım:** **Deneyap Kart 1A v2**
* **Çip Mimarisi:** **ESP32-S3** (Type-C soketli).
* **Arduino IDE Kart Seçimi:** `Araçlar → Kart → Deneyap Kart → Deneyap Kart 1A v2`
* **Dokümanlardaki Çelişki:**
  - `docs/KURULUM_REHBERI.md` Satır 42'de kart *ESP32-WROOM-32* olarak yazılmıştır (bu Deneyap Kart 1A v1'in çipidir).
  - `docs/ASSET_2.0_PIN_SEMASI.md` dosyasında kısaca *Deneyap Kart 1A* yazılmıştır.
  - Gerçek fiziksel kartlar ve firmware başlıkları (`asset_node_ble.ino:3`) **Deneyap Kart 1A v2 (ESP32-S3)** donanımıdır.

### 4.2. Donanım Nesillerinin Pin Karşılaştırması

| Fonksiyon / Bileşen | Eski Nesil (v1 - `asset_firmware.ino`) | Yeni Nesil (v2 - `asset_node_ble.ino`) | Kritik Not / Çakışma |
| :--- | :--- | :--- | :--- |
| **Gaz / Duman Sensörü** | MQ-2 Analog Çıkış $\rightarrow$ **A0** | MQ-2 Analog Çıkış $\rightarrow$ **A0** | Her iki nesilde de `A0` kullanılır. |
| **Sıcaklık ve Nem** | Yok (veya kodda harici sabit) | DHT11 Data $\rightarrow$ **D4** (10k Pull-up) | v1'de DHT bağlı değildi. |
| **Alarm / Müdahale Çıkışı** | **D1** (Su Rölesi - Active HIGH) | **D1** (IRF5210 Gate - Active LOW) | ⚠️ **KRİTİK ÇAKIŞMA:** v1 röle açmak için `D1`'i HIGH yapar; v2 MOSFET'i açmak için `D1`'i LOW yapar. Eski kod yeni karta yüklenirse buzzer sürekli öter! |
| **İkincil Siren Çıkışı** | **D0** (Siren Rölesi) | *Kullanılmıyor* (Boşta) | v2'de siren ve LED tek bir MOSFET üzerinden `D1` ile sürülür. |
| **Test Butonu** | **D2** (Input Pull-up) | *Kullanılmıyor* (Boşta) | v2'de donanım butonu yoktur; testler API simülasyonu ile yapılır. |
| **Susturma Butonu** | **D3** (Input Pull-up) | *Kullanılmıyor* (Boşta) | v2'de buton yoktur. |
| **Pil Voltaj Okuma** | **A1** (Gerilim Bölücü) | *Kodda sabit %95 dönülür* | v2 firmware'de `readBatteryPct()` analog okuma yapmaz, sabit 95 döner. |

### 4.3. Yeni Nesil (ASSET 2.0) P-Kanal MOSFET (IRF5210) Sürme Mantığı
IRF5210 bir P-Kanal Güç MOSFET'idir ve **High-Side Switch** olarak pozitif 3.3V hattını anahtarlar:
* **Gate = HIGH (3.3V):** $V_{GS} = V_{Gate} - V_{Source} = 3.3V - 3.3V = 0V$. MOSFET kesimdedir (**OFF**). LED ve Buzzer sönük/sessizdir.
* **Gate = LOW (0V - GND):** $V_{GS} = 0V - 3.3V = -3.3V$. MOSFET iletimdedir (**ON**). 3.3V akımı Drain üzerinden LED ve Buzzer'a akar.
* **Açılış Glitch Koruması:** `setup()` içinde pin önce `digitalWrite(ALARM_PIN, HIGH)` yapılır, ardından `pinMode(ALARM_PIN, OUTPUT)` verilir. Ayrıca Gate ile Source (3.3V) arasına 10k$\Omega$ pull-up direnç konulmuştur.

### 4.4. 13 Baytlık Paketlenmiş Struct ve CRC-8 Doğrulaması

Firmware (`asset_node_ble.ino`, `asset_hub_ble.ino`), PC Köprüsü (`bridge.js`) ve Backend (`sensorController.js`) arasında kullanılan ikili veri yapısı:

```c
struct __attribute__((packed)) AssetPacket {
  uint8_t  schema_version;   // Bayt 0:    Şema versiyonu (Sabit 0x01)
  uint8_t  device_id;        // Bayt 1:    Düğüm ID (1 - 5)
  uint16_t temp_c_x10;       // Bayt 2-3:  Sıcaklık x10 Little-Endian (örn. 245 = 24.5°C)
  uint8_t  humidity_pct;     // Bayt 4:    Bağıl Nem (%0 - 100)
  uint16_t smoke_raw;        // Bayt 5-6:  MQ-2 ADC Telafili Değer (0 - 4095) Little-Endian
  uint32_t seq_no;           // Bayt 7-10: Paket Sıra Numarası Little-Endian (32-bit)
  uint8_t  battery_pct;      // Bayt 11:   Pil Yüzdesi (%0 - 100)
  uint8_t  crc8;             // Bayt 12:   İlk 12 baytın CRC-8 Dallas/Maxim sağlama toplamı
};
// Toplam Uzunluk: 13 Bayt
```

* **CRC-8 Polinomu:** `0x07` (Dallas/Maxim: $x^8 + x^2 + x + 1$), Başlangıç değeri: `0x00`.
* **Hesaplama:** İlk 12 bayt üzerinde bit düzeyinde XOR ve kaydırma yapılarak hesaplanır. 13. bayttaki gelen CRC ile karşılaştırılır. Uyuşmazsa paket Hub ve Bridge seviyesinde doğrudan çöpe atılır.

### 4.5. Eşik Değeri Senkronizasyonu Durumu (ÖNEMLİ ANALİZ)
Firmware kodunda (`asset_node_ble.ino:37`):
```cpp
volatile int smokeThresholdLocal = 1000;
```
* **USB Üzerinden Senkronizasyon:** Karta seri port üzerinden `THRESHOLD:<değer>\n` yazıldığında `processSerialCommand()` fonksiyonu bu komutu yakalar, `smokeThresholdLocal` değişkenini günceller ve `THRESHOLD_ACK:<değer>` döner. `bridge.js` backend'deki `ThresholdConfig.smokeThreshold` (varsayılan 850) değerini okuyup seri porta basacak şekilde tasarlanmıştır.
* **Sahada / Pilde Çalışırken Senkronizasyon Durumu [BELİRSİZ / RİSK]:**
  - Sensör düğümleri arazide pille çalışırken USB portuna bağlı DEĞİLDİR.
  - Düğümler BLE üzerinden yalnızca tek yönlü yayın (Advertising) yapmaktadır; Hub'a gelen bir GATT bağlantısı veya geri bildirim kanalı yoktur.
  - **Sonuç:** Düğüm pille çalışırken backend'den veya dashboard'dan değiştirilen eşik değerini kablosuz olarak **ALAMAZ**. Kendi üzerindeki başlangıç değeri olan `1000` eşiğiyle lokal alarm (buzzer/LED) kontrolü yapar. Backend ise veritabanındaki `850` eşiğine göre konsensüs kararı verir.

---

## 5. BACKEND VE KARAR MOTORU (FUSION ENGINE)

### 5.1. API Uç Noktaları Kataloğu

| Yöntem | Endpoint | Yetkilendirme | Açıklama |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/sensors/ingest` | `x-api-key` (Zorunlu) | Hub veya Bridge'den gelen telemetri paketini (`rawHex` veya JSON) kabul eder ve füzyon motoruna iletir. |
| `POST` | `/api/sensors/data` | `x-api-key` (Zorunlu) | v1 geriye dönük uyumluluk veri yükleme ucu. |
| `POST` | `/api/sensors/heartbeat` | `x-api-key` (Zorunlu) | Cihaz yaşam sinyali ve batarya güncelleme. |
| `GET` | `/api/config/thresholds` | Açık | Aktif `ThresholdConfig` eşik parametrelerini döner. |
| `PUT` | `/api/config/thresholds` | Açık | Eşik parametrelerini günceller ve Socket.io ile `config:updated` yayar. |
| `GET` | `/api/sensors/nodes-overview`| Açık | Dashboard için 5 node durumu, son 20 ölçüm logu, aktif alarmlar ve hangar koordinatını döner. |
| `POST` | `/api/sensors/simulate-scenario` | Açık | Hızlı test senaryosu uygular (`normal`, `single_warning`, `consensus_fire`). |
| `POST` | `/api/auth/register` | Açık | Yeni kullanıcı kaydı. |
| `POST` | `/api/auth/login` | Açık | Giriş ve JWT token üretimi. |
| `GET` | `/api/auth/me` | JWT (Bearer) | Aktif kullanıcı profili. |
| `GET` | `/api/devices` | JWT (Bearer) | Kullanıcının cihaz listesi. |
| `POST` | `/api/devices` | JWT (Bearer) | Yeni cihaz kaydı (Benzersiz `deviceId` ve `apiKey` üretir). |
| `GET` | `/api/alerts` | JWT (Bearer) | Alarm geçmişi sorgulama. |
| `GET` | `/api/health` | Açık | UptimeRobot / Sistem sağlık kontrolü (DB & Redis durumu). |
| `GET` | `/api/sysinfo` | Açık | Sistem bellek, uptime ve son 50 HTTP isteği dökümü. |

### 5.2. Veri Modelleri
1. **`Device` (`backend/src/models/Device.js`):**
   * Alanlar: `name`, `deviceId` (unique String), `apiKey` (gizli), `zoneId` ("zone-alpha", "zone-bravo"), `coordinates` (`lat`, `lng`), `location` ("ASSET Sektör 1"), `status` (`online`, `offline`, `warning`, `fire`), `isOnline`, `batteryPct`, `totalPacketsReceived`, `totalPacketsLost`, `lastSeq`, `lastSeen`, `lastHeartbeat`.
   * **`forestRegion` Analizi:** Kod tabanında `forestRegion` adında bir model veya alan **YOKTUR**. Bölge gruplaması `zoneId` üzerinden, metin açıklaması ise `location` üzerinden yapılmaktadır.
2. **`Alert` (`backend/src/models/Alert.js`):**
   * Alanlar: `alertId` (UUID), `zoneId`, `severity` (`warning`, `fire`), `type` (`fire`, `gas_warning`, `offline`), `triggeringDeviceIds` (String dizisi), `coordinates` (`lat`, `lng`), `message`, `resolved` (Boolean), `resolvedAt`, `notificationStatus`.
3. **`SensorLog` (`backend/src/models/SensorLog.js`):**
   * Alanlar: `deviceId`, `tempC`, `humidityPct`, `smokeRaw`, `movingAvgSmoke`, `smokeFlag`, `heatRateFlag`, `humidityDropFlag`, `gasStatus`, `source` (`hardware`, `mock`, `sim`), `rawSeqNo`, `timestamp`.
   * **Arşivleme / Otomatik Temizlik:** Koleksiyon üzerinde 30 günlük MongoDB TTL indeksi (`expireAfterSeconds: 30 * 24 * 60 * 60`) tanımlıdır. 30 günden eski loglar veritabanı motoru tarafından otomatik silinir.
4. **`ThresholdConfig` (`backend/src/models/ThresholdConfig.js`):**
   * `smokeThreshold` (varsayılan: 850)
   * `heatRateThresholdCPerSec` (varsayılan: 0.15 °C/s)
   * `humidityDropThresholdPct` (varsayılan: %5.0)
   * `windowSeconds` (varsayılan: 45 sn)
   * `minNodesForFire` (varsayılan: 2 düğüm)
   * `cooldownSeconds` (varsayılan: 180 sn)
   * `movingAverageSize` (varsayılan: 3 örnek)

### 5.3. Karar Mantığı (`fusionEngine.js`)

#### 1. Düğüm Seviyesi Füzyon (Node Fusion)
Her gelen paket için düğümün son okumaları bir hareketli pencere tamponunda (`deviceWindows`) saklanır:
* **Duman Kontrolü:** Son 3 okumanın ortalaması alınır: $\bar{S} \ge \text{smokeThreshold}$ ise `smokeFlag = true`.
* **Isı Artış Hızı Kontrolü:** Tampondaki en eski ve en yeni örnek arasındaki türev hesaplanır:
  $$\frac{\Delta T}{\Delta t} = \frac{T_{\text{yeni}} - T_{\text{eski}}}{t_{\text{yeni}} - t_{\text{eski}}} \ge 0.15 \, ^\circ\text{C/sn} \implies \text{heatRateFlag} = \text{true}$$
* **Ani Nem Düşüşü Kontrolü:** Yangın anında havanın hızla kuruması izlenir:
  $$\Delta H = H_{\text{eski}} - H_{\text{yeni}} \ge 5\% \implies \text{humidityDropFlag} = \text{true}$$
* **DÜĞÜM UYARI (WARNING) KURALI:**
  $$\text{isWarning} = \text{smokeFlag} \land (\text{heatRateFlag} \lor \text{humidityDropFlag})$$
  *(DHT11'in ısı artış ve nem düşüş verisi koddaki `isWarning` kararında bizzat kullanılmaktadır; tek başına duman yükselmesi düğümü WARNING yapmaz).*

#### 2. Zon Seviyesi Konsensüs (Zone Consensus)
* Aynı `zoneId` içindeki düğümlerin son `windowSeconds` (45 sn) içinde aktif `isWarning` verip vermediği taranır.
* **YANGIN (FIRE) KURALI:**
  $$\text{Aktif Uyarı Veren Düğüm Sayısı} \ge \text{minNodesForFire} \quad (\text{Varsayılan: } 2)$$
* **Cooldown Mekanizması:** Yangın alarmı oluştuktan sonra `cooldownSeconds` (180 sn) boyunca aynı zon için mükerrer alarm ve bildirim üretilmez (`fire_cooldown`).
* **Sönme / Normale Dönüş:** Aktif uyarı sayısı konsensüs eşiğinin altına düşer ve cooldown süresi dolarsa alarm otomatik kapatılır (`alert:resolved` yayılır, düğümler `online` durumuna döner).

### 5.4. Bildirim Akışı ve Dış Kurum Entegrasyonları
* **FCM (Firebase Cloud Messaging):** `notificationService.js` üzerinden kullanıcı tokenlarına yüksek öncelikli (`asset_alarm_channel_v3`) push bildirim gönderilir.
* **E-Posta Bildirimi:** Kodda bir e-posta gönderim modülü (Nodemailer, SendGrid vb.) **BULUNMAMAKTADIR**. `Alert.notifiedUsers` alanında kullanıcı referansları tutulmakta ancak fiziksel e-posta tetiklenmemektedir.
* **OGM / Alo 177 Durumu [BELİRSİZ / KODLANMAMIŞ]:**
  - Orman Genel Müdürlüğü (OGM) sistemleri, Alo 177 acil hattı veya herhangi bir harici SMS / IVR çağrı merkezi entegrasyonu kod tabanında **YOKTUR**. Bu kısımlar tamamen kavramsal hedeftir, kodda bir kalıntısı veya servisi bulunmamaktadır.

---

## 6. FRONTEND / DASHBOARD ANALİZİ

### 6.1. Taktik NOC Komuta Merkezi (`backend/public/admin.html`)
* **Kullanılan Teknolojiler:** HTML5, Vanilla JavaScript, CSS3 (Glassmorphism dark theme), Leaflet 1.9.4, MapLibre GL 3.6.2 & `@maplibre/maplibre-gl-leaflet`, Chart.js, Socket.io Client.
* **Harita Katmanları:**
  - CARTO Dark Matter Vektör Haritası (Filigransız / MapLibre GL ile yüksek performanslı render).
  - Esri World Imagery (Yüksek çözünürlüklü uydu görüntüsü altlığı).
* **Canlı Göstergeler ve Öğeler:**
  - 5 sensör düğümünün GPS konumları, durum renkleri (Yeşil: Güvenli, Sarı: Uyarı, Kırmızı: Yangın Konsensüsü, Gri: Çevrimdışı).
  - Sensör kartlarında veri kaynağı rozetleri (`HW`: Gerçek Donanım, `MOCK`: Sanal Köprü, `SIM`: Senaryo Simülasyonu).
  - Anlık duman (ham ve filtreli) zaman serisi grafiği.
  - Eşik Kalibrasyon Modalı (`PUT /api/config/thresholds`).
  - Hızlı Senaryo Tetikleme Butonları (`Normal`, `Tekli Uyarı`, `Konsensüs Yangın`, `Sıfırla`).

### 6.2. Resmi Tanıtım ve Giriş Portalı (`backend/public/index.html`)
* `airdusremote.com` ana alan adı için hazırlanan vitrin sayfası.
* Sistem mimarisi tanıtımı, canlı sistem durumu rozeti (`socket.io` ile bağlı düğüm sayısını anlık gösterir) ve yetkili giriş/kayıt modalı (`/api/auth/login` ve `/api/auth/register`).

---

## 7. KURULUM VE ÇALIŞTIRMA REHBERİ

### 7.1. Gereksinimler
* Node.js (v18.x, v20.x veya v22.x LTS)
* npm (v9.x veya v10.x)
* MongoDB (Yerel MongoDB v6.0+ veya MongoDB Atlas Cloud)
* Redis (v6.2+ veya Upstash / Yoksa otomatik bellek içi mock devreye girer)
* Arduino IDE (v2.x) + Deneyap Kart Paketleri
* USB-UART Sürücüleri (CP210x veya CH340)

### 7.2. Ortam Değişkenleri Kataloğu (`backend/.env`)

> ⚠️ **GÜVENLİK KURALI:** Aşağıda gizli değerler YAZILMAMIŞTIR; sadece değişken adları ve işlevleri listelenmiştir. Değerler `backend/.env` dosyasında tutulur.

| Değişken Adı | Zorunlu mu? | Açıklama / Görevi |
| :--- | :--- | :--- |
| `PORT` | Hayır (Vars: 5000) | Express HTTP dinleme portu. |
| `NODE_ENV` | Hayır (Vars: development)| Çalışma ortamı (`development`, `production`). |
| `MONGODB_URI` | **Evet** | MongoDB Atlas veya yerel bağlantı adresi. |
| `REDIS_URI` | Hayır | Redis bağlantı adresi. Boş bırakılırsa bellek içi Map kullanılır. |
| `JWT_SECRET` | **Evet** | Kullanıcı oturum tokenlarını imzalayan gizli anahtar. |
| `INGEST_API_KEY` | **Evet** | Bridge ve donanımın `/api/sensors/ingest` erişiminde kullandığı anahtar. |
| `ALLOWED_ORIGINS` | Hayır | CORS izinli alan adları virgülle ayrılmış liste. |
| `HEARTBEAT_TIMEOUT_MS`| Hayır (Vars: 60000) | Düğüm çevrimdışı sayılma süresi. |
| `CARTO_API_KEY` | Hayır | CARTO vektör harita altlığı API anahtarı. |
| `FIREBASE_PROJECT_ID` | Hayır | Firebase Admin SDK proje kimliği (FCM için). |
| `FIREBASE_CLIENT_EMAIL`| Hayır | Firebase servis hesabı e-postası. |
| `FIREBASE_PRIVATE_KEY` | Hayır | Firebase servis hesabı RSA gizli anahtarı. |
| `BACKEND_HOST` | Hayır (Bridge için) | `bridge.js`'in bağlanacağı backend adresi (Vars: localhost). |
| `BACKEND_PORT` | Hayır (Bridge için) | `bridge.js`'in bağlanacağı backend portu (Vars: 5000). |
| `NODE_POSITIONS_JSON` | Hayır | 5 düğümün konumlarını kod değiştirmeden ezmek için JSON dizesi. |

### 7.3. Adım Adım Çalıştırma Komutları

#### 1. Backend Sunucusunu Başlatma
```bash
cd /home/sah/Belgeler/Deneyap/asset-aydem/asset/backend
npm install
npm run dev
```
*Beklenen çıktı:*
```text
✅ MongoDB bağlandı: ...
ℹ️ Redis URI ayarlanmadı, bellek içi (In-Memory Map) önbellek aktif.
🚀 ASSET Backend API çalışıyor: http://localhost:5000
```

#### 2. ASSET 2.1 BLE Hub'ı Yükleme ve Bağlama
1. Deneyap Kart 1A v2'yi USB ile bağlayın.
2. Arduino IDE'den `iot/asset_hub_ble/asset_hub_ble.ino` dosyasını açın.
3. Kart: `Deneyap Kart 1A v2`, Port: `/dev/ttyUSB1` (veya ilgili port) seçip yükleyin.
4. Yükleme bitince seri port ekranını **kapatın**.

#### 3. PC Köprü Servisini (Bridge) Başlatma
```bash
cd /home/sah/Belgeler/Deneyap/asset-aydem/asset/backend
# Otomatik port algılama ile:
node bridge/bridge.js

# Veya belirli bir port belirterek:
node bridge/bridge.js --port=/dev/ttyUSB1 --baud=115200

# Donanım bağlı değilken sanal akış (Mock) başlatmak için:
node bridge/bridge.js --mock
```

#### 4. Sensör Düğümlerini (Node) Programlama ve Çalıştırma
1. Node #1 için `iot/asset_node_ble/asset_node_ble.ino` dosyasında `#define NODE_DEVICE_ID 1` yapıp karta yükleyin.
2. Node #2 için `iot/asset_node2_ble/asset_node2_ble.ino` dosyasında `#define NODE_DEVICE_ID 2` yapıp karta yükleyin.
3. Kartları pilden besleyin. Hub BLE paketlerini yakalayacak ve terminalde iletim logları akacaktır.

#### 5. Cloudflare Tünelini Açma (İnternet Yayını)
```bash
cloudflared tunnel run asset-backend
# Veya hızlı tünel için:
cloudflared tunnel --url http://localhost:5000
```

#### 6. Test ve Simülasyon Komutları
Backend çalışırken harici test tetiklemek için:
```bash
# Yangın konsensüs testi:
curl -X POST http://localhost:5000/api/sensors/simulate-scenario \
  -H "Content-Type: application/json" \
  -d '{"scenario":"consensus_fire"}'

# Tekli uyarı testi (Drone kalkmaz, sarı warning):
curl -X POST http://localhost:5000/api/sensors/simulate-scenario \
  -H "Content-Type: application/json" \
  -d '{"scenario":"single_warning"}'

# Normale döndürme:
curl -X POST http://localhost:5000/api/sensors/simulate-scenario \
  -H "Content-Type: application/json" \
  -d '{"scenario":"normal"}'

# Sağlık kontrolü:
curl http://localhost:5000/api/health
```

---

## 8. PROJE DURUM TABLOSU

| Modül / Özellik | Durum | İlgili Dosya Yolu | Notlar |
| :--- | :---: | :--- | :--- |
| **ASSET 2.0 Node BLE Beacon** | **Tamamlandı** | `iot/asset_node_ble/asset_node_ble.ino` | 13B struct, CRC8, 5sn yayın, active-low MOSFET alarmı çalışıyor. |
| **ASSET 2.1 BLE Central Hub** | **Tamamlandı** | `iot/asset_hub_ble/asset_hub_ble.ino` | Kesintisiz tarama, CRC8 kontrolü ve USB seri JSON çıktısı çalışıyor. |
| **PC Seri Port Köprüsü (Bridge)** | **Tamamlandı** | `backend/bridge/bridge.js` | Auto-detect, CRC8, Ingest API iletimi, mock modu çalışıyor. |
| **Sensör Füzyon Motoru** | **Tamamlandı** | `backend/src/services/fusionEngine.js` | Duman + $\Delta T/\Delta t$ + $\Delta H$ düğüm füzyonu ve zon konsensüsü çalışıyor. |
| **Dinamik Eşik Yönetimi** | **Tamamlandı** | `backend/src/models/ThresholdConfig.js` | REST API ve Socket.io ile runtime güncelleme çalışıyor. |
| **Taktik NOC Dashboard** | **Tamamlandı** | `backend/public/admin.html` | CARTO vektör harita, Chart.js, canlı socket göstergeleri çalışıyor. |
| **Resmi Tanıtım & Auth Portalı** | **Tamamlandı** | `backend/public/index.html` | Glassmorphism UI, onboarding kartları ve JWT auth formları hazır. |
| **Cloudflare Tunnel Entegrasyonu** | **Tamamlandı** | `~/.cloudflared/config.yml` | `admin.airdusremote.com` ve `api.airdusremote.com` üzerinden canlı yayında. |
| **Pilli Düğümlerde Eşik Senkronu** | **Yarım Kaldı** | `iot/asset_node_ble/asset_node_ble.ino` | Düğüm USB'de değilken backend eşiğini kablosuz alamıyor (Varsayılan 1000'de kalıyor). |
| **Drone (İHA) Fiziksel Entegrasyonu**| **İptal Edildi** | `backend/public/admin.html:978` | Fiziksel drone çıkarıldı; dashboard üzerinde sadece görsel animasyon kaldı. |
| **FCM Push Bildirimleri** | **Yarım Kaldı** | `backend/src/services/notificationService.js` | Altyapı var ancak Firebase servis anahtarı girilmediğinde pasif kalıyor. |
| **E-Posta ve SMS Bildirimleri** | **Başlanmadı** | `backend/src/services/notificationService.js` | Kodda Nodemailer veya SMS entegrasyonu kodlanmamış. |
| **OGM / Alo 177 Entegrasyonu** | **Başlanmadı** | *Yok* | Kodda resmi kurum entegrasyonu bulunmuyor. |
| **Flutter Mobil Uygulaması** | **Eski / Devre Dışı** | `mobileApp/` | v1 ev prototipi için kalmış, v2 taktik sensör ağıyla entegre değil. |

---

## 9. BİLİNEN SORUNLAR, RİSKLER VE ÇELİŞKİLER

### 9.1. Kod ile Doküman Çelişkileri
1. **Mikrodenetleyici Çipi:** `docs/KURULUM_REHBERI.md` dosyasında kart *ESP32-WROOM-32* olarak tanımlanmıştır. Oysa gerçek donanım ve firmware **Deneyap Kart 1A v2 (ESP32-S3)** tabanlıdır.
2. **D1 Pini Anlam Çatışması:** Eski rehber ve firmware'de `D1` pini *Su Rölesi (Active HIGH)* olarak tanımlıyken; güncel ASSET 2.0 şemasında `D1` pini *IRF5210 P-Kanal MOSFET Gate (Active LOW)* olarak buzzer/LED sürmektedir.
3. **Mimarinin Değişimi:** `docs/KURULUM_REHBERI.md` ve `docs/AR-GE_Raporu.md` projenin Wi-Fi + Röleli ev dedektörü olduğunu iddia etmektedir. Ancak kod tabanı BLE Beacon + Hub + Bridge + Web NOC haritasına evrilmiştir.

### 9.2. Kod İçi Riskler ve Açık Noktalar
1. **Sabit Kodlanmış API Anahtarları (Hardcoded Secrets):**
   - `backend/src/controllers/sensorController.js:67`: `<INGEST_API_KEY>` fallback master key olarak koda gömülmüştür.
   - `backend/bridge/bridge.js:23`: Aynı key bridge içine gömülmüştür. `.env` yoksa bu anahtarla yetkilendirme geçilebilir.
2. **`scripts/simulate_scenarios.js` Yetkilendirme Hatası:**
   - Script, `sendPacket()` içinde HTTP başlıklarına `x-api-key` eklemez. Backend'de `INGEST_API_KEY` zorunlu olduğu için script doğrudan çalıştırıldığında `401 Unauthorized` hatası alır.
3. **Pilli Düğümlerde `readBatteryPct()`:**
   - `asset_node_ble.ino:76`: Gerçek voltaj okuması yapılmamakta, kod sabit olarak `return 95;` dönmektedir. Piller bitse bile dashboard %95 göstermeye devam eder.
4. **TODO / Tamamlanmamış Kodlar:**
   - `mobileApp/lib/features/auth/screens/register_screen.dart:23`: `// TODO: backend entegrasyonu` yorumu bulunmaktadır.
5. **DHT11 Sensör Hassasiyeti:**
   - Açık arazide DHT11 sensörünün nem hassasiyeti (%$\pm5$) ve sıcaklık tepki süresi (6-10 saniye) orman yangını başlangıcındaki ani değişimleri yakalamada DHT22 veya endüstriyel sensörlere göre yavaş kalabilir.

---

## 10. GİT GEÇMİŞİ VE ÇALIŞMA DİZİNİ ÖZETİ

### 10.1. Branch Listesi
* `main` (Aktif yerel dal)
* `remotes/origin/main` (Uzak GitHub dalı)

### 10.2. Son Commitler
* `5b68058 (HEAD -> main, origin/main)`: *asset-v1-latest*
* `c5e7980`: *asset-v1-latest*
* `296f398`: *asset-v1*
* `68e199f`: *asset-v1*
* `832f3bf`: *Initialize repository with comprehensive .gitignore*

### 10.3. Çalışma Dizininde İzlenmeyen ve Değişen Kritik Bileşenler
Git commit geçmişi v1 aşamasında kalmıştır; projenin v2 aşamasına geçişi (`bridge/`, `fusionEngine.js`, `ThresholdConfig.js`, `admin.html`, `asset_node_ble/`, `asset_hub_ble/`) yerel çalışma dizininde gerçekleştirilmiştir ve commitlenmeyi beklemektedir.

---

## 11. SONRAKİ ADIMLAR VE ÖNCELİK SIRASI

### Öncelik 1: Pilli Düğümlere Kablosuz Eşik Senkronizasyonu Sağlanması
* **Sorun:** Pille çalışan düğümler backend'deki duman eşik değişimini alamamaktadır.
* **Çözüm:** Hub periyodik olarak backend eşiğini BLE Advertising verisiyle yayınlamalı (veya ESP-NOW / BLE GATT bağlantısı kurulmalı), düğümler de uyanıp bu eşiği NVS kalıcı hafızasına kaydetmelidir.

### Öncelik 2: Gerçek Batarya Voltaj Ölçümü
* `asset_node_ble.ino` içindeki `readBatteryPct()` fonksiyonu, Deneyap Kart'ın `A1` analog pinine bağlı 10k:10k voltaj bölücü devresinden gerçek Li-Ion voltaj eğrisini (3.0V = %0, 4.2V = %100) okuyacak şekilde güncellenmelidir.

### Öncelik 3: Saha Testi ve Sensör Kalibrasyonu
* MQ-2 sensörünün açık havada baz duman/temiz hava ADC değeri atölyede tespit edilmeli; `ThresholdConfig.smokeThreshold` değeri güneş ışığı ve rüzgar koşullarına göre ayarlanmalıdır.

### Öncelik 4: Gerçek Bildirim Kanallarının Eklenmesi
* E-posta bildirimi için `nodemailer`, SMS veya acil arama bildirimleri için kurumsal bir SMS sağlayıcı entegrasyonu `notificationService.js` dosyasına eklenmelidir.

### Öncelik 5: Kod Tabanı Temizliği
* Artık kullanılmayan eski v1 Wi-Fi dosyaları (`iot/asset_firmware/`) ve Flutter mobil uygulaması (`mobileApp/`) repoda ayrı bir `legacy/` veya `archive/` klasörüne taşınarak kafa karışıklığı önlenmelidir.

---

## 12. YENİ BİRİ İÇİN HIZLI BAŞLANGIÇ (10 DAKİKADA NEREDEN BAŞLANIR?)

Projeyi ilk defa açıyorsan veya uzun süre sonra geri döndüysen aşağıdaki adımları sırayla uygula:

1. **Repo Yapısını Anla (1. Dakika):**
   * Flutter mobil uygulamasına ve `asset_firmware.ino`'ya bakma; onlar eski ev tipi prototiptir.
   * Güncel mimari: `iot/asset_node_ble` (Sensör) $\rightarrow$ `iot/asset_hub_ble` (Toplayıcı) $\rightarrow$ `backend/bridge/bridge.js` $\rightarrow$ `backend/` (Express) $\rightarrow$ `admin.html` (Harita).

2. **Backend'i Ayağa Kaldır (3. Dakika):**
   ```bash
   cd backend
   npm install
   npm run dev
   ```
   Konsolda `MongoDB bağlandı` ve `ASSET Backend API çalışıyor: http://localhost:5000` yazısını gör.

3. **Taktik Komuta Panelini Aç (4. Dakika):**
   * Tarayıcından `http://localhost:5000/admin` adresine git.
   * Karşına Leaflet haritası, 5 adet düğüm ve Drone Hangar Alpha gelecek.

4. **Simülasyon ile Sistemi Canlı İzle (6. Dakika):**
   * Donanım takılı değilse haritanın altındaki mavi **"🔥 Konsensüs Yangın (Drone Uçar)"** butonuna bas.
   * Node 1 ve Node 2'nin duman değerlerinin 1500+ üzerine çıktığını, kartların kırmızıya döndüğünü, kırmızı yangın banner'ının açıldığını ve hangardan kalkan simüle drone'un bölgeye uçtuğunu gör.
   * **"Normale Döndür"** butonuna basarak sistemi temizle.

5. **Gerçek Donanımı Bağla (10. Dakika):**
   * Deneyap Hub kartını USB'ye tak.
   * Ayrı bir terminalde `node bridge/bridge.js` çalıştır. Port otomatik bulunacak ve BLE'den gelen gerçek duman/sıcaklık paketleri haritaya anlık akacaktır.

---

## 📌 DOKÜMANDAKİ "BELİRSİZ" İŞARETLENEN NOKTALARIN ÖZETİ

1. **Pilli Düğümlerde Eşik Senkronizasyonu Mekanizması:** Düğümler pildeyken backend'deki eşik güncellemelerini kablosuz alacak bir kanal (GATT veya ESP-NOW) kodda mevcut değildir; sahada eşik güncellemesinin nasıl yapılacağı belirsizdir.
2. **`forestRegion` Modeli:** Proje isterlerinde adı geçen `forestRegion` veri yapısı kod tabanında bulunmamaktadır; yerine `zoneId` kullanılmaktadır.
3. **OGM / Alo 177 Entegrasyonu:** Kod tabanında Orman Genel Müdürlüğü veya Alo 177 ile ilgili herhangi bir API, SMS veya webhook kodu bulunmamaktadır (yalnızca kavramsal hedeftir).
4. **Gerçek Batarya Voltaj Eğrisi:** `asset_node_ble.ino` içindeki `readBatteryPct()` fonksiyonu donanımsal ölçüm yapmamakta, sabit %95 dönmektedir. Gerçek donanım voltaj bölücü kalibrasyonu belirsizdir.
