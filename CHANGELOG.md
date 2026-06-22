# Changelog

All notable changes to CYD-Flock-You firmware are documented here.

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