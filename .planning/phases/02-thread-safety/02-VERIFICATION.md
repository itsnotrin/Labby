---
phase: 02-thread-safety
verified: 2026-03-03T00:00:00Z
status: passed
score: 7/7 must-haves verified
---

# Phase 2: Thread Safety Verification Report

**Phase Goal:** All ViewModels and service clients operate without memory leaks or data races
**Verified:** 2026-03-03
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| #   | Truth                                                                                               | Status     | Evidence                                                                                                        |
| --- | --------------------------------------------------------------------------------------------------- | ---------- | --------------------------------------------------------------------------------------------------------------- |
| 1   | Auto-refresh timers in PiHoleViewModel and PiHoleDetailViewModel do not retain self after dealloc  | VERIFIED   | PiHole.swift lines 147, 641: `[weak self]` + `guard let self = self else { return }` on both Timer closures    |
| 2   | Auto-refresh timers in ProxmoxViewModel and ProxmoxDetailViewModel do not retain self after dealloc | VERIFIED   | Proxmox.swift lines 339, 968: `[weak self]` + `guard let self = self else { return }` on both Timer closures   |
| 3   | Concurrent reads and writes to JellyfinClient cached auth state do not produce undefined behavior  | VERIFIED   | JellyfinClient.swift line 10: `actor JellyfinClient`; cachedUserId, cachedAuthToken, authTokenTimestamp are actor-isolated private vars |
| 4   | Concurrent access to PiHoleClient session state does not produce undefined behavior                | VERIFIED   | PiHoleClient.swift line 3: `actor PiHoleClient`; sid, csrf, sidExpiry are actor-isolated private vars          |
| 5   | Concurrent access to ProxmoxClient.netSnapshots static dictionary does not produce undefined behavior | VERIFIED | ProxmoxClient.swift lines 13-24: dedicated `private actor NetSnapshotStore` wraps all reads/writes; no bare static var remains |
| 6   | No unprotected mutable static state remains in ProxmoxClient                                       | VERIFIED   | `grep -n 'static var' ProxmoxClient.swift` returns no matches; the old `static var netSnapshots` is gone       |
| 7   | ProxmoxClient clearCache() call sites correctly await the actor-isolated method                    | VERIFIED   | Proxmox.swift lines 223, 805, 1769: all three call sites use `await client.clearCache()` in async context      |

**Score:** 7/7 truths verified

### Required Artifacts

| Artifact                                          | Expected                                                         | Status   | Details                                                                                                  |
| ------------------------------------------------- | ---------------------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------------------- |
| `Labby/Services/PiHole/PiHole.swift`              | Timer closures with `[weak self]` in PiHoleViewModel and PiHoleDetailViewModel | VERIFIED | Lines 147 and 641; both follow: `[weak self] _ in` then `guard let self = self else { return }` then `Task { await self.refresh() }` |
| `Labby/Services/Proxmox/Proxmox.swift`            | Timer closures with `[weak self]` in ProxmoxViewModel and ProxmoxDetailViewModel | VERIFIED | Lines 339 and 968; same pattern. Line 1808 (ProxmoxDetailViewModelLarge) also has `[weak self]` — pre-existing, correct, untouched |
| `Labby/Services/Jellyfin/JellyfinClient.swift`    | Thread-safe access to cachedUserId, cachedAuthToken, authTokenTimestamp via actor | VERIFIED | Line 10: `actor JellyfinClient: ServiceClient`. Properties are private vars at lines 12–14, actor-isolated by Swift runtime. URLSession at line 19: `nonisolated(unsafe) lazy var` (URLSession is documented thread-safe) |
| `Labby/Services/PiHole/PiHoleClient.swift`        | Thread-safe access to sid, csrf, sidExpiry via actor            | VERIFIED | Line 3: `actor PiHoleClient: ServiceClient`. Properties at lines 5–7, actor-isolated. URLSession at line 14: `nonisolated(unsafe) lazy var` |
| `Labby/Services/Proxmox/ProxmoxClient.swift`      | Thread-safe access to netSnapshots static dictionary and instance caches via actor | VERIFIED | Line 26: `actor ProxmoxClient: ServiceClient`. Lines 13–24: dedicated `private actor NetSnapshotStore` with `.shared` singleton. Instance caches (cachedNodes, cachedVMs, cachedStorage, timestamps) at lines 30–37, actor-isolated |

### Key Link Verification

| From                                          | To                                            | Via                                                   | Status   | Details                                                                                    |
| --------------------------------------------- | --------------------------------------------- | ----------------------------------------------------- | -------- | ------------------------------------------------------------------------------------------ |
| `PiHoleViewModel.startAutoRefresh()`          | `self.refresh()`                              | `[weak self]` + `guard let self` in Timer closure     | WIRED    | PiHole.swift lines 147–151: capture list present, guard-let present, Task calls `self.refresh()` |
| `PiHoleDetailViewModel.startAutoRefresh()`    | `self.refresh()`                              | `[weak self]` + `guard let self` in Timer closure     | WIRED    | PiHole.swift lines 641–645: same pattern                                                   |
| `ProxmoxViewModel.startAutoRefresh()`         | `self.refresh()`                              | `[weak self]` + `guard let self` in Timer closure     | WIRED    | Proxmox.swift lines 339–343: same pattern                                                  |
| `ProxmoxDetailViewModel.startAutoRefresh()`   | `self.refresh()`                              | `[weak self]` + `guard let self` in Timer closure     | WIRED    | Proxmox.swift lines 968–972: same pattern                                                  |
| `JellyfinClient.authenticate()` (and callers) | `cachedAuthToken/cachedUserId/authTokenTimestamp` | actor-isolated property access                    | WIRED    | `actor JellyfinClient` declaration at line 10; all mutable auth state properties are actor-isolated by Swift |
| `PiHoleClient.ensureAuthenticated()`          | `sid/csrf/sidExpiry`                          | actor-isolated property access                        | WIRED    | `actor PiHoleClient` declaration at line 3; session state properties are actor-isolated    |
| `ProxmoxClient` (multiple instances)          | `ProxmoxClient.netSnapshots` (now NetSnapshotStore) | `await NetSnapshotStore.shared.get/set`          | WIRED    | ProxmoxClient.swift lines 190, 202: reads use `await NetSnapshotStore.shared.get(config.id)`, writes use `await NetSnapshotStore.shared.set(config.id, value:)` |

### Requirements Coverage

| Requirement | Source Plan   | Description                                                                      | Status    | Evidence                                                                                |
| ----------- | ------------- | -------------------------------------------------------------------------------- | --------- | --------------------------------------------------------------------------------------- |
| MEM-01      | 02-01-PLAN.md | Timer retain cycles in PiHoleViewModel, PiHoleDetailViewModel, ProxmoxViewModel, ProxmoxDetailViewModel must use `[weak self]` | SATISFIED | All four Timer closures verified with `[weak self]` + guard-let in PiHole.swift (lines 147, 641) and Proxmox.swift (lines 339, 968) |
| MEM-02      | 02-02-PLAN.md | Race conditions on JellyfinClient cached auth state must be resolved              | SATISFIED | `actor JellyfinClient` at JellyfinClient.swift:10; all three mutable cache properties are actor-isolated |
| MEM-03      | 02-02-PLAN.md | Race conditions on PiHoleClient session state must be resolved                   | SATISFIED | `actor PiHoleClient` at PiHoleClient.swift:3; sid, csrf, sidExpiry are actor-isolated  |
| MEM-04      | 02-02-PLAN.md | Race condition on ProxmoxClient.netSnapshots static dictionary must be resolved  | SATISFIED | `private actor NetSnapshotStore` at ProxmoxClient.swift:13; no bare `static var` remains; all access goes through `await NetSnapshotStore.shared.get/set` |

No orphaned requirements — all four MEM-01 through MEM-04 were claimed by plans and verified in the codebase.

### Anti-Patterns Found

| File                  | Line | Pattern                             | Severity | Impact                                                              |
| --------------------- | ---- | ----------------------------------- | -------- | ------------------------------------------------------------------- |
| `Proxmox.swift`       | 1596 | `"Network management coming soon..."` | Info   | Pre-existing UI placeholder unrelated to thread safety phase        |
| `Proxmox.swift`       | 1641 | `// Recent Activity/Logs (placeholder)` | Info | Pre-existing comment unrelated to thread safety phase               |

No blockers or warnings. The two info-level items are pre-existing UI placeholders outside the scope of this phase.

### Human Verification Required

None. All thread safety changes are structural (actor declaration, capture list syntax) and fully verifiable through static code inspection. No runtime behavior that requires human observation to confirm.

### Commit Verification

All documented commit hashes exist in git history:

| Commit    | Description                                              |
| --------- | -------------------------------------------------------- |
| `2c14795` | fix(02-01): fix timer retain cycles in PiHoleViewModel and PiHoleDetailViewModel |
| `fb3d933` | fix(02-01): fix timer retain cycles in ProxmoxViewModel and ProxmoxDetailViewModel |
| `4c9215c` | feat(02-02): convert JellyfinClient from final class to actor |
| `143afcb` | feat(02-02): convert PiHoleClient from final class to actor |
| `4d1294b` | feat(02-02): convert ProxmoxClient from final class to actor with NetSnapshotStore |

### Gaps Summary

No gaps. All must-haves from both plans are implemented, substantive, and wired correctly.

**MEM-01 (Timer retain cycles):** All four target Timer closures — PiHoleViewModel, PiHoleDetailViewModel, ProxmoxViewModel, ProxmoxDetailViewModel — use the complete `[weak self] _ in / guard let self = self else { return } / Task { await self.refresh() }` pattern. No Timer.scheduledTimer call in any of the phase files lacks `[weak self]`.

**MEM-02/03 (Actor conversion):** JellyfinClient and PiHoleClient are declared `actor` at the top of their files. The previously-racy mutable instance properties (cachedUserId, cachedAuthToken, authTokenTimestamp; sid, csrf, sidExpiry) are now actor-isolated with zero code changes at call sites — callers already used `await` for all async methods.

**MEM-04 (Static dictionary):** The bare `private static var netSnapshots` is gone from ProxmoxClient. A dedicated `private actor NetSnapshotStore` (not `nonisolated(unsafe)`) provides genuine concurrent isolation for the shared dictionary. The two access sites in the stats calculation method correctly use `await NetSnapshotStore.shared.get/set`. All three clearCache() call sites in Proxmox.swift correctly use `await` in async contexts.

---

_Verified: 2026-03-03T00:00:00Z_
_Verifier: Claude (gsd-verifier)_
