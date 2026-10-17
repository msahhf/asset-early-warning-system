# ASSET 2.1 — 3D Files (v2)

Editable source CAD files (OpenSCAD). All dimensions are in **mm**.

## Scope

| File | Description | Status |
|---|---|---|
| `asset_node_enclosure_v2.scad` | Node enclosure: base + lid (`part = both/base/lid`) | **DRAFT** — dimensions marked as ASSUMPTIONS are present (see table) |
| `asset_node_enclosure_v2_base.stl` | Base STL export (OpenSCAD 2021.01, bbox 145×85×44.5) | DRAFT alongside its source |
| `asset_node_enclosure_v2_lid.stl` | Lid STL export (bbox 145×85×2.5) | DRAFT alongside its source |
| `asset_hub_enclosure_v2.scad` | Hub enclosure: parametric framework + USB-C opening | **DRAFT — NO STL GENERATED** (no verified dimensions) |
| v1 reference: `../asset-aydem-v1/` | v1 enclosure (`.scad` + `.stl`) | Reference for form/presentation only |

## Assumptions (measure these before manufacturing)

| Parameter | Value in file | Status |
|---|---|---|
| Board (Deneyap 1A v2) | 63.5×25.4×15.7 | ASSUMPTION (carried over from v1); measure the actual board |
| MQ-2 module | 40×22×27 | ASSUMPTION (models range from 32–40); measure the purchased module |
| 18650 battery | 65.0×18.4 (nominal) | ASSUMPTION; measure the actual cell and wrapping |
| WAGO 221-413 | 18.7×18.6×8.3 | Catalog value |
| PG7 cable-gland hole | Ø12.5 | Catalog value |
| M3 holes | Ø2.6 / Ø3.5 | Catalog value |
| Button hole | Ø12.2 | ASSUMPTION (12 mm button assumed) |
| USB-C opening | 14×8 | ASSUMPTION (v1 center); measure connector alignment |
| DHT11 grille opening (lid) | 13×7 | ASSUMPTION (new in v2) |
| Buzzer hole (lid) | Ø16.2 | ASSUMPTION and **DISABLED (`buzzer_hole=false`)** |
| Hub enclosure (all dimensions) | — | ALL DRAFT; see the checklist in the source file |

## Verified details (documentation + firmware, high confidence)

- MCU: Deneyap Kart 1A v2 (ESP32-S3, Type-C) — `docs/PROJECT_HANDOVER.md` §4.1
- MQ-2 → A0 (10k:10k divider, ×2 compensation), DHT11 → D4, IRF5210 → D1 active-low — `iot/asset_node_ble.ino`
- Active buzzer + 5 mm LED on the IRF5210 drain — BOM in `docs/ASSET_2.0_PINOUT.md`

## v2 ↔ v1 change log

- Battery compartment: v1's 40×28 (ASSUMPTION) → **18650, 65×18.4 nominal**.
- The v1 inner enclosure (125×75) **could not fit** an 18650 — the battery extended through the +X wall
  (caught by the bounding-box check). The v2 inner enclosure was enlarged to **140×80** and the layout
  was reorganized: front bay = board + MQ-2 (front-wall ventilation); rear bay = WAGO (left) + 18650 (right).
- Lid: a **DHT11 grille opening** was added (assumed dimensions); the **buzzer hole** is parametric but disabled by default.
- End walls were retained on the battery holder to prevent the cell from sliding.
- To regenerate: `openscad -o base.stl -D 'part="base"' asset_node_enclosure_v2.scad`, etc.

## Summary of dimension sources

The three repository documents (`docs/ASSET_2.0_PINOUT*.md`, `docs/PROJECT_HANDOVER.md`)
do **not include** enclosure outer dimensions or hole diameters; therefore, the v2 sources are marked
as parametric DRAFTS. The source of each parameter is documented in the headers of
`asset_node_enclosure_v2.scad` and in the assumptions table above.
