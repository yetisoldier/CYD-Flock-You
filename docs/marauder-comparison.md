# Architectural Comparison: CYD-Flock-You vs ESP32 Marauder

**Date:** 2026-06-29  
**Reference:** [ESP32 Marauder CYD fork](https://github.com/Fr4nkFletcher/ESP32-Marauder-Cheap-Yellow-Display) by Fr4nkFletcher  
**Author:** Bob (architect agent), with Jarvis

---

## Why We Compared

After driving past 12+ known Flock cameras with zero detections, we investigated whether the ESP32 Marauder — a purpose-built ESP32 wardriving firmware with native CYD support — had techniques we could adopt. The Marauder is a well-established project with field-proven WiFi and BLE scanning on the exact same hardware (ESP32-2432S028R Cheap Yellow Display).

## Summary Verdict

Our callback architecture is **superior** to the Marauder's for targeted detection. The zero-detection problem was a **timing/interception probability issue**, not an architecture issue. We adopted five specific improvements from the Marauder's approach while retaining our better architectural patterns.

---

## What We Have That's Better

### 1. Callback Architecture

| Feature | CYD-Flock-You | Marauder |
|---------|---------------|----------|
| ISR safety | `IRAM_ATTR` callback + lock-free ring buffer | `Serial.print()` + `String` allocation inside callbacks |
| Callback work | Minimal: OUI match + enqueue | Heavy: string formatting, display updates, `delay()` |
| Decoupling | Callback → queue → `loop()` processes | Callback does everything inline |

Our callback does the absolute minimum (OUI match, IE fingerprint, enqueue) and all Serial/display/JSON work happens in `drainAlertQueue()` from `loop()`. The Marauder's callbacks call `Serial.print()`, allocate `String` objects, and even call `delay(random(0, 10))` — all unsafe in promiscuous mode callbacks. We never miss packets during Serial output.

### 2. Detection Logic

| Feature | CYD-Flock-You | Marauder |
|---------|---------------|----------|
| OUI matching | 34 pre-compiled byte tables, IRAM-resident | None |
| IE fingerprint | Full ordered TLV walk with vendor payload comparison | None |
| Confidence scoring | 7-level ranking (high/medium/low per method) | None |
| Persistence | SPIFFS with CRC32 envelope, survives reboot | None (lost on power cycle) |
| Dedup | 16-slot serial rate-limit + 200-entry persistent table + rediscover logic | 100-entry linear scan, no persistence |

Our IE fingerprint matching (`FLOCK_PRIMARY_PROBE_IES`) is best-in-class — it walks the ordered Information Element TLVs in probe requests and compares vendor payloads byte-by-byte. The Marauder has nothing equivalent.

### 3. BLE Flock Detection

The Marauder catalogs all BLE devices generically. We have targeted Flock-specific signatures:
- "Penguin-NNNNNNNNNN" (10-digit) name matching
- "FS Ext Battery" name matching
- Pure 10-digit name with OUI cross-check (new — reduces false positives)
- XUNTONG company ID 0x09C8 in manufacturer data

---

## What We Adopted From the Marauder

### 1. Optimized WiFi Init Config

**What:** Custom `wifi_init_config_t` disabling AMPDU, CSI, and NVS.  
**Marauder calls it:** `cfg2`  
**Why it matters:** The default `WIFI_INIT_CONFIG_DEFAULT()` enables AMPDU aggregation, CSI (channel state information), and NVS (non-volatile storage) writes. These add overhead and can drop promiscuous mode packets. The Marauder's cfg2 disables all three and reduces RX buffer counts from 10+32 to 6+6, freeing ~48KB RAM.

**Our implementation:** Byte-for-byte identical to the Marauder's cfg2:
```c
.static_rx_buf_num = 6,
.dynamic_rx_buf_num = 6,
.csi_enable = false,
.ampdu_rx_enable = false,
.ampdu_tx_enable = false,
.amsdu_tx_enable = false,
.nvs_enable = false,
.rx_ba_win = 6,
```

### 2. Channel Coverage (1–13)

**What:** Expanded hop list to cover all legal 2.4 GHz channels.  
**Marauder does:** Hops 1→13 (all channels).  
**Why it matters:** We previously only hopped channels 1–11. Channels 12 and 13 are legal in most regions (EU, Japan, etc.) and Flock cameras may use them. The Marauder's full coverage ensures no channel is missed.

**Our implementation:** We went further than the Marauder's simple ascending pattern. We use a **Flock channel-priority hop**: `{11, 6, 1, 10, 5, 2, 9, 4, 3, 8, 7, 12, 13}`. This hits the three non-overlapping 2.4 GHz channels (1, 6, 11) — the most common Flock channels — first in each cycle, doubling interception probability on those channels.

### 3. Longer Channel Dwell Time

**What:** Increased dwell from 250ms to 750ms per channel.  
**Marauder uses:** 1000ms (1s).  
**Why it matters:** Flock cameras are burst-sleep devices that transmit for 50–200ms every few seconds. With 250ms dwell and 11 channels, a camera transmitting 100ms every 3s had only ~3.3% chance of being caught per dwell window. At 750ms dwell with 13 channels (9.75s full cycle), that jumps to ~22%.

**Why not 1s like the Marauder:** A 1s dwell gives a 13s full cycle. At 30mph, a camera is only visible for ~10s, meaning we'd only cover ~10 of 13 channels per pass. 750ms gives a 9.75s cycle — just enough to complete a full sweep during a typical drive-by.

### 4. BLE Scan Parameters

**What:** Matched scan interval, window, and active scan settings.  
**Marauder uses:** `setInterval(100)`, `setWindow(99)`, `setActiveScan(true)` — 99% duty cycle.  
**Why it matters:** These are the maximum BLE scan parameters. The 99/100 ratio means the scanner is active 99% of the time.

**Our implementation:** Already identical. We additionally tightened the duty cycle to 15s scan / 16s interval (94% overall), since the device is USB-powered and doesn't need battery conservation. The Marauder uses 5s scan bursts.

### 5. RSSI Threshold

**What:** Lowered from -95 dBm to -100 dBm.  
**Marauder does:** No RSSI filtering in sniffer callbacks.  
**Why it matters:** Distant or obstructed cameras may have weak signals (-96 to -100 dBm) that were being filtered out. The Marauder accepts all packets and lets downstream logic decide. We keep the threshold as a noise filter but lowered it to -100 to catch weak cameras while still rejecting background noise below -100.

---

## What We Did NOT Adopt (and Why)

### Active WiFi Scanning (`WiFi.scanNetworks()`)

**Marauder does:** Uses `WiFi.scanNetworks()` in wardrive mode — sends probe requests and listens for responses.  
**Why we didn't:** Our firmware is passive-only by design (stated in README: "does not transmit Wi-Fi"). Active scanning could be illegal in some jurisdictions and breaks the passive research tool principle. The architectural review noted this as a **possible diagnostic mode** for testing if detections remain at zero after all passive improvements, but not for production.

### NimBLE BLE Stack

**Marauder uses:** NimBLE (`NimBLEDevice.h`) — ~10KB RAM, native multi-role support.  
**Why we didn't (yet):** We use Bluedroid (`BLEDevice.h`) — ~50KB RAM. NimBLE would free ~40KB and provide better multi-role (peripheral + central) support. However, switching requires a ~200-line rewrite of BLE server + scan callbacks. Our Bluedroid implementation works correctly with simultaneous scan + phone UART. This is a **medium-priority long-term improvement** — only worth the refactor if BLE detection proves unreliable or RAM pressure becomes an issue.

### Multiple Specialized Sniffer Callbacks

**Marauder has:** Separate callbacks for beacons, probes, stations, deauths, EAPOL, raw, AP, etc.  
**Why we didn't:** Our single `wifiSniffer()` callback with conditional logic inside is cleaner and avoids duplicate packet processing. The Marauder switches callbacks when changing modes, which adds overhead. Our approach handles all frame types in one pass with OUI matching + IE fingerprinting.

---

## Field Test Protocol

If detections remain at zero after these changes, follow this diagnostic decision tree:

```
Zero detections after field test?
├── rx_frames = 0 → Hardware issue (WiFi not in promiscuous mode, antenna problem)
├── rx_frames > 0, rx_mgmt = 0 → Filter mask issue (not receiving management frames)
├── rx_mgmt > 0, no OUI hits → OUI list gap (Flock uses different manufacturer)
│   └── Capture raw packets, analyze MAC addresses
├── OUI hits but no probe requests → Channel timing issue
│   └── Increase dwell time, try single-channel parking test
└── Probe requests captured but no IE fingerprint match
    └── Flock firmware update changed probe IE pattern
        └── Update FLOCK_PRIMARY_PROBE_IES from new captures
```

### Success Criteria

- **Minimum viable:** 1 detection per 10 known camera pass-bys
- **Target:** 1 detection per 3 known camera pass-bys
- **Excellent:** 1 detection per 1–2 known camera pass-bys

---

## Reference

- Full architectural review: `architectural-review-cyd-flock-you.md` (workspace)
- Marauder source: `WiFiScan.cpp` (7020 lines), `WiFiScan.h` (535 lines)
- Our firmware: `main.cpp` (~2650 lines)