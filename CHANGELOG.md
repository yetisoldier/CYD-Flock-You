# Changelog

All notable changes to CYD-Flock-You firmware are documented here.

## [Unreleased] — 2026-06-29

### Fixed
- BLE Flock scanning no longer pauses when phone BLE UART is connected — ESP32 Bluedroid supports simultaneous peripheral + central roles. Removed `PAUSE` status from display; now shows `BT+SCAN` / `BT+IDLE` when phone is connected.
- Channel hop list expanded to cover all legal 2.4 GHz channels (1–13)
- BLE advertising now restarts after every scan stop (not just when phone is disconnected), ensuring phone pairing is always available
- BLE OUI cross-check for 10-digit name pattern — reduces false positives from other IoT devices with numeric names by verifying the BLE MAC's OUI against known Flock prefixes
- FF badge: removed decorative diagonal line, centered "FF" text in badge
- Metric box text positioning: nudged labels and values up slightly so text sits higher in boxes instead of on the bottom edge
- RF STATUS panel: nudged "SCAN"/"HIT" text and "RF STATUS" label up for better vertical balance

### Changed
- **Channel hop pattern** changed to Flock channel-priority: `{11,6,1,10,5,2,9,4,3,8,7,12,13}` — hits the three non-overlapping channels (1, 6, 11) first, doubling interception probability on common Flock channels
- **Channel dwell increased** from 250ms to 750ms — optimal compromise between the Marauder's proven 1s dwell and cycle completion during a drive-by (full cycle: 9.75s)
- **RSSI threshold lowered** from -95 to -100 dBm — catches weak/distant camera signals
- **Dedup slots increased** from 8 to 16 — prevents false eviction in dense camera environments
- **WiFi init config** replaced with optimized custom config (disables AMPDU, CSI, NVS) modeled after ESP32 Marauder's cfg2 for leaner promiscuous mode — frees ~48KB RAM
- **BLE scan near-continuous:** 15s scan duration, 16s interval (94% duty cycle) — optimized for USB power, no battery conservation needed
- BLE scan parameters match Marauder: `setInterval(100)`, `setWindow(99)`, `setActiveScan(true)`

### Research
- Architectural comparison with [ESP32 Marauder CYD fork](https://github.com/Fr4nkFletcher/ESP32-Marauder-Cheap-Yellow-Display) — full analysis in [`docs/marauder-comparison.md`](docs/marauder-comparison.md). Key findings: our callback architecture (IRAM_ATTR + lock-free ring buffer) is superior to the Marauder's for detection reliability; the zero-detection problem was a timing/interception probability issue, not an architecture issue. Five recommendations from the review were implemented in this release.

## [v1.4.0] — 2026-06-22

### Added
- IE fingerprinting — strict ordered TLV walk of probe request Information Elements against known Flock Liteon vendor payload (`50:6f:9a:16:03:01:03`) and WPA vendor payload (`00:50:f2:08:00:00:00`). New `wildcard_probe_ie_sig` detection method (highest confidence).
- Confidence scoring — every JSON detection now includes `"confidence":"high|medium|low"` based on detection method ranking: `wildcard_probe_ie_sig` > `wildcard_probe` > `ssid` > `oui_addr2` > `oui_addr1` > `hidden_ssid`
- Per-method hit counters in `pair_status` JSON — `method_counts` object with counts for all 7 detection methods
- LAA OUI allowlist — `82:6b:f2` (DeFlockJoplin field-confirmed, locally-administered prefix) now functional via explicit allowlist exception in `matchOuiRaw()`
- New OUI `b4:1e:52` — Flock Safety's own IEEE-registered OUI (was missing)
- New OUI `e0:0a:f6` — Liteon Technology prefix (from upstream issue #28 / PR #29)

### Changed
- Channel hop order reversed to descending (11→1) — matches observed Flock camera ascending hop pattern for better intercept probability (credit: nsm_barri via DeFlockJoplin)
- Channel dwell reduced from 400ms to 250ms — 2× the observed 125ms Flock camera hop rate
- OUI list expanded from 31 to 33 prefixes
- `matchOuiRaw()` now checks LAA allowlist before rejecting locally-administered MACs

### Research
- Best-practices audit conducted by Scout agent covering ESP32 promiscuous mode, Flock Wi-Fi fingerprinting, OUI detection, channel strategy, RSSI thresholds, active vs passive detection, and alternative hardware. Full report in `research/cyd-wifi-scanning-best-practices.md`.

## [v1.3.0] — 2026-06-22

### Added
- Continuous BLE Flock scanning — passively scans for Flock-style BLE signatures in addition to WiFi monitoring
- BLE Flock scan status indicator on the SCAN screen showing live BLE scan activity
- BLE Flock battery detection — detects and reports battery level from Flock BLE devices (Penguin-style names, FS Ext Battery, 10-digit battery names)
- XUNTONG manufacturer data support — matches manufacturer ID `0x09c8` in BLE advertising data
- Full-screen red FLOCK FOUND flash on detection — immediate visual feedback
- Touch-to-dismiss for FLOCK FOUND alert — tap the touchscreen to clear the flash
- CYD touchscreen controls — tap cycles display screens, boot button rotates orientation
- Installation guide and usage documentation in README

### Changed
- BLE scan callback is now reused instead of allocated every scan cycle (reduces heap fragmentation)
- Penguin name matching tightened to `Penguin-` + exactly 10 digits (reduces false positives)
- Repeat display and CSV counts now use the matched detection object
- BLE advertised device names are JSON-escaped before emission (prevents JSON corruption from names with quotes/backslashes)

## [v1.2.0] — 2026-06-19

### Added
- FlockFree branding and display restyle with navy/cyan/blue colors and danger accents
- Portrait-aware layout for both landscape and portrait orientations
- Screen rotation cycling (landscape → portrait → landscape reversed → portrait reversed)

## [v1.1.0] — 2026-06-18

### Added
- WiFi promiscuous mode detection with OUI matching
- Multiple detection methods: wildcard probe, OUI addr1/addr2/addr3, SSID keyword, hidden SSID
- BLE Nordic UART service for phone companion communication
- SD card CSV logging for detections
- TFT status display with scan/GPS/CSV/last detection screens
- Phone GPS streaming via FYGPS BLE UART command
- Simulate mode (FYSIM) for bench testing without live RF
- Serial command interface (FYHELLO, FYSTATUS, FYGPS, FYSIM, FYSCREEN, FYTOUCH)
- Buzzer chirp and LED flash on detection
- Pairing protocol documentation