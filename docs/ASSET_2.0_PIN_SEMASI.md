# 🔌 ASSET 2.0 Sensör Düğümü — Pin ve Donanım Bağlantı Şeması

Bu doküman, **ASSET 2.0 (Sensör Düğümü)** prototipinin devre bağlantılarını, pin eşleşmelerini ve donanım sürme mantığını açıklar.

---

## 1. Kullanılan Bileşenler Listesi

| # | Bileşen | Model / Özellik | Görev |
|---|---|---|---|
| **1** | **Mikrodenetleyici** | Deneyap Kart 1A (ESP32 mimarisi) | BLE yayını, sensör okuma ve alarm kontrolü |
| **2** | **Gaz/Duman Sensörü** | MQ-2 Sensör Modülü | Duman ve yanıcı gaz tespiti (Analog okuma) |
| **3** | **Sıcaklık ve Nem Sensörü** | DHT11 (4 Pinli Kılıf) | Ortam sıcaklık artışı (&Delta;T) ve nem düşüşü (&Delta;H) |
| **4** | **P-Kanal Güç MOSFET** | IRF5210 (TO-220, 3 Pinli) | Buzzer ve LED yükünü anahtarlama (High-Side Switch) |
| **5** | **Görsel Uyarıcı** | 5mm Kırmızı LED (+ 220&Omega; - 330&Omega; Direnç) | Lokal görsel yangın/tehlike uyarısı |
| **6** | **Sesli Uyarıcı** | 5V / 3.3V Aktif Buzzer | Lokal yüksek desibel sesli siren |
| **7** | **Dirençler** | 10k&Omega; (2 adet), 220&Omega; - 330&Omega; (1 adet) | DHT11 Pull-up, MOSFET Gate Pull-up, LED Akım sınırlama |

---

## 2. Bacak Yapıları (Pinout Kılavuzu)

### A. IRF5210 (TO-220 Kılıf - Önden, Yazılı Yüzeyden Bakış)
```
     +---------------+
     |   [ O ] TAB   |  <-- Soğutucu Metal Tab (Drain'e bağlıdır)
     +---------------+
     |  IRF5210      |
     |  P-CHANNEL    |
     +---------------+
       |     |     |
       1     2     3
     Gate  Drain Source
```
* **Pin 1 (Gate - G):** Kontrol pini (Deneyap Kart `D1` pinine bağlanır, 10k&Omega; ile Source hattına çekilir).
* **Pin 2 (Drain - D):** Çıkış pini (Yüklerin pozitif besleme girişine gider: LED Anot & Buzzer +).
* **Pin 3 (Source - S):** Pozitif güç girişi (Doğrudan `3.3V` besleme hattına bağlanır).

