# 📋 ASSET Project Comprehensive Handover Document
**Advanced Smart Sensing and Suppression Technology (ASSET)**
**Last Updated / Analysis Date:** October 17, 2026
**Document Version:** 2.1.0
**Development Environment:** Linux (CachyOS x86_64) / Deneyap Technology Workshops

---

## ⚠️ IMPORTANT: TWO HARDWARE GENERATIONS IN THE REPOSITORY (v1 vs v2)

The codebase and documentation show that the project has two generations:
1. **Legacy generation (asset-aydem v1 / ASSET 1.0):**
   * **Focus:** A standalone smart smoke/fire detector for homes and offices.
   * **Communication:** HTTP POST directly to the backend over Wi-Fi STA (`/api/sensors/data`, `/api/sensors/heartbeat`).
   * **Initial setup:** SSID/password transfer over a BLE GATT service (Wi-Fi provisioning).
   * **Physical actuators:** Siren relay (`D0`), water suppression relay (`D1`), test button (`D2`), mute button (`D3`).
   * **Clients:** Flutter mobile app (`mobileApp/`) and Firebase FCM notifications.
   * **Related files:** *(archived)* `archive/asset-v1-eski-nesil/asset-aydem/asset/iot/asset_firmware/asset_firmware.ino`, `archive/.../docs/KURULUM_REHBERI.md`, `archive/.../docs/AR-GE_Raporu.md`, `archive/.../mobileApp/`.

2. **Current generation (ASSET 2.0 sensor node + ASSET 2.1 BLE hub) — ACTIVE SYSTEM:**
   * **Focus:** A tactical sensor network for early fire detection in forests and open areas (5 nodes).
   * **Communication:** Wi-Fi is not used. Battery-powered nodes broadcast one-way BLE beacons using Manufacturer Specific Data (`0xFFFF`, 13-byte binary struct).
   * **Central collector (hub):** The Deneyap Kart-based BLE Central Hub (`asset_hub_ble.ino`) captures packets over the air, validates CRC8, and streams JSON over the USB serial port.
   * **Bridge:** `backend/bridge/bridge.js` runs on a PC, listens to the serial port, deduplicates packets (`seqNo`), and forwards them to the backend Ingest API (`/api/sensors/ingest`).
   * **Decision engine:** `backend/src/services/fusionEngine.js` performs multi-sensor fusion (smoke + $\Delta T/\Delta t$ + $\Delta H$) and zone consensus (simultaneous warnings from at least two nodes).
   * **Physical actuators:** Relays have been removed. A local LED and buzzer are driven by an IRF5210 P-channel power MOSFET connected to node pin `D1` (active-low trigger).
   * **Clients:** Web-based Tactical NOC Map Panel (`public/admin.html`) and Public Portal (`public/index.html`). The Flutter app is not used in this architecture.
   * **Related files:** `iot/asset_node_ble/`, `iot/asset_node2_ble/`, `iot/asset_hub_ble/`, `backend/bridge/bridge.js`, `backend/src/services/fusionEngine.js`, `docs/ASSET_2.0_PINOUT.md`, `docs/ASSET_2.0_PINOUT_V2.md`.

---

## 1. ABOUT THE PROJECT

### 1.1. Purpose and Motivation
Traditional fire and smoke detectors are usually isolated devices designed for indoor use. They produce only a local audible alarm (buzzer) and cannot track how a fire spreads across a large area. **ASSET** was developed to address this limitation by digitizing detection, telemetry, monitoring, decision-making, and response coordination end to end.

### 1.2. Evolution from a Home Device to a Forest-Area System
* **Initial goal:** A smart device for homes and buildings that uses Wi-Fi, has an 18650 lithium-battery backup (UPS), triggers water/gas solenoid valves through relays when smoke or gas is detected, and notifies the homeowner through a Flutter mobile app (`asset_firmware.ino`).
* **Current goal:** A tactical network of low-power (BLE), multi-sensor nodes that can operate independently on batteries and solar panels in forested areas without infrastructure (Wi-Fi or 220 V mains). The system uses **sensor fusion** and **zone consensus** to prevent false positives caused by airflow or solar heating affecting a single detector.

### 1.3. Target Users
* **Operational:** General Directorate of Forestry (OGM) crisis centers, fire-watch tower operators, and emergency response teams (SOC/NOC operators).
* **Administrative:** Field engineers and system administrators who calibrate thresholds and manage sensor locations on the map.
* *(The legacy home version targeted individual homeowners and office owners.)*

### 1.4. Drone Status and Remaining Code
* **Project status:** A physical autonomous fire-suppression UAV (drone) has been **removed** from the hardware and software plan.
* **Remaining code:**
  1. `backend/public/admin.html` (lines 231–285, 638–662, 978–1055): A "Drone Hangar Alpha" location is defined on the Leaflet map (`HANGAR_POS`). When a red `alert:fire` alarm is triggered, `dispatchSimulatedDrone()` runs; the code contains a visual simulation called **Drone Telemetry HUD Overlay**, with an animated drone icon flying from the hangar coordinates to the fire zone, simulated altitude (40–120 m), speed display (60–68 km/h), and estimated time of arrival (ETA) countdown.
  2. `backend/src/config/nodePositions.js` (lines 30–35): Stores the `DEFAULT_HANGAR` (`HANGAR_LAT`, `HANGAR_LNG`, `HANGAR_NAME`) variables.
  3. `backend/src/controllers/sensorController.js` (lines 317, 347, 353, 392): Test scenarios contain logs and descriptions such as *"Drone does not take off"* and *"Simulated drone dispatch started"*.
  4. **Hardware status:** The codebase contains **no** MAVLink, PX4, ArduPilot, physical drone telemetry receiver, or related library. The drone is entirely a visual dashboard simulation.

