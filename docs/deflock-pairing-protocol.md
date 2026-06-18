# DeFlock Pairing Protocol

CYD Flock-You is intentionally a detector, not an uploader. The Android app owns GPS, review, map adjustment, duplicate checks, and OpenStreetMap upload approval.

## Transport

The field integration uses Bluetooth LE UART because the Moto cannot reliably power the CYD over USB OTG. Power the CYD separately, then connect from DeFlock over BLE.

- BLE peripheral name: `CYD-Flock-You`
- BLE service UUID: `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`
- RX/write UUID: `6E400002-B5A3-F393-E0A9-E50E24DCCA9E`
- TX/notify UUID: `6E400003-B5A3-F393-E0A9-E50E24DCCA9E`
- Line format: newline-delimited text
- CYD output: JSON lines plus human-readable debug lines
- App input: simple command lines

The app should ignore non-JSON lines unless it is showing a raw debug console.

The DeFlock fork is using `flutter_blue_plus` on Android. It should scan for the Nordic UART service, connect to the CYD, enable notifications on TX, send `FYHELLO` to RX, then subscribe to newline-delimited output.

USB serial remains available at `115200` for flashing, bench monitoring, and debugging from a computer.

## Pairing

The app sends:

```text
FYHELLO
```

The CYD replies immediately, and also repeats this every 5 seconds:

```json
{"event":"pair_status","device":"CYD-Flock-You","protocol_version":1,"features":["wifi_promisc","phone_gps","sd_csv","tft_status","ble_uart"],"gps":false,"sd":true,"detections":0,"csv_rows":0}
```

Use `device == "CYD-Flock-You"` and `protocol_version == 1` as the pairing check.

Current firmware also includes diagnostic fields in `pair_status`:

```json
{"scan_mode":"full_hop","channel":6,"rx_frames":1000,"rx_mgmt":900,"rx_data":100,"queue_drops":0}
```

Use these during field testing:

- `rx_frames == 0`: the CYD is not receiving Wi-Fi frames.
- `rx_frames > 0` and no detections: RF is present, but signatures are not matching.
- `queue_drops > 0`: the Wi-Fi callback is producing alerts faster than the loop can drain them.

## Phone GPS Input

The app should stream the phone location once per second while paired:

```text
FYGPS,<lat>,<lon>,<accuracy_m>,<speed_kmph>,<course_deg>,<sats>,<hdop>
```

Example:

```text
FYGPS,45.171234,-93.225678,6.5,38.2,184.0,12,0.9
```

The current Android branch sends the extended format:

```text
FYGPS,<lat>,<lon>,<accuracy_m>,<speed_kmph>,<course_deg>,<sats>,<hdop>,<unix_time>,<utc_offset_min>
```

The CYD accepts both formats. The extended fields let the CYD show local time while keeping the older GPS-only protocol compatible.

The CYD treats GPS as fresh for 10 seconds. Fresh GPS is embedded into detection JSON and written to the SD CSV log.

The CYD also accepts raw NMEA lines starting with `$` for later compatibility, but the Flutter app should prefer `FYGPS`.

## Bench Test

For indoor testing where no Flock radio signatures are expected, send:

```text
FYSIM
```

The CYD emits one synthetic `event:"detection"` using the freshest phone GPS fix. This is only a transport/review-flow test hook; it is not evidence of a real RF hit.

## Detection Output

Detection JSON lines look like:

```json
{"event":"detection","detection_method":"wifi_wildcard_probe","protocol":"wifi_2_4ghz","mac_address":"70:c9:4e:aa:bb:cc","oui":"70:c9:4e","device_name":"","rssi":-63,"channel":6,"frequency":2437,"ssid":"","gps":{"latitude":45.171234,"longitude":-93.225678,"accuracy":6.5,"age_ms":250,"source":"phone"}}
```

The app should treat these as candidate observations, not submissions.

## DeFlock Candidate Flow

Recommended Android flow:

1. Power the CYD separately and pair with it over Bluetooth LE UART.
2. Keep sending `FYGPS`.
3. On `event == "detection"`, use the freshest phone GPS as the initial candidate coordinate.
4. Check existing DeFlock/OSM surveillance nodes within `250 feet` (`76.2 meters`).
5. If a matching or nearby camera already exists, suppress the candidate or attach it as a local observation only.
6. If no nearby camera exists, add a pending "CYD candidate" to the app review queue.
7. Review screen shows a map marker and direction cone.
8. User drags the marker from the road to the actual roadside camera position.
9. User sets camera direction manually; do not infer it from vehicle travel.
10. User approves, edits tags if needed, then DeFlock queues the normal OSM upload.

This keeps uploads human-reviewed and OSM-friendly while still making CYD detections useful in the field.

## Local CSV

When an SD card is present, CYD appends detections to:

```text
/flock.csv
```

Columns:

```text
millis,mac,oui,method,rssi,channel,frequency_mhz,lat,lon,accuracy_m,gps_age_ms,speed_kmph,course_deg,count
```
