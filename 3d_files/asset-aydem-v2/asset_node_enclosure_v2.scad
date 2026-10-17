// ASSET 2.1 — v2 Sensor Node Enclosure (Parametric DRAFT)
// Source: Updated based on 3d_files/asset-aydem-v1/asset_node_enclosure_v1.scad.
//
// ─────────────────────────────────────────────────────────────────────────────
// DIMENSION SOURCES / CONFIDENCE NOTES (see docs/ASSET_2.0_PINOUT.md,
// docs/PROJECT_HANDOVER.md, iot/asset_node_ble/asset_node_ble.ino):
//
// VERIFIED (documentation and firmware agree; high confidence):
//   - MCU: Deneyap Kart 1A v2 (ESP32-S3), with USB Type-C connector
//     (docs/PROJECT_HANDOVER.md §4.1)
//   - MQ-2 smoke: A0, 10k:10k divider (×2 compensation)  (asset_node_ble.ino:150-153)
//   - DHT11: D4  |  IRF5210 (TO-220) gate: D1, active-low  (firmware:24-29)
//   - 5 mm red LED, active buzzer, 10k pull-ups  (ASSET_2.0_PINOUT.md BOM)
//
// ESTIMATE / DRAFT (measure the actual parts BEFORE manufacturing!):
//   - board 63.5×25.4×15.7  → approximate dimensions carried over from v1 (measure the board)
//   - MQ-2 40×22×27         → models range from 32–40; measure the purchased module
//   - 18650 battery 65.0×18.4 → standard 18650 NOMINAL dimensions; account for wrapping/cell tolerance;
//                               actual dimensions are required for clip/spring placement
//   - btn 12.2, buzzer_d    → adjust for the panel button/buzzer model
//   - DHT11 grille opening  → package dimensions are not documented (optional, disabled)
//
// Parameters marked ESTIMATE in this file MUST NOT be used for manufacturing
// until measured and verified. The design is not sealed due to its ventilation openings.
// ─────────────────────────────────────────────────────────────────────────────

// part = "both" | "base" | "lid"
part = "both";

// ── VERIFIED hardware identity (source of truth: docs + firmware) ──
board_name = "Deneyap Kart 1A v2 (ESP32-S3, Type-C)";
mcu_note   = "MQ-2 A0 (10k:10k), DHT11 D4, IRF5210 D1 active-low";

// ── DIMENSIONS (mm) — medium-confidence values carried over from v1 ──
board_l = 63.5;     // ESTIMATE: Deneyap Kart 1A v2 length — measure it
board_w = 25.4;     // ESTIMATE: width — measure it
board_h = 15.7;     // ESTIMATE: height including pins — measure it
mq2_l   = 40;       // ESTIMATE: MQ-2 module (models range from 32–40; measure it)
mq2_w   = 22;
mq2_h   = 27;
wago_l  = 18.7;     // WAGO 221-413 (3-position) catalog dimensions
wago_w  = 18.6;
wago_h  = 8.3;
wago_n  = 3;        // Number of terminals

// ── BATTERY (v2 change): 18650 — DRAFT ──
// In v1 this was 40×28 with a "measure the actual battery" note; v2 plans an 18650 Li-ion
// (docs/PROJECT_HANDOVER.md: 10k:10k divider to A1, 3.0 V = 0% / 4.2 V = 100%).
// Standard 18650: Ø18.0 × 65.0 mm (nominal). Add +0.4 mm for wrapping.
batt_l = 65.0;      // ESTIMATE (nominal): cell length
batt_w = 18.4;      // ESTIMATE (nominal): cell diameter + wrapping allowance

// ── ENCLOSURE ── (NOTE: v1's 125×75 inner enclosure was TOO SMALL for an 18650: the battery
// extended 16 mm through the +X wall (caught in the bounding-box check). In v2, the inner enclosure
// was enlarged to 140×80 and the layout was reorganized with the battery parallel to the board:
// front bay = board + MQ-2; rear bay = WAGO (left) + 18650 (right).
wall   = 2.5;
floor_t = 2.5;
lid_t  = 2.5;
in_l   = 140;       // DRAFT: inner length (enlarged to fit 18650)
in_w   = 80;        // DRAFT: inner width
in_h   = 42;        // DRAFT: inner height
tol    = 0.5;       // assembly clearance

