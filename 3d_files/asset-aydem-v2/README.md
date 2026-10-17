# ASSET 2.1 — 3D Dosyaları (v2)

Düzenlenebilir kaynak CAD dosyaları (OpenSCAD). Tüm ölçüler **mm**.

## Kapsam

| Dosya | Açıklama | Durum |
|---|---|---|
| `asset_node_kapsul_v2.scad` | Düğüm kapsülü: Gövde + Kapak (`part = both/base/lid`) | **TASLAK** — VARSAYIM işaretli ölçüler var (bkz. tablo) |
| `asset_node_kapsul_v2_base.stl` | Gövde STL dışa aktarımı (OpenSCAD 2021.01, bbox 145×85×44,5) | Kaynağıyla birlikte TASLAK |
| `asset_node_kapsul_v2_lid.stl` | Kapak STL dışa aktarımı (bbox 145×85×2,5) | Kaynağıyla birlikte TASLAK |
| `asset_hub_kutusu_v2.scad` | Hub kutusu: parametrik çatkı + USB-C pasajı | **TASLAK — STL ÜRETİLMEDİ** (doğrulanmış ölçü yok) |
| v1 referans: `../asset-aydem-v1/` | v1 kapsül (`.scad` + `.stl`) | Yalnız biçim/sunum örneği |

## Varsayım tablosu (üretim öncesi MUTLAKA ölçün)

| Parametre | Dosyadaki değer | Durum |
|---|---|---|
| Kart (Deneyap 1A v2) | 63,5×25,4×15,7 | VARSAYIM (v1'den devralınan); gerçek kartla ölçün |
| MQ-2 modülü | 40×22×27 | VARSAYIM (modeller 32–40 arası); satın alınan modülü ölçün |
| 18650 pil | 65,0×18,4 (nominal) | VARSAYIM; gerçek hücre + sarmasını ölçün |
| WAGO 221-413 | 18,7×18,6×8,3 | Katalog değeri |
| PG7 rakor deliği | Ø12,5 | Katalog değeri |
| M3 delikleri | Ø2,6 / Ø3,5 | Katalog değeri |
| Buton deliği | Ø12,2 | VARSAYIM (12 mm buton varsayıldı) |
| USB-C açıklığı | 14×8 | VARSAYIM (v1 ortası); soket hizasını ölçün |
| DHT11 ızgara açıklığı (kapak) | 13×7 | VARSAYIM (v2'de yeni) |
| Buzzer deliği (kapak) | Ø16,2 | VARSAYIM ve **KAPALI (`buzzer_hole=false`)** |
| Hub kutusu (tüm ölçüler) | — | HEPİSİ TASLAK; doğrulama listesi dosyanın içinde |

## Doğrulanmış unsurlar (doküman + firmware, yüksek güven)

- MCU: Deneyap Kart 1A v2 (ESP32-S3, Type-C) — `docs/PROJE_DEVIR_TESLIM.md` §4.1
- MQ-2 → A0 (10k:10k bölücü, ×2 telafi), DHT11 → D4, IRF5210 → D1 aktif-düşük — `iot/asset_node_ble.ino`
- Aktif buzzer + 5 mm LED IRF5210 drain'inde — `docs/ASSET_2.0_PIN_SEMASI.md` BOM

## v2 ↔ v1 değişiklik günlüğü

- Pil bölmesi: v1'deki 40×28 (VARSAYIM) → **18650 65×18,4 nominal**.
- v1'in iç kutusu (125×75) 18650'ye **yetmiyordu** — batarya +X duvarına taşıyordu
  (bbox denetimiyle yakalandı). v2 iç kutu **140×80'e** büyütüldü, yerleşim yeniden
  bölümlendi: ön bant = Kart + MQ-2 (ön duvar havalandırması), arka bant =
  WAGO (sol) + 18650 (sağ).
- Kapak: **DHT11 ızgara açıklığı** eklendi (varsayım ölçü); **buzzer deliği**
  parametrik ama başlangıçta KAPALI.
- Pil tutucusuna uç duvarlar korundu (hücre kaymasını önler).
- Yeniden üretim: `openscad -o base.stl -D 'part="base"' asset_node_kapsul_v2.scad`
  vb.

## Ölçü kaynağı özeti

Depodaki üç doküman (`docs/ASSET_2.0_PIN_SEMASI*.md`, `docs/PROJE_DEVIR_TESLIM.md`)
kutu dış ölçüsü/delik çapı **içermiyor**; bu yüzden v2 kaynakları parametrik TASLAK
olarak işaretlendi. Parametrelerin hangi kaynak dosyadan geldiği, `asset_node_kapsul_v2.scad`
başlıklarında ve yukarıdaki varsayım tablosunda belgelidir.
