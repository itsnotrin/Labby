//
//  HomeView.swift
//  Labby
//
//  Created by Ryan Wiecz on 27/07/2025.
//

import SwiftUI

struct HomeView: View {

    @ObservedObject private var serviceManager = ServiceManager.shared
    @ObservedObject private var layoutStore = HomeLayoutStore.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("autoRefreshInterval") private var autoRefreshInterval = 30.0
    @AppStorage("showServiceStats") private var showServiceStats = true
    @State private var refreshTask: Task<Void, Never>? = nil
    @State private var lastFetchByWidget: [UUID: Date] = [:]

    @State private var homes: [String] =
        UserDefaults.standard.stringArray(forKey: "homes") ?? ["Default Home"]
    @State private var selectedHome: String =
        UserDefaults.standard.string(forKey: "selectedHome") ?? "Default Home"
    @State private var isAddingHome: Bool = false
    @State private var testingServiceId: UUID?
    @State private var testResult: String?
    @State private var testError: String?
    @State private var isEditingLayout: Bool = false
    @State private var editingWidget: HomeWidget?
    @State private var stats: [UUID: ServiceStatsPayload] = [:]
    @State private var isPresentingAddWidget: Bool = false
    @State private var showAutoLayoutAlert: Bool = false
    @State private var isPresentingServicesView: Bool = false

    private var filteredServices: [ServiceConfig] {
        serviceManager.services.filter { $0.home == selectedHome }
    }

    private var displayWidgets: [HomeWidget] {
        layoutStore.layout(for: selectedHome).widgets.filter { w in
            filteredServices.contains(where: { $0.id == w.serviceId })
        }
    }

    private var headerText: String {
        if serviceManager.services.isEmpty {
            return "No Services Added"
        } else {
            return "No Services in \(selectedHome)"
        }
    }

    private var subheaderText: String {
        if serviceManager.services.isEmpty {
            return "Add services in the Services tab to see them here"
        } else {
            return "Add services to the \(selectedHome) home in the Services tab"
        }
    }

