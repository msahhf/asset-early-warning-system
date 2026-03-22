# AR-GE VE SİSTEM MİMARİSİ RAPORU (GÜNCELLENMİŞ PROTOTİP SÜRÜMÜ)

**Proje Adı:** ASSET (Gelişmiş Akıllı Algılama ve Söndürme Teknolojisi)
**Proje Yürütücüsü:** Muhammedşah Fidan
**Geliştirme Ortamı:** Deneyap Teknoloji Atölyeleri

---

## 1. Proje Özeti ve Vizyon

ASSET, geleneksel duman dedektörlerinin yalnızca lokal uyarı (siren) verebilme zafiyetini ortadan kaldırarak; algılama, bildirim, izleme ve müdahale süreçlerini uçtan uca dijitalleştiren loT tabanlı bir güvenlik ekosistemidir. Sistem, karmaşık endüstriyel donanımlardan ziyade, prototip sunumlarına tam uyumlu, maliyet-etkin ve yazılım gücünü öne çıkaran bir mimari üzerine kurgulanmıştır.

## 2. Donanım ve Kesintisiz Güç (UPS) Mimarisi

* **Merkezi Kontrolcü:** Sistemin kalbinde, güçlü Wi-Fi ve BLE (Bluetooth Low Energy) altyapısına sahip Deneyap Kart 1A v2 Type-C mikrodenetleyicisi bulunmaktadır.
* **UPS ve Load Sharing Mimarisi:** Elektrik kesintilerinde sistemin ayakta kalması için TP4056 Type-C 1S 3.7V şarj modülü ve Samsung 18650 2600mAh lityum-iyon pil kullanılmıştır. Pil, BH-18650 tekli pil yuvasına entegre edilmiştir. 1N5819 diyotlar ile kurulan yük paylaşım (Load Sharing) devresi sayesinde güç kesintilerinde kart resetlenmeden anında pilden beslenmeye geçer.
* **Telemetri ve Güvenlik:** 10K ve 20K dirençler kullanılarak oluşturulan voltaj bölücü devre ile pilin anlık voltajı ADC üzerinden okunarak arayüze aktarılır. Sistemin ana enerjisi IC125B S mini anahtar ile kontrol edilir ve batarya çıkışında 5x20mm kart tipi sigorta ile kısa devre koruması sağlanır. Modülerlik için tüm bileşenler 5x7 cm çift yüzlü pertinaks üzerine yerleştirilir.

## 3. Algılama ve Veri İşleme (Sensör Filtreleme)

* **Çift Doğrulama:** Sisteme DHT22 sıcaklık/nem sensörü ve MQ-2 yanıcı gaz ve sigara dumanı sensör kartı entegre edilmiştir.
* **Algoritma:** Temel yazılım mantığı, "Duman seviyesi yüksek VE sıcaklık aniden artıyorsa = Gerçek Yangın" denklemi üzerine kuruludur.
* **Hareketli Ortalama (Moving Average):** Prototip testlerinde oluşabilecek anlık çevresel müdahaleleri (sensöre üfleme vb.) ve yanlış pozitifleri önlemek adına, sensör verileri yazılımsal bir hareketli ortalama filtresinden geçirilerek işlenir.

## 4. Yazılım Ekosistemi ve Veritabanı Mimarisi

* **Full-Stack Altyapı:** Son kullanıcılar için cihaz kurulumu ve anlık takip sağlayan mobil uygulama Flutter ile, sistem yöneticileri için dashboard ise React.js ile geliştirilmiştir. "Push Notification" bildirimleri Firebase Cloud Messaging (FCM) altyapısıyla sağlanır.
* **Backend ve Depolama:** Veri trafiği merkezi Node.js sunucusu tarafından yönetilir. Cihaz logları, alarm geçmişi ve yetkilendirmeler MongoDB üzerinde tutulurken, cihazların anlık yaşam durumları yüksek hızlı veri okuma/yazma için Redis üzerinde işlenir.
* **Güvenli Eşleştirme (Provisioning):** Cihaz ilk açıldığında BLE üzerinden yayın yapar. Wi-Fi şifresi asla buluta gönderilmez, cihazın şifreli hafızasında (NVS) tutulur.

## 5. Hata Toleransı ve Heartbeat (Yaşam Sinyali) Mimarisi

* **Redis Tabanlı Ping:** Cihaz her 60 saniyede bir sunucuya ping atar. Bu istekler doğrudan Redis üzerindeki ilgili cihazın TTL (Time To Live) süresini yeniler, böylece veritabanında darboğaz oluşması engellenir.
* **UptimeRobot Entegrasyonu:** Sunucu 3 dakika ping alamazsa "Bağlantı Koptu / Elektrik Kesintisi" uyarısı verir. Bu durum, Node.js üzerindeki özel bir sağlık denetimi endpoint'inin UptimeRobot tarafından periyodik olarak dinlenmesiyle kusursuz şekilde tetiklenir.

## 6. Fiziksel Müdahale ve Prototip Simülasyonu

Gerçek sulu veya gazlı söndürme sistemlerini ve akıllı şalterleri güvenli bir şekilde simüle etmek için sistem rölelerine mini DC su pompaları, fanlar ve ana akımı temsil eden LED şeritler bağlanır. Manuel sistem testleri, alarm susturma ve donanımsal resetleme işlemleri için pertinaks üzerinde konumlandırılan 4 pinli tact switch butonlar kullanılır.