# Phase 1: Crashes & Navigation - Context

**Gathered:** 2026-03-03
**Status:** Ready for planning

<domain>
## Phase Boundary

Eliminate force-unwrap crashes in AddWidgetView and fix double-nested navigation patterns in HomeGridView and Proxmox views. Four bugs: CRASH-01, CRASH-02, NAV-01, NAV-02.

</domain>

<decisions>
## Implementation Decisions

### Claude's Discretion

All implementation decisions are Claude's discretion — these are straightforward bug fixes.

**Navigation ownership (NAV-01):**
- HomeGridView currently wraps HomeWidgetCard in NavigationLink per service kind (lines 722-864)
- HomeWidgetCard.body also wraps in NavigationLink when not editing (line 341)
- Claude decides: Remove NavigationLink from HomeWidgetCard, keep navigation in HomeGridView. Rationale: HomeGridView already handles per-service-kind routing with specific destination views. HomeWidgetCard should be a pure display component.

**Proxmox nested NavigationStack (NAV-02):**
- ProxmoxDetailView (line 669), ProxmoxVMsView (line 1440), ProxmoxContainersView (line 1496) each create NavigationStack but are already pushed inside one from ProxmoxView
- Claude decides: Remove inner NavigationStack from these views. They are navigation destinations, not roots.

**Toolbar consolidation (CRASH-01, CRASH-02):**
- AddWidgetView has two toolbars: inner on Form (lines 1508-1559, safe, uses if-let, calls normalizeColumnForSize) and outer on NavigationView (lines 1566-1601, unsafe, uses force-unwraps, skips normalizeColumnForSize)
- Claude decides: Delete the outer toolbar entirely. Keep the inner toolbar which is safe and complete.

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- `destinationView(for:)` in HomeWidgetCard (used for routing) — can be extracted or left unused once navigation moves to HomeGridView
- HomeGridView already has per-kind routing logic for qbittorrent, pihole, proxmox, jellyfin

### Established Patterns
- NavigationView used in HomeView (line 62) — this is the navigation root
- NavigationStack used in Proxmox views — inconsistent with the NavigationView root
- HomeWidgetCard wraps in NavigationLink only when `!isEditing`

### Integration Points
- HomeGridView renders both single-widget rows (700-787) and multi-widget rows (788+)
- Both paths need the NavigationLink fix
- ProxmoxView pushes ProxmoxDetailView via NavigationLink
- ProxmoxDetailView has a NavigationGridSection that pushes VMsView/ContainersView

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

*Phase: 01-crashes-navigation*
*Context gathered: 2026-03-03*