---

## 2. SYSTEM ARCHITECTURE AND DATA FLOW

The system consists of five layers:
1. **Sensor layer (ASSET 2.0 Node):** Collects, packages, and broadcasts environmental data over BLE.
2. **Collector layer (ASSET 2.1 Hub):** Receives BLE packets over the air and sends them to the PC over USB-UART.
3. **Bridge layer (`bridge.js`):** Parses serial-port data, validates CRC, and forwards it to the local REST Ingest API. It also sends threshold updates back to the board over USB.
4. **Backend and decision layer (Node.js Express / Socket.io / MongoDB Atlas / Redis):** Processes packets, analyzes them in a sliding window, calculates zone consensus, writes to the database, and distributes updates over WebSocket.
5. **Visualization and tactical layer (`admin.html` / `index.html`):** Displays nodes, smoke curves, and alerts live on a map.

### 2.1. Text-Based End-to-End Data Flow Diagram

```text
+-----------------------+     +-----------------------+
|  ASSET 2.0 Node #1    |     |  ASSET 2.0 Node #2    |
|  [MQ-2 + DHT11]       |     |  [MQ-2 + DHT11]       |
|  (Battery-powered)    |     |  (Battery-powered)    |
+-----------+-----------+     +-----------+-----------+
            |                             |
     BLE Adv (5 sec)               BLE Adv (5 sec)
  Mfg Data (13-byte struct)    Mfg Data (13-byte struct)
            |                             |
            +--------------+--------------+
                           |
                           v
            +-------------------------------+
            |  ASSET 2.1 BLE Central Hub    |
            |  (Deneyap Kart 1A v2 - USB)   |
            |  - Continuous BLE scan (90 ms)|
            |  - CRC-8 validation           |
            |  - SeqNo deduplication        |
            +---------------+---------------+
                            |
                   USB serial port (115200 baud)
                   JSON / hex character string
                            |
                            v
            +-------------------------------+
|  PC Serial Port Bridge        |
            |  (backend/bridge/bridge.js)   |
|  - Multi-port auto-detection  |
|  - CRC-8 validation           |
            |  - HTTP POST + x-api-key      |
            +---------------+---------------+
                            |
             HTTP POST /api/sensors/ingest
             (x-api-key authenticated)
                            |
                            v
            +-------------------------------+
|  ASSET 2.1 Backend Server     |
            |  (Node.js / Express 5.x)      |
            +---------------+---------------+
                            |
            +---------------+---------------+
            |                               |
            v                               v
+-----------------------+       +-----------------------+
| fusionEngine.js       |       | Data Storage          |
| 1. Node fusion        |       | - MongoDB Atlas       |
|   (Smoke + ΔT + ΔH)   |       |   (Device, SensorLog, |
| 2. Zone consensus     |       |    Alert, Config)     |
|   (minNodes >= 2)     |       | - Redis (Opsiyonel /  |
| 3. Cooldown (180 sn)  |       |   In-Memory Map)      |
+-----------+-----------+       +-----------------------+
            |
    Socket.io Events
    (sensor:update, node:warning, alert:fire, alert:resolved)
            |
            +-------------------------------+
            |                               |
            v                               v
+-------------------------------+ +-------------------------------+
| Tactical NOC Map Panel        | | Cloudflare Tunnel             |
| (public/admin.html)           | | https://<panel-address>         |
| - Leaflet & CARTO Vector      | | https://<api-address>           |
| - Live Chart.js smoke curve   | +-------------------------------+
| - Drone simulation HUD        |
| - Threshold calibration modal |
+-------------------------------+
```

---

## 3. DIRECTORY AND FILE STRUCTURE (**CURRENT — October 17, 2026**)

> **Generation distinction:** The legacy generation (v1: Wi-Fi + relay-based home prototype, Flutter `mobileApp/`, `asset_firmware.ino`) has been moved out of the repository root to an external archive directory (`archive/asset-v1-eski-nesil/`). The tree below lists only the **current (v2) active code path**.

```text
assetaydem/   (this repository root)
├── 3d_files/
│   └── asset-aydem-v1/              # 3D enclosure designs (.scad / .stl)
├── backend/
│   ├── app.js                   # Express configuration, CORS, Helmet, rate limiting, admin-protected routes
│   ├── server.js                # HTTP server & Socket.io startup, rehydrateWithRetry, graceful shutdown
│   ├── package.json             # Dependencies (Express 5, Mongoose 9, Socket.io 4, Serialport 13)
│   ├── .env                     # Active environment variables (values stored here; excluded from repo)
│   ├── .env.example             # Environment-variable catalog template
│   ├── bridge/
│   │   └── bridge.js            # ASSET 2.1 PC serial-port to backend bridge (x-api-key + x-admin-key)
│   ├── scripts/
│   │   └── simulate_scenarios.js# Five-node console simulator (ingest with x-api-key header)
│   ├── public/
│   │   ├── admin.html           # Tactical NOC dashboard (admin-key-protected endpoints)
│   │   └── index.html           # Public portal (live badges: /api/public/status)
│   └── src/
│       ├── config/
│       │   ├── db.js            # Mongoose MongoDB connection pool
│       │   ├── redis.js         # Redis client + in-memory fallback layer
│       │   ├── firebase.js      # Firebase Admin SDK initializer (FCM)
│       │   └── nodePositions.js # Coordinates for five nodes + drone hangar
│       ├── controllers/
│       │   ├── alertController.js   # Alert-history queries
│       │   ├── authController.js    # Registration / login / profile (JWT)
│       │   ├── deviceController.js  # Device CRUD + emergency contacts
│       │   └── sensorController.js  # Ingest, heartbeat, thresholds, nodes-overview, getPublicStatus, simulateScenario
│       ├── middleware/
│       │   ├── authMiddleware.js    # JWT validation
│       │   └── adminAuth.js         # requireAdminKey (timing-safe ADMIN_API_KEY check) + simulateGuard (production lock)
│       ├── models/
│       │   ├── Alert.js         # Fire/warning alerts (timestamps, resolved/resolvedAt)
│       │   ├── Device.js        # IoT device schema (UUID, zone, battery, location, packet loss)
│       │   ├── SensorLog.js     # Time-series logs (30-day TTL index)
│       │   ├── ThresholdConfig.js # Dynamic thresholds and consensus parameters
│       │   └── User.js          # User accounts and emergency contacts
│       ├── routes/
│       │   ├── alertRoutes.js   # /api/alerts (JWT)
│       │   ├── apiRoutes.js     # /api router: auth, devices, alerts
│       │   ├── authRoutes.js    # /api/auth
│       │   ├── deviceRoutes.js  # /api/devices (JWT)
│       │   └── sensorRoutes.js  # /api/sensors: ingest/heartbeat (x-api-key), thresholds/overview/simulate (x-admin-key)
│       ├── services/
│       │   ├── fusionEngine.js  # Sensor fusion + zone consensus + restart rehydration (singleton)
│       │   ├── notificationService.js # FCM push notification service
│       │   └── redisService.js  # Device lifecycle (TTL) / state buffering
│       ├── socket/
│       │   └── socketHandler.js # Live telemetry Socket.io rooms
│       └── utils/
│           ├── errorHandler.js  # Global error handler (404/500)
│           └── logger.js        # Winston-based logging
├── docs/
│   ├── ASSET_2.0_PINOUT.md          # [CURRENT] MOSFET and sensor wiring diagram
│   ├── ASSET_2.0_PINOUT_V2.md       # [CURRENT] Quick setup + checklist
│   └── PROJECT_HANDOVER.md          # This document (maintained copy)
└── iot/
    ├── asset_hub_ble/               # [CURRENT] ASSET 2.1 BLE Central Hub firmware
    │   └── asset_hub_ble.ino
    ├── asset_node_ble/              # [CURRENT] ASSET 2.0 Sensor Node (Node #1)
    │   └── asset_node_ble.ino
    └── asset_node2_ble/             # [CURRENT] ASSET 2.0 Sensor Node (Node #2)
        └── asset_node2_ble.ino

Legacy generation (v1) sources — ARCHIVED (outside the repo):
archive/asset-v1-eski-nesil/
├── ARSIV_NOTU.md                    # Explains why the files were archived
├── asset-aydem/                     # v1 repo snapshot (iot/asset_firmware/, mobileApp/, legacy docs)
└── deneyap-kok/                     # Root-level files from the v1 period
```

---

## 4. HARDWARE AND FIRMWARE ANALYSIS

### 4.1. Microcontroller Board and Naming Inconsistencies
* **Correct hardware:** **Deneyap Kart 1A v2**
* **Chip architecture:** **ESP32-S3** (with Type-C connector).
* **Arduino IDE board selection:** `Tools → Board → Deneyap Kart → Deneyap Kart 1A v2`
* **Documentation inconsistencies:**
  - `docs/KURULUM_REHBERI.md` identifies the board as *ESP32-WROOM-32* on line 42 (the chip used by Deneyap Kart 1A v1).
  - `docs/ASSET_2.0_PINOUT.md` refers to it simply as *Deneyap Kart 1A*.
  - The physical boards and firmware headers (`asset_node_ble.ino:3`) use **Deneyap Kart 1A v2 (ESP32-S3)** hardware.

### 4.2. Pin Comparison Across Hardware Generations

| Function / Component | Legacy generation (v1 - `asset_firmware.ino`) | Current generation (v2 - `asset_node_ble.ino`) | Critical note / conflict |
| :--- | :--- | :--- | :--- |
| **Gas / Smoke Sensor** | MQ-2 analog output $\rightarrow$ **A0** | MQ-2 analog output $\rightarrow$ **A0** | Both generations use `A0`. |
| **Temperature and Humidity** | None (or hardcoded in code) | DHT11 data $\rightarrow$ **D4** (10k pull-up) | DHT was not connected in v1. |
| **Alarm / Response Output** | **D1** (water relay — active HIGH) | **D1** (IRF5210 gate — active LOW) | ⚠️ **CRITICAL CONFLICT:** v1 sets `D1` HIGH to activate the relay; v2 sets `D1` LOW to turn on the MOSFET. Uploading the old code to the new board will keep the buzzer sounding! |
| **Secondary Siren Output** | **D0** (siren relay) | *Unused* | In v2, the siren and LED are driven together through one MOSFET on `D1`. |
| **Test Button** | **D2** (input pull-up) | *Unused* | v2 has no hardware button; tests use API simulation. |
| **Mute Button** | **D3** (input pull-up) | *Unused* | v2 has no button. |
| **Battery Voltage Reading** | **A1** (voltage divider) | *Hardcoded as 95% in code* | In v2 firmware, `readBatteryPct()` does not perform an analog reading; it returns a fixed 95. |

