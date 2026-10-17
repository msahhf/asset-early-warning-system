# ASSET 2.0 Sensör Düğümü — Kurulum ve Çalıştırma Rehberi

Bu rehber, ASSET 2.0 donanımının kablolanmasından backend/bridge servislerinin çalıştırılmasına ve her node'a özel yapılması gereken kod değişikliklerine kadar tüm süreci tek dosyada toplar.

---

## 1. Donanım — Bileşen Listesi

| # | Bileşen | Model / Özellik | Görev |
|---|---|---|---|
| 1 | Mikrodenetleyici | Deneyap Kart 1A (ESP32) | BLE yayını, sensör okuma, alarm kontrolü |
| 2 | Gaz/Duman Sensörü | MQ-2 | Duman/yanıcı gaz tespiti (analog) |
| 3 | Sıcaklık/Nem Sensörü | DHT11 (4 pinli) | ΔT ve ΔH tespiti |
| 4 | P-Kanal Güç MOSFET | IRF5210 (TO-220) | Buzzer/LED anahtarlama (high-side switch) |
| 5 | Görsel Uyarıcı | 5mm Kırmızı LED + 220-330Ω direnç | Lokal görsel alarm |
| 6 | Sesli Uyarıcı | 5V/3.3V Aktif Buzzer | Lokal sesli alarm |
| 7 | Dirençler | 10kΩ ×2, 220-330Ω ×1 | DHT11 pull-up, MOSFET gate pull-up, LED akım sınırlama |

## 2. Pin Bağlantı Tablosu

| Bileşen | Bacak | Deneyap Kart Pini | Not |
|---|---|---|---|
| MQ-2 | VCC | 5V | Isıtıcı için 5V şart |
| MQ-2 | GND | GND | |
| MQ-2 | A0 (Analog Out) | A0 | 0-4095 ADC |
| MQ-2 | D0 (Digital Out) | *Boşta* | Kullanılmaz, eşik yazılımsal |
| DHT11 | Pin 1 (VCC) | 3.3V | |
| DHT11 | Pin 2 (DATA) | D4 | VCC'ye 10kΩ pull-up ile |
| DHT11 | Pin 3 (NC) | *Boşta* | |
| DHT11 | Pin 4 (GND) | GND | |
| IRF5210 | Pin 1 (Gate) | D1 | 3.3V'a (Source) 10kΩ pull-up ile |
| IRF5210 | Pin 3 (Source) | 3.3V | |
| IRF5210 | Pin 2 (Drain) | Yüklere çıkış | |
| Kırmızı LED | Anot (+) | IRF5210 Drain | 220-330Ω seri direnç üzerinden |
| Kırmızı LED | Katot (-) | GND | |
| Aktif Buzzer | VCC (+) | IRF5210 Drain | |
| Aktif Buzzer | GND (-) | GND | |

**Alarm mantığı (Active-LOW, P-Kanal MOSFET):** `D1` pini normalde `HIGH` (alarm sessiz). Alarm tetiklendiğinde `D1` `LOW` yapılır → MOSFET iletime geçer → LED yanar, buzzer öter.

```cpp
#define ALARM_PIN D1
void setup() {
  pinMode(ALARM_PIN, OUTPUT);
  digitalWrite(ALARM_PIN, HIGH); // başlangıçta sessiz
}
void triggerAlarm(bool active) {
  digitalWrite(ALARM_PIN, active ? LOW : HIGH);
}
```

⚠️ **Hatırlatma (önceki incelemeden):** Bu `D1` alarm mantığının eşiği (kaç ADC değerinde tetikleneceği) backend'deki `ThresholdConfig.smokeThreshold` ile senkron olmalı — ikisi ayrı ayrı hardcode edilmemeli. Bu henüz doğrulanmadıysa, çalıştırmadan önce Antigravity'ye bunu teyit ettir.

## 3. Backend ve Bridge Servislerini Başlatma

### 3.1 Backend Sunucusu (1. Terminal)
```bash
cd backend      # (repo kökünden)
npm run dev
```
Beklenen çıktı:
```
✅ MongoDB bağlandı: localhost
✅ Redis bağlandı.
🚀 ASSET Backend API çalışıyor: http://localhost:5000
```
Tarayıcıdan `http://localhost:5000` adresine gidip dashboard'u aç.

