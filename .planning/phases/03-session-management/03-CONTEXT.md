# Phase 3: Session Management - Context

**Gathered:** 2026-03-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Fix session scoping, caching, and recovery across all services. Five bugs: SESS-01, SESS-02, SESS-03, SESS-04, SESS-05. No new session management abstractions — fix each bug at its source.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion

All implementation decisions are Claude's discretion — these are technical bug fixes with established patterns in the codebase.

**PiHole session scoping (SESS-01):**
- Prior decision (project init): Use service ID in UserDefaults keys to support multiple instances
- Current keys are hardcoded strings: `defaultsKeySID`, `defaultsKeyCSRF`, `defaultsKeySidExpiry`
- Fix: Incorporate `config.id` into key names so each PiHole instance has isolated storage
- Claude decides exact key format

**ServiceManager client caching (SESS-02):**
- `client(for:)` currently creates a NEW client instance on every call — cached auth tokens are lost
- Fix: Add an in-memory dictionary keyed by `config.id` to reuse client instances
- Cache lifetime: per-app-session (in-memory) — sufficient since PiHole persists tokens to UserDefaults/Keychain and Jellyfin tokens have 1-hour expiry
- Claude decides cache invalidation strategy (e.g., when service config changes)

**qBittorrent session cookies (SESS-03):**
- qBittorrent already has an in-memory static cookie cache with NSLock (`_cookieCache`, `_cookieLock`)
- Uses ephemeral URLSession — no persistent cookie jar
- Issue: `makeSession()` creates a new URLSession per API call, cookie only set via header extraction
- Claude decides whether to persist cookies or ensure the existing in-memory cache is sufficient

**qBittorrent retry on 403 (SESS-04):**
- No 403 retry logic exists — 403 results in `ServiceError.httpStatus(403)`
- PiHole already has a clear-and-re-auth pattern on 401 — use as reference
- Fix: On 403, clear cached cookie, re-authenticate, retry the original request once
- Claude decides exact retry mechanism (single retry, no exponential backoff — this is session expiry, not a transient error)

**PiHole Keychain migration (SESS-05):**
- Session tokens (SID, CSRF, expiry) currently stored in plaintext UserDefaults
- `KeychainStorage.shared` already exists with `saveSecret()`/`loadSecret()`/`deleteSecret()`
- Passwords already use Keychain via `passwordKeychainKey` — session tokens should follow same pattern
- Migration: Read existing UserDefaults values, save to Keychain, delete from UserDefaults — transparent to user
- Claude decides Keychain key naming convention (should incorporate config.id per SESS-01)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `KeychainStorage.shared` (Managers/KeychainStorage.swift) — saveSecret/loadSecret/deleteSecret, uses Security framework
- PiHole re-auth on 401 pattern (PiHoleClient.swift:510,517) — clear session, next call triggers ensureAuthenticated()
- qBittorrent NSLock-protected cookie cache (QBittorrent.swift:75-76, 92-101) — existing thread-safe static cache
- Jellyfin token expiry check (JellyfinClient.swift:87-89) — 1-hour expiry before reauth

### Established Patterns
- Service clients are now actors (Phase 2) — PiHoleClient, JellyfinClient, ProxmoxClient
- QBittorrentClient is still a `final class` (not converted in Phase 2 — wasn't required)
- All client methods are async throws
- ServiceManager.client(for:) creates new instances per call (no cache)
- PiHole passwords stored in Keychain; session tokens in UserDefaults (inconsistent)

### Integration Points
- ServiceManager.swift line 40: `client(for config:)` — switch on service kind, returns ServiceClient
- PiHoleClient.swift lines 28, 533, 510: loadSessionCache/saveSessionCache/clearSessionCache
- QBittorrentClient.swift lines 204-213: cookie extraction from Set-Cookie header
- QBittorrent.swift line 139-140: getCookie → cachedCookie() → loginAndGetCookie()

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

*Phase: 03-session-management*
*Context gathered: 2026-03-03*
