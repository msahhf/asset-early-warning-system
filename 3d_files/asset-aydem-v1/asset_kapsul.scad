// ASSET 2.0 sensör hücresi kapsülü - ÖRNEK (v1)
// Tüm ölçüler mm. Önce parametreleri kontrol et.
// part = "both" | "base" | "lid"
part = "both";

// ── ÖLÇÜLER (internetten alınan değerler) ──
board_l = 63.5;     // Deneyap Kart 1A v2 uzunluk
board_w = 25.4;     // genişlik
board_h = 15.7;     // yükseklik (üstündeki parçalarla birlikte)
mq2_l   = 40;       // MQ-2 modülü (modeller 32-40 arası değişiyor, büyüğü alındı)
mq2_w   = 22;
mq2_h   = 27;
wago_l  = 18.7;     // WAGO 221-413 (3'lü)
wago_w  = 18.6;
wago_h  = 8.3;
wago_n  = 3;        // klemens adedi
batt_l  = 40;       // PİL YERİ - TAHMİN, gerçek pili ölç!
batt_w  = 28;

// ── KUTU ──
wall   = 2.5;
floor_t = 2.5;
lid_t  = 2.5;
in_l   = 125;       // iç uzunluk
in_w   = 75;        // iç genişlik
in_h   = 42;        // iç yükseklik
tol    = 0.5;       // yerleşim boşluğu

// ── DELİKLER ──
btn_d    = 12.2;    // panel buton deliği (12 mm buton varsayıldı)
gland_d  = 12.5;    // PG7 rakor deliği
screw_d  = 2.6;     // M3 vida için kılavuz delik (plastiğe vidalanır)
screw_cl = 3.5;     // kapakta M3 geçiş deliği

// ── YERLEŞİM ──
board_x = 10;  board_y = 10;  board_stand = 12;  // pinler için altta boşluk
mq2_x   = in_l - 10 - mq2_l;  mq2_y = 10;  mq2_stand = 4;
wago_x0 = 10;  wago_y = 42;   wago_pitch = wago_l + 4;  wago_rim = 4;
batt_x  = mq2_x;  batt_y = 40;

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

            // Deneyap Kart: 4 köşe direği + yan tutucular
            for (dx = [0, board_l - 4]) for (dy = [0, board_w - 4])
                translate([board_x + dx, board_y + dy, 0]) cube([4, 4, board_stand]);
            // kartı yana kaçmaktan tutan ince duvarcıklar
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

            // pil yeri çerçevesi
            translate([batt_x - 1.5, batt_y - 1.5, 0])
                difference() {
                    cube([batt_l + 2*tol + 3, batt_w + 2*tol + 3, 5]);
                    translate([1.5, 1.5, 0.8]) cube([batt_l + 2*tol, batt_w + 2*tol, 6]);
                }
        }
        // vida delikleri
        boss_positions() translate([0, 0, in_h - 14]) cylinder(d = screw_d, h = 15);

        // USB-C açıklığı (sol duvar, kartın ucu)
        translate([-wall - 1, board_y + board_w/2 - 7, board_stand + 0.5])
            cube([wall + 2, 14, 8]);

        // kablo rakoru delikleri (arka duvar)
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
        // test ve susturma butonları
        translate([board_x + 12, 58, -1]) cylinder(d = btn_d, h = lid_t + 2);
        translate([board_x + 38, 58, -1]) cylinder(d = btn_d, h = lid_t + 2);
    }
}

if (part == "base" || part == "both") base();
if (part == "lid")  translate([0, 0, 0]) lid();
if (part == "both") translate([0, in_w + 20, 0]) lid();