### 3.2 Firmware Yükleme (Arduino IDE)
> Kod yüklemeden önce, eğer bridge servisi zaten çalışıyorsa terminalde **Ctrl+C** ile durdur — port çakışması olmasın.

1. Arduino IDE'yi aç.
2. **Kart:** `Araçlar → Kart → Deneyap Kart → Deneyap Kart 1A v2`
3. **Port:** `Araçlar → Port → /dev/ttyUSB0` (veya sistemindeki port adı)
4. `asset_node_ble.ino` dosyasını aç, **Yükle**'ye bas.
5. Yükleme bitince Arduino IDE'nin Seri Port ekranını **kapat** (portu bridge'e bırak).

### 3.3 PC Köprü Servisi (2. Terminal)
```bash
cd backend      # (repo kökünden)
node bridge/bridge.js --port=/dev/ttyUSB0 --baud=115200
```
Kart veri gönderdikçe konsolda göreceksin:
```
📥 [Seri Port]: {"deviceId":1,"tempC":24.2,"humidityPct":48,"smokeRaw":310,"seqNo":1,"batteryPct":95}
✅ [İletildi] Node #1: Duman=310, Isı=24.2°C, Seq=1
```
Dashboard'da ilgili node aynı anda canlı güncellenmeli.

**Donanım yokken test:** `node bridge/bridge.js --mock` veya `node scripts/simulate_scenarios.js --scenario=consensus_fire`.

## 4. Her Node'u Kodlarken Değiştirmen Gereken Noktalar (Checklist)

Kablolamayı 5 node'da da bu rehberdeki tabloya birebir aynı şekilde yaptıysan (hepsi A0/D4/D1 kullanıyorsa), firmware'de **tek bir satır** değişir:

- [ ] `DEVICE_ID` sabiti — her karta yüklerken 1'den 5'e kadar sırayla değiştir (`#define DEVICE_ID 1`, `2`, `3`...)

Aşağıdakiler **değişmemeli** (hepsinde aynı kalmalı):
- [ ] Pin tanımları (A0, D4, D1) — kablolama standardize edildiyse aynı
- [ ] BLE advertising mantığı, CRC8 hesaplama fonksiyonu
- [ ] Alarm eşiği (bkz. Bölüm 2'deki senkronizasyon uyarısı — firmware'e sabit yazılmamalı, backend'den okunmalı)

`zoneId` ataması firmware'de **değil**, backend'de (`Device.js`/veritabanı) yapılır — her node'u fiziksel olarak yerleştirdiğinde hangi zon'a ait olduğunu dashboard/backend üzerinden gir, koda dokunma.

## 5. Test Senaryoları

1. **Kararlı durum:** Enerji verildikten sonra 20-30 saniye bekle (MQ-2 ısınma süresi), duman değeri 200-400 aralığında stabil kalmalı, buzzer/LED sessiz.
2. **Tekli node testi (WARNING beklenir, FIRE değil):** Tek bir node'a kontrollü şekilde duman/gaz ver, backend'de o node `warning` durumuna geçmeli ama zon genelinde `FIRE` tetiklenmemeli (konsensüs yok).
3. **Konsensüs testi (FIRE beklenir):** Aynı zon'daki 2 node'u aynı anda tetikle, `alert:fire` yayılmalı, dashboard kırmızıya dönmeli, simüle drone animasyonu başlamalı, 180sn cooldown devreye girmeli.
4. **Normale dönüş:** Gazı uzaklaştır, değerler eşiğin altına düşünce buzzer/LED/alarm durumu otomatik sıfırlanmalı.

## 6. Sorun Giderme

| Sorun | Olası Sebep | Çözüm |
|---|---|---|
| `nodemon: Erişim engellendi` | `node_modules/.bin/` çalıştırma izni eksik | `chmod +x node_modules/.bin/*` |
| Bridge port açamıyor | Arduino IDE seri port ekranı açık kalmış | IDE'nin seri port penceresini kapat |
| CRC uyuşmazlığı / paket reddi | Firmware ve bridge CRC8 implementasyonu farklı | İkisini aynı test vektörüyle karşılaştır (bkz. önceki doğrulama) |
| Tek node testinde FIRE tetikleniyor | Zon-konsensüs katmanı bypass ediliyor olabilir | `fusionEngine.js`'i kontrol et, Bölüm 2'deki uyarıya bak |