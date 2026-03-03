---
phase: 02-thread-safety
plan: 02
subsystem: api
tags: [swift, actor, concurrency, thread-safety, jellyfin, pihole, proxmox]

# Dependency graph
requires:
  - phase: 01-crashes-navigation
    provides: Stable build foundation with crash fixes applied
provides:
  - Thread-safe JellyfinClient using Swift actor isolation
  - Thread-safe PiHoleClient using Swift actor isolation
  - Thread-safe ProxmoxClient using Swift actor isolation with dedicated NetSnapshotStore actor
affects: [any phase adding new service clients or calling existing client methods]

# Tech tracking
tech-stack:
  added: []
  patterns: [Swift actor for service client thread safety, nonisolated(unsafe) for thread-safe lazy vars, dedicated actor for shared static state]

key-files:
  created: []
  modified:
    - Labby/Services/Jellyfin/JellyfinClient.swift
    - Labby/Services/PiHole/PiHoleClient.swift
    - Labby/Services/Proxmox/ProxmoxClient.swift
    - Labby/Services/Proxmox/Proxmox.swift

key-decisions:
  - "Use nonisolated(unsafe) lazy var for URLSession in all three actors (URLSession is internally thread-safe)"
  - "Use dedicated NetSnapshotStore actor (not nonisolated(unsafe)) for ProxmoxClient.netSnapshots to achieve real isolation"
  - "Move client.clearCache() calls inside Task {} blocks in synchronous @MainActor methods (Proxmox.swift call sites)"

patterns-established:
  - "Service client actor pattern: actor declaration + nonisolated(unsafe) lazy var session + all mutable state auto-isolated"
  - "Shared static state pattern: dedicated private actor wrapping static dictionary, not nonisolated(unsafe)"

requirements-completed: [MEM-02, MEM-03, MEM-04]

# Metrics
duration: 2min
completed: 2026-03-03
---

# Phase 02 Plan 02: Thread Safety (Service Client Actors) Summary

**Three service clients converted from final class to actor using Swift-native isolation: JellyfinClient (auth token cache), PiHoleClient (session state), ProxmoxClient (instance caches + static netSnapshots behind dedicated NetSnapshotStore actor)**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-03T10:38:41Z
- **Completed:** 2026-03-03T10:40:59Z
- **Tasks:** 3
- **Files modified:** 4

## Accomplishments
- JellyfinClient converted to actor; cachedUserId, cachedAuthToken, authTokenTimestamp are now actor-isolated
- PiHoleClient converted to actor; sid, csrf, sidExpiry are now actor-isolated
- ProxmoxClient converted to actor; instance caches (cachedNodes, cachedVMs, cachedStorage) and timestamps are actor-isolated; static netSnapshots moved to a dedicated NetSnapshotStore actor

## Task Commits

Each task was committed atomically:

1. **Task 1: Convert JellyfinClient from final class to actor** - `4c9215c` (feat)
2. **Task 2: Convert PiHoleClient from final class to actor** - `143afcb` (feat)
3. **Task 3: Convert ProxmoxClient from final class to actor** - `4d1294b` (feat)

**Plan metadata:** (to follow)

## Files Created/Modified
- `Labby/Services/Jellyfin/JellyfinClient.swift` - Changed to actor, lazy var session marked nonisolated(unsafe)
- `Labby/Services/PiHole/PiHoleClient.swift` - Changed to actor, lazy var session marked nonisolated(unsafe)
- `Labby/Services/Proxmox/ProxmoxClient.swift` - Changed to actor, added private NetSnapshotStore actor, netSnapshots accesses updated to await NetSnapshotStore.shared.get/set
- `Labby/Services/Proxmox/Proxmox.swift` - Updated clearCache() call sites: added await in async context, moved into Task {} blocks in synchronous @MainActor methods

## Decisions Made
- Used `nonisolated(unsafe) lazy var` for URLSession in all three actors. URLSession is documented as internally thread-safe, making the manual safety assertion valid.
- Created a dedicated `NetSnapshotStore` actor for the static dictionary rather than using `nonisolated(unsafe) static var`. Static state is shared across all ProxmoxClient instances, so a real actor provides genuine isolation rather than a compiler silence.
- In Proxmox.swift, the two synchronous `refreshCache()` methods on `@MainActor` classes could not directly `await client.clearCache()`. Fixed by moving the clearCache call inside the existing Task { } block that was already spawned for `refresh()`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed Proxmox.swift call sites for actor-isolated clearCache()**
- **Found during:** Task 3 (Convert ProxmoxClient to actor)
- **Issue:** Three call sites in Proxmox.swift called `client.clearCache()` synchronously from `@MainActor` context after ProxmoxClient became an actor. Compiler errors: "call to actor-isolated instance method in a synchronous main actor-isolated context"
- **Fix:** (1) Two synchronous `refreshCache()` methods: moved `clearCache()` inside the existing `Task {}` block; (2) One async `refreshVMStatus()` method: added `await` prefix
- **Files modified:** Labby/Services/Proxmox/Proxmox.swift
- **Verification:** Build succeeded with no errors after fix
- **Committed in:** 4d1294b (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (Rule 3 - blocking call site compiler errors)
**Impact on plan:** Fix was necessary to complete the actor conversion. No behavior change — clearCache still runs before refresh, just asynchronously.

## Issues Encountered
None beyond the call site fix documented above.

## Next Phase Readiness
- All three service clients are thread-safe actors. Concurrent async calls can no longer produce data races on shared mutable state.
- Callers already used `await` for all client methods (they were already async throws), so no other call sites required changes.
- The ServiceClient protocol has no `AnyObject`/`class` constraint, so actor conformance worked cleanly.

---
*Phase: 02-thread-safety*
*Completed: 2026-03-03*
