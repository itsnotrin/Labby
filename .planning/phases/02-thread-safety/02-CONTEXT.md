# Phase 2: Thread Safety - Context

**Gathered:** 2026-03-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Resolve all race conditions on shared mutable state in service clients and fix timer retain cycles in PiHole and Proxmox ViewModels. Four bugs: MEM-01, MEM-02, MEM-03, MEM-04.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion

All implementation decisions are Claude's discretion — these are technical bug fixes with clear patterns in the existing codebase.

**Timer retain cycles (MEM-01):**
- PiHoleViewModel, PiHoleDetailViewModel (PiHole.swift) and ProxmoxViewModel, ProxmoxDetailViewModel (Proxmox.swift) all use `Timer.scheduledTimer` with implicit `self` capture
- Prior decision (project init): Use `[weak self]` for timer closures
- QBittorrentViewModel already uses the safer Task-based pattern (`Task.sleep()` + `[weak self]`) and ProxmoxDetailViewModelLarge already uses `[weak self]` with Timer
- Claude decides approach per ViewModel based on existing patterns

**JellyfinClient race condition (MEM-02):**
- `cachedUserId`, `cachedAuthToken`, `authTokenTimestamp` are unprotected mutable instance properties
- JellyfinClient is NOT @MainActor — concurrent async calls can race on token read/write
- No existing synchronization primitives anywhere in the codebase (no actors, locks, or queues)
- Claude decides synchronization mechanism

**PiHoleClient race condition (MEM-03):**
- `sid`, `csrf`, `sidExpiry` are unprotected mutable instance properties
- PiHoleClient is NOT @MainActor — concurrent calls to `ensureAuthenticated()` and `login()` can race
- Claude decides synchronization mechanism (should be consistent with MEM-02 approach)

**ProxmoxClient race condition (MEM-04):**
- `netSnapshots` is a static dictionary mutated by multiple ProxmoxClient instances — most critical race
- Additional unprotected instance cache: `cachedNodes`, `cachedVMs`, `cachedStorage` + timestamps
- Claude decides synchronization mechanism and whether to protect additional cache state defensively

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- QBittorrentViewModel Task-based timer pattern (lines 393-400) — reference for MEM-01 modernization
- ProxmoxDetailViewModelLarge [weak self] Timer pattern (line 1806) — reference for minimal MEM-01 fix

### Established Patterns
- All ViewModels are @MainActor — UI updates are already main-thread safe
- All client methods are async throws — Swift structured concurrency is used throughout
- Service clients (JellyfinClient, PiHoleClient, ProxmoxClient) are NOT @MainActor
- No existing locking, actors, or DispatchQueue synchronization in the codebase

### Integration Points
- Timer closures in 4 ViewModels call `self.refresh()` or `self.load()` — all async @MainActor methods
- JellyfinClient auth state is read/written during `authenticate()`, `testConnection()`, and every API call
- PiHoleClient session state is read/written during `ensureAuthenticated()`, `login()`, and persistence methods
- ProxmoxClient.netSnapshots is read/written during network stats calculation across all instances

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

*Phase: 02-thread-safety*
*Context gathered: 2026-03-03*