    var body: some View {
        NavigationView {
            HomeContentView(
                filteredServicesIsEmpty: filteredServices.isEmpty,
                displayWidgets: displayWidgets,
                services: serviceManager.services,
                selectedHome: selectedHome,
                isEditingLayout: isEditingLayout,
                stats: stats,
                onEditWidget: { editingWidget = $0 },
                onStats: { serviceId, payload in
                    stats[serviceId] = payload
                },
                onMove: { sourceId, targetId in
                    var layout = layoutStore.layout(for: selectedHome)
                    guard
                        let sourceIndex = layout.widgets.firstIndex(where: { $0.id == sourceId }),
                        let targetIndex = layout.widgets.firstIndex(where: { $0.id == targetId })
                    else { return }
                    let adjustedIndex = sourceIndex < targetIndex ? max(0, targetIndex - 1) : targetIndex
                    layout.moveWidget(id: sourceId, to: adjustedIndex)
                    layoutStore.setLayout(layout)
                },
                showServiceStats: showServiceStats,
                shouldSelfFetch: false
            )
            .toolbar {
                HomeToolbarLeading(
                    homes: $homes,
                    selectedHome: $selectedHome,
                    isAddingHome: $isAddingHome
                )
                HomeToolbarTrailing(
                    isEditingLayout: $isEditingLayout,
                    isPresentingAddWidget: $isPresentingAddWidget,
                    isPresentingServicesView: $isPresentingServicesView,
                    onAutoLayout: {
                        var layout = layoutStore.layout(for: selectedHome)
                        layout.applyAutoLayout(services: serviceManager.services)
                        layoutStore.setLayout(layout)
                        showAutoLayoutAlert = true
                    }
                )
            }
        }
        .sheet(isPresented: $isAddingHome) {
            AddHomeView(homes: $homes, selectedHome: $selectedHome)
        }
        .sheet(item: $editingWidget) { widget in
            if let cfg = serviceManager.services.first(where: { $0.id == widget.serviceId }) {
                EditWidgetView(
                    widget: widget,
                    config: cfg,
                    onSave: { updated in
                        var layout = layoutStore.layout(for: selectedHome)
                        layout.updateWidget(updated)
                        layoutStore.setLayout(layout)
                        editingWidget = nil
                    },
                    onDelete: {
                        layoutStore.removeWidget(id: widget.id, from: selectedHome)
                        editingWidget = nil
                    }
                )
            } else {
                Text("Service not found for this widget.")
                    .padding()
            }
        }
        .sheet(isPresented: $isPresentingAddWidget) {
            AddWidgetView(
                services: serviceManager.services.filter { $0.home == selectedHome },
                onAdd: { newWidget in
                    var layout = layoutStore.layout(for: selectedHome)
                    layout.addWidget(newWidget)
                    layoutStore.setLayout(layout)
                }
            )
        }
        .alert("Test Result", isPresented: .constant(testResult != nil || testError != nil)) {
            Button("OK") {
                testResult = nil
                testError = nil
            }
        } message: {
            if let result = testResult {
                Text(result)
            } else if let error = testError {
                Text(error)
            }
        }
        .alert("Auto Layout Applied", isPresented: $showAutoLayoutAlert) {
            Button("OK") { }
        } message: {
            Text("Dashboard has been automatically organized with optimal widget sizes and layouts for all services.")
        }
        .sheet(isPresented: $isPresentingServicesView) {
            ServicesView()
        }
        .onAppear {
            if let stored = UserDefaults.standard.string(forKey: "selectedHome") {
                selectedHome = stored
            }
            let serviceHomes = Set(serviceManager.services.map { $0.home })
            var updated = homes
            for h in serviceHomes where !updated.contains(h) {
                updated.append(h)
            }
            if updated != homes {
                homes = updated
                UserDefaults.standard.set(updated, forKey: "homes")
            }
            if !homes.contains(selectedHome) {
                selectedHome = homes.first ?? "Default Home"
                UserDefaults.standard.set(selectedHome, forKey: "selectedHome")
            }
            // Ensure a layout exists for this home; create defaults if empty
            var layout = layoutStore.layout(for: selectedHome)
            if layout.widgets.isEmpty {
                layout = HomeLayoutDefaults.generateLayout(
                    homeName: selectedHome, services: serviceManager.services)
                layoutStore.setLayout(layout)
            }
            // Start periodic stats refresh
            startRefreshTask()
        }
        .onChange(of: autoRefreshInterval) {
            restartRefreshTask()
        }
        .onChange(of: showServiceStats) {
            restartRefreshTask()
        }
        .onChange(of: selectedHome) {
            // Clear cached stats when switching homes to avoid stale data
            stats.removeAll()
            lastFetchByWidget.removeAll()
            restartRefreshTask()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                restartRefreshTask()
            case .background, .inactive:
                refreshTask?.cancel()
                refreshTask = nil
            @unknown default:
                break
            }
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
        }
    }

    private func testConnection(_ config: ServiceConfig) async {
        testingServiceId = config.id
        let client = serviceManager.client(for: config)
        do {
            let info = try await client.testConnection()
            print("[Service Test] \(config.displayName): \(info)")
            testResult = info
        } catch {
            print("[Service Test] \(config.displayName) error: \(error.localizedDescription)")
            testError = error.localizedDescription
        }
        testingServiceId = nil
    }

    // Periodic refresh logic
    private func startRefreshTask() {
        refreshTask?.cancel()
        guard showServiceStats else { return }
        // Interval computed per-iteration based on widget overrides
        refreshTask = Task {
            await refreshAllStatsOnce()
            while !Task.isCancelled {
                let interval = max(1.0, minEffectiveInterval())
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                await refreshAllStatsOnce()
            }
        }
    }

    private func restartRefreshTask() {
        refreshTask?.cancel()
        refreshTask = nil
        startRefreshTask()
    }

    private func minEffectiveInterval() -> Double {
        let base = autoRefreshInterval
        let overrides = displayWidgets.compactMap { $0.refreshIntervalOverride }
        let minOverride = overrides.min()
        return min(base, minOverride ?? base)
    }

    private func refreshAllStatsOnce() async {
        guard showServiceStats else { return }
        let widgets = displayWidgets
        let due = widgets.compactMap { w -> (HomeWidget, ServiceConfig)? in
            guard
                let cfg = serviceManager.services.first(where: {
                    $0.id == w.serviceId && $0.home == selectedHome
                })
            else { return nil }
            let interval = w.refreshIntervalOverride ?? autoRefreshInterval
            if let last = lastFetchByWidget[w.id], Date().timeIntervalSince(last) < interval {
                return nil
            }
            return (w, cfg)
        }

        await withTaskGroup(of: (UUID, UUID, ServiceStatsPayload)?.self) { group in
            for (w, cfg) in due {
                group.addTask {
                    let client = await MainActor.run { ServiceManager.shared.client(for: cfg) }
                    do {
                        let payload = try await client.fetchStats()
                        return (w.id, w.serviceId, payload)
                    } catch {
                        // Ignore individual fetch errors
                        return nil
                    }
                }
            }
            for await result in group {
                if let (widgetId, serviceId, payload) = result {
                    await MainActor.run {
                        stats[serviceId] = payload
                        lastFetchByWidget[widgetId] = Date()
                    }
                }
            }
        }
    }

    // Build rows for a 2-column grid: large widgets occupy their own row, small widgets pair per row
    private func buildRows(from widgets: [HomeWidget]) -> [[HomeWidget]] {
        var rows: [[HomeWidget]] = []
        var buffer: [HomeWidget] = []
        for w in widgets {
            if w.size == .large {
                if !buffer.isEmpty {
                    rows.append(buffer)
                    buffer.removeAll()
                }
                rows.append([w])
            } else {
                buffer.append(w)
                if buffer.count == 2 {
                    rows.append(buffer)
                    buffer.removeAll()
                }
            }
        }
        if !buffer.isEmpty { rows.append(buffer) }
        return rows
    }

    struct HomeWidgetCard: View {
        let widget: HomeWidget
        let config: ServiceConfig
        let stats: ServiceStatsPayload?
        let isEditing: Bool
        let onEdit: () -> Void
        let onStats: (ServiceStatsPayload) -> Void
        let showServiceStats: Bool
        let shouldSelfFetch: Bool

        @State private var isLoadingStats = false

        var body: some View {
            let height: CGFloat = {
                switch widget.size {
                case .small: return 120
                case .medium: return 180
                case .wide: return 140
                case .large: return 240
                case .tall: return 280
                case .extraWide: return 320
                case .auto: return 150
                }
            }()

            let contentOverflows = !HomeLayout.validateWidgetSize(widget.size, for: widget.metrics, serviceKind: config.kind, tolerance: false)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: iconName(for: config.kind))
                        .font(.title2)
                    Spacer()
                    if isEditing {
                        Image(systemName: "slider.horizontal.3")
                            .foregroundStyle(.secondary)
                    }
                }

                Text(
                    widget.titleOverride?.isEmpty == false
                        ? (widget.titleOverride ?? "") : config.displayName
                )
                .font({
                    switch widget.size {
                    case .small: return .subheadline
                    case .medium, .wide: return .headline
                    case .large, .tall, .extraWide: return .title2
                    case .auto: return .headline
                    }
                }())
                .foregroundStyle(.primary)

                if showServiceStats {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(statLines(), id: \.self) { line in
                            Text(line)
                                .font({
                                    switch widget.size {
                                    case .small: return .caption
                                    case .medium, .wide: return .subheadline
                                    case .large, .tall, .extraWide: return .body
                                    case .auto: return .subheadline
                                    }
                                }())
                                .foregroundStyle(.secondary)
                        }
                        if stats == nil {
                            HStack(spacing: 6) {
                                ProgressView().scaleEffect(0.7)
                                Text("Loading...")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(
                maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading
            )
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 5)
            }
            .overlay(alignment: .topTrailing) {
                if isEditing {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(contentOverflows ? Color.orange : Color(UIColor.quaternaryLabel), lineWidth: contentOverflows ? 2 : 0.5)
            }
            .overlay(alignment: .bottomTrailing) {
                if contentOverflows && !isEditing {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(8)
                }
            }
            .onTapGesture {
                if isEditing { onEdit() }
            }
            .task {
                guard shouldSelfFetch && showServiceStats else { return }
                guard !isLoadingStats else { return }
                isLoadingStats = true
                let client = ServiceManager.shared.client(for: config)
                do {
                    let payload = try await client.fetchStats()
                    onStats(payload)
                } catch {
                    // Swallow errors for now; could surface in UI if desired
                }
                isLoadingStats = false
            }
        }

        private func iconName(for kind: ServiceKind) -> String {
            switch kind {
            case .proxmox: return "server.rack"
            case .jellyfin: return "tv"
            case .qbittorrent: return "arrow.down.circle"
            case .pihole: return "shield.lefthalf.filled"
            }
        }

        private func statLines() -> [String] {
            guard let stats = stats else { return [] }
            switch (config.kind, widget.metrics) {
            case (.proxmox, .proxmox(let metrics)):
                guard case .proxmox(let p) = stats else { return [] }
                var lines: [String] = []
                for m in metrics {
                    switch m {
                    case .cpuPercent:
                        lines.append("CPU: \(StatFormatter.formatPercent(p.cpuUsagePercent))")
                    case .memoryUsedBytes:
                        lines.append(
                            "Memory: \(StatFormatter.formatBytes(p.memoryUsedBytes)) / \(StatFormatter.formatBytes(p.memoryTotalBytes))"
                        )
                    case .memoryPercent:
                        let percent =
                            p.memoryTotalBytes > 0
                            ? (Double(p.memoryUsedBytes) / Double(p.memoryTotalBytes)) * 100.0 : 0
                        lines.append("Memory: \(StatFormatter.formatPercent(percent))")
                    case .totalCTs:
                        lines.append("CTs: \(p.totalCTs)")
                    case .totalVMs:
                        lines.append("VMs: \(p.totalVMs)")
                    case .runningCount:
                        lines.append("Running: \(p.runningCount)")
                    case .stoppedCount:
                        lines.append("Stopped: \(p.stoppedCount)")
                    case .netUpBps:
                        lines.append("Up: \(StatFormatter.formatRateBytesPerSec(p.netUpBps))")
                    case .netDownBps:
                        lines.append("Down: \(StatFormatter.formatRateBytesPerSec(p.netDownBps))")
                    }
                }
                return lines

            case (.jellyfin, .jellyfin(let metrics)):
                guard case .jellyfin(let j) = stats else { return [] }
                var lines: [String] = []
                for m in metrics {
                    switch m {
                    case .tvShowsCount:
                        lines.append("TV Shows: \(j.tvShows)")
                    case .moviesCount:
                        lines.append("Movies: \(j.movies)")
                    case .userCount:
                        lines.append("Users: \(j.users)")
                    }
                }
                return lines

            case (.qbittorrent, .qbittorrent(let metrics)):
                guard case .qbittorrent(let q) = stats else { return [] }
                var lines: [String] = []
                for m in metrics {
                    switch m {
                    case .seedingCount:
                        lines.append("Seeding: \(q.seeding)")
                    case .downloadingCount:
                        lines.append("Downloading: \(q.downloading)")
                    case .uploadSpeedBytesPerSec:
                        lines.append(
                            "Up: \(StatFormatter.formatRateBytesPerSec(q.uploadSpeedBytesPerSec))")
                    case .downloadSpeedBytesPerSec:
                        lines.append(
                            "Down: \(StatFormatter.formatRateBytesPerSec(q.downloadSpeedBytesPerSec))"
                        )
                    }
                }
                return lines

            case (.pihole, .pihole(let metrics)):
                guard case .pihole(let p) = stats else { return [] }
                var lines: [String] = []
                for m in metrics {
                    switch m {
                    case .dnsQueriesToday:
                        lines.append("Queries: \(p.dnsQueriesToday)")
                    case .adsBlockedToday:
                        lines.append("Blocked: \(p.adsBlockedToday)")
                    case .adsPercentageToday:
                        lines.append(
                            "Block %: \(p.adsPercentageToday)")
                    case .uniqueClients:
                        lines.append("Clients: \(p.uniqueClients)")
                    case .queriesForwarded:
                        lines.append("Forwarded: \(p.queriesForwarded)")
                    case .queriesCached:
                        lines.append("Cached: \(p.queriesCached)")
                    case .domainsBeingBlocked:
                        lines.append("Domains Blocked: \(p.domainsBeingBlocked)")
                    case .gravityLastUpdatedRelative:
                        lines.append("Gravity: \(p.gravityLastUpdatedRelative ?? "-")")
                    case .blockingStatus:
                        let statusText = (p.status ?? "-")
                        lines.append("Status: \(statusText.capitalized)")
                    }
                }
                return lines

            default:
                return []
            }
        }
    }

    struct HomeContentView: View {
        let filteredServicesIsEmpty: Bool
        let displayWidgets: [HomeWidget]
        let services: [ServiceConfig]
        let selectedHome: String
        let isEditingLayout: Bool
        let stats: [UUID: ServiceStatsPayload]
        let onEditWidget: (HomeWidget) -> Void
        let onStats: (UUID, ServiceStatsPayload) -> Void
        let onMove: (UUID, UUID) -> Void
        let showServiceStats: Bool
        let shouldSelfFetch: Bool

        var body: some View {
            ScrollView {
                if filteredServicesIsEmpty {
                    EmptyStateView(
                        header: "No Services Added",
                        subheader: "Add services in the Services tab to see them here"
                    )
                } else {
                    HomeGridView(
                        widgets: displayWidgets,
                        services: services,
                        selectedHome: selectedHome,
                        isEditingLayout: isEditingLayout,
                        stats: stats,
                        onEditWidget: onEditWidget,
                        onStats: onStats,
                        onMove: onMove,
                        showServiceStats: showServiceStats,
                        shouldSelfFetch: shouldSelfFetch
                    )
                    .padding()
                }
            }
        }
    }

    struct HomeGridView: View {
        let widgets: [HomeWidget]
        let services: [ServiceConfig]
        let selectedHome: String
        let isEditingLayout: Bool
        let stats: [UUID: ServiceStatsPayload]
        let onEditWidget: (HomeWidget) -> Void
        let onStats: (UUID, ServiceStatsPayload) -> Void
        let onMove: (UUID, UUID) -> Void
        let showServiceStats: Bool
        let shouldSelfFetch: Bool

        private var rows: [[HomeWidget]] {
            var out: [[HomeWidget]] = []
            var buffer: [HomeWidget] = []
            for w in widgets {
                if w.size.columnSpan > 1 {
                    // Multi-column widgets (wide, large, extraWide) need their own row
                    if !buffer.isEmpty {
                        out.append(buffer)
                        buffer.removeAll()
                    }
                    out.append([w])
                } else {
                    // Single-column widgets (small, medium, tall) can share rows
                    buffer.append(w)
                    if buffer.count == 2 {
                        out.append(buffer)
                        buffer.removeAll()
                    }
                }
            }
            if !buffer.isEmpty { out.append(buffer) }
            return out
        }

        struct ReorderableCard<Content: View>: View {
            let id: UUID
            let isEditing: Bool
            let onMove: (UUID, UUID) -> Void
            @ViewBuilder let content: () -> Content
            @State private var isTargeted = false

            var body: some View {
                let view = content()
                if isEditing {
                    view
                        .onDrag { NSItemProvider(object: id.uuidString as NSString) }
                        .dropDestination(for: String.self) { items, _ in
                            if let first = items.first,
                               let sourceId = UUID(uuidString: first),
                               sourceId != id {
                                onMove(sourceId, id)
                            }
                            return true
                        } isTargeted: { over in
                            isTargeted = over
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(isTargeted ? Color.accentColor : .clear,
                                              style: StrokeStyle(lineWidth: 3, dash: [6]))
                        )
                } else {
                    view
                }
            }
        }

        var body: some View {
            Grid(horizontalSpacing: 16, verticalSpacing: 16) {
                ForEach(rows.indices, id: \.self) { index in
                    let row = rows[index]
                    GridRow {
                        if row.count == 1 {
                            let w = row[0]
                            if let cfg = services.first(where: {
                                $0.id == w.serviceId && $0.home == selectedHome
                            }) {
                                if isEditingLayout {
                                    ReorderableCard(id: w.id, isEditing: isEditingLayout, onMove: onMove) {
                                        HomeWidgetCard(
                                            widget: w,
                                            config: cfg,
                                            stats: stats[w.serviceId],
                                            isEditing: isEditingLayout,
                                            onEdit: { onEditWidget(w) },
                                            onStats: { payload in onStats(w.serviceId, payload) },
                                            showServiceStats: showServiceStats,
                                            shouldSelfFetch: shouldSelfFetch
                                        )
                                    }
                                    .gridCellColumns(w.size.columnSpan)
                                } else {
                                    if cfg.kind == .qbittorrent {
                                        NavigationLink {
                                            QBittorrentView(config: cfg)
                                        } label: {
                                            HomeWidgetCard(
                                                widget: w,
                                                config: cfg,
                                                stats: stats[w.serviceId],
                                                isEditing: isEditingLayout,
                                                onEdit: { onEditWidget(w) },
                                                onStats: { payload in onStats(w.serviceId, payload) },
                                                showServiceStats: showServiceStats,
                                                shouldSelfFetch: shouldSelfFetch
                                            )
                                        }
                                        .gridCellColumns(w.size.columnSpan)
                                    } else if cfg.kind == .pihole {
                                        NavigationLink {
                                            PiHoleView(config: cfg)
                                        } label: {
                                            HomeWidgetCard(
                                                widget: w,
                                                config: cfg,
                                                stats: stats[w.serviceId],
                                                isEditing: isEditingLayout,
                                                onEdit: { onEditWidget(w) },
                                                onStats: { payload in onStats(w.serviceId, payload) },
                                                showServiceStats: showServiceStats,
                                                shouldSelfFetch: shouldSelfFetch
                                            )
                                        }
                                        .gridCellColumns(w.size.columnSpan)
                                    } else {
                                        HomeWidgetCard(
                                            widget: w,
                                            config: cfg,
                                            stats: stats[w.serviceId],
                                            isEditing: isEditingLayout,
                                            onEdit: { onEditWidget(w) },
                                            onStats: { payload in onStats(w.serviceId, payload) },
                                            showServiceStats: showServiceStats,
                                            shouldSelfFetch: shouldSelfFetch
                                        )
                                        .gridCellColumns(w.size.columnSpan)
                                    }
                                }
                            } else {
                                Color.clear
                                    .gridCellColumns(w.size.columnSpan)
                            }
                        } else {
                            ForEach(row.indices, id: \.self) { idx in
                                let w = row[idx]
                                if let cfg = services.first(where: {
                                    $0.id == w.serviceId && $0.home == selectedHome
                                }) {
                                    if isEditingLayout {
                                        ReorderableCard(id: w.id, isEditing: isEditingLayout, onMove: onMove) {
                                            HomeWidgetCard(
                                                widget: w,
                                                config: cfg,
                                                stats: stats[w.serviceId],
                                                isEditing: isEditingLayout,
                                                onEdit: { onEditWidget(w) },
                                                onStats: { payload in onStats(w.serviceId, payload) },
                                                showServiceStats: showServiceStats,
                                                shouldSelfFetch: shouldSelfFetch
                                            )
                                        }
                                    } else {
                                        if cfg.kind == .qbittorrent {
                                            NavigationLink {
                                                QBittorrentView(config: cfg)
                                            } label: {
                                                HomeWidgetCard(
                                                    widget: w,
                                                    config: cfg,
                                                    stats: stats[w.serviceId],
                                                    isEditing: isEditingLayout,
                                                    onEdit: { onEditWidget(w) },
                                                    onStats: { payload in onStats(w.serviceId, payload) },
                                                    showServiceStats: showServiceStats,
                                                    shouldSelfFetch: shouldSelfFetch
                                                )
                                            }
                                        } else if cfg.kind == .pihole {
                                            NavigationLink {
                                                PiHoleView(config: cfg)
                                            } label: {
                                                HomeWidgetCard(
                                                    widget: w,
                                                    config: cfg,
                                                    stats: stats[w.serviceId],
                                                    isEditing: isEditingLayout,
                                                    onEdit: { onEditWidget(w) },
                                                    onStats: { payload in onStats(w.serviceId, payload) },
                                                    showServiceStats: showServiceStats,
                                                    shouldSelfFetch: shouldSelfFetch
                                                )
                                            }
                                        } else {
                                            HomeWidgetCard(
                                                widget: w,
                                                config: cfg,
                                                stats: stats[w.serviceId],
                                                isEditing: isEditingLayout,
                                                onEdit: { onEditWidget(w) },
                                                onStats: { payload in onStats(w.serviceId, payload) },
                                                showServiceStats: showServiceStats,
                                                shouldSelfFetch: shouldSelfFetch
                                            )
                                        }
                                    }
                                } else {
                                    Color.clear
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    struct EditWidgetView: View {
        @Environment(\.dismiss) private var dismiss

        @State private var workingWidget: HomeWidget
        let config: ServiceConfig
        let onSave: (HomeWidget) -> Void
        let onDelete: () -> Void

        init(
            widget: HomeWidget, config: ServiceConfig, onSave: @escaping (HomeWidget) -> Void,
            onDelete: @escaping () -> Void
        ) {
            self._workingWidget = State(initialValue: widget)
            self.config = config
            self.onSave = onSave
            self.onDelete = onDelete
        }

        var body: some View {
            NavigationView {
                Form {
                    Section("Widget") {
                        Picker("Size", selection: $workingWidget.size) {
                            Text("Auto").tag(HomeWidgetSize.auto)

                            Group {
                                Text("Small (1x1)")
                                    .foregroundStyle(HomeLayout.validateWidgetSize(.small, for: workingWidget.metrics, serviceKind: config.kind, tolerance: true) ? .primary : .secondary)
                                    .tag(HomeWidgetSize.small)

                                Text("Medium (1x2)")
                                    .foregroundStyle(HomeLayout.validateWidgetSize(.medium, for: workingWidget.metrics, serviceKind: config.kind, tolerance: true) ? .primary : .secondary)
                                    .tag(HomeWidgetSize.medium)

                                Text("Wide (2x1)")
                                    .foregroundStyle(HomeLayout.validateWidgetSize(.wide, for: workingWidget.metrics, serviceKind: config.kind, tolerance: true) ? .primary : .secondary)
                                    .tag(HomeWidgetSize.wide)

                                Text("Large (2x2)")
                                    .foregroundStyle(HomeLayout.validateWidgetSize(.large, for: workingWidget.metrics, serviceKind: config.kind, tolerance: true) ? .primary : .secondary)
                                    .tag(HomeWidgetSize.large)

                                Text("Tall (1x3)")
                                    .foregroundStyle(HomeLayout.validateWidgetSize(.tall, for: workingWidget.metrics, serviceKind: config.kind, tolerance: true) ? .primary : .secondary)
                                    .tag(HomeWidgetSize.tall)

                                Text("Extra Wide (2x3)")
                                    .foregroundStyle(HomeLayout.validateWidgetSize(.extraWide, for: workingWidget.metrics, serviceKind: config.kind, tolerance: true) ? .primary : .secondary)
                                    .tag(HomeWidgetSize.extraWide)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: workingWidget.size) { _, newSize in
                            if newSize == .auto {
                                // Auto-determine optimal size and metrics
                                let optimalSize = HomeLayoutDefaults.determineOptimalSize(for: config.kind)
                                workingWidget.size = optimalSize
                                workingWidget.metrics = HomeLayoutDefaults.defaultMetrics(for: config.kind, size: optimalSize)
                            } else if !HomeLayout.validateWidgetSize(newSize, for: workingWidget.metrics, serviceKind: config.kind, tolerance: true) {
                                // If selected size is too small, use minimum required size
                                workingWidget.size = HomeLayout.minimumSizeForContent(workingWidget.metrics, serviceKind: config.kind, strict: false)
                            }
                        }

                        if workingWidget.size == .auto {
                            Text("Auto size automatically chooses the optimal widget size and metrics based on the service type and content.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            let isValidSize = HomeLayout.validateWidgetSize(workingWidget.size, for: workingWidget.metrics, serviceKind: config.kind, tolerance: true)
                            if !isValidSize {
                                let minSize = HomeLayout.minimumSizeForContent(workingWidget.metrics, serviceKind: config.kind, strict: false)
                                Text("Current metrics require at least \(minSize.rawValue) size to display properly.")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }

                        TextField(
                            "Title (optional)",
                            text: Binding(
                                get: { workingWidget.titleOverride ?? "" },
                                set: { workingWidget.titleOverride = $0.isEmpty ? nil : $0 }
                            ))
                    }

                    Section("Metrics") {
                        Button("Restore Defaults") {
                            workingWidget.metrics = HomeLayoutDefaults.defaultMetrics(
                                for: config.kind, size: workingWidget.size)
                            // Validate size after metrics change
                            if !HomeLayout.validateWidgetSize(workingWidget.size, for: workingWidget.metrics, serviceKind: config.kind, tolerance: false) {
                                workingWidget.size = HomeLayout.minimumSizeForContent(workingWidget.metrics, serviceKind: config.kind, strict: false)
                            }
                        }
                        switch config.kind {
                        case .proxmox:
                            let available = ProxmoxMetric.allCases
                            ForEach(available, id: \.self) { m in
                                Toggle(
                                    labelForProxmox(m),
                                    isOn: Binding(
                                        get: { selectedProxmox().contains(m) },
                                        set: { on in
                                            var arr = selectedProxmox()
                                            if on {
                                                if !arr.contains(m) { arr.append(m) }
                                            } else {
                                                arr.removeAll { $0 == m }
                                            }
                                            workingWidget.metrics = .proxmox(arr)
                                            // Validate size after metrics change
                                            if !HomeLayout.validateWidgetSize(workingWidget.size, for: workingWidget.metrics, serviceKind: config.kind, tolerance: false) {
                                                workingWidget.size = HomeLayout.minimumSizeForContent(workingWidget.metrics, serviceKind: config.kind, strict: false)
                                            }
                                        }
                                    )
                                )
                            }

                        case .jellyfin:
                            let available = JellyfinMetric.allCases
                            ForEach(available, id: \.self) { m in
                                Toggle(
                                    labelForJellyfin(m),
                                    isOn: Binding(
                                        get: { selectedJellyfin().contains(m) },
                                        set: { on in
                                            var arr = selectedJellyfin()
                                            if on {
                                                if !arr.contains(m) { arr.append(m) }
                                            } else {
                                                arr.removeAll { $0 == m }
                                            }
                                            workingWidget.metrics = .jellyfin(arr)
                                            // Validate size after metrics change
                                            if !HomeLayout.validateWidgetSize(workingWidget.size, for: workingWidget.metrics, serviceKind: config.kind, tolerance: false) {
                                                workingWidget.size = HomeLayout.minimumSizeForContent(workingWidget.metrics, serviceKind: config.kind, strict: false)
                                            }
                                        }
                                    )
                                )
                            }

                        case .qbittorrent:
                            let available = QBittorrentMetric.allCases
                            ForEach(available, id: \.self) { m in
                                Toggle(
                                    labelForQB(m),
                                    isOn: Binding(
                                        get: { selectedQB().contains(m) },
                                        set: { on in
                                            var arr = selectedQB()
                                            if on {
                                                if !arr.contains(m) { arr.append(m) }
                                            } else {
                                                arr.removeAll { $0 == m }
                                            }
                                            workingWidget.metrics = .qbittorrent(arr)
                                            // Validate size after metrics change
                                            if !HomeLayout.validateWidgetSize(workingWidget.size, for: workingWidget.metrics, serviceKind: config.kind, tolerance: false) {
                                                workingWidget.size = HomeLayout.minimumSizeForContent(workingWidget.metrics, serviceKind: config.kind, strict: false)
                                            }
                                        }
                                    )
                                )
                            }

                        case .pihole:
                            let available = PiHoleMetric.allCases
                            ForEach(available, id: \.self) { m in
                                Toggle(
                                    labelForPiHole(m),
                                    isOn: Binding(
                                        get: { selectedPiHole().contains(m) },
                                        set: { on in
                                            var arr = selectedPiHole()
                                            if on {
                                                if !arr.contains(m) { arr.append(m) }
                                            } else {
                                                arr.removeAll { $0 == m }
                                            }
                                            workingWidget.metrics = .pihole(arr)
                                            // Validate size after metrics change
                                            if !HomeLayout.validateWidgetSize(workingWidget.size, for: workingWidget.metrics, serviceKind: config.kind, tolerance: false) {
                                                workingWidget.size = HomeLayout.minimumSizeForContent(workingWidget.metrics, serviceKind: config.kind, strict: false)
                                            }
                                        }
                                    )
                                )
                            }
                        }
                    }
                    .tint(.green)

                    Section("Refresh") {
                        Toggle(
                            "Use custom refresh interval",
                            isOn: Binding(
                                get: { workingWidget.refreshIntervalOverride != nil },
                                set: { useCustom in
                                    if useCustom {
                                        if workingWidget.refreshIntervalOverride == nil {
                                            workingWidget.refreshIntervalOverride = 30.0
                                        }
                                    } else {
                                        workingWidget.refreshIntervalOverride = nil
                                    }
                                }
                            )
                        )
                        if workingWidget.refreshIntervalOverride != nil {
                            Slider(
                                value: Binding(
                                    get: { workingWidget.refreshIntervalOverride ?? 30.0 },
                                    set: { workingWidget.refreshIntervalOverride = $0 }
                                ),
                                in: 5...300,
                                step: 5
                            ) {
                                Text("Custom Interval")
                            }
                            Text("\(Int(workingWidget.refreshIntervalOverride ?? 30.0)) seconds")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Section {
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Label("Delete Widget", systemImage: "trash")
                        }
                    }
                }
                .navigationTitle("Edit Widget")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(workingWidget)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }

        private func selectedProxmox() -> [ProxmoxMetric] {
            if case .proxmox(let arr) = workingWidget.metrics { return arr }
            return []
        }
        private func selectedJellyfin() -> [JellyfinMetric] {
            if case .jellyfin(let arr) = workingWidget.metrics { return arr }
            return []
        }
        private func selectedQB() -> [QBittorrentMetric] {
            if case .qbittorrent(let arr) = workingWidget.metrics { return arr }
            return []
        }
        private func selectedPiHole() -> [PiHoleMetric] {
            if case .pihole(let arr) = workingWidget.metrics { return arr }
            return []
        }

        private func labelForProxmox(_ m: ProxmoxMetric) -> String {
            switch m {
            case .cpuPercent: return "CPU %"
            case .memoryUsedBytes: return "Memory Used"
            case .memoryPercent: return "Memory %"
            case .totalCTs: return "Total CTs"
            case .totalVMs: return "Total VMs"
            case .runningCount: return "Running"
            case .stoppedCount: return "Stopped"
            case .netUpBps: return "Net ↑"
            case .netDownBps: return "Net ↓"
            }
        }
        private func labelForJellyfin(_ m: JellyfinMetric) -> String {
            switch m {
            case .tvShowsCount: return "TV Shows"
            case .moviesCount: return "Movies"
            case .userCount: return "Users"
            }
        }
        private func labelForQB(_ m: QBittorrentMetric) -> String {
            switch m {
            case .seedingCount: return "Seeding Count"
            case .downloadingCount: return "Downloading Count"
            case .uploadSpeedBytesPerSec: return "Upload Speed"
            case .downloadSpeedBytesPerSec: return "Download Speed"
            }
        }
        private func labelForPiHole(_ m: PiHoleMetric) -> String {
            switch m {
            case .dnsQueriesToday: return "Queries"
            case .adsBlockedToday: return "Blocked"
            case .adsPercentageToday: return "Percentage Blocked"
            case .uniqueClients: return "Clients"
            case .queriesForwarded: return "Forwarded"
            case .queriesCached: return "Cached"
            case .domainsBeingBlocked: return "Domains Blocked"
            case .gravityLastUpdatedRelative: return "Gravity Updated"
            case .blockingStatus: return "Status"
            }
        }
    }

    struct EmptyStateView: View {
        let header: String
        let subheader: String

        var body: some View {
            VStack(spacing: 24) {
                Spacer(minLength: 0)

                Image(systemName: "server.rack")
                    .font(.system(size: 64))
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    Text(header)
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(subheader)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                NavigationLink {
                    ServicesView()
                } label: {
                    Label("Go to Services", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        }
    }

    struct HomeToolbarLeading: ToolbarContent {
        @Binding var homes: [String]
        @Binding var selectedHome: String
        @Binding var isAddingHome: Bool

        var body: some ToolbarContent {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    ForEach(homes, id: \.self) { home in
                        Button(action: {
                            selectedHome = home
                            UserDefaults.standard.set(home, forKey: "selectedHome")
                        }) {
                            HStack {
                                Text(home)
                                    .fontWeight(selectedHome == home ? .bold : .regular)
                                Spacer()
                                if selectedHome == home {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    Divider()
                    Button(action: { isAddingHome = true }) {
                        Label("Add New Home", systemImage: "plus")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedHome)
                            .font(.title)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.down")
                            .font(.title2)
                    }
                    .foregroundStyle(.primary)
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    struct HomeToolbarTrailing: ToolbarContent {
        @Binding var isEditingLayout: Bool
        @Binding var isPresentingAddWidget: Bool
        @Binding var isPresentingServicesView: Bool
        let onAutoLayout: () -> Void

        var body: some ToolbarContent {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    isEditingLayout.toggle()
                } label: {
                    Image(
                        systemName: isEditingLayout
                            ? "checkmark.seal.fill" : "rectangle.and.pencil.and.ellipsis")
                }

                Menu {
                    Button("Auto Layout", systemImage: "square.grid.3x3.fill.square") {
                        onAutoLayout()
                    }

                    if isEditingLayout {
                        Button("Add Widget", systemImage: "plus.square.on.square") {
                            isPresentingAddWidget = true
                        }
                    } else {
                        Button("Add Service", systemImage: "plus") {
                            isPresentingServicesView = true
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }

    struct AddWidgetView: View {
        @Environment(\.dismiss) private var dismiss
        let services: [ServiceConfig]
        let onAdd: (HomeWidget) -> Void

        @State private var selectedServiceId: UUID? = nil
        @State private var size: HomeWidgetSize = .auto
        @State private var title: String = ""
        @State private var proxmoxSelection: [ProxmoxMetric] = []
        @State private var jellyfinSelection: [JellyfinMetric] = []
        @State private var qbSelection: [QBittorrentMetric] = []
        @State private var piholeSelection: [PiHoleMetric] = []

        private var selectedConfig: ServiceConfig? {
            services.first(where: { $0.id == selectedServiceId })
        }

        private var isSavable: Bool { selectedConfig != nil }

        init(services: [ServiceConfig], onAdd: @escaping (HomeWidget) -> Void) {
            self.services = services
            self.onAdd = onAdd
        }

        var body: some View {
            NavigationView {
                Form {
                    if services.isEmpty {
                        Section {
                            Text(
                                "No services in this home. Add a service first in the Services tab."
                            )
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                        }
                    } else {
                        Section("Service") {
                            let serviceSelection = Binding<UUID?>(
                                get: { selectedServiceId ?? services.first?.id },
                                set: { selectedServiceId = $0 }
                            )
                            Picker(
                                "Service",
                                selection: serviceSelection
                            ) {
                                ForEach(services) { svc in
                                    Text(svc.displayName).tag(svc.id as UUID?)
                                }
                            }
                        }

                        Section("Widget") {
                            Picker("Size", selection: $size) {
                                Text("Auto").tag(HomeWidgetSize.auto)

                                if let config = selectedConfig {
                                    let currentMetrics = getCurrentMetrics()

                                    Group {
                                        Text("Small (1x1)")
                                            .foregroundStyle(HomeLayout.validateWidgetSize(.small, for: currentMetrics, serviceKind: config.kind, tolerance: true) ? .primary : .secondary)
                                            .tag(HomeWidgetSize.small)

                                        Text("Medium (1x2)")
                                            .foregroundStyle(HomeLayout.validateWidgetSize(.medium, for: currentMetrics, serviceKind: config.kind, tolerance: true) ? .primary : .secondary)
                                            .tag(HomeWidgetSize.medium)

                                        Text("Wide (2x1)")
                                            .foregroundStyle(HomeLayout.validateWidgetSize(.wide, for: currentMetrics, serviceKind: config.kind, tolerance: true) ? .primary : .secondary)
                                            .tag(HomeWidgetSize.wide)

                                        Text("Large (2x2)")
                                            .foregroundStyle(HomeLayout.validateWidgetSize(.large, for: currentMetrics, serviceKind: config.kind, tolerance: true) ? .primary : .secondary)
                                            .tag(HomeWidgetSize.large)

                                        Text("Tall (1x3)")
                                            .foregroundStyle(HomeLayout.validateWidgetSize(.tall, for: currentMetrics, serviceKind: config.kind, tolerance: true) ? .primary : .secondary)
                                            .tag(HomeWidgetSize.tall)

                                        Text("Extra Wide (2x3)")
                                            .foregroundStyle(HomeLayout.validateWidgetSize(.extraWide, for: currentMetrics, serviceKind: config.kind, tolerance: true) ? .primary : .secondary)
                                            .tag(HomeWidgetSize.extraWide)
                                    }
                                } else {
                                    Text("Small (1x1)").tag(HomeWidgetSize.small)
                                    Text("Medium (1x2)").tag(HomeWidgetSize.medium)
                                    Text("Wide (2x1)").tag(HomeWidgetSize.wide)
                                    Text("Large (2x2)").tag(HomeWidgetSize.large)
                                    Text("Tall (1x3)").tag(HomeWidgetSize.tall)
                                    Text("Extra Wide (2x3)").tag(HomeWidgetSize.extraWide)
                                }
                            }
                            .pickerStyle(.menu)
                            .onChange(of: size) { _, newSize in
                                if newSize == .auto, let config = selectedConfig {
                                    // Auto-determine optimal size and reset metrics
                                    let optimalSize = HomeLayoutDefaults.determineOptimalSize(for: config.kind)
                                    size = optimalSize
                                    proxmoxSelection = []
                                    jellyfinSelection = []
                                    qbSelection = []
                                    piholeSelection = []

                                    // Set default metrics for the optimal size
                                    let defaultMetrics = HomeLayoutDefaults.defaultMetrics(for: config.kind, size: optimalSize)
                                    switch defaultMetrics {
                                    case .proxmox(let metrics):
                                        proxmoxSelection = metrics
                                    case .jellyfin(let metrics):
                                        jellyfinSelection = metrics
                                    case .qbittorrent(let metrics):
                                        qbSelection = metrics
                                    case .pihole(let metrics):
                                        piholeSelection = metrics
                                    }
                                } else if let config = selectedConfig {
                                    // Validate size against current metrics
                                    let currentMetrics = getCurrentMetrics()
                                    if !HomeLayout.validateWidgetSize(newSize, for: currentMetrics, serviceKind: config.kind, tolerance: true) {
                                        // If selected size is too small, use minimum required size
                                        size = HomeLayout.minimumSizeForContent(currentMetrics, serviceKind: config.kind, strict: false)
                                    }
                                }
                            }
                            .onChange(of: selectedServiceId) { _, newServiceId in
                                if size == .auto, let serviceId = newServiceId, let config = services.first(where: { $0.id == serviceId }) {
                                    // Auto-determine optimal size and reset metrics when service changes
                                    let optimalSize = HomeLayoutDefaults.determineOptimalSize(for: config.kind)
                                    size = optimalSize
                                    proxmoxSelection = []
                                    jellyfinSelection = []
                                    qbSelection = []
                                    piholeSelection = []

                                    // Set default metrics for the optimal size
                                    let defaultMetrics = HomeLayoutDefaults.defaultMetrics(for: config.kind, size: optimalSize)
                                    switch defaultMetrics {
                                    case .proxmox(let metrics):
                                        proxmoxSelection = metrics
                                    case .jellyfin(let metrics):
                                        jellyfinSelection = metrics
                                    case .qbittorrent(let metrics):
                                        qbSelection = metrics
                                    case .pihole(let metrics):
                                        piholeSelection = metrics
                                    }
                                }
                            }

                            if size == .auto {
                                Text("Auto size automatically chooses the optimal widget size and metrics based on the service type and content.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else if let config = selectedConfig {
                                let currentMetrics = getCurrentMetrics()
                                let isValidSize = HomeLayout.validateWidgetSize(size, for: currentMetrics, serviceKind: config.kind, tolerance: true)
                                if !isValidSize {
                                    let minSize = HomeLayout.minimumSizeForContent(currentMetrics, serviceKind: config.kind, strict: false)
                                    Text("Current metrics require at least \(minSize.rawValue) size to display properly.")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }

                            TextField("Title (optional)", text: $title)
                        }

                        if let cfg = selectedConfig {
                            Section("Metrics") {
                                switch cfg.kind {
                                case .proxmox:
                                    ForEach(ProxmoxMetric.allCases, id: \.self) { m in
                                        Toggle(labelForProxmox(m), isOn: bindingForProxmox(m))
                                    }
                                case .jellyfin:
                                    ForEach(JellyfinMetric.allCases, id: \.self) { m in
                                        Toggle(labelForJellyfin(m), isOn: bindingForJellyfin(m))
                                    }
                                case .qbittorrent:
                                    ForEach(QBittorrentMetric.allCases, id: \.self) { m in
                                        Toggle(labelForQB(m), isOn: bindingForQB(m))
                                    }
                                case .pihole:
                                    ForEach(PiHoleMetric.allCases, id: \.self) { m in
                                        Toggle(labelForPiHole(m), isOn: bindingForPiHole(m))
                                    }
                                }
                            }
                            .tint(.green)
                        }
                    }

                }
                .navigationTitle("Add Widget")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            if let cfg = selectedConfig {
                                let metrics: WidgetMetricsSelection
                                switch cfg.kind {
                                case .proxmox:
                                    metrics =
                                        proxmoxSelection.isEmpty
                                        ? HomeLayoutDefaults.defaultMetrics(
                                            for: cfg.kind, size: size)
                                        : .proxmox(proxmoxSelection)
                                case .jellyfin:
                                    metrics =
                                        jellyfinSelection.isEmpty
                                        ? HomeLayoutDefaults.defaultMetrics(
                                            for: cfg.kind, size: size)
                                        : .jellyfin(jellyfinSelection)
                                case .qbittorrent:
                                    metrics =
                                        qbSelection.isEmpty
                                        ? HomeLayoutDefaults.defaultMetrics(
                                            for: cfg.kind, size: size)
                                        : .qbittorrent(qbSelection)
                                case .pihole:
                                    metrics =
                                        piholeSelection.isEmpty
                                        ? HomeLayoutDefaults.defaultMetrics(
                                            for: cfg.kind, size: size)
                                        : .pihole(piholeSelection)
                                }
                                var widget = HomeWidget(
                                    serviceId: cfg.id,
                                    size: size,
                                    row: 0,
                                    column: 0,
                                    titleOverride: title.isEmpty ? nil : title,
                                    metrics: metrics
                                )
                                widget.normalizeColumnForSize()
                                onAdd(widget)
                                dismiss()
                            }
                        }
                        .disabled(!isSavable)
                        .buttonStyle(.borderedProminent)
                    }
                }
                .onAppear {
                    if selectedServiceId == nil {
                        selectedServiceId = services.first?.id
                    }
                }
            }
            .navigationTitle("Add Widget")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let newWidget = HomeWidget(
                            serviceId: selectedServiceId!,
                            size: size,
                            row: 0,
                            column: 0,
                            titleOverride: title.isEmpty ? nil : title,
                            metrics: {
                                switch selectedConfig!.kind {
                                case .proxmox:
                                    return .proxmox(proxmoxSelection)
                                case .jellyfin:
                                    return .jellyfin(jellyfinSelection)
                                case .qbittorrent:
                                    return .qbittorrent(qbSelection)
                                case .pihole:
                                    return .pihole(piholeSelection)
                                }
                            }()
                        )
                        onAdd(newWidget)
                        dismiss()
                    }
                    .disabled(!isSavable)
                    .buttonStyle(.borderedProminent)
                }
            }
        }

        // Helper bindings extracted to simplify Toggle closures and improve type-check performance
        private func bindingForProxmox(_ m: ProxmoxMetric) -> Binding<Bool> {
            Binding(
                get: { proxmoxSelection.contains(m) },
                set: { on in
                    if on {
                        if !proxmoxSelection.contains(m) { proxmoxSelection.append(m) }
                    } else {
                        proxmoxSelection.removeAll { $0 == m }
                    }
                    // Validate size after metrics change
                    if let config = selectedConfig {
                        let currentMetrics = getCurrentMetrics()
                        if !HomeLayout.validateWidgetSize(size, for: currentMetrics, serviceKind: config.kind, tolerance: false) {
                            size = HomeLayout.minimumSizeForContent(currentMetrics, serviceKind: config.kind, strict: false)
                        }
                    }
                }
            )
        }

        private func getCurrentMetrics() -> WidgetMetricsSelection {
            guard let config = selectedConfig else {
                return .proxmox([])
            }

            switch config.kind {
            case .proxmox:
                return .proxmox(proxmoxSelection)
            case .jellyfin:
                return .jellyfin(jellyfinSelection)
            case .qbittorrent:
                return .qbittorrent(qbSelection)
            case .pihole:
                return .pihole(piholeSelection)
            }
        }

        private func bindingForJellyfin(_ m: JellyfinMetric) -> Binding<Bool> {
            Binding(
                get: { jellyfinSelection.contains(m) },
                set: { on in
                    if on {
                        if !jellyfinSelection.contains(m) { jellyfinSelection.append(m) }
                    } else {
                        jellyfinSelection.removeAll { $0 == m }
                    }
                    // Validate size after metrics change
                    if let config = selectedConfig {
                        let currentMetrics = getCurrentMetrics()
                        if !HomeLayout.validateWidgetSize(size, for: currentMetrics, serviceKind: config.kind, tolerance: false) {
                            size = HomeLayout.minimumSizeForContent(currentMetrics, serviceKind: config.kind, strict: false)
                        }
                    }
                }
            )
        }

        private func bindingForQB(_ m: QBittorrentMetric) -> Binding<Bool> {
            Binding(
                get: { qbSelection.contains(m) },
                set: { on in
                    if on {
                        if !qbSelection.contains(m) { qbSelection.append(m) }
                    } else {
                        qbSelection.removeAll { $0 == m }
                    }
                    // Validate size after metrics change
                    if let config = selectedConfig {
                        let currentMetrics = getCurrentMetrics()
                        if !HomeLayout.validateWidgetSize(size, for: currentMetrics, serviceKind: config.kind, tolerance: false) {
                            size = HomeLayout.minimumSizeForContent(currentMetrics, serviceKind: config.kind, strict: false)
                        }
                    }
                }
            )
        }

        private func bindingForPiHole(_ m: PiHoleMetric) -> Binding<Bool> {
            Binding(
                get: { piholeSelection.contains(m) },
                set: { on in
                    if on {
                        if !piholeSelection.contains(m) { piholeSelection.append(m) }
                    } else {
                        piholeSelection.removeAll { $0 == m }
                    }
                    // Validate size after metrics change
                    if let config = selectedConfig {
                        let currentMetrics = getCurrentMetrics()
                        if !HomeLayout.validateWidgetSize(size, for: currentMetrics, serviceKind: config.kind, tolerance: false) {
                            size = HomeLayout.minimumSizeForContent(currentMetrics, serviceKind: config.kind, strict: false)
                        }
                    }
                }
            )
        }

        private func labelForProxmox(_ m: ProxmoxMetric) -> String {
            switch m {
            case .cpuPercent: return "CPU %"
            case .memoryUsedBytes: return "Memory Used"
            case .memoryPercent: return "Memory %"
            case .totalCTs: return "Total CTs"
            case .totalVMs: return "Total VMs"
            case .runningCount: return "Running"
            case .stoppedCount: return "Stopped"
            case .netUpBps: return "Net ↑"
            case .netDownBps: return "Net ↓"
            }
        }
        private func labelForJellyfin(_ m: JellyfinMetric) -> String {
            switch m {
            case .tvShowsCount: return "TV Shows"
            case .moviesCount: return "Movies"
            case .userCount: return "Users"
            }
        }
        private func labelForQB(_ m: QBittorrentMetric) -> String {
            switch m {
            case .seedingCount: return "Seeding Count"
            case .downloadingCount: return "Downloading Count"
            case .uploadSpeedBytesPerSec: return "Upload Speed"
            case .downloadSpeedBytesPerSec: return "Download Speed"
            }
        }
        private func labelForPiHole(_ m: PiHoleMetric) -> String {
            switch m {
            case .dnsQueriesToday: return "Queries"
            case .adsBlockedToday: return "Blocked"
            case .adsPercentageToday: return "Percentage Blocked"
            case .uniqueClients: return "Clients"
            case .queriesForwarded: return "Forwarded"
            case .queriesCached: return "Cached"
            case .domainsBeingBlocked: return "Domains Blocked"
            case .gravityLastUpdatedRelative: return "Gravity Updated"
            case .blockingStatus: return "Status"
            }
        }
    }

    struct StatusBadgeView: View {
        enum Status {
            case online
            case offline
            case warning

            var color: Color {
                switch self {
                case .online: return .green
                case .offline: return .red
                case .warning: return .yellow
                }
            }
        }

        let status: Status

        var body: some View {
            Circle()
                .fill(status.color)
                .frame(width: 10, height: 10)
                .overlay {
                    Circle()
                        .stroke(status.color.opacity(0.3), lineWidth: 2)
                        .scaleEffect(1.5)
                }
        }
    }
}

#Preview("HomeView") {
    NavigationView {
        HomeView()
    }
}
