# Roadmap: Labby Bug Fix Milestone

## Overview

Thirty-three bugs discovered through a comprehensive audit are addressed across five phases. The order is dependency-driven: crashes and broken navigation first (app must be usable), then thread safety (clients must be stable before session and API work), then session management, then API correctness, and finally UI/data/performance leaf fixes. Each phase leaves the app more stable and correct than it was before.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Crashes & Navigation** - Eliminate force-unwrap crashes and broken navigation patterns (completed 2026-03-03)
- [x] **Phase 2: Thread Safety** - Resolve all race conditions and timer retain cycles (completed 2026-03-03)
- [ ] **Phase 3: Session Management** - Fix session scoping, caching, and retry across all services
- [ ] **Phase 4: API & Data Correctness** - Fix broken API calls and inaccurate data computations
- [ ] **Phase 5: UI & Performance** - Fix all UI inconsistencies, empty states, and performance regressions

## Phase Details

### Phase 1: Crashes & Navigation
**Goal**: The app does not crash and navigation flows work without double-nesting
**Depends on**: Nothing (first phase)
**Requirements**: CRASH-01, CRASH-02, NAV-01, NAV-02
**Success Criteria** (what must be TRUE):
  1. Tapping "Add" in AddWidgetView never crashes regardless of optional state
  2. The toolbar appears exactly once in HomeView with consistent logic
  3. Navigating into a widget card opens the correct detail view without double-push
  4. Proxmox detail, VMs, and Containers views open without wrapping an inner NavigationStack inside the existing navigation context
**Plans:** 2/2 plans complete
- [ ] 01-01-PLAN.md — Fix crash-causing force-unwraps in AddWidgetView and eliminate double-nested NavigationLink in HomeWidgetCard
- [ ] 01-02-PLAN.md — Remove nested NavigationStack from ProxmoxDetailView, ProxmoxVMsView, and ProxmoxContainersView

### Phase 2: Thread Safety
**Goal**: All ViewModels and service clients operate without memory leaks or data races
**Depends on**: Phase 1
**Requirements**: MEM-01, MEM-02, MEM-03, MEM-04
**Success Criteria** (what must be TRUE):
  1. Auto-refresh timers in PiHole and Proxmox ViewModels do not retain self after the ViewModel is deallocated
  2. Concurrent reads and writes to JellyfinClient cached auth state do not produce undefined behavior
  3. Concurrent access to PiHoleClient session state does not produce undefined behavior
  4. Concurrent access to ProxmoxClient.netSnapshots does not produce undefined behavior
**Plans:** 2/2 plans complete
- [ ] 02-01-PLAN.md — Fix timer retain cycles in PiHole and Proxmox ViewModels ([weak self] capture)
- [ ] 02-02-PLAN.md — Convert JellyfinClient, PiHoleClient, and ProxmoxClient from final class to actor for thread-safe state access

### Phase 3: Session Management
**Goal**: All services correctly scope, cache, and recover their authentication sessions
**Depends on**: Phase 2
**Requirements**: SESS-01, SESS-02, SESS-03, SESS-04, SESS-05
**Success Criteria** (what must be TRUE):
  1. Two Pi-hole instances can be configured simultaneously without sharing session tokens
  2. ServiceManager hands back the same client instance on repeated calls, preserving cached auth tokens
  3. qBittorrent session cookies persist across API calls so the service is not IP-banned
  4. qBittorrent automatically re-authenticates and retries when it receives a 403 response
  5. PiHole session tokens are stored in Keychain, not UserDefaults
**Plans:** 2 plans
- [ ] 03-01-PLAN.md — Scope PiHole session keys per-instance and migrate session token storage from UserDefaults to Keychain
- [ ] 03-02-PLAN.md — Add ServiceManager client instance caching, fix qBittorrent session cookie reuse, and add 403 retry logic

### Phase 4: API & Data Correctness
**Goal**: All API calls use the correct method and parameters, and all data computations are accurate
**Depends on**: Phase 3
**Requirements**: API-01, API-02, API-03, DATA-01, DATA-02, DATA-03, DATA-04
**Success Criteria** (what must be TRUE):
  1. Pi-hole blocking toggle sends a POST request with a proper JSON body and the blocking state changes correctly
  2. Creating a Proxmox backup includes the vmid in the request body and succeeds
  3. Alt-mode in qBittorrent only toggles when the user explicitly requests it, not on every limit application
  4. qBittorrent torrent state counts reflect exact state matching rather than substring inclusion
  5. Proxmox VM list removes entries that no longer exist on the server after a refresh
**Plans**: TBD

### Phase 5: UI & Performance
**Goal**: All visible UI states are correct and repeated interactions do not allocate unnecessary resources
**Depends on**: Phase 4
**Requirements**: UI-01, UI-02, UI-03, UI-04, UI-05, UI-06, UI-07, UI-08, PERF-01, PERF-02, OTHER-01, OTHER-02, OTHER-03
**Success Criteria** (what must be TRUE):
  1. Alerts throughout the app open and dismiss without console warnings about constant bindings
  2. HomeContentView displays the correct header and subheader text when no homes or widgets exist
  3. ServicesView reflects the correct selected home when the user switches tabs and back
  4. Pull-to-refresh on JellyfinSeriesDetailView works and the search bar remains visible when filtered results are empty
  5. Repeated navigation and refresh cycles do not progressively allocate new URLSession or formatter instances
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Crashes & Navigation | 2/2 | Complete   | 2026-03-03 |
| 2. Thread Safety | 2/2 | Complete   | 2026-03-03 |
| 3. Session Management | 1/2 | In progress | - |
| 4. API & Data Correctness | 0/TBD | Not started | - |
| 5. UI & Performance | 0/TBD | Not started | - |