// ── OPENINGS ──
btn_d    = 12.2;    // ESTIMATE: panel button hole (measure the button)
gland_d  = 12.5;    // PG7 rakor (standart nominal)
screw_d  = 2.6;     // M3 pilot hole (screws into plastic)
screw_cl = 3.5;     // M3 clearance hole in lid
buzzer_d = 16.2;    // ESTIMATE: buzzer opening (measure the model to be used)
buzzer_hole = false; // v2: disabled by default (dimension not verified)
dht_hole    = true;  // v2: DHT11 grille opening in lid — estimated dimensions
dht_hole_l  = 13;   // ESTIMATE: DHT11 package grille length (measure it)
dht_hole_w  = 7;    // ESTIMATE: grille width (measure it)

// ── LAYOUT (v2: front bay = board + MQ-2, rear bay = WAGO + 18650) ──
board_x = 8;   board_y = 8;   board_stand = 12;  // clearance underneath for pins
mq2_x   = 95;  mq2_y   = 8;   mq2_stand = 4;     // MQ-2 at front wall (front-wall ventilation)
wago_x0 = 8;   wago_y  = 45;  wago_pitch = wago_l + 2;  wago_rim = 4;
batt_x  = 70;  batt_y  = 50;   // 18650 long axis along X, right side of rear bay

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
            // Screw bosses
            boss_positions() cylinder(d = 8, h = in_h);

            // Deneyap Kart 1A v2: four corner posts + side retainers
            for (dx = [0, board_l - 4]) for (dy = [0, board_w - 4])
                translate([board_x + dx, board_y + dy, 0]) cube([4, 4, board_stand]);
            translate([board_x - 1.2, board_y - 1.2, 0]) cube([1.2, board_w + 2.4, board_stand + 3]);
            translate([board_x + board_l, board_y - 1.2, 0]) cube([1.2, board_w + 2.4, board_stand + 3]);

            // MQ-2 posts
            for (dx = [0, mq2_l - 4]) for (dy = [0, mq2_w - 4])
                translate([mq2_x + dx, mq2_y + dy, 0]) cube([4, 4, mq2_stand]);

            // WAGO slots (rimmed frame)
            for (i = [0 : wago_n - 1])
                translate([wago_x0 + i * wago_pitch, wago_y, 0])
                    difference() {
                        translate([-1.5, -1.5, 0]) cube([wago_l + 2*tol + 3, wago_w + 2*tol + 3, wago_rim]);
                        translate([0, 0, 0.8]) cube([wago_l + 2*tol, wago_w + 2*tol, wago_rim]);
                    }

            // 18650 battery holder (v2: end walls keep the cell from sliding)
            translate([batt_x - 1.5, batt_y - 1.5, 0])
                difference() {
                    cube([batt_l + 2*tol + 3, batt_w + 2*tol + 3, 6]);
                    translate([1.5, 1.5, 0.8]) cube([batt_l + 2*tol, batt_w + 2*tol, 6]);
                }
        }
        // Screw holes
        boss_positions() translate([0, 0, in_h - 14]) cylinder(d = screw_d, h = 15);

        // USB-C opening (left wall, connector end) — measure connector alignment
        translate([-wall - 1, board_y + board_w/2 - 7, board_stand + 0.5])
            cube([wall + 2, 14, 8]);

        // Cable-gland holes (rear wall) — 2× PG7 (rear clearance corridor: y>68 is clear)
        for (x = [20, 50])
            translate([x, in_w - 1, 14]) rotate([-90, 0, 0]) cylinder(d = gland_d, h = wall + 3);

        // MQ-2 side ventilation (front wall)
        for (i = [0 : 4])
            translate([mq2_x + 4 + i * 7, -wall - 1, 12]) cube([3, wall + 2, 18]);
    }
}

module lid() {
    difference() {
        translate([-wall, -wall, 0]) cube([in_l + 2*wall, in_w + 2*wall, lid_t]);
        // Screw holes
        boss_positions() translate([0, 0, -1]) cylinder(d = screw_cl, h = lid_t + 2);
        // Ventilation above MQ-2
        for (i = [0 : 5])
            translate([mq2_x + 3 + i * 6.2, mq2_y + 2, -1]) cube([3, mq2_w - 4, lid_t + 2]);
        // Test and mute buttons (DRAFT positions: in the free rear bay)
        translate([20, 71, -1]) cylinder(d = btn_d, h = lid_t + 2);
        translate([48, 71, -1]) cylinder(d = btn_d, h = lid_t + 2);
        // DHT11 grille opening (v2, ESTIMATED dimensions) — free area between board and MQ-2
        if (dht_hole)
            translate([76, 38, -1]) cube([dht_hole_l, dht_hole_w, lid_t + 2]);
        // Buzzer opening (v2, disabled by default — enable after verifying dimensions)
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
