// ASSET 2.1 — v2 Hub Kutusu (Parametrik TASLAK — ÜRETIM İÇİN DEĞİL)
//
// ⚠ TASLAK — ÖLÇÜ DOĞRULANMADI ⚠
// Hub (iot/asset_hub_ble) kutu içinde yalnız Deneyap Kart 1A v2 (ESP32-S3,
// USB Type-C) içerir; sensör/ek donanım yoktur (asset_hub_ble.ino 109 satır,
// yalnız BLE Central + USB seri). Deposu hiçbir hub kutu/delik ölçüsü
// içermiyor (bkz. ek-C raporu; 3d_files/asset-aydem-v1'de hub çizimi de yok).
//
// Bu dosyanın rolü: şekil/yapı çatısı (kutu, kapak, USB-C pasajı, M3 montaj)
// sağlamak ve parametrelerin DOĞRULAMA LİSTESİNE açıkça bağlamaktır. Ölçüler
// TASLAK işaretler; gerçek kart ve bağlantı ölçüleri ile güncellenmeden STL
// dışa aktarım ve üretim yapılmamalıdır (repo'da hub için STL ÜRETİLMEDİ).
//
// DOĞRULAMA LİSTESİ (ölçülüp doldurılacak):
//   [ ] kart gerçek uzunluk/genişlik  (v1'den devralınan yaklaşımlık)
//   [ ] kart pin header üstü yüksekliği
//   [ ] USB-C soketin karta göre hizası (x-y-z offset)
//   [ ] BLE anten temiz görüşü (plastik kutu içinde sinyal zarfi — etek testi)
//   [ ] harici güç (powerbank/adaptör) tutucusu gereksinimi
// ────────────────────────────────────────────────────────────────────────────

// part = "both" | "base" | "lid"
part = "both";

board_isim = "Deneyap Kart 1A v2 (ESP32-S3, Type-C)";

// ── T A S L A K  O L Ç Ü L E R (mm) — hepsi doğrulama listesine tabidir ──
board_l = 63.5;     // TASLAK (v1'den yaklaşım) — ölçün
board_w = 25.4;     // TASLAK — ölçün
board_h = 15.7;     // TASLAK: pin üstü dahil yüksekliği — ölçün

wall   = 2.5;
floor_t = 2.5;
lid_t  = 2.5;
tol    = 0.5;

// İç kutu: TASLAK — kart + USB kablosu gevşek döngüsü için yeterli döngü istek.
in_l  = 90;         // TASLAK
in_w  = 45;         // TASLAK
in_h  = 30;         // TASLAK (kart durakı + üstte kablo payı)

board_x = 10;  board_y = 10;  board_stand = 6;   // TASLAK (kısa direktler)

// DELİKLER
usb_c_l  = 14;      // TASLAK (v1'den): USB-C soket açıklığı genişlik
usb_c_h  = 8;       // TASLAK: soket açıklığı yükseklik
screw_d  = 2.6;     // M3 kılavuz
screw_cl = 3.5;     // kapakta geçiş
vent_w   = 4;       // TASLAK: havalandırma yataycıkların genişlik
vent_n   = 3;       // TASLAK: aded

$fn = 40;

module boss_positions() {
    for (x = [4, in_l - 4]) for (y = [4, in_w - 4]) translate([x, y, 0]) children();
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
            boss_positions() cylinder(d = 7, h = in_h);

            // kart durakları (TASLAK konum: merkez banda)
            for (dx = [0, board_l - 4]) for (dy = [0, board_w - 4])
                translate([board_x + dx, board_y + dy, 0]) cube([4, 4, board_stand]);
        }
        // vida delikleri
        boss_positions() translate([0, 0, in_h - 12]) cylinder(d = screw_d, h = 13);

        // USB-C pasajı: arka-duvar yerine LEFT kenar (kart soket hizasını ölçün)
        translate([-wall - 1, board_y + board_w/2 - usb_c_l/2, board_stand - 1])
            cube([wall + 2, usb_c_l, usb_c_h]);

        // havalandırma yan-arka duvar (TASLAK)
        for (i = [0 : vent_n - 1])
            translate([in_l - i * (vent_w + 6) - vent_w, in_w - 1, 10])
                cube([vent_w, wall + 2, in_h - 12]);
    }
}

module lid() {
    difference() {
        translate([-wall, -wall, 0]) cube([in_l + 2*wall, in_w + 2*wall, lid_t]);
        boss_positions() translate([0, 0, -1]) cylinder(d = screw_cl, h = lid_t + 2);
        // lid havalandırma yataycıkları (TASLAK)
        for (i = [0 : vent_n - 1])
            translate([10 + i * (vent_w + 6), 8, -1]) cube([vent_w, in_w - 16, lid_t + 2]);
    }
}

if (part == "base") base();
if (part == "lid")  translate([0, 60, 0]) lid();
if (part == "both") {
    base();
    translate([0, in_w + 20, 0]) lid();
}