### 4.3. Current Generation (ASSET 2.0) P-Channel MOSFET (IRF5210) Drive Logic
The IRF5210 is a P-channel power MOSFET that switches the positive 3.3 V line as a **high-side switch**:
* **Gate = HIGH (3.3 V):** $V_{GS} = V_{Gate} - V_{Source} = 3.3V - 3.3V = 0V$. The MOSFET is cut off (**OFF**). The LED is off and the buzzer is silent.
* **Gate = LOW (0 V — GND):** $V_{GS} = 0V - 3.3V = -3.3V$. The MOSFET conducts (**ON**). 3.3 V flows through the Drain to the LED and buzzer.
* **Startup glitch protection:** In `setup()`, first call `digitalWrite(ALARM_PIN, HIGH)` on the pin, then set it to `pinMode(ALARM_PIN, OUTPUT)`. A 10k$\Omega$ pull-up resistor is also connected between Gate and Source (3.3 V).

### 4.4. 13-Byte Packed Struct and CRC-8 Validation

Binary data structure used by the firmware (`asset_node_ble.ino`, `asset_hub_ble.ino`), PC bridge (`bridge.js`), and backend (`sensorController.js`):

```c
struct __attribute__((packed)) AssetPacket {
  uint8_t  schema_version;   // Byte 0:    Schema version (fixed 0x01)
  uint8_t  device_id;        // Byte 1:    Node ID (1–5)
  uint16_t temp_c_x10;       // Bytes 2–3: Temperature x10, little-endian (e.g. 245 = 24.5°C)
  uint8_t  humidity_pct;     // Byte 4:    Relative humidity (0–100%)
  uint16_t smoke_raw;        // Bytes 5–6: MQ-2 ADC compensated value (0–4095), little-endian
  uint32_t seq_no;           // Bytes 7–10: Packet sequence number, little-endian (32-bit)
  uint8_t  battery_pct;      // Byte 11:   Battery percentage (0–100%)
  uint8_t  crc8;             // Byte 12:   CRC-8 Dallas/Maxim checksum of the first 12 bytes
};
// Total length: 13 bytes
```

* **CRC-8 polynomial:** `0x07` (Dallas/Maxim: $x^8 + x^2 + x + 1$), initial value: `0x00`.
* **Calculation:** Computed over the first 12 bytes using bitwise XOR and shifts, then compared with the received CRC in byte 13. If they do not match, the packet is discarded at both the Hub and Bridge layers.

### 4.5. Threshold Synchronization Status (IMPORTANT ANALYSIS)
In the firmware (`asset_node_ble.ino:37`):
```cpp
volatile int smokeThresholdLocal = 1000;
```
* **Synchronization over USB:** When `THRESHOLD:<value>\n` is sent to the board over the serial port, `processSerialCommand()` catches the command, updates `smokeThresholdLocal`, and returns `THRESHOLD_ACK:<value>`. `bridge.js` is designed to read the backend's `ThresholdConfig.smokeThreshold` value (default 850) and write it to the serial port.
* **Synchronization while deployed / battery-powered [UNCERTAIN / RISK]:**
  - Sensor nodes are **not** connected to a USB port while operating on batteries in the field.
  - Nodes only broadcast one-way over BLE; there is no GATT connection or feedback channel from the Hub to a node.
  - **Result:** While battery-powered, a node **CANNOT** receive threshold changes made in the backend or dashboard over the air. It uses its local startup threshold of `1000` to control its alarm (buzzer/LED). The backend, meanwhile, makes consensus decisions using the database threshold of `850`.

---

## 5. BACKEND AND DECISION ENGINE (FUSION ENGINE)

### 5.1. API Endpoint Catalog

| Method | Endpoint | Authorization | Description |
| :--- | :--- | :--- | :--- |
| `POST` | `/api/sensors/ingest` | `x-api-key` (Required) | Accepts a telemetry packet (`rawHex` or JSON) from the Hub or Bridge and forwards it to the fusion engine. |
| `POST` | `/api/sensors/data` | `x-api-key` (Required) | v1 backward-compatible data-ingest endpoint. |
| `POST` | `/api/sensors/heartbeat` | `x-api-key` (Required) | Device heartbeat and battery update. |
| `GET` | `/api/config/thresholds` | Public | Returns active `ThresholdConfig` threshold parameters. |
| `PUT` | `/api/config/thresholds` | Public | Updates threshold parameters and emits `config:updated` over Socket.io. |
| `GET` | `/api/sensors/nodes-overview`| Public | Returns the status of five nodes, the latest 20 measurement logs, active alerts, and hangar coordinates for the dashboard. |
| `POST` | `/api/sensors/simulate-scenario` | Public | Runs a quick test scenario (`normal`, `single_warning`, `consensus_fire`). |
| `POST` | `/api/auth/register` | Public | Registers a new user. |
| `POST` | `/api/auth/login` | Public | Logs in and issues a JWT. |
| `GET` | `/api/auth/me` | JWT (Bearer) | Active user profile. |
| `GET` | `/api/devices` | JWT (Bearer) | The user's device list. |
| `POST` | `/api/devices` | JWT (Bearer) | Registers a device (generates unique `deviceId` and `apiKey`). |
| `GET` | `/api/alerts` | JWT (Bearer) | Queries alert history. |
| `GET` | `/api/health` | Public | UptimeRobot/system health check (DB and Redis status). |
| `GET` | `/api/sysinfo` | Public | Returns system memory, uptime, and the latest 50 HTTP requests. |

### 5.2. Data Models
1. **`Device` (`backend/src/models/Device.js`):**
   * Fields: `name`, `deviceId` (unique String), `apiKey` (secret), `zoneId` ("zone-alpha", "zone-bravo"), `coordinates` (`lat`, `lng`), `location` ("ASSET Sector 1"), `status` (`online`, `offline`, `warning`, `fire`), `isOnline`, `batteryPct`, `totalPacketsReceived`, `totalPacketsLost`, `lastSeq`, `lastSeen`, `lastHeartbeat`.
   * **`forestRegion` analysis:** There is **no** model or field named `forestRegion` in the codebase. Regions are grouped by `zoneId` and described by the `location` field.
2. **`Alert` (`backend/src/models/Alert.js`):**
   * Alanlar: `alertId` (UUID), `zoneId`, `severity` (`warning`, `fire`), `type` (`fire`, `gas_warning`, `offline`), `triggeringDeviceIds` (String dizisi), `coordinates` (`lat`, `lng`), `message`, `resolved` (Boolean), `resolvedAt`, `notificationStatus`.
3. **`SensorLog` (`backend/src/models/SensorLog.js`):**
   * Alanlar: `deviceId`, `tempC`, `humidityPct`, `smokeRaw`, `movingAvgSmoke`, `smokeFlag`, `heatRateFlag`, `humidityDropFlag`, `gasStatus`, `source` (`hardware`, `mock`, `sim`), `rawSeqNo`, `timestamp`.
   * **Archiving / automatic cleanup:** The collection has a 30-day MongoDB TTL index (`expireAfterSeconds: 30 * 24 * 60 * 60`). Logs older than 30 days are automatically deleted by the database engine.
4. **`ThresholdConfig` (`backend/src/models/ThresholdConfig.js`):**
   * `smokeThreshold` (default: 850)
   * `heatRateThresholdCPerSec` (default: 0.15 °C/s)
   * `humidityDropThresholdPct` (default: 5.0%)
   * `windowSeconds` (default: 45 sec)
   * `minNodesForFire` (default: 2 nodes)
   * `cooldownSeconds` (default: 180 sec)
   * `movingAverageSize` (default: 3 samples)

### 5.3. Decision Logic (`fusionEngine.js`)

#### 1. Node-Level Fusion
For each incoming packet, the node's latest readings are stored in a sliding-window buffer (`deviceWindows`):
* **Smoke check:** The latest three readings are averaged: if $\bar{S} \ge \text{smokeThreshold}$, then `smokeFlag = true`.
* **Heat-rise rate check:** The derivative between the oldest and newest samples in the buffer is calculated:
  $$\frac{\Delta T}{\Delta t} = \frac{T_{\text{new}} - T_{\text{old}}}{t_{\text{new}} - t_{\text{old}}} \ge 0.15 \, ^\circ\text{C/sec} \implies \text{heatRateFlag} = \text{true}$$
* **Sudden humidity-drop check:** Rapid drying of the air during a fire is monitored:
  $$\Delta H = H_{\text{old}} - H_{\text{new}} \ge 5\% \implies \text{humidityDropFlag} = \text{true}$$
* **NODE WARNING RULE:**
  $$\text{isWarning} = \text{smokeFlag} \land (\text{heatRateFlag} \lor \text{humidityDropFlag})$$
  *(The DHT11's temperature-rise and humidity-drop data are used directly in the code's `isWarning` decision; a smoke increase alone does not put a node into WARNING state.)*

#### 2. Zone-Level Consensus
* Checks whether nodes in the same `zoneId` have an active `isWarning` state within the latest `windowSeconds` (45 seconds).
* **FIRE RULE:**
  $$\text{Number of Nodes with Active Warnings} \ge \text{minNodesForFire} \quad (\text{Default: } 2)$$
* **Cooldown mechanism:** After a fire alert is created, duplicate alerts and notifications for the same zone are suppressed for `cooldownSeconds` (180 seconds) (`fire_cooldown`).
* **Clearing / return to normal:** When active warnings fall below the consensus threshold and the cooldown expires, the alert is automatically resolved (`alert:resolved` is emitted and nodes return to `online`).

### 5.4. Notifications and External Integrations
* **FCM (Firebase Cloud Messaging):** High-priority (`asset_alarm_channel_v3`) push notifications are sent to user tokens through `notificationService.js`.
* **Email notifications:** There is **no** email-sending module (Nodemailer, SendGrid, etc.) in the code. User references are stored in `Alert.notifiedUsers`, but no actual email is sent.
* **OGM / Alo 177 status [UNCERTAIN / NOT IMPLEMENTED]:**
  - There is **no** integration in the codebase with the General Directorate of Forestry (OGM), the Alo 177 emergency line, or any external SMS/IVR call center. These are conceptual goals only; no related code or service exists.