### B. DHT11 (4 Pinli Kılıf - Izgaralı Ön Yüzden Bakış, Soldan Sağa)
```
     +---------------+
     |  |||||||||||  |
     |  DHT11 SENSÖR |
     +---------------+
       |   |   |   |
       1   2   3   4
      VCC DATA NC GND
```
* **Pin 1 (VCC):** 3.3V Besleme
* **Pin 2 (DATA):** Deneyap Kart `D4` pini (10k&Omega; pull-up direnci ile VCC'ye bağlanmalıdır)
* **Pin 3 (NC):** Boşta (Bağlantı Yok)
* **Pin 4 (GND):** Ortak Toprak (GND)

---

## 3. Tam Pin Bağlantı Tablosu

| Bileşen | Bileşen Bacağı | Deneyap Kart 1A Pini | Açıklama / Araya Eklenen Parça |
|---|---|---|---|
| **MQ-2** | **VCC** | **5V** | Sensörün dahili ısıtıcısı için 5V besleme şarttır. |
| **MQ-2** | **GND** | **GND** | Ortak toprak hattı. |
| **MQ-2** | **A0 (Analog Out)** | **A0** | 0 - 4095 ADC okuma pini. |
| **MQ-2** | **D0 (Digital Out)** | *BOŞTA* | Kullanılmaz (Threshold yazılımsaldır). |
| **DHT11** | **Pin 1 (VCC)** | **3.3V** | Pozitif besleme. |
| **DHT11** | **Pin 2 (DATA)** | **D4** | Veri iletim pini (VCC arasına 10k&Omega; pull-up direnç). |
| **DHT11** | **Pin 3 (NC)** | *BOŞTA* | Boş pin. |
| **DHT11** | **Pin 4 (GND)** | **GND** | Ortak toprak hattı. |
| **IRF5210** | **Pin 1 (Gate)** | **D1** | Kontrol pini (3.3V Source arasına 10k&Omega; pull-up direnç). |
| **IRF5210** | **Pin 3 (Source)** | **3.3V** | Pozitif besleme girişi. |
| **IRF5210** | **Pin 2 (Drain)** | **Yüklere Çıkış** | Anahtarlanan pozitif güç hattı. |
| **Kırmızı LED** | **Anot (+)** | **IRF5210 Drain** | 220&Omega; - 330&Omega; akım sınırlayıcı seri direnç üzerinden. |
| **Kırmızı LED** | **Katot (-)** | **GND** | Ortak toprak hattı. |
| **Aktif Buzzer**| **VCC (+)** | **IRF5210 Drain** | Doğrudan MOSFET Drain çıkışına bağlanır. |
| **Aktif Buzzer**| **GND (-)** | **GND** | Ortak toprak hattı. |

---

## 4. Blok ve Devre Şeması

```
                       DENEYAP KART 1A
                     +-----------------+
                     |                 |
  [MQ-2 VCC] <------ | 5V              |
                     |                 |
  [DHT11 Pin 1] <--- | 3.3V            | ---> [IRF5210 Source (Pin 3)]
                     |                 |        |
  [MQ-2 GND]   <---> | GND             |        +---[ 10kΩ Pull-up ]---+
  [DHT11 Pin 4]<---> |                 |                               |
  [Buzzer (-)] <---> |                 |                               v
  [LED Katot]  <---> |                 |                     [IRF5210 Gate (Pin 1)] <--- D1 (Alarm Pin)
                     |                 |
  [MQ-2 AO]   -----> | A0              |                     [IRF5210 Drain (Pin 2)] (Anahtarlanan Çıkış)
                     |                 |                               |
  [DHT11 Pin 2] <--> | D4              |                               +-------------------+
                     +-----------------+                               |                   |
                       ^          |                                    v                   v
                       |          |                               [ 220Ω Direnç ]    [ Aktif Buzzer (+) ]
                       +-[10kΩ]---+                                    |                   |
                        (Pull-up)                                      v                   v
                                                                 [ LED Anot (+) ]          |
                                                                       |                   |
                                                                 [ LED Katot (-) ]   [ Buzzer GND (-) ]
                                                                       |                   |
                                                                       v                   v
                                                                    ( GND )             ( GND )
```

---

## 5. P-Kanal MOSFET (IRF5210) Çalışma ve Sürme Mantığı

IRF5210, bir **P-Kanal Güç MOSFET'idir** ve **High-Side Switch (Pozitif Hat Anahtarlayıcı)** olarak görev yapar:

1. **Gate = HIGH (3.3V):**
   - $V_{GS} = V_{Gate} - V_{Source} = 3.3V - 3.3V = 0V$.
   - MOSFET kesimdedir (**OFF**).
   - Drain çıkışında voltaj yoktur; **LED ve Buzzer SÖNÜK ve SESSİZDİR**.
2. **Gate = LOW (0V - GND):**
   - $V_{GS} = 0V - 3.3V = -3.3V$.
   - MOSFET tam iletimdedir (**ON**).
   - Drain çıkışına 3.3V akar; **LED YANAR ve BUZZER ÇALAR**.

> [!IMPORTANT]
> **Ters Mantık (Active-LOW Tetikleme):**
> Firmware kodunuzda alarm durumu yokken `D1` pini **HIGH** tutulmalıdır. Yangın veya uyarı algılandığında `D1` pini **LOW** yapılarak alarm tetiklenir:
> ```cpp
> #define ALARM_PIN D1
> 
> void setup() {
>   pinMode(ALARM_PIN, OUTPUT);
>   digitalWrite(ALARM_PIN, HIGH); // Başlangıçta sessiz (MOSFET OFF)
> }
> 
> void triggerAlarm(bool active) {
>   if (active) {
>     digitalWrite(ALARM_PIN, LOW);  // Alarm Aktif (MOSFET ON -> LED & Buzzer ÇALIŞIR)
>   } else {
>     digitalWrite(ALARM_PIN, HIGH); // Alarm Pasif (MOSFET OFF)
>   }
> }
> ```

---

## 6. Güvenlik ve Montaj İpuçları

1. **MQ-2 Isınma Süresi:** MQ-2 sensörünün içindeki nikrom tel ısıtıcının doğru değer üretebilmesi için karta enerji verildikten sonra ilk 20-30 saniye stabilizasyon süresi beklenmelidir.
2. **Ortak Toprak (Common Ground):** Deneyap Kart, MQ-2, DHT11, Buzzer ve LED katotlarının tüm GND pinleri **aynı hatta (Breadboard mavi hattı)** birleştirilmelidir.
3. **Aktif Buzzer Kutupları:** Aktif buzzer'ların üstünde genellikle bir `+` işareti veya uzun bacak bulunur. Ters bağlanırsa ses çıkmaz.
4. **10k&Omega; Pull-up Dirençleri:**
   - DHT11 Pin 2 ile Pin 1 arasına 10k&Omega; konulması sinyal stabilitesi için gereklidir.
   - IRF5210 Pin 1 (Gate) ile Pin 3 (Source) arasına 10k&Omega; konulması, kart açılışında veya reset anında parazitik sinyallerle buzzer'ın ötmesini engeller.
