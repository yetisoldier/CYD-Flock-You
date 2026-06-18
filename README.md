# CYD Flock-You

Cheap Yellow Display firmware and DeFlock Android companion work for passive, human-reviewed Flock Safety / ALPR discovery.

This project turns an ESP32 Cheap Yellow Display (ESP32-2432S028R, usually called a CYD) into a field sensor that watches 2.4 GHz Wi-Fi traffic for known Flock-style RF signatures. The Android companion work connects over Bluetooth LE, streams phone GPS to the CYD, receives detections, and opens a review-first DeFlock workflow so a human can place and submit the camera location accurately.

## Repository Pair

This public beta is split across two repositories:

- CYD firmware: [`yetisoldier/CYD-Flock-You`](https://github.com/yetisoldier/CYD-Flock-You)
- Android companion branch: [`yetisoldier/deflock-app`, branch `cyd-flock-you-integration`](https://github.com/yetisoldier/deflock-app/tree/cyd-flock-you-integration)

Use this firmware with the companion Android branch above. Upstream DeFlock releases do not yet include the CYD Bluetooth workflow.

## Status

This is ready as a public beta, not as a polished consumer product.

Verified so far:

- CYD firmware builds and flashes with PlatformIO.
- CYD TFT status screen, button cycling, buzzer, LED, Bluetooth LE UART, SD CSV logging, and phone GPS intake are working on bench hardware.
- DeFlock Android companion branch connects to the CYD over Bluetooth LE, streams phone GPS, receives simulated CYD detections, creates pending review candidates, and opens the normal DeFlock add-node flow.
- Android map follow-me camera movement has visual smoothing so driving should be less jerky while raw GPS continues to stream unchanged to the CYD.

Still field-test territory:

- Real-world RF detection depends on nearby hardware behavior, antenna placement, vehicle speed, channel dwell, and local RF noise.
- A bench `FYSIM` detection verifies the data path, but it is not evidence of a real Flock hit.
- The Android companion work currently lives in a DeFlock fork/branch and is not upstream DeFlock.
- Use this as a research and review-assist tool. Do not blindly upload automated locations.

## Forks and Upstream Projects

This work stands on several existing projects and research efforts:

- Firmware fork: [`colonelpanichacks/flock-you`](https://github.com/colonelpanichacks/flock-you)
- Android app fork: [`FoggedLens/deflock-app`](https://github.com/FoggedLens/deflock-app)
- Wildcard probe signature and added OUI research: [`DeflockJoplin/flock-you`](https://github.com/DeflockJoplin/flock-you)
- BLE manufacturer ID work referenced by the upstream ecosystem: [`wgreenberg/flock-you`](https://github.com/wgreenberg/flock-you)
- DeFlock project and public map workflow: [deflock.me](https://deflock.me)

Additional credit belongs to ØяĐöØцяöЪöяцฐ / @NitekryDPaul for the original Wi-Fi OUI research and receiver-side `addr1` technique documented in [`datasets/NitekryDPaul_wifi_ouis.md`](datasets/NitekryDPaul_wifi_ouis.md).

## What Changed In This Fork

### CYD Firmware

The firmware adds a `cyd` PlatformIO target for ESP32-2432S028R boards.

Major changes:

- TFT_eSPI display support with a FlockFree-styled field status UI.
- Dark navy/cyan/red CYD scan screen with an FF badge, current channel, hit count, GPS state, SD state, Bluetooth state, local time, and latest captured location.
- Screen cycling with the CYD boot button.
- SD card CSV logging to `/flock.csv`.
- Bluetooth LE UART using the Nordic UART UUIDs.
- Phone GPS input through `FYGPS`.
- Pairing/status replies through `FYHELLO` and `FYSTATUS`.
- Indoor simulation command through `FYSIM`.
- Detection JSON output with GPS metadata when a fresh phone fix is available.
- Visual/audible hit feedback: screen changes from `SCAN` to `HIT`, buzzer chirps, and LED flashes.

The detector remains passive. It listens to 2.4 GHz Wi-Fi frames and does not transmit Wi-Fi, associate to networks, or upload anything by itself.

### Android Companion Work

The DeFlock app fork adds a CYD Bluetooth integration path.

Major changes:

- Bluetooth LE scan/connect to `CYD-Flock-You`.
- Nordic UART notification parsing for CYD JSON lines.
- Phone GPS streaming to CYD.
- CYD candidate queue for received detections.
- Duplicate suppression against known nearby surveillance nodes using a 250 foot / 76.2 meter radius.
- Review-first handoff into DeFlock's normal add-node sheet.
- Required manual adjustment away from the original phone GPS point before submission.
- Required manual camera direction selection.
- `FYSIM` button while connected for bench testing.
- Follow-me map smoothing for driving.

The app owns review and upload approval. The CYD is only a sensor.

## What To Expect

When the system is working:

- The CYD screen shows scan status and Bluetooth/GPS/SD state.
- The phone connects over Bluetooth and shows a CYD disconnect button.
- The phone sends GPS updates to the CYD roughly once per second.
- A CYD detection writes a row to `/flock.csv`, updates the CYD hit count, and sends a JSON event to the phone.
- The Android app either suppresses the event as a duplicate or creates a pending CYD candidate.
- Reviewing a candidate opens the normal DeFlock add-camera flow.

Expected limitations:

- The CYD needs separate power in the current field setup. USB OTG from the test phone was unreliable.
- BLE and Wi-Fi share the ESP32 2.4 GHz radio, so this favors a simple Wi-Fi sniffing plus BLE UART design rather than adding more concurrent radio work.
- GPS accuracy comes from the phone. The candidate starts at the vehicle location; the user must move it to the actual roadside camera.
- Direction is not inferred from travel direction. The user sets it manually.
- Detection can miss cameras. RF behavior is bursty, local, and hardware-dependent.

## Hardware

Primary target:

- Cheap Yellow Display / ESP32-2432S028R
- ESP32 with ILI9341 TFT
- microSD card recommended
- Separate USB power bank or other stable power source

CYD pin assumptions:

| Pin | Function |
| --- | --- |
| GPIO 4 | Red RGB LED detection feedback, active low |
| GPIO 5 | SD card CS |
| GPIO 12 | TFT MISO |
| GPIO 13 | TFT MOSI |
| GPIO 14 | TFT SCLK |
| GPIO 15 | TFT CS |
| GPIO 2 | TFT DC |
| GPIO 21 | TFT backlight |
| GPIO 26 | Piezo buzzer |
| GPIO 0 | Screen cycle button |

The older Seeed XIAO ESP32-S3 target from upstream remains in the tree, but the public beta work here is centered on the CYD target.

## Build And Flash The CYD

Install PlatformIO, then run:

```bash
pio run -e cyd
pio run -e cyd -t upload
```

Shortcut:

```bash
./scripts/flash-cyd.sh
```

Serial monitor:

```bash
pio device monitor -e cyd
```

Useful serial commands:

```text
FYHELLO
FYSTATUS
FYSIM
FYSCREEN,next
```

`FYHELLO` and `FYSTATUS` return a JSON `pair_status` line.

## Android Companion App

The Android integration lives in Eric's DeFlock app fork:

- Fork: [`yetisoldier/deflock-app`](https://github.com/yetisoldier/deflock-app)
- Branch: [`cyd-flock-you-integration`](https://github.com/yetisoldier/deflock-app/tree/cyd-flock-you-integration)
- Upstream: [`FoggedLens/deflock-app`](https://github.com/FoggedLens/deflock-app)

```text
git clone https://github.com/yetisoldier/deflock-app.git
cd deflock-app
git checkout cyd-flock-you-integration
```

Build locally:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Install to a connected Android device:

```bash
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

The Android device needs Bluetooth and precise location permission. For driving tests, enable follow-me mode in the app and keep the CYD powered separately.

## Field Use

1. Flash the CYD firmware.
2. Insert a microSD card if you want local CSV logging.
3. Power the CYD from a stable source.
4. Open the DeFlock Android companion build.
5. Tap the CYD Bluetooth button and connect to `CYD-Flock-You`.
6. Confirm the app shows a connected/disconnect state.
7. Drive normally with the phone providing GPS.
8. If the app shows a pending CYD candidate, review it.
9. Move the marker from the road/vehicle position to the actual camera location.
10. Set camera direction manually.
11. Submit through the normal DeFlock/OpenStreetMap review path only when you are confident.

Bench test without a real RF hit:

1. Connect the app to the CYD.
2. Tap the simulate button or send `FYSIM`.
3. Confirm a pending candidate appears.
4. Cancel the candidate after verifying the flow so it is not confused with a real observation.

## Bluetooth Protocol

The field integration uses Bluetooth LE UART because the test phone did not reliably power/enumerate the CYD over USB OTG.

- Peripheral name: `CYD-Flock-You`
- Service UUID: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- RX/write UUID: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- TX/notify UUID: `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`
- Line format: newline-delimited text

Pairing:

```text
FYHELLO
```

Typical status response:

```json
{"event":"pair_status","device":"CYD-Flock-You","protocol_version":1,"features":["wifi_promisc","phone_gps","sd_csv","tft_status","ble_uart"],"gps":true,"sd":true,"detections":0,"csv_rows":0}
```

Phone GPS input:

```text
FYGPS,<lat>,<lon>,<accuracy_m>,<speed_kmph>,<course_deg>,<sats>,<hdop>,<unix_time>,<utc_offset_min>
```

The shorter format without time fields is still accepted:

```text
FYGPS,<lat>,<lon>,<accuracy_m>,<speed_kmph>,<course_deg>,<sats>,<hdop>
```

Detection output:

```json
{"event":"detection","detection_method":"wifi_wildcard_probe","protocol":"wifi_2_4ghz","mac_address":"70:c9:4e:aa:bb:cc","oui":"70:c9:4e","device_name":"","rssi":-63,"channel":6,"frequency":2437,"ssid":"","gps":{"latitude":45.171234,"longitude":-93.225678,"accuracy":6.5,"age_ms":250,"source":"phone"}}
```

More detail is in [`docs/deflock-pairing-protocol.md`](docs/deflock-pairing-protocol.md).

For the latest build/test snapshot, hardware assumptions, and field lessons, see
[`docs/current-state.md`](docs/current-state.md).

## CSV Log

When SD is available, detections append to:

```text
/flock.csv
```

Columns:

```text
millis,mac,oui,method,rssi,channel,frequency_mhz,lat,lon,accuracy_m,gps_age_ms,speed_kmph,course_deg,count
```

## Detection Logic

The firmware keeps the upstream promiscuous-mode split:

```text
Wi-Fi callback -> lock-free alert queue -> loop drain -> detection table -> JSON/BLE/CSV/UI
```

The Wi-Fi callback stays lightweight. It does fast matching only and avoids serial printing, file I/O, and heap allocation.

Detection methods include:

- `wifi_wildcard_probe`: probe request with wildcard SSID from a known OUI.
- `wifi_oui_addr2`: transmitter address OUI match.
- `wifi_oui_addr1`: receiver-side OUI match, useful for quiet/sleeping infrastructure.
- `wifi_oui_addr3`: BSSID OUI match, disabled by default.
- `wifi_ssid`: SSID keyword match for Flock-style strings such as `flock`, `flck`, and `test_flck`.
- `wifi_hidden_ssid`: hidden beacon/probe-response from a known OUI.

The target OUI list and research credit are documented in [`datasets/NitekryDPaul_wifi_ouis.md`](datasets/NitekryDPaul_wifi_ouis.md).

## OpenStreetMap And Data Quality

This project is intentionally review-first.

The CYD does not submit to OpenStreetMap. The Android app should only create a candidate. The user is responsible for confirming:

- A camera is actually present.
- The location is moved from the vehicle path to the physical camera.
- The direction is set correctly.
- Existing nodes are not duplicated.
- Tags are appropriate for the device.

This keeps the workflow useful without turning RF observations into blind automated map edits.

## Release Checklist

Before tagging a public release:

- Build CYD firmware with `pio run -e cyd`.
- Flash and verify `FYHELLO` returns `sd:true` if an SD card is present.
- Build Android companion with `flutter analyze`, `flutter test`, and `flutter build apk --debug`.
- Pair app and CYD over BLE.
- Verify phone GPS makes CYD status report `gps:true`.
- Run one `FYSIM` candidate and cancel it afterward.
- Run at least one real drive test and compare CYD CSV, app candidate state, and known camera locations.

## Disclaimer

This is a passive research and privacy-auditing tool. It does not transmit Wi-Fi, authenticate to networks, or bypass access controls. Wireless reception and public infrastructure mapping laws vary by jurisdiction. Use responsibly, follow local law, and avoid submitting unverified data.
