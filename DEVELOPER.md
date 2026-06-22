# CYD-Flock-You — Developer Documentation

Technical documentation for building, modifying, and extending the CYD-Flock-You firmware.

---

## Architecture Overview

The CYD-Flock-You firmware runs on an ESP32-2432S028R (Cheap Yellow Display) and performs passive WiFi and BLE monitoring for Flock Safety camera signatures. It communicates with the FlockFree Navigation Android app over Bluetooth LE.

### Core Modules

```
src/
├── main.cpp                    # Entry point, WiFi/BLE scanning, detection logic, display
├── display.cpp / display.h     # TFT rendering, screen cycling, FLOCK FOUND flash
├── ble_uart.cpp / ble_uart.h   # BLE Nordic UART service, JSON line protocol
├── sd_log.cpp / sd_log.h       # SD card CSV logging
├── touch.cpp / touch.h         # XPT2046 touchscreen driver
└── gps.cpp / gps.h             # GPS parsing from phone BLE input
```

### Detection Pipeline

```
WiFi promiscuous mode
    ↓
Frame parsed (probe/beacon)
    ↓
OUI match against known Flock list
    ↓
SSID keyword check (flock, flck, test_flck)
    ↓
Detection event created
    ↓
├── SD card CSV log
├── BLE JSON to phone
├── TFT display update
├── Buzzer chirp
└── Full-screen red FLOCK FOUND flash
```

### BLE Detection Pipeline

```
BLE active scan (continuous)
    ↓
Advertise payload parsed
    ↓
Manufacturer data match (0x09c8 XUNTONG)
    ↓
Device name pattern match (Penguin-##########)
    ↓
Battery level extraction (FS Ext Battery, 10-digit names)
    ↓
Detection event via existing JSON path
```

## Build Environment

### PlatformIO

The project uses PlatformIO for building. Configuration is in `platformio.ini`:

```ini
[env:cyd]
platform = espressif32
board = esp32dev
framework = arduino
build_flags = ...
```

### Build

```bash
pio run -e cyd
```

### Flash

Connect the CYD via USB:

```bash
pio run -e cyd -t upload
```

### Serial Monitor

```bash
pio device monitor -e cyd
```

### Build Artifacts

| File | Location | Purpose |
|------|----------|---------|
| `firmware.bin` | `.pio/build/cyd/firmware.bin` | Flashable binary (use with `esptool.py`) |
| `firmware.elf` | `.pio/build/cyd/firmware.elf` | ELF with debug symbols |
| `firmware.map` | `.pio/build/cyd/firmware.map` | Memory map |

### Flash with esptool (alternative)

```bash
esptool.py --port /dev/ttyUSB0 write_flash 0x10000 firmware.bin
```

## Hardware Reference

### ESP32-2432S028R Pin Map

| Pin | Function |
|-----|----------|
| GPIO 4 | Red RGB LED (detection feedback, active low) |
| GPIO 5 | SD card CS |
| GPIO 12 | TFT MISO |
| GPIO 13 | TFT MOSI |
| GPIO 14 | TFT SCLK |
| GPIO 15 | TFT CS |
| GPIO 2 | TFT DC |
| GPIO 21 | TFT backlight |
| GPIO 26 | Piezo buzzer |
| GPIO 0 | Boot button / display control |
| GPIO 25 | XPT2046 touch CLK |
| GPIO 32 | XPT2046 touch MOSI |
| GPIO 39 | XPT2046 touch MISO |
| GPIO 33 | XPT2046 touch CS |
| GPIO 36 | XPT2046 touch IRQ |

### TFT Configuration

- Driver: ILI9341_2_DRIVER
- Dimensions: 240×320 (native), rotated to 320×240 landscape at runtime
- Rotation: `CYD_TFT_ROTATION=1`
- SPI bus: HSPI
- Touch controller: XPT2046 on separate SPI bus

### Memory Usage (v1.3.0)

- Flash: 51.6% used (1,590,173 / 3,080,192 bytes)
- RAM: 24.3% used (79,656 / 327,680 bytes)

## BLE Protocol

See [docs/deflock-pairing-protocol.md](docs/deflock-pairing-protocol.md) for the full protocol specification.

### Quick Reference

