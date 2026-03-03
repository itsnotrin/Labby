# Labby Bug Fix Milestone

## What This Is

Labby is an iOS SwiftUI app for managing home lab services (Proxmox, Jellyfin, Pi-hole, qBittorrent). This milestone addresses 32 bugs discovered through a comprehensive codebase audit, ranging from crash-causing force-unwraps and broken API calls to memory leaks, race conditions, and UI inconsistencies.

## Core Value

Fix all identified bugs to make Labby stable, reliable, and correct — crashes and broken features (like Pi-hole toggle, Proxmox backup, qBittorrent alt-mode) are the highest priority.

## Requirements

### Validated

- ✓ Proxmox VM/container management and monitoring — existing
- ✓ Jellyfin library browsing and media detail views — existing
- ✓ Pi-hole statistics and blocking status display — existing
- ✓ qBittorrent torrent listing and speed monitoring — existing
- ✓ Multi-home layout system with widget grid — existing
- ✓ Service configuration with Keychain-stored secrets — existing
- ✓ Dark/light theme support via AppearanceManager — existing

### Active

- [ ] Fix all crash-causing force-unwraps and unsafe code
- [ ] Fix broken API calls (Pi-hole toggle, Proxmox backup)
- [ ] Fix memory leaks from timer retain cycles in all ViewModels
- [ ] Fix race conditions on shared mutable state in service clients
- [ ] Fix navigation bugs (double-nested NavigationLinks, nested NavigationStacks)
- [ ] Fix incorrect torrent state counting and alt-mode toggle in qBittorrent
- [ ] Fix session management issues (per-instance scoping, caching, retry)
- [ ] Fix UI inconsistencies (alerts, empty states, search, widget layout)
- [ ] Fix performance issues (DateFormatter allocation, URLSession creation)

### Out of Scope

- New features — this milestone is bug fixes only
- macOS support — Labby targets iOS only
- Architecture refactoring beyond what's needed for fixes
- Adding tests — focus on fixing bugs, not adding test coverage

## Context

- **Platform:** iOS (SwiftUI), Swift
- **Architecture:** MVVM with ObservableObject ViewModels, service client classes per integration
- **Services:** Proxmox, Jellyfin, Pi-hole (v6 API), qBittorrent
- **Storage:** Keychain for secrets, UserDefaults for preferences and session cache
- **Navigation:** Mix of NavigationView and NavigationStack
- **Known patterns:** Auto-refresh timers in ViewModels, static caches in Jellyfin ViewModels, ServiceManager singleton

## Constraints

- **No breaking changes**: Bug fixes must not change external behavior (except fixing broken behavior)
- **iOS only**: No need to handle macOS/`NSColor` paths
- **Backward compatible**: Existing UserDefaults and Keychain data must continue to work

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Fix all 32 bugs in one milestone | Comprehensive cleanup before adding features | — Pending |
| iOS-only target | macOS compile issues (systemGray6) not relevant | — Pending |
| Use `[weak self]` for timer closures | Standard Swift pattern for breaking retain cycles | — Pending |
| Scope PiHole session keys per-instance | Use service ID in UserDefaults keys to support multiple instances | — Pending |

---
*Last updated: 2026-03-03 after initialization*
