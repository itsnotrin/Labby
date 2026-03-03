# Requirements: Labby Bug Fix Milestone

**Defined:** 2026-03-03
**Core Value:** Fix all identified bugs to make Labby stable, reliable, and correct

## v1 Requirements

### Crash Safety

- [x] **CRASH-01**: `AddWidgetView` toolbar "Add" button must not force-unwrap optionals (HomeView.swift:1577,1583)
- [x] **CRASH-02**: Duplicate toolbar with divergent logic must be consolidated into one safe implementation (HomeView.swift:1508-1601)

### Navigation

- [x] **NAV-01**: `HomeWidgetCard` must not double-nest `NavigationLink` inside `HomeGridView` (HomeView.swift:722-864)
- [x] **NAV-02**: `ProxmoxDetailView`, `ProxmoxVMsView`, and `ProxmoxContainersView` must not nest `NavigationStack` inside existing navigation context (Proxmox.swift:669,1440,1496)

### API Correctness

- [ ] **API-01**: `PiHoleClient.toggleBlocking()` must use correct HTTP method (POST) with proper JSON body (PiHoleClient.swift:582-601)
- [ ] **API-02**: `ProxmoxClient.createBackup()` must include `vmid` parameter in the request body (ProxmoxClient.swift:415-432)
- [ ] **API-03**: `QBittorrent.applyLimits()` must only toggle alt-mode when the user explicitly requests it (QBittorrent.swift:429-431)

### Memory & Thread Safety

- [x] **MEM-01**: Timer retain cycles in PiHoleViewModel, PiHoleDetailViewModel, ProxmoxViewModel, ProxmoxDetailViewModel must use `[weak self]` (PiHole.swift:147-149,640-643; Proxmox.swift:339-342,968-972)
- [x] **MEM-02**: Race conditions on `JellyfinClient` cached auth state must be resolved (JellyfinClient.swift:12-14)
- [x] **MEM-03**: Race conditions on `PiHoleClient` session state must be resolved (PiHoleClient.swift:5-7)
- [x] **MEM-04**: Race condition on `ProxmoxClient.netSnapshots` static dictionary must be resolved (ProxmoxClient.swift:11)

### Session Management

- [x] **SESS-01**: PiHole session cache keys must be scoped per-instance to support multiple Pi-holes (PiHoleClient.swift:9-11)
- [x] **SESS-02**: `ServiceManager.client(for:)` must reuse client instances to preserve cached auth tokens (ServiceManager.swift:40)
- [x] **SESS-03**: qBittorrent must cache session cookies across calls to avoid IP bans (QBittorrentClient.swift:30,116)
- [x] **SESS-04**: qBittorrent must retry authentication on session expiration (403 response) (QBittorrent.swift:138-141)
- [x] **SESS-05**: PiHole session tokens should be stored in Keychain instead of UserDefaults (PiHoleClient.swift:556-566)

### UI Correctness

- [ ] **UI-01**: Alert bindings must use proper `@State` instead of `.constant()` computed expressions (HomeView.swift:140; AddServiceView.swift:226; ServicesView.swift:138)
- [ ] **UI-02**: Empty-state text in `HomeContentView` must use computed `headerText`/`subheaderText` (HomeView.swift:605-608)
- [ ] **UI-03**: `selectedHome` in `ServicesView` must stay synced with changes from other tabs (ServicesView.swift:16-17)
- [ ] **UI-04**: `.refreshable` on `JellyfinSeriesDetailView` must be applied to a `List`, not `ScrollView` (JellyfinSeriesDetailView.swift:249-251)
- [ ] **UI-05**: Duplicate Jellyfin person IDs must be deduplicated for `ForEach` (JellyfinMovieDetailView.swift:224; JellyfinSeriesDetailView.swift:150)
- [ ] **UI-06**: `.searchable` must remain visible when filter yields empty results (JellyfinSeasonDetailView.swift:130; JellyfinLibraryView.swift:79)
- [ ] **UI-07**: `dedupeSeasons` must preserve nil `childCount` instead of converting to 0 (JellyfinView.swift:304)
- [ ] **UI-08**: `AddHomeView` trim character set must be consistent between disabled check and save (AddHomeView.swift:43,50)

