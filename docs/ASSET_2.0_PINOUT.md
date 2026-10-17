# 🔌 ASSET 2.0 Sensor Node — Pinout and Hardware Wiring Diagram

This document describes the circuit connections, pin assignments, and hardware-driving logic of the **ASSET 2.0 (Sensor Node)** prototype.

---

## 1. Bill of Materials (BOM)

| # | Component | Model / Specification | Function |
|---|---|---|---|
| **1** | **Microcontroller** | Deneyap Kart 1A (ESP32 architecture) | BLE advertising, sensor readings, and alarm control |
| **2** | **Gas/Smoke Sensor** | MQ-2 sensor module | Smoke and flammable-gas detection (analog reading) |
| **3** | **Temperature and Humidity Sensor** | DHT11 (4-pin package) | Ambient temperature rise (&Delta;T) and humidity drop (&Delta;H) |
| **4** | **P-Channel Power MOSFET** | IRF5210 (TO-220, 3-pin) | Switching the buzzer and LED load (high-side switch) |
| **5** | **Visual Indicator** | 5 mm red LED (+ 220&Omega;–330&Omega; resistor) | Local visual fire/hazard warning |
| **6** | **Audible Indicator** | 5 V / 3.3 V active buzzer | Local high-decibel audible siren |
| **7** | **Resistors** | 10k&Omega; (2), 220&Omega;–330&Omega; (1) | DHT11 pull-up, MOSFET gate pull-up, and LED current limiting |

---

## 2. Pin Layouts (Pinout Guide)

### A. IRF5210 (TO-220 Package — Front View, Marked Side Facing You)
```
     +---------------+
     |   [ O ] TAB   |  <-- Metal heat sink tab (connected to Drain)
     +---------------+
     |  IRF5210      |
     |  P-CHANNEL    |
     +---------------+
       |     |     |
       1     2     3
     Gate  Drain Source
```
* **Pin 1 (Gate - G):** Control pin (connect to Deneyap Kart `D1`; pull up to the Source line with a 10k&Omega; resistor).
* **Pin 2 (Drain - D):** Output pin (connects to the positive supply inputs of the loads: LED anode and buzzer +).
* **Pin 3 (Source - S):** Positive power input (connect directly to the `3.3V` supply line).

### B. DHT11 (4-Pin Package — Front Grille Facing You, Left to Right)
```
     +---------------+
     |  |||||||||||  |
     |  DHT11 SENSOR |
     +---------------+
       |   |   |   |
       1   2   3   4
      VCC DATA NC GND
```
* **Pin 1 (VCC):** 3.3 V supply
* **Pin 2 (DATA):** Deneyap Kart `D4` pin (connect to VCC through a 10k&Omega; pull-up resistor)
* **Pin 3 (NC):** Unconnected (no connection)
* **Pin 4 (GND):** Common ground (GND)

---

## 3. Complete Pin Connection Table

| Component | Component Pin | Deneyap Kart 1A Pin | Description / Inline Component |
|---|---|---|---|
| **MQ-2** | **VCC** | **5V** | A 5 V supply is required for the sensor's internal heater. |
| **MQ-2** | **GND** | **GND** | Common ground line. |
| **MQ-2** | **A0 (Analog Out)** | **A0** | ADC reading pin, 0–4095. |
| **MQ-2** | **D0 (Digital Out)** | *UNCONNECTED* | Not used (the threshold is set in software). |
| **DHT11** | **Pin 1 (VCC)** | **3.3V** | Positive supply. |
| **DHT11** | **Pin 2 (DATA)** | **D4** | Data pin (10k&Omega; pull-up resistor to VCC). |
| **DHT11** | **Pin 3 (NC)** | *UNCONNECTED* | Unused pin. |
| **DHT11** | **Pin 4 (GND)** | **GND** | Common ground line. |
| **IRF5210** | **Pin 1 (Gate)** | **D1** | Control pin (10k&Omega; pull-up resistor to the 3.3 V Source line). |
| **IRF5210** | **Pin 3 (Source)** | **3.3V** | Positive supply input. |
| **IRF5210** | **Pin 2 (Drain)** | **Load Output** | Switched positive supply line. |
| **Red LED** | **Anode (+)** | **IRF5210 Drain** | Through a 220&Omega;–330&Omega; series current-limiting resistor. |
| **Red LED** | **Cathode (-)** | **GND** | Common ground line. |
| **Active Buzzer**| **VCC (+)** | **IRF5210 Drain** | Connect directly to the MOSFET Drain output. |
| **Active Buzzer**| **GND (-)** | **GND** | Common ground line. |

