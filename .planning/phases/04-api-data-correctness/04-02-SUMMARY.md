# Plan 04-02 Summary: Fix Data Computation Bugs

**Status:** Complete
**Duration:** ~3 min (part of batch fix)

## What Changed

### DATA-01: qBittorrent state counting
- **Before:** Used `.contains()` substring matching — "pausedUP" counted as seeding, "stalledDL" as downloading
- **After:** Uses exact state set membership: `downloadingStates = ["downloading", "forceddl", "metadl"]`, `seedingStates = ["uploading", "forcedup"]`
- **File:** `Labby/Services/QBittorrent/QBittorrentClient.swift`

### DATA-02: Jellyfin file size estimation
- **Before:** Used `mediaStreams.first` which could be audio or subtitle stream
- **After:** Uses `videoStream` (already parsed via `mediaStreams.first { $0.type == "Video" }`) in both cache and fetch paths
- **File:** `Labby/Services/Jellyfin/Views/JellyfinSeasonDetailView.swift`

### DATA-03: Proxmox isUsingCachedData
- **Before:** Relied on count comparison (beforeNodes != afterNodes) which is unreliable if server count matches
- **After:** ProxmoxClient now sets explicit `lastNodesFetchWasCached`, `lastVMsFetchWasCached`, `lastStorageFetchWasCached` flags on each fetch. ViewModel reads these flags.
- **Files:** `Labby/Services/Proxmox/ProxmoxClient.swift`, `Labby/Services/Proxmox/Proxmox.swift`

### DATA-04: Proxmox mergeVMs stale entries
- **Before:** Started dict from existing VMs then added new — stale entries never removed
- **After:** Starts from new VMs only (naturally excludes stale entries), preserves object identity from existing when unchanged. Both copies (ProxmoxViewModel and ProxmoxDetailViewModelLarge) fixed.
- **File:** `Labby/Services/Proxmox/Proxmox.swift`

## Verification
- Build: ✓ (zero errors, zero warnings)
