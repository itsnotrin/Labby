---
phase: 01-crashes-navigation
plan: "01"
subsystem: ui
tags: [swiftui, navigation, crash-fix, toolbar, homeview]

# Dependency graph
requires: []
provides:
  - Safe AddWidgetView toolbar with if-let guard replacing force-unwrap crash
  - HomeWidgetCard as pure display component with no NavigationLink
  - Single navigation ownership: HomeGridView owns all per-kind NavigationLink wrapping
affects: [home-widget-layout, navigation-stack-cleanup]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Navigation ownership: container (HomeGridView) owns NavigationLink, child card (HomeWidgetCard) is pure display"
    - "Safe optional unwrapping: if let cfg = selectedConfig in toolbar actions, never force-unwrap"

key-files:
  created: []
  modified:
    - Labby/Views/Core/HomeView.swift

key-decisions:
  - "Keep inner Form toolbar (safe if-let) and delete outer NavigationView toolbar (force-unwrap crash)"
  - "HomeWidgetCard renders widgetContent directly; navigation belongs to HomeGridView"

patterns-established:
  - "Container-owns-navigation: NavigationLink lives in the parent grid, not the child card"
  - "Safe-toolbar: all toolbar actions use if-let unwrapping, never ! force-unwraps"

requirements-completed: [CRASH-01, CRASH-02, NAV-01]

# Metrics
duration: 4min
completed: 2026-03-03
---

# Phase 1 Plan 1: Fix AddWidgetView crash and double-push navigation Summary

**Eliminated two crash vectors: force-unwrap in AddWidgetView toolbar replaced with if-let guard, and NavigationLink removed from HomeWidgetCard to fix double-push navigation**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-03T10:17:45Z
- **Completed:** 2026-03-03T10:21:45Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Deleted the outer AddWidgetView toolbar that crashed on nil `selectedServiceId!` and `selectedConfig!` force-unwraps
- Consolidated navigation title and display mode onto the inner Form (where the safe toolbar lives)
- Removed NavigationLink from HomeWidgetCard.body, making it a pure display component
- Deleted unused `destinationView(for:)` function from HomeWidgetCard
- HomeGridView retains sole ownership of per-kind NavigationLink wrapping (qbittorrent, pihole, proxmox, jellyfin)

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove unsafe outer toolbar from AddWidgetView** - `7c2991d` (fix)
2. **Task 2: Remove NavigationLink from HomeWidgetCard body** - `2cd7158` (fix)

**Plan metadata:** (final docs commit — see below)

## Files Created/Modified
- `Labby/Views/Core/HomeView.swift` - Removed outer unsafe toolbar (force-unwrap crash) and HomeWidgetCard NavigationLink (double-push bug)

## Decisions Made
- Keep the inner Form toolbar (already had correct `if let cfg = selectedConfig` guard and `normalizeColumnForSize()` call) rather than trying to fix the outer one. The inner one was already complete and correct.
- HomeWidgetCard body simplified to `if isEditing { widgetContent.onTapGesture { onEdit() } } else { widgetContent }` — the editing tap gesture is still needed since HomeGridView only wraps non-editing widgets in NavigationLink.

## Deviations from Plan

**1. [Rule 1 - Bug] Brace mismatch after initial outer toolbar deletion**
- **Found during:** Task 1 (build verification)
- **Issue:** First edit removed the outer toolbar block but missed restoring the closing `}` for the NavigationView wrapper — resulted in "Expected '}' in struct" build error
- **Fix:** Added back the missing closing brace for NavigationView
- **Files modified:** Labby/Views/Core/HomeView.swift
- **Verification:** Build succeeded after fix
- **Committed in:** 7c2991d (part of Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - brace mismatch bug during edit)
**Impact on plan:** Necessary correction during execution, no scope creep.

## Issues Encountered
- `xcodebuild` destination `platform=iOS Simulator,name=iPhone 16` not available (no iPhone 16 simulator installed). Used `iPhone 17` instead — no functional impact.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- AddWidgetView crash on nil optional is fixed
- Double-push navigation eliminated from HomeWidgetCard
- HomeGridView navigation structure untouched and intact
- Ready for remaining crash/navigation fixes in Phase 1

---
*Phase: 01-crashes-navigation*
*Completed: 2026-03-03*
