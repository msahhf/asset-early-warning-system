# ASSET 2.0 Sensor Node — Setup and Operation Guide

This guide brings together the complete process, from wiring the ASSET 2.0 hardware and starting the backend/bridge services to making the code changes required for each node.

---

## 1. Hardware — Bill of Materials

| # | Component | Model / Specification | Function |
|---|---|---|---|
| 1 | Microcontroller | Deneyap Kart 1A (ESP32) | BLE advertising, sensor readings, alarm control |
| 2 | Gas/Smoke Sensor | MQ-2 | Smoke/flammable-gas detection (analog) |
| 3 | Temperature/Humidity Sensor | DHT11 (4-pin) | ΔT and ΔH detection |
| 4 | P-Channel Power MOSFET | IRF5210 (TO-220) | Buzzer/LED switching (high-side switch) |
| 5 | Visual Indicator | 5 mm red LED + 220–330Ω resistor | Local visual alarm |
| 6 | Audible Indicator | 5V/3.3V active buzzer | Local audible alarm |
| 7 | Resistors | 10kΩ ×2, 220–330Ω ×1 | DHT11 pull-up, MOSFET gate pull-up, LED current limiting |

## 2. Pin Connection Table

| Component | Pin | Deneyap Kart Pin | Note |
|---|---|---|---|
| MQ-2 | VCC | 5V | 5 V required for heater |
| MQ-2 | GND | GND | |
| MQ-2 | A0 (Analog Out) | A0 | 0-4095 ADC |
| MQ-2 | D0 (Digital Out) | *Unconnected* | Not used; threshold is set in software |
| DHT11 | Pin 1 (VCC) | 3.3V | |
| DHT11 | Pin 2 (DATA) | D4 | 10kΩ pull-up to VCC |
| DHT11 | Pin 3 (NC) | *Unconnected* | |
| DHT11 | Pin 4 (GND) | GND | |
| IRF5210 | Pin 1 (Gate) | D1 | 10kΩ pull-up to 3.3 V (Source) |
| IRF5210 | Pin 3 (Source) | 3.3V | |
| IRF5210 | Pin 2 (Drain) | Load output | |
| Red LED | Anode (+) | IRF5210 Drain | Through a 220–330Ω series resistor |
| Red LED | Cathode (-) | GND | |
| Active Buzzer | VCC (+) | IRF5210 Drain | |
| Active Buzzer | GND (-) | GND | |

**Alarm logic (active-low, P-channel MOSFET):** `D1` is normally `HIGH` (alarm silent). When the alarm is triggered, set `D1` to `LOW` → the MOSFET conducts → the LED lights and the buzzer sounds.

```cpp
#define ALARM_PIN D1
void setup() {
  pinMode(ALARM_PIN, OUTPUT);
  digitalWrite(ALARM_PIN, HIGH); // silent at startup
}
void triggerAlarm(bool active) {
  digitalWrite(ALARM_PIN, active ? LOW : HIGH);
}
```

⚠️ **Reminder (from the previous review):** The threshold for this `D1` alarm logic (the ADC value that triggers it) must be synchronized with the backend's `ThresholdConfig.smokeThreshold`; do not hardcode them separately. If this has not yet been verified, ask Antigravity to confirm it before operation.

## 3. Starting the Backend and Bridge Services

### 3.1 Backend Server (Terminal 1)
```bash
cd backend      # (from the repository root)
npm run dev
```
Expected output:
```
✅ MongoDB connected: localhost
✅ Redis connected.
🚀 ASSET Backend API is running: http://localhost:5000
```
Open the dashboard at `http://localhost:5000` in a browser.

### 3.2 Uploading Firmware (Arduino IDE)
> Before uploading code, stop the bridge service with **Ctrl+C** in the terminal if it is already running, to avoid a port conflict.

1. Open Arduino IDE.
2. **Board:** `Tools → Board → Deneyap Kart → Deneyap Kart 1A v2`
3. **Port:** `Tools → Port → /dev/ttyUSB0` (or the port name on your system)
4. Open `asset_node_ble.ino` and click **Upload**.
5. When the upload is complete, **close** Arduino IDE's Serial Monitor to release the port to the bridge.

### 3.3 PC Bridge Service (Terminal 2)
```bash
cd backend      # (from the repository root)
node bridge/bridge.js --port=/dev/ttyUSB0 --baud=115200
```
As the board sends data, you should see output like this in the console:
```
📥 [Serial Port]: {"deviceId":1,"tempC":24.2,"humidityPct":48,"smokeRaw":310,"seqNo":1,"batteryPct":95}
✅ [Forwarded] Node #1: Smoke=310, Temperature=24.2°C, Seq=1
```
The corresponding node should update live on the dashboard.

**Test without hardware:** `node bridge/bridge.js --mock` or `node scripts/simulate_scenarios.js --scenario=consensus_fire`.

## 4. Per-Node Code Changes (Checklist)

If all five nodes are wired exactly as shown in this guide (all using A0/D4/D1), only **one line** needs to change in the firmware:

- [ ] `DEVICE_ID` constant — change it for each board, sequentially from 1 to 5 (`#define DEVICE_ID 1`, `2`, `3`...)

The following **must not change** (they must remain the same on every node):
- [ ] Pin definitions (A0, D4, D1) — keep the same if wiring is standardized
- [ ] BLE advertising logic and CRC8 calculation function
- [ ] Alarm threshold (see the synchronization warning in Section 2 — do not hardcode it in firmware; read it from the backend)

The `zoneId` is assigned in the backend (`Device.js`/database), **not** in the firmware. After physically placing each node, assign its zone through the dashboard/backend; do not change the code.

## 5. Test Scenarios

1. **Stable state:** Wait 20–30 seconds after powering the board (MQ-2 warm-up time). The smoke reading should stabilize between 200 and 400, and the buzzer/LED should remain off.
2. **Single-node test (WARNING expected, not FIRE):** Apply a controlled amount of smoke/gas to one node. That node should enter `warning` in the backend, but the zone should not trigger `FIRE` (there is no consensus).
3. **Consensus test (FIRE expected):** Trigger two nodes in the same zone at the same time. `alert:fire` should be emitted, the dashboard should turn red, the simulated drone animation should start, and the 180-second cooldown should begin.
4. **Return to normal:** Remove the gas. When readings fall below the threshold, the buzzer/LED/alarm state should reset automatically.

## 6. Troubleshooting

| Issue | Possible Cause | Solution |
|---|---|---|
| `nodemon: Permission denied` | Missing execute permission for `node_modules/.bin/` | `chmod +x node_modules/.bin/*` |
| Bridge cannot open the port | Arduino IDE's Serial Monitor is still open | Close the IDE's Serial Monitor window |
| CRC mismatch / packet rejected | Firmware and bridge use different CRC8 implementations | Compare both against the same test vector (see the previous verification) |
| FIRE triggers in a single-node test | The zone-consensus layer may be bypassed | Check `fusionEngine.js` and see the warning in Section 2 |
