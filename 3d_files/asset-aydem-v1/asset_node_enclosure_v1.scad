// ASSET 2.0 sensor cell enclosure — EXAMPLE (v1)
// All dimensions are in mm. Check the parameters first.
// part = "both" | "base" | "lid"
part = "both";

// ── DIMENSIONS (values sourced from the internet) ──
board_l = 63.5;     // Deneyap Kart 1A v2 length
board_w = 25.4;     // width
board_h = 15.7;     // height (including components mounted on it)
mq2_l   = 40;       // MQ-2 module (models range from 32–40; the largest was used)
mq2_w   = 22;
mq2_h   = 27;
wago_l  = 18.7;     // WAGO 221-413 (3-position)
wago_w  = 18.6;
wago_h  = 8.3;
wago_n  = 3;        // Number of terminals
batt_l  = 40;       // BATTERY SPACE — ESTIMATE; measure the actual battery!
batt_w  = 28;

// ── ENCLOSURE ──
wall   = 2.5;
floor_t = 2.5;
lid_t  = 2.5;
in_l   = 125;       // inner length
in_w   = 75;        // inner width
in_h   = 42;        // inner height
tol    = 0.5;       // assembly clearance

// ── OPENINGS ──
btn_d    = 12.2;    // Panel button hole (12 mm button assumed)
gland_d  = 12.5;    // PG7 cable-gland hole
screw_d  = 2.6;     // M3 pilot hole (screws into plastic)
screw_cl = 3.5;     // M3 clearance hole in lid

// ── LAYOUT ──
board_x = 10;  board_y = 10;  board_stand = 12;  // clearance underneath for pins
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
            // Screw bosses
            boss_positions() cylinder(d = 8, h = in_h);

            // Deneyap Kart: four corner posts + side retainers
            for (dx = [0, board_l - 4]) for (dy = [0, board_w - 4])
                translate([board_x + dx, board_y + dy, 0]) cube([4, 4, board_stand]);
            // Thin walls that keep the board from sliding sideways
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

            // Battery compartment frame
            translate([batt_x - 1.5, batt_y - 1.5, 0])
                difference() {
                    cube([batt_l + 2*tol + 3, batt_w + 2*tol + 3, 5]);
                    translate([1.5, 1.5, 0.8]) cube([batt_l + 2*tol, batt_w + 2*tol, 6]);
                }
        }
        // Screw holes
        boss_positions() translate([0, 0, in_h - 14]) cylinder(d = screw_d, h = 15);

        // USB-C opening (left wall, board connector end)
        translate([-wall - 1, board_y + board_w/2 - 7, board_stand + 0.5])
            cube([wall + 2, 14, 8]);

        // Cable-gland holes (rear wall)
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
        // Test and mute buttons
        translate([board_x + 12, 58, -1]) cylinder(d = btn_d, h = lid_t + 2);
        translate([board_x + 38, 58, -1]) cylinder(d = btn_d, h = lid_t + 2);
    }
}

if (part == "base" || part == "both") base();
if (part == "lid")  translate([0, 0, 0]) lid();
if (part == "both") translate([0, in_w + 20, 0]) lid();