### Data Accuracy

- [ ] **DATA-01**: qBittorrent torrent state counting must use exact state matching instead of `.contains()` (QBittorrentClient.swift:183-186)
- [ ] **DATA-02**: Jellyfin file size estimation must use video stream bitrate, not first stream (JellyfinSeasonDetailView.swift:656,696)
- [ ] **DATA-03**: Proxmox `isUsingCachedData` must not rely solely on count comparison (Proxmox.swift:248-254)
- [ ] **DATA-04**: Proxmox `mergeVMs` must remove VMs that no longer exist on the server (Proxmox.swift:350-373,926-949)

### Performance

- [ ] **PERF-01**: qBittorrent must reuse `URLSession` instances instead of creating per-call (QBittorrent.swift:79-89)
- [ ] **PERF-02**: Jellyfin date/byte formatters must be static/cached, not created per render (JellyfinSeasonDetailView.swift:530-537)

### Other

- [ ] **OTHER-01**: `PiHoleTopClient`/`PiHoleTopDomain` must use stable IDs across refreshes (PiHole.swift:9-19,21-31)
- [ ] **OTHER-02**: `LabbyApp` must use `@StateObject` instead of `@ObservedObject` for singleton (LabbyApp.swift:12)
- [ ] **OTHER-03**: `JellyfinClient.testConnection()` must not log auth token to console (JellyfinClient.swift:49)

## v2 Requirements

None — this is a bug fix milestone.

## Out of Scope

| Feature | Reason |
|---------|--------|
| New features | Bug fix milestone only |
| macOS support | iOS-only target |
| Architecture refactoring | Only change what's needed for fixes |
| Test coverage | Focus on fixing bugs, not adding tests |
| Jellyfin `onAppear` guard/caching | Low impact, views work correctly today |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| CRASH-01 | Phase 1 | Complete |
| CRASH-02 | Phase 1 | Complete |
| NAV-01 | Phase 1 | Complete |
| NAV-02 | Phase 1 | Complete |
| MEM-01 | Phase 2 | Complete |
| MEM-02 | Phase 2 | Complete |
| MEM-03 | Phase 2 | Complete |
| MEM-04 | Phase 2 | Complete |
| SESS-01 | Phase 3 | Complete |
| SESS-02 | Phase 3 | Complete |
| SESS-03 | Phase 3 | Complete |
| SESS-04 | Phase 3 | Complete |
| SESS-05 | Phase 3 | Complete |
| API-01 | Phase 4 | Pending |
| API-02 | Phase 4 | Pending |
| API-03 | Phase 4 | Pending |
| DATA-01 | Phase 4 | Pending |
| DATA-02 | Phase 4 | Pending |
| DATA-03 | Phase 4 | Pending |
| DATA-04 | Phase 4 | Pending |
| UI-01 | Phase 5 | Pending |
| UI-02 | Phase 5 | Pending |
| UI-03 | Phase 5 | Pending |
| UI-04 | Phase 5 | Pending |
| UI-05 | Phase 5 | Pending |
| UI-06 | Phase 5 | Pending |
| UI-07 | Phase 5 | Pending |
| UI-08 | Phase 5 | Pending |
| PERF-01 | Phase 5 | Pending |
| PERF-02 | Phase 5 | Pending |
| OTHER-01 | Phase 5 | Pending |
| OTHER-02 | Phase 5 | Pending |
| OTHER-03 | Phase 5 | Pending |

**Coverage:**
- v1 requirements: 33 total
- Mapped to phases: 33
- Unmapped: 0

---
*Requirements defined: 2026-03-03*
*Last updated: 2026-03-03 after roadmap creation*