---

## 4. Block and Circuit Diagram

```
                       DENEYAP KART 1A
                     +-----------------+
                     |                 |
  [MQ-2 VCC] <------ | 5V              |
                     |                 |
  [DHT11 Pin 1] <--- | 3.3V            | ---> [IRF5210 Source (Pin 3)]
                     |                 |        |
  [MQ-2 GND]   <---> | GND             |        +---[ 10kΩ Pull-up ]---+
  [DHT11 Pin 4]<---> |                 |                               |
  [Buzzer (-)] <---> |                 |                               v
  [LED Cathode] <---> |                |                     [IRF5210 Gate (Pin 1)] <--- D1 (Alarm Pin)
                     |                 |
  [MQ-2 AO]   -----> | A0              |                     [IRF5210 Drain (Pin 2)] (Switched Output)
                     |                 |                               |
  [DHT11 Pin 2] <--> | D4              |                               +-------------------+
                     +-----------------+                               |                   |
                       ^          |                                    v                   v
                       |          |                               [220Ω Resistor]    [Active Buzzer (+)]
                       +-[10kΩ]---+                                    |                   |
                        (Pull-up)                                      v                   v
                                                                 [ LED Anode (+) ]         |
                                                                       |                   |
                                                                 [ LED Cathode (-) ] [ Buzzer GND (-) ]
                                                                       |                   |
                                                                       v                   v
                                                                    ( GND )             ( GND )
```

---

## 5. P-Channel MOSFET (IRF5210) Operation and Drive Logic

The IRF5210 is a **P-channel power MOSFET** and operates as a **high-side switch** on the positive supply line:

1. **Gate = HIGH (3.3V):**
   - $V_{GS} = V_{Gate} - V_{Source} = 3.3V - 3.3V = 0V$.
   - The MOSFET is cut off (**OFF**).
   - There is no voltage at the Drain output; the **LED is OFF and the buzzer is SILENT**.
2. **Gate = LOW (0V - GND):**
   - $V_{GS} = 0V - 3.3V = -3.3V$.
   - The MOSFET is fully conducting (**ON**).
   - 3.3 V is supplied at the Drain output; the **LED LIGHTS and the BUZZER SOUNDS**.

> [!IMPORTANT]
> **Inverted logic (active-low trigger):**
> In the firmware, keep `D1` **HIGH** when no alarm is active. When a fire or warning is detected, set `D1` **LOW** to trigger the alarm:
> ```cpp
> #define ALARM_PIN D1
>
> void setup() {
>   pinMode(ALARM_PIN, OUTPUT);
>   digitalWrite(ALARM_PIN, HIGH); // Silent at startup (MOSFET OFF)
> }
>
> void triggerAlarm(bool active) {
>   if (active) {
>     digitalWrite(ALARM_PIN, LOW);  // Alarm active (MOSFET ON -> LED and buzzer ON)
>   } else {
>     digitalWrite(ALARM_PIN, HIGH); // Alarm inactive (MOSFET OFF)
>   }
> }
> ```

---

## 6. Safety and Assembly Tips

1. **MQ-2 warm-up time:** Allow 20–30 seconds for stabilization after powering the board so the MQ-2's internal nichrome-wire heater can produce accurate readings.
2. **Common ground:** Connect all GND pins of the Deneyap Kart, MQ-2, DHT11, buzzer, and LED cathode to the **same rail (the breadboard's blue rail)**.
3. **Active buzzer polarity:** Active buzzers usually have a `+` mark or a longer lead. They will not sound if connected with reversed polarity.
4. **10k&Omega; pull-up resistors:**
   - A 10k&Omega; resistor between DHT11 Pin 2 and Pin 1 is required for signal stability.
   - A 10k&Omega; resistor between IRF5210 Pin 1 (Gate) and Pin 3 (Source) prevents the buzzer from sounding due to parasitic signals during board startup or reset.
