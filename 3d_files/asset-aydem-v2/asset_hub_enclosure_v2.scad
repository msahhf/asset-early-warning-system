// ASSET 2.1 — v2 Hub Enclosure (Parametric DRAFT — NOT FOR MANUFACTURING)
//
// ⚠ DRAFT — DIMENSIONS NOT VERIFIED ⚠
// The Hub enclosure (iot/asset_hub_ble) contains only a Deneyap Kart 1A v2 (ESP32-S3,
// USB Type-C); there are no sensors or additional hardware (asset_hub_ble.ino is 109 lines,
// BLE Central + USB serial only). The repository contains no Hub enclosure/opening dimensions
// (see appendix C report; there is also no Hub drawing in 3d_files/asset-aydem-v1).
//
// This file provides a shape/structure framework (enclosure, lid, USB-C opening, M3 mounts)
// and explicitly links its parameters to a VERIFICATION CHECKLIST. Dimensions are marked
// DRAFT; do not export an STL or manufacture the part before updating them from measurements
// of the actual board and connectors (NO Hub STL has been generated in this repository).
//
// VERIFICATION CHECKLIST (measure and fill in):
//   [ ] Actual board length/width (approximate values carried over from v1)
//   [ ] Board height including pin headers
//   [ ] USB-C connector alignment relative to board (x-y-z offset)
//   [ ] Clear line of sight for BLE antenna (signal envelope inside plastic enclosure — range test)
//   [ ] Requirement for an external power-bank/adapter holder
// ────────────────────────────────────────────────────────────────────────────

// part = "both" | "base" | "lid"
part = "both";

board_isim = "Deneyap Kart 1A v2 (ESP32-S3, Type-C)";

// ── D R A F T  D I M E N S I O N S (mm) — all are subject to the verification checklist ──
board_l = 63.5;     // DRAFT (approximation from v1) — measure it
board_w = 25.4;     // DRAFT — measure it
board_h = 15.7;     // DRAFT: height including pin headers — measure it

wall   = 2.5;
floor_t = 2.5;
lid_t  = 2.5;
tol    = 0.5;

// Inner enclosure: DRAFT — allowance for the board + a loose loop of USB cable.
in_l  = 90;         // DRAFT
in_w  = 45;         // DRAFT
in_h  = 30;         // DRAFT (board stop + cable clearance above)

board_x = 10;  board_y = 10;  board_stand = 6;   // DRAFT (short posts)

// OPENINGS
usb_c_l  = 14;      // DRAFT (from v1): USB-C connector opening width
usb_c_h  = 8;       // DRAFT: connector opening height
screw_d  = 2.6;     // M3 pilot hole
screw_cl = 3.5;     // Clearance hole in lid
vent_w   = 4;       // DRAFT: ventilation slot width
vent_n   = 3;       // DRAFT: number of slots

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
            // Screw bosses
            boss_positions() cylinder(d = 7, h = in_h);

            // Board stops (DRAFT position: center bay)
            for (dx = [0, board_l - 4]) for (dy = [0, board_w - 4])
                translate([board_x + dx, board_y + dy, 0]) cube([4, 4, board_stand]);
        }
        // Screw holes
        boss_positions() translate([0, 0, in_h - 12]) cylinder(d = screw_d, h = 13);

        // USB-C opening: on the LEFT side instead of the rear wall (measure board connector alignment)
        translate([-wall - 1, board_y + board_w/2 - usb_c_l/2, board_stand - 1])
            cube([wall + 2, usb_c_l, usb_c_h]);

        // Ventilation on side/rear wall (DRAFT)
        for (i = [0 : vent_n - 1])
            translate([in_l - i * (vent_w + 6) - vent_w, in_w - 1, 10])
                cube([vent_w, wall + 2, in_h - 12]);
    }
}

module lid() {
    difference() {
        translate([-wall, -wall, 0]) cube([in_l + 2*wall, in_w + 2*wall, lid_t]);
        boss_positions() translate([0, 0, -1]) cylinder(d = screw_cl, h = lid_t + 2);
        // Lid ventilation slots (DRAFT)
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