| Parameter | Value |
|-----------|-------|
| Peripheral name | `CYD-Flock-You` |
| Service UUID | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` |
| RX (write) UUID | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` |
| TX (notify) UUID | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` |
| Line format | Newline-delimited text |
| Protocol version | 1 |

### Serial Commands

| Command | Description |
|---------|-------------|
| `FYHELLO` | Returns pairing/status JSON |
| `FYSTATUS` | Returns full telemetry JSON |
| `FYGPS,lat,lon,acc,speed,course,sats,hdop,unix_time,offset` | Phone GPS input |
| `FYSIM` | Simulate a detection for testing |
| `FYSCREEN,next` | Cycle to next display screen |
| `FYTOUCH` | Report raw touch diagnostic values |

## Detection Methods

### WiFi Detection

| Method | Description |
|--------|-------------|
| `wifi_wildcard_probe` | Probe request with wildcard SSID from a known OUI |
| `wifi_oui_addr2` | Transmitter address OUI match |
| `wifi_oui_addr1` | Receiver-side OUI match (quiet/sleeping infrastructure) |
| `wifi_oui_addr3` | BSSID OUI match (disabled by default) |
| `wifi_ssid` | SSID keyword match (flock, flck, test_flck) |
| `wifi_hidden_ssid` | Hidden beacon/probe-response from a known OUI |

### BLE Detection

| Method | Description |
|--------|-------------|
| Penguin name match | Device name matches `Penguin-` + 10 digits |
| Manufacturer data | XUNTONG manufacturer ID `0x09c8` in advertising data |
| FS Ext Battery | Battery-level devices with `FS Ext Battery` name pattern |
| 10-digit battery | 10-digit numeric device names from known OUIs |

### OUI List

Target OUI list: [`datasets/NitekryDPaul_wifi_ouis.md`](datasets/NitekryDPaul_wifi_ouis.md)

## Display System

### Screens

1. **Scan screen** — FF badge, current channel, hit count, GPS/SD/BLE status, local time
2. **GPS screen** — Latest GPS fix details (from phone)
3. **CSV Log screen** — SD card logging status and row count
4. **Last Detection screen** — Most recent detection details

### Controls

| Control | Action |
|---------|--------|
| Touchscreen tap | Cycle to next display screen |
| Boot button press (GPIO 0) | Rotate screen orientation |
| Touchscreen tap (during FLOCK FOUND) | Dismiss the alert flash |

### FLOCK FOUND Alert

On detection, the display flashes a full-screen red **FLOCK FOUND** alert. Tap the touchscreen to dismiss.

## CSV Log Format

When SD is available, detections append to `/flock.csv`:

```
millis,mac,oui,method,rssi,channel,frequency_mhz,lat,lon,accuracy_m,gps_age_ms,speed_kmph,course_deg,count
```

## Companion App Integration

### FlockFree Navigation (OsmAnd fork)

- Repo: [yetisoldier/FlockFree-Navigation](https://github.com/yetisoldier/FlockFree-Navigation)
- Connects over BLE, streams GPS, receives detection events
- CYD auto-pauses when FlockFree detects Flock WiFi beacon
- Detection markers appear on map for manual review

### DeFlock (Flutter app, CYD branch)

- Repo: [yetisoldier/deflock-app](https://github.com/yetisoldier/deflock-app), branch `cyd-flock-you-integration`
- Connects over BLE using `flutter_blue_plus`
- Same Nordic UART protocol
- Detection review flow with OSM upload

## Extending the Firmware

### Adding a New Detection Method

1. Add the method name to the detection method enum/strings in `main.cpp`
2. Implement the detection logic in the appropriate scan callback
3. Emit a detection JSON via `ble_uart_send_detection()`
4. Log to SD via `sd_log_append()`
5. Update the TFT display and trigger buzzer/LED/flash

### Adding a New Display Screen

1. Add the screen to the screen enum in `display.h`
2. Implement the render function in `display.cpp`
3. Add it to the screen cycle in the touch handler
4. Update the `FYSCREEN,next` command to include it

### Adding a New BLE Command

1. Parse the command in `ble_uart.cpp` command handler
2. Implement the response logic
3. Document the command in the serial commands table and README

## Credits and Upstream

- Firmware fork: [colonelpanichacks/flock-you](https://github.com/colonelpanichacks/flock-you)
- Wi-Fi OUI research: ØяĐöØцяöЪöяцฐ / @NitekryDPaul
- BLE manufacturer ID work: [wgreenberg/flock-you](https://github.com/wgreenberg/flock-you)
- Wildcard probe signature: [DeflockJoplin/flock-you](https://github.com/DeflockJoplin/flock-you)

## Disclaimer

This is a passive research and privacy-auditing tool. It does not transmit Wi-Fi, authenticate to networks, or bypass access controls. Wireless reception and public infrastructure mapping laws vary by jurisdiction. Use responsibly.