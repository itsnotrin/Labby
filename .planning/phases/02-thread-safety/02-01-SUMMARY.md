---
phase: 02-thread-safety
plan: 01
subsystem: ui
tags: [swift, memory-management, retain-cycles, timer, viewmodel]

# Dependency graph
requires: []
provides:
  - Timer closures in PiHoleViewModel and PiHoleDetailViewModel capture [weak self]
  - Timer closures in ProxmoxViewModel and ProxmoxDetailViewModel capture [weak self]
  - All four ViewModel auto-refresh timers break retain cycles on deallocation
affects: [02-thread-safety]

# Tech tracking
tech-stack:
  added: []
  patterns: "[weak self] with guard let self in Timer.scheduledTimer closures"

key-files:
  created: []
  modified:
    - Labby/Services/PiHole/PiHole.swift
    - Labby/Services/Proxmox/Proxmox.swift

key-decisions:
  - "Use [weak self] capture list + guard let self = self else { return } pattern — matches existing ProxmoxDetailViewModelLarge pattern already in codebase"

patterns-established:
  - "Timer closure pattern: Timer.scheduledTimer(...) { [weak self] _ in guard let self = self else { return } Task { await self.method() } }"

requirements-completed: [MEM-01]

# Metrics
duration: 5min
completed: 2026-03-03
---

# Phase 2 Plan 01: Fix Timer Retain Cycles Summary

**[weak self] guard-let pattern applied to all four broken Timer.scheduledTimer closures in PiHoleViewModel, PiHoleDetailViewModel, ProxmoxViewModel, and ProxmoxDetailViewModel**

## Performance

- **Duration:** ~5 min
- **Started:** 2026-03-03T10:35:00Z
- **Completed:** 2026-03-03T10:40:03Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Fixed PiHoleViewModel.startAutoRefresh() — timer no longer retains self strongly after ViewModel deallocates
- Fixed PiHoleDetailViewModel.startAutoRefresh() — same fix, 15s interval timer
- Fixed ProxmoxViewModel.startAutoRefresh() — timer no longer retains self strongly after ViewModel deallocates
- Fixed ProxmoxDetailViewModel.startAutoRefresh() — same fix, 15s interval timer
- ProxmoxDetailViewModelLarge left unchanged — already had the correct [weak self] pattern

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix timer retain cycles in PiHoleViewModel and PiHoleDetailViewModel** - `2c14795` (fix)
2. **Task 2: Fix timer retain cycles in ProxmoxViewModel and ProxmoxDetailViewModel** - `fb3d933` (fix)

**Plan metadata:** (docs commit after summary)

## Files Created/Modified
- `Labby/Services/PiHole/PiHole.swift` - Added [weak self] to PiHoleViewModel (line 147) and PiHoleDetailViewModel (line 641) timer closures
- `Labby/Services/Proxmox/Proxmox.swift` - Added [weak self] to ProxmoxViewModel (line 339) and ProxmoxDetailViewModel (line 968) timer closures

## Decisions Made
- Matched the existing [weak self] pattern already established in ProxmoxDetailViewModelLarge — consistent approach across all timers in the codebase

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
- xcodebuild with `-scheme Labby` alone failed due to missing `-project` flag (required explicit `-project Labby.xcodeproj`) and simulator name changed (iPhone 17 requires OS 26.4). Resolved by using device ID directly.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- All four broken timer retain cycles resolved — ViewModels can now be properly deallocated when views disappear
- Memory leak source (timer strongly capturing self) eliminated for PiHole and Proxmox services
- Ready to continue with remaining 02-thread-safety plans

---
*Phase: 02-thread-safety*
*Completed: 2026-03-03*
