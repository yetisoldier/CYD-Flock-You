# CYD Flock-You Current State

Last updated: 2026-06-18 11:05 CDT

This note captures the working state of the CYD Flock-You firmware and its DeFlock Android companion path so the project can be resumed without reconstructing the whole field session.

## Repositories

- Firmware: `yetisoldier/CYD-Flock-You`
- Android companion: `yetisoldier/deflock-app`, branch `cyd-flock-you-integration`
- Upstream firmware base: `colonelpanichacks/flock-you`
- Upstream app base: `FoggedLens/deflock-app`

## Hardware Target

Primary target is the ESP32-2432S028R Cheap Yellow Display.

Important firmware assumptions:

- PlatformIO environment: `cyd`
- Board profile: `esp32dev`
- TFT driver: `ILI9341_2_DRIVER`
- TFT base dimensions: `TFT_WIDTH=240`, `TFT_HEIGHT=320`
- Runtime rotation: `CYD_TFT_ROTATION=1`
- Logical UI canvas: `320x240`
- TFT inversion: `TFT_INVERSION_ON` plus `tft.invertDisplay(true)`
- SPI bus: HSPI
- Backlight: GPIO 21
- SD card CS: GPIO 5
- Red LED feedback: GPIO 4, active low
- Piezo buzzer: GPIO 26
- Screen cycle button: GPIO 0

Current field setup powers the CYD separately. The Moto test phone did not reliably enumerate or power the CYD over USB OTG, so Bluetooth LE UART is the primary app transport.

## Firmware Features

The `cyd` target currently includes:

- Passive Wi-Fi promiscuous-mode sniffing.
- Full channel hop across channels 1-11.
- `CHANNEL_DWELL_MS=400` for CYD.
- `RSSI_MIN=-95`.
- Lock-free alert queue from Wi-Fi callback into the main loop.
- SPIFFS session persistence for the in-memory detection table.
- SD CSV append logging to `/flock.csv`.
- FlockFree-styled TFT status UI with a dark navy/cyan/red field dashboard and FF badge.
- Button-driven screen cycle: scan, GPS, CSV log, last detection.
- Visual hit state: `SCAN` changes to `HIT` for 15 seconds.
- Buzzer chirps and red LED flash on hits.
- Bluetooth LE UART using Nordic UART UUIDs.
- Phone GPS ingestion through `FYGPS`.
- Bench simulation through `FYSIM`.
- Status diagnostics in `pair_status`: GPS, SD, detection count, CSV rows, scan mode, current channel, received frames, management/data frame counts, and queue drops.

## Detection Methods

The firmware emits these method names in JSON and CSV:

- `wildcard_probe`: known OUI transmitter sending a probe request with wildcard/blank SSID.
- `oui_addr2`: known OUI in transmitter/source address.
- `oui_addr1`: known OUI in receiver/destination address.
- `oui_addr3`: known OUI in BSSID address, currently disabled by `CHECK_ADDR3=0`.
- `ssid`: SSID keyword hit using `flock`, `flck`, or `test_flck`.
- `hidden_ssid`: beacon/probe response from a known OUI with hidden/wildcard SSID.

The target OUI list is in `main.cpp`; the research provenance is in `datasets/NitekryDPaul_wifi_ouis.md`.

## Bluetooth Protocol

BLE peripheral:

- Name: `CYD-Flock-You`
- Service: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- RX/write: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- TX/notify: `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`
- Wire format: newline-delimited text
- BLE notification chunk size: 20 bytes
- RX queue: 8 lines
- RX line size: 180 bytes

Commands:

```text
FYHELLO
FYSTATUS
FYGPS,<lat>,<lon>,<accuracy_m>,<speed_kmph>,<course_deg>,<sats>,<hdop>,<unix_time>,<utc_offset_min>
FYSIM
FYSCREEN,next
```

The older 7-field `FYGPS` format is still accepted, but the Android branch now sends epoch seconds and UTC offset so the CYD can show local time.

## Android Companion State

The companion app branch currently includes:

- `CydBluetoothService` using `flutter_blue_plus`.
- BLE scan for the Nordic UART service and `CYD-Flock-You` device.
- `FYHELLO` on connect.
- `FYGPS` once per second from phone location while connected.
- `FYSIM` button when connected.
- JSON line parsing into pair status and detection models.
- `CydCandidateService` duplicate suppression within 76.2 meters / 250 feet.
- Pending CYD candidate queue.
- Handoff into the normal DeFlock add-node flow.
- Required marker movement of at least 2 meters from the original phone GPS point.
- Required manual direction before upload.
- Follow-me smoothing for driving:
  - animation duration: 1200 milliseconds
  - minimum animation interval: 600 milliseconds
  - jitter floor: 4 meters
  - snap distance: 140 meters
  - slow alpha: 0.18
  - city driving alpha: 0.36
  - fast driving alpha: 0.52
  - heading alpha: 0.18
- Follow-me surveillance refresh throttling: 8 seconds or 250 meters.

Raw GPS still streams to the CYD; smoothing only affects map camera movement.

## Verified On 2026-06-17

Verified locally:

- `pio run -e cyd`
- Firmware flash to CYD.
- `FYHELLO` status over serial.
- SD status `sd:true` with a mounted card.
- Bluetooth LE connection from Android.
- Android GATT writes succeeded.
- Phone GPS streaming made CYD report fresh GPS.
- `FYSIM` produced a synthetic detection.
- Synthetic detection incremented CYD/app counters and opened the DeFlock review flow.
- Android debug APK built and installed on a Moto G Stylus.
- `flutter analyze`
- `flutter test`
- `flutter build apk --debug`

Field observation:

- An early drive past known cameras missed hits because the phone was not connected to the CYD at that time.
- Later bench/live checks confirmed the app showed the connected `Disconnect CYD` state.
- Map follow-me movement was jerky with raw GPS, so camera smoothing was added.
- Repeated surveillance data loading during driving is expected when the viewport moves far enough to trigger map data refresh.

## Known Limitations

- Real detection depends on RF behavior from nearby hardware, vehicle speed, antenna placement, and channel dwell.
- A bench `FYSIM` hit proves the data path, not real-world detection.
- BLE and Wi-Fi share the ESP32 2.4 GHz radio, so the design avoids adding BLE scanning or other heavy concurrent radio work.
- The candidate starts at the vehicle/phone position and must be moved manually.
- Direction is not inferred from vehicle travel.
- The app branch is not upstream DeFlock.
- The CYD should be separately powered during field work.

## Recovery Commands

Firmware:

```bash
cd /home/yetisoldier/projects/CYD-Flock-You
pio run -e cyd
pio run -e cyd -t upload
pio device monitor -e cyd
```

Android:

```bash
cd /home/yetisoldier/projects/deflock-cyd-app
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

Useful runtime checks:

```text
FYHELLO
FYSTATUS
FYSIM
```

## Next Work

- Run another drive test with the app already connected to the CYD.
- Compare `pair_status.rx_frames`, `rx_mgmt`, `rx_data`, and `queue_drops` before and after a drive past known cameras.
- If RX frame counts are high but hits stay zero, tune signature logic.
- If RX frame counts are low, tune placement, antenna/power, channel dwell, or route speed.
- Consider a richer candidate list UI if multiple CYD detections queue at once.
- Keep the workflow review-first and avoid blind OpenStreetMap edits.