---

## 6. FRONTEND / DASHBOARD ANALYSIS

### 6.1. Tactical NOC Command Center (`backend/public/admin.html`)
* **Technologies:** HTML5, vanilla JavaScript, CSS3 (glassmorphism dark theme), Leaflet 1.9.4, MapLibre GL 3.6.2 & `@maplibre/maplibre-gl-leaflet`, Chart.js, Socket.io Client.
* **Map layers:**
  - CARTO Dark Matter vector map (no watermark / high-performance rendering with MapLibre GL).
  - Esri World Imagery (high-resolution satellite imagery base layer).
* **Live indicators and features:**
  - GPS locations of five sensor nodes, with status colors (green: safe, yellow: warning, red: fire consensus, gray: offline).
  - Data-source badges on sensor cards (`HW`: real hardware, `MOCK`: virtual bridge, `SIM`: scenario simulation).
  - Real-time time-series chart for smoke (raw and filtered).
  - Threshold calibration modal (`PUT /api/config/thresholds`).
  - Quick scenario buttons (`Normal`, `Single Warning`, `Fire Consensus`, `Reset`).

### 6.2. Public Landing and Login Portal (`backend/public/index.html`)
* Landing page prepared for the `<your-domain>.com` apex domain (the real domain was replaced with a generic example).
* Introduces the system architecture, displays a live system-status badge (shows the connected-node count in real time over `socket.io`), and provides an authenticated login/registration modal (`/api/auth/login` and `/api/auth/register`).

---

## 7. SETUP AND OPERATION GUIDE

### 7.1. Requirements
* Node.js (v18.x, v20.x veya v22.x LTS)
* npm (v9.x veya v10.x)
* MongoDB (local MongoDB v6.0+ or MongoDB Atlas Cloud)
* Redis (v6.2+ or Upstash / an in-memory mock is enabled automatically if unavailable)
* Arduino IDE (v2.x) + Deneyap Kart Paketleri
* USB-UART drivers (CP210x or CH340)

### 7.2. Environment Variable Catalog (`backend/.env`)

> ⚠️ **SECURITY RULE:** Secret values are NOT listed below; only variable names and their purposes are shown. Values are stored in `backend/.env`.

| Variable | Required? | Description / Purpose |
| :--- | :--- | :--- |
| `PORT` | No (default: 5000) | Express HTTP listening port. |
| `NODE_ENV` | No (default: development) | Runtime environment (`development`, `production`). |
| `MONGODB_URI` | **Yes** | MongoDB Atlas or local connection URI. |
| `REDIS_URI` | No | Redis connection URI. An in-memory Map is used when empty. |
| `JWT_SECRET` | **Yes** | Secret used to sign user session tokens. |
| `INGEST_API_KEY` | **Yes** | Key used by the Bridge and hardware to access `/api/sensors/ingest`. |
| `ALLOWED_ORIGINS` | No | Comma-separated list of CORS-allowed origins. |
| `HEARTBEAT_TIMEOUT_MS`| No (default: 60000) | Time after which a node is considered offline. |
| `CARTO_API_KEY` | No | CARTO vector basemap API key. |
| `FIREBASE_PROJECT_ID` | No | Firebase Admin SDK project ID (for FCM). |
| `FIREBASE_CLIENT_EMAIL`| No | Firebase service-account email. |
| `FIREBASE_PRIVATE_KEY` | No | Firebase service-account RSA private key. |
| `BACKEND_HOST` | No (Bridge only) | Backend host for `bridge.js` (default: localhost). |
| `BACKEND_PORT` | No (Bridge only) | Backend port for `bridge.js` (default: 5000). |
| `NODE_POSITIONS_JSON` | No | JSON string to override the locations of five nodes without code changes. |

### 7.3. Step-by-Step Startup Commands

#### 1. Starting the Backend Server
```bash
cd backend        # (from the repository root)
npm install
npm run dev
```
*Expected output:*
```text
✅ MongoDB connected: ...
ℹ️ Redis URI is not configured; in-memory Map cache is active.
🚀 ASSET Backend API is running: http://localhost:5000
```

#### 2. Uploading and Connecting the ASSET 2.1 BLE Hub
1. Connect the Deneyap Kart 1A v2 over USB.
2. Open `iot/asset_hub_ble/asset_hub_ble.ino` in Arduino IDE.
3. Select board `Deneyap Kart 1A v2` and port `/dev/ttyUSB1` (or the applicable port), then upload.
4. When the upload is complete, **close** the serial monitor.

#### 3. Starting the PC Bridge Service
```bash
cd backend      # (from the repository root)
# With automatic port detection:
node bridge/bridge.js

# Or specify a port:
node bridge/bridge.js --port=/dev/ttyUSB1 --baud=115200

# To start a virtual stream (mock) without hardware:
node bridge/bridge.js --mock
```

#### 4. Programming and Running the Sensor Nodes
1. For Node #1, set `#define NODE_DEVICE_ID 1` in `iot/asset_node_ble/asset_node_ble.ino` and upload it to the board.
2. For Node #2, set `#define NODE_DEVICE_ID 2` in `iot/asset_node2_ble/asset_node2_ble.ino` and upload it to the board.
3. Power the boards from batteries. The Hub will capture BLE packets, and transmission logs will appear in the terminal.

#### 5. Starting the Cloudflare Tunnel (Internet Access)
```bash
cloudflared tunnel run <tunel-adiniz>
# Or use a quick tunnel:
cloudflared tunnel --url http://localhost:5000
```

#### 6. Test and Simulation Commands
To trigger external tests while the backend is running:
```bash
# Fire-consensus test:
curl -X POST http://localhost:5000/api/sensors/simulate-scenario \
  -H "Content-Type: application/json" \
  -d '{"scenario":"consensus_fire"}'

# Single-warning test (the drone does not take off; yellow warning):
curl -X POST http://localhost:5000/api/sensors/simulate-scenario \
  -H "Content-Type: application/json" \
  -d '{"scenario":"single_warning"}'

# Return to normal:
curl -X POST http://localhost:5000/api/sensors/simulate-scenario \
  -H "Content-Type: application/json" \
  -d '{"scenario":"normal"}'

# Health check:
curl http://localhost:5000/api/health
```

---

## 8. PROJECT STATUS TABLE

| Module / Feature | Status | Related File Path | Notes |
| :--- | :---: | :--- | :--- |
| **ASSET 2.0 Node BLE Beacon** | **Complete** | `iot/asset_node_ble/asset_node_ble.ino` | 13-byte struct, CRC8, 5-second broadcast, and active-low MOSFET alarm are operational. |
| **ASSET 2.1 BLE Central Hub** | **Complete** | `iot/asset_hub_ble/asset_hub_ble.ino` | Continuous scanning, CRC8 validation, and USB serial JSON output are operational. |
| **PC Serial Bridge** | **Complete** | `backend/bridge/bridge.js` | Auto-detection, CRC8, Ingest API forwarding, and mock mode are operational. |
| **Sensor Fusion Engine** | **Complete** | `backend/src/services/fusionEngine.js` | Smoke + $\Delta T/\Delta t$ + $\Delta H$ node fusion and zone consensus are operational. |
| **Dynamic Threshold Management** | **Complete** | `backend/src/models/ThresholdConfig.js` | Runtime updates through REST API and Socket.io are operational. |
| **Tactical NOC Dashboard** | **Complete** | `backend/public/admin.html` | CARTO vector map, Chart.js, and live socket indicators are operational. |
| **Public Portal and Authentication** | **Complete** | `backend/public/index.html` | Glassmorphism UI, onboarding cards, and JWT auth forms are ready. |
| **Cloudflare Tunnel Integration** | **Complete** | Cloudflare Tunnel configuration file (`config.yml`) | Live at `<panel-subdomain>.<your-domain>.com` and `<api-subdomain>.<your-domain>.com` (real addresses replaced with generic examples). |
| **Threshold Sync to Battery-Powered Nodes** | **Incomplete** | `iot/asset_node_ble/asset_node_ble.ino` | A node cannot receive backend thresholds wirelessly while disconnected from USB (it remains at the default 1000). |
| **Physical Drone (UAV) Integration**| **Cancelled** | `backend/public/admin.html:978` | The physical drone was removed; only a visual animation remains in the dashboard. |
| **FCM Push Notifications** | **Incomplete** | `backend/src/services/notificationService.js` | Infrastructure exists but remains inactive until a Firebase service key is configured. |
| **Email and SMS Notifications** | **Not started** | `backend/src/services/notificationService.js` | Nodemailer or SMS integration has not been implemented. |
| **OGM / Alo 177 Integration** | **Not started** | *None* | No official-agency integration exists in the code. |
| **Flutter Mobile App** | **Legacy / Disabled** | `mobileApp/` | Retained for the v1 home prototype; not integrated with the v2 tactical sensor network. |

---

## 9. KNOWN ISSUES, RISKS, AND INCONSISTENCIES

### 9.1. Code and Documentation Inconsistencies
1. **Microcontroller chip:** `docs/KURULUM_REHBERI.md` identifies the board as *ESP32-WROOM-32*. The actual hardware and firmware are based on **Deneyap Kart 1A v2 (ESP32-S3)**.
2. **D1 pin logic conflict:** The legacy guide and firmware define `D1` as a *water relay (active HIGH)*, while the current ASSET 2.0 diagram uses `D1` as the *IRF5210 P-channel MOSFET gate (active LOW)* to drive the buzzer/LED.
3. **Architecture change:** `docs/KURULUM_REHBERI.md` and `docs/AR-GE_Raporu.md` describe a Wi-Fi + relay-based home detector. The codebase has since evolved into a BLE beacon + Hub + Bridge + web NOC map.

### 9.2. In-Code Risks and Open Items
1. **Hardcoded API keys (hardcoded secrets):**
   - `backend/src/controllers/sensorController.js:67`: `<INGEST_API_KEY>` is embedded in the code as a fallback master key.
   - `backend/bridge/bridge.js:23`: The same key is embedded in the Bridge. If `.env` is absent, this key can bypass authorization.
2. **Authorization issue in `scripts/simulate_scenarios.js`:**
   - The script does not add `x-api-key` to HTTP headers in `sendPacket()`. Since `INGEST_API_KEY` is required by the backend, running the script directly results in `401 Unauthorized`.
3. **`readBatteryPct()` on battery-powered nodes:**
   - `asset_node_ble.ino:76`: Actual voltage is not measured; the code always returns `95`. The dashboard continues to show 95% even when the batteries are depleted.
4. **TODO / incomplete code:**
   - `mobileApp/lib/features/auth/screens/register_screen.dart:23`: Contains the comment `// TODO: backend integration`.
5. **DHT11 sensor accuracy:**
   - In open terrain, the DHT11's humidity accuracy (%$\pm5$) and response time (6–10 seconds) may be too slow to detect rapid changes at the start of a forest fire compared with a DHT22 or industrial sensor.

---

## 10. GIT HISTORY AND WORKING TREE SUMMARY

### 10.1. Branches
* `main` (active local branch)
* `remotes/origin/main` (remote GitHub branch)

### 10.2. Recent Commits
* `5b68058 (HEAD -> main, origin/main)`: *asset-v1-latest*
* `c5e7980`: *asset-v1-latest*
* `296f398`: *asset-v1*
* `68e199f`: *asset-v1*
* `832f3bf`: *Initialize repository with comprehensive .gitignore*

### 10.3. Untracked and Changed Critical Components in the Working Tree
The Git commit history ends at the v1 stage; the project's transition to v2 (`bridge/`, `fusionEngine.js`, `ThresholdConfig.js`, `admin.html`, `asset_node_ble/`, `asset_hub_ble/`) was made in the local working tree and is awaiting a commit.

---

## 11. NEXT STEPS AND PRIORITIES

### Priority 1: Wireless Threshold Synchronization to Battery-Powered Nodes
* **Issue:** Battery-powered nodes cannot receive smoke-threshold changes from the backend.
* **Solution:** The Hub should periodically broadcast the backend threshold in BLE advertising data (or use ESP-NOW / a BLE GATT connection), and nodes should wake up and save the threshold to persistent NVS storage.

### Priority 2: Actual Battery Voltage Measurement
* Update `readBatteryPct()` in `asset_node_ble.ino` to read the actual Li-ion voltage curve (3.0 V = 0%, 4.2 V = 100%) from a 10k:10k voltage divider connected to the Deneyap Kart's `A1` analog pin.

### Priority 3: Field Testing and Sensor Calibration
* Determine the MQ-2's baseline clean-air ADC reading in the workshop; adjust `ThresholdConfig.smokeThreshold` for sunlight and wind conditions.

### Priority 4: Add Real Notification Channels
* Add `nodemailer` for email notifications and integrate a commercial SMS provider for SMS or emergency-call notifications in `notificationService.js`.

### Priority 5: Codebase Cleanup
* Move the obsolete v1 Wi-Fi files (`iot/asset_firmware/`) and Flutter mobile app (`mobileApp/`) into a separate `legacy/` or `archive/` directory to avoid confusion.
* **✔ COMPLETED (October 17, 2026):** v1 sources have been moved to the external archive directory (`archive/asset-v1-eski-nesil/`); see Section 3 for the current tree.

---

## 12. QUICK START FOR NEW CONTRIBUTORS (WHERE TO START IN 10 MINUTES)

If you are opening the project for the first time or returning after a long break, follow these steps in order:

1. **Understand the repository structure (Minute 1):**
   * Do not use the Flutter mobile app or `asset_firmware.ino`; they belong to the legacy home prototype.
   * Current architecture: `iot/asset_node_ble` (sensor) $\rightarrow$ `iot/asset_hub_ble` (collector) $\rightarrow$ `backend/bridge/bridge.js` $\rightarrow$ `backend/` (Express) $\rightarrow$ `admin.html` (map).

2. **Start the backend (Minute 3):**
   ```bash
   cd backend
   npm install
   npm run dev
   ```
   Look for `MongoDB connected` and `ASSET Backend API is running: http://localhost:5000` in the console.

3. **Open the tactical command panel (Minute 4):**
   * Go to `http://localhost:5000/admin` in your browser.
   * You should see a Leaflet map, five nodes, and Drone Hangar Alpha.

4. **Monitor the system live with a simulation (Minute 6):**
   * If no hardware is connected, click the blue **"🔥 Consensus Fire (Drone Takes Off)"** button below the map.
   * Observe Node 1 and Node 2 smoke readings rise above 1500, the cards turn red, the red fire banner appears, and the simulated drone flies from the hangar to the zone.
   * Click **"Return to Normal"** to reset the system.

5. **Connect real hardware (Minute 10):**
   * Connect the Deneyap Hub board over USB.
   * Run `node bridge/bridge.js` in a separate terminal. The port will be detected automatically, and real smoke/temperature packets received over BLE will stream to the map.

---

## 📌 SUMMARY OF ITEMS MARKED "UNCERTAIN" IN THIS DOCUMENT

1. **Threshold synchronization for battery-powered nodes:** The code has no channel (GATT or ESP-NOW) for nodes to receive backend threshold updates wirelessly while battery-powered; field threshold updates remain undefined.
2. **`forestRegion` model:** The `forestRegion` data structure mentioned in the project requirements does not exist in the codebase; `zoneId` is used instead.
3. **OGM / Alo 177 integration:** The codebase has no API, SMS, or webhook integration for the General Directorate of Forestry or Alo 177 (this remains a conceptual goal only).
4. **Actual battery-voltage curve:** `readBatteryPct()` in `asset_node_ble.ino` does not perform a hardware measurement and returns a fixed 95%. Calibration of the actual hardware voltage divider remains undefined.
