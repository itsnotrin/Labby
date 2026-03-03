# Phase 4: API & Data Correctness - Context

**Gathered:** 2026-03-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix broken API calls (wrong HTTP method, missing parameters, unintended side effects) and inaccurate data computations (substring matching, wrong bitrate source, stale VM entries). Seven bugs: API-01, API-02, API-03, DATA-01, DATA-02, DATA-03, DATA-04.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion

All implementation decisions are Claude's discretion — these are targeted bug fixes with clear requirements.

**PiHole toggleBlocking (API-01):**
- `toggleBlocking()` must use POST with proper JSON body instead of current incorrect method
- PiHoleClient is now an actor (Phase 2) — all methods are async
- Claude decides exact JSON body structure based on Pi-hole v6 API

**Proxmox createBackup (API-02):**
- `createBackup()` must include `vmid` in request body
- ProxmoxClient is now an actor (Phase 2)
- Claude decides parameter placement (body vs query)

**qBittorrent applyLimits alt-mode (API-03):**
- `applyLimits()` currently toggles alt-mode on every call — must only toggle when user explicitly requests it
- Claude decides how to gate the toggle (parameter flag, separate method, or conditional check)

**qBittorrent state counting (DATA-01):**
- State counting uses `.contains()` substring matching — must use exact state matching
- Claude decides matching approach (exact string equality, enum, or switch)

**Jellyfin file size estimation (DATA-02):**
- Currently uses first stream bitrate — must use video stream bitrate specifically
- Claude decides how to identify the video stream (type field, codec check, etc.)

**Proxmox isUsingCachedData (DATA-03):**
- Currently relies solely on count comparison — unreliable if server count happens to match
- Claude decides alternative staleness detection (timestamp, hash, explicit flag)

**Proxmox mergeVMs stale entries (DATA-04):**
- `mergeVMs` doesn't remove VMs that no longer exist on server after refresh
- Claude decides merge strategy (replace vs diff-and-remove)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- PiHoleClient actor with session management and Keychain storage (Phase 2+3)
- ProxmoxClient actor with NetSnapshotStore (Phase 2)
- qBittorrent performWithRetry helper for 403 retry (Phase 3)
- ServiceManager client caching (Phase 3)

### Established Patterns
- All service clients are actors (Phase 2) except QBittorrentClient (still final class)
- API methods are async throws throughout
- qBittorrent extension methods in QBittorrent.swift use performWithRetry pattern

### Integration Points
- PiHoleClient.swift:582-601 — toggleBlocking method
- ProxmoxClient.swift:415-432 — createBackup method
- QBittorrent.swift:429-431 — applyLimits method
- QBittorrentClient.swift:183-186 — state counting logic
- JellyfinSeasonDetailView.swift:656,696 — file size estimation
- Proxmox.swift:248-254 — isUsingCachedData check
- Proxmox.swift:350-373,926-949 — mergeVMs logic

</code_context>

<specifics>
## Specific Ideas

No specific requirements — open to standard approaches.

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope.

</deferred>

---

*Phase: 04-api-data-correctness*
*Context gathered: 2026-03-03*
