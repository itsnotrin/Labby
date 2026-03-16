# Plan 04-01 Summary: Fix Broken API Calls

**Status:** Complete
**Duration:** ~2 min (part of batch fix)

## What Changed

### API-01: PiHoleClient.toggleBlocking
- **Before:** Used POST or DELETE based on enable flag, sent no JSON body
- **After:** Always uses POST with JSON body `{"blocking": true/false}` per Pi-hole v6 API spec
- **File:** `Labby/Services/PiHole/PiHoleClient.swift`

### API-02: ProxmoxClient.createBackup
- **Before:** POSTed to vzdump with no body — vmid parameter was accepted but never sent
- **After:** Includes `vmid` in form-encoded POST body with Content-Type header
- **File:** `Labby/Services/Proxmox/ProxmoxClient.swift`

### API-03: QBittorrentViewModel.applyLimits
- **Before:** `if let _ = toggleAltMode` triggered toggle on any non-nil value (true or false)
- **After:** Compares desired state with current `limits?.alternativeModeEnabled` and only toggles when they differ
- **File:** `Labby/Services/QBittorrent/QBittorrent.swift`

## Verification
- Build: ✓ (zero errors, zero warnings)
