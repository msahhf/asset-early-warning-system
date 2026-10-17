// ASSET 2.1 — v2 Sensör Düğüm Kapsülü (Parametrik TASLAK)
// Kaynak: 3d_files/asset-aydem-v1/asset_kapsul.scad temel alınarak güncellendi.
//
// ─────────────────────────────────────────────────────────────────────────────
// ÖLÇÜ KAYNAK / GÜVENİLİRLİK NOTLARI (bkz. docs/ASSET_2.0_PIN_SEMASI.md,
// docs/PROJE_DEVIR_TESLIM.md, iot/asset_node_ble/asset_node_ble.ino):
//
// DOĞRULANMIŞ (doküman+firmware tutarlı, yüksek güven):
//   - MCU: Deneyap Kart 1A v2 (ESP32-S3), USB Type-C soketli
//     (docs/PROJE_DEVIR_TESLIM.md §4.1)
//   - MQ-2 duman: A0, 10k:10k bölücü (×2 telafi)  (asset_node_ble.ino:150-153)
//   - DHT11: D4  |  IRF5210 (TO-220) gate: D1, aktif-düşük  (firmware:24-29)
//   - 5 mm kırmızı LED, aktif buzzer, 10k pull-up'lar  (ASSET_2.0_PIN_SEMASI.md BOM)
//
// TAHMİN / TASLAK (üretime almadan ÖNCE gerçek parçayı ölçün!):
//   - board 63.5×25.4×15.7  → v1'den devralınan yaklaşık ölçü (kartı ölçün)
//   - MQ-2 40×22×27         → "modeller 32-40 arası", satın alınan modülü ölçün
//   - 18650 pil 65.0×18.4   → standart 18650 NOMİNEL ölçü; sarma/hucre payı ±,
//                             klips/spring yerleşimi için gerçek ölçü gerekli
//   - btn 12.2, buzzer_d    → panel buton/buzzer modeline göre değiştirin
//   - DHT11 ızgara açıklığı → kılıf ölçüsü dokümanlarda yok (opsiyonel, kapalı)
//
// Bu dosyadaki TAHMİN işaretli parametreler değiştirilip doğrulanmadan üretime
// ALINMAMALIDIR. Havalandırma açıklıkları nedeniyle tasarım sızdırmaz değildir.
// ─────────────────────────────────────────────────────────────────────────────

// part = "both" | "base" | "lid"
part = "both";

// ── DOĞRULANMIŞ donanım kimliği (kalite kaynağı: docs + firmware) ──
board_name = "Deneyap Kart 1A v2 (ESP32-S3, Type-C)";
mcu_note   = "MQ-2 A0 (10k:10k), DHT11 D4, IRF5210 D1 aktif-dusuk";

// ── ÖLÇÜLER (mm) — v1'den devralınan orta-güven değerler ──
board_l = 63.5;     // TAHMİN: Deneyap Kart 1A v2 uzunluk — ölçün
board_w = 25.4;     // TAHMİN: genişlik — ölçün
board_h = 15.7;     // TAHMİN: pin üstü dahil yükseklik — ölçün
mq2_l   = 40;       // TAHMİN: MQ-2 modülü (32-40 arası; ölçün)
mq2_w   = 22;
mq2_h   = 27;
wago_l  = 18.7;     // WAGO 221-413 (3'lü) katalog ölçüsü
wago_w  = 18.6;
wago_h  = 8.3;
wago_n  = 3;        // klemens adedi

// ── PİL (v2 değişikliği): 18650 — TASLAK ──
// v1'de 40×28 "gerçek pili ölç" notuyla duruyordu; v2 planı 18650 Li-Ion
// (docs/PROJE_DEVIR_TESLIM.md: A1'e 10k:10k bölücü, 3.0V=%0 / 4.2V=%100).
// Standart 18650: Ø18.0 × 65.0 mm (nominal). Sarma payı +0.4 mm alınır.
batt_l = 65.0;      // TAHMİN (nominal): hücre uzunluğu
batt_w = 18.4;      // TAHMİN (nominal): hücre çapı + sarma payı

// ── KUTU ── (NOT: v1'in 125×75 iç kutusu 18650'ye YETMEMİYORDU: batarya
// +X duvarına 16 mm taşıyordu (bbox denetiminde yakalandı). v2'de iç kutu
// 140×80'e büyütüldü ve yerleşim batarya paralel düzenleyiciyle yeniden
// kuruldu: ön bant = Kart + MQ-2, arka bant = WAGO (sol) + 18650 (sağ).
wall   = 2.5;
floor_t = 2.5;
lid_t  = 2.5;
in_l   = 140;       // TASLAK: iç uzunluk (18650 yerleşimi için büyütüldü)
in_w   = 80;        // TASLAK: iç genişlik
in_h   = 42;        // TASLAK: iç yükseklik
tol    = 0.5;       // yerleşim boşluğu

// ── DELİKLER ──
btn_d    = 12.2;    // TAHMİN: panel buton delağı (butonu ölçün)
gland_d  = 12.5;    // PG7 rakor (standart nominal)
screw_d  = 2.6;     // M3 kılavuz delik (plastiğe vidalanır)
screw_cl = 3.5;     // kapakta M3 geçiş deliği
buzzer_d = 16.2;    // TAHMİN: buzzer deliği (kullanacağız modeli ölçün)
buzzer_hole = false; // v2: varsayılan KAPALI (ölçü doğrulanmadı)
dht_hole    = true;  // v2: lid üzerinde DHT11 ızgara açıklığı — TAHMİN ölçü
dht_hole_l  = 13;   // TAHMİN: DHT11 kılıf ızgara uzunluğu (ölçün)
dht_hole_w  = 7;    // TAHMİN: ızgara genişliği (ölçün)

// ── YERLEŞİM (v2: ön bant = Kart+MQ-2, arka bant = WAGO+18650) ──
board_x = 8;   board_y = 8;   board_stand = 12;  // pinler için altta boşluk
mq2_x   = 95;  mq2_y   = 8;   mq2_stand = 4;     // MQ-2 ön duvara (hav. ön duvar)
wago_x0 = 8;   wago_y  = 45;  wago_pitch = wago_l + 2;  wago_rim = 4;
batt_x  = 70;  batt_y  = 50;   // 18650 uzun ekseni X yönünde, arka bandın sağı

$fn = 40;

module boss_positions() {
    for (x = [4.5, in_l - 4.5]) for (y = [4.5, in_w - 4.5]) translate([x, y, 0]) children();
}

module base() {
    difference() {
        union() {
            difference() {
                translate([-wall, -wall, -floor_t])
                    cube([in_l + 2*wall, in_w + 2*wall, in_h + floor_t]);
                translate([0, 0, 0]) cube([in_l, in_w, in_h + 1]);
            }
            // vida kuleleri
            boss_positions() cylinder(d = 8, h = in_h);

            // Deneyap Kart 1A v2: 4 köşe direği + yan tutucular
            for (dx = [0, board_l - 4]) for (dy = [0, board_w - 4])
                translate([board_x + dx, board_y + dy, 0]) cube([4, 4, board_stand]);
            translate([board_x - 1.2, board_y - 1.2, 0]) cube([1.2, board_w + 2.4, board_stand + 3]);
            translate([board_x + board_l, board_y - 1.2, 0]) cube([1.2, board_w + 2.4, board_stand + 3]);

            // MQ-2 direkleri
            for (dx = [0, mq2_l - 4]) for (dy = [0, mq2_w - 4])
                translate([mq2_x + dx, mq2_y + dy, 0]) cube([4, 4, mq2_stand]);

            // WAGO yuvaları (kenar duvarlı çerçeve)
            for (i = [0 : wago_n - 1])
                translate([wago_x0 + i * wago_pitch, wago_y, 0])
                    difference() {
                        translate([-1.5, -1.5, 0]) cube([wago_l + 2*tol + 3, wago_w + 2*tol + 3, wago_rim]);
                        translate([0, 0, 0.8]) cube([wago_l + 2*tol, wago_w + 2*tol, wago_rim]);
                    }

            // 18650 pil yuvası (v2: uç tutucu duvarlar — hücre kaymasın)
            translate([batt_x - 1.5, batt_y - 1.5, 0])
                difference() {
                    cube([batt_l + 2*tol + 3, batt_w + 2*tol + 3, 6]);
                    translate([1.5, 1.5, 0.8]) cube([batt_l + 2*tol, batt_w + 2*tol, 6]);
                }
        }
        // vida delikleri
        boss_positions() translate([0, 0, in_h - 14]) cylinder(d = screw_d, h = 15);

        // USB-C açıklığı (sol duvar, Type-C soketin ucu) — soket hizasını ölçün
        translate([-wall - 1, board_y + board_w/2 - 7, board_stand + 0.5])
            cube([wall + 2, 14, 8]);

        // kablo rakoru delikleri (arka duvar) — PG7 ×2 (arka boş koridor: y>68 serbest)
        for (x = [20, 50])
            translate([x, in_w - 1, 14]) rotate([-90, 0, 0]) cylinder(d = gland_d, h = wall + 3);

        // MQ-2 yan havalandırma (ön duvar)
        for (i = [0 : 4])
            translate([mq2_x + 4 + i * 7, -wall - 1, 12]) cube([3, wall + 2, 18]);
    }
}

module lid() {
    difference() {
        translate([-wall, -wall, 0]) cube([in_l + 2*wall, in_w + 2*wall, lid_t]);
        // vida delikleri
        boss_positions() translate([0, 0, -1]) cylinder(d = screw_cl, h = lid_t + 2);
        // MQ-2 üstü havalandırma
        for (i = [0 : 5])
            translate([mq2_x + 3 + i * 6.2, mq2_y + 2, -1]) cube([3, mq2_w - 4, lid_t + 2]);
        // test ve susturma butonları (TASLAK konum: arka serbest bantta)
        translate([20, 71, -1]) cylinder(d = btn_d, h = lid_t + 2);
        translate([48, 71, -1]) cylinder(d = btn_d, h = lid_t + 2);
        // DHT11 ızgara açıklığı (v2, TAHMİN ölçü) — Kart/MQ-2 arasındaki boş bölge
        if (dht_hole)
            translate([76, 38, -1]) cube([dht_hole_l, dht_hole_w, lid_t + 2]);
        // buzzer deliği (v2, KAPALI başlar — ölçü doğrulanınca açın)
        if (buzzer_hole)
            translate([84, 15, -1]) cylinder(d = buzzer_d, h = lid_t + 2);
    }
}

if (part == "base") base();
if (part == "lid")  translate([0, 80, 0]) lid();
if (part == "both") {
    base();
    translate([0, in_w + 20, 0]) lid();
}
