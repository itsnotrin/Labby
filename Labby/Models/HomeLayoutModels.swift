//
//  HomeLayoutModels.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Combine
import Foundation

// MARK: - Widget Size

enum HomeWidgetSize: String, Codable, CaseIterable, Identifiable {
    case small  // 1x1
    case large  // 2x2 (spans both columns and two rows)

    public var id: String { rawValue }

    public var columnSpan: Int {
        switch self {
        case .small: return 1
        case .large: return 2
        }
    }

    public var rowSpan: Int {
        switch self {
        case .small: return 1
        case .large: return 2
        }
    }
}

// MARK: - Metrics by Service Kind

enum ProxmoxMetric: String, Codable, CaseIterable, Identifiable {
    case cpuPercent
    case memoryUsedBytes
    case memoryPercent
    case totalCTs
    case totalVMs
    case runningCount
    case stoppedCount
    case netUpBps
    case netDownBps

    public var id: String { rawValue }
}

enum JellyfinMetric: String, Codable, CaseIterable, Identifiable {
    case tvShowsCount
    case moviesCount

    public var id: String { rawValue }
}

enum QBittorrentMetric: String, Codable, CaseIterable, Identifiable {
    case seedingCount
    case downloadingCount
    case uploadSpeedBytesPerSec
    case downloadSpeedBytesPerSec

    public var id: String { rawValue }
}

// MARK: - Widget Metric Selection

enum WidgetMetricsSelection: Codable, Equatable {
    case proxmox([ProxmoxMetric])
    case jellyfin([JellyfinMetric])
    case qbittorrent([QBittorrentMetric])

    private enum CodingKeys: String, CodingKey {
        case type, proxmox, jellyfin, qbittorrent
    }

    private enum Discriminator: String, Codable {
        case proxmox, jellyfin, qbittorrent
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Discriminator.self, forKey: .type)
        switch type {
        case .proxmox:
            let metrics = try container.decode([ProxmoxMetric].self, forKey: .proxmox)
            self = .proxmox(metrics)
        case .jellyfin:
            let metrics = try container.decode([JellyfinMetric].self, forKey: .jellyfin)
            self = .jellyfin(metrics)
        case .qbittorrent:
            let metrics = try container.decode([QBittorrentMetric].self, forKey: .qbittorrent)
            self = .qbittorrent(metrics)
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .proxmox(let metrics):
            try container.encode(Discriminator.proxmox, forKey: .type)
            try container.encode(metrics, forKey: .proxmox)
        case .jellyfin(let metrics):
            try container.encode(Discriminator.jellyfin, forKey: .type)
            try container.encode(metrics, forKey: .jellyfin)
        case .qbittorrent(let metrics):
            try container.encode(Discriminator.qbittorrent, forKey: .type)
            try container.encode(metrics, forKey: .qbittorrent)
        }
    }
}

// MARK: - Stats Payloads for Services

struct ProxmoxStats: Codable, Equatable {
    public var cpuUsagePercent: Double
    public var memoryUsedBytes: Int64
    public var memoryTotalBytes: Int64
    public var totalCTs: Int
    public var totalVMs: Int
    public var runningCount: Int
    public var stoppedCount: Int
    public var netUpBps: Double
    public var netDownBps: Double

    public init(
        cpuUsagePercent: Double,
        memoryUsedBytes: Int64,
        memoryTotalBytes: Int64,
        totalCTs: Int = 0,
        totalVMs: Int = 0,
        runningCount: Int = 0,
        stoppedCount: Int = 0,
        netUpBps: Double = 0,
        netDownBps: Double = 0
    ) {
        self.cpuUsagePercent = cpuUsagePercent
        self.memoryUsedBytes = memoryUsedBytes
        self.memoryTotalBytes = memoryTotalBytes
        self.totalCTs = totalCTs
        self.totalVMs = totalVMs
        self.runningCount = runningCount
        self.stoppedCount = stoppedCount
        self.netUpBps = netUpBps
        self.netDownBps = netDownBps
    }

    private enum CodingKeys: String, CodingKey {
        case cpuUsagePercent, memoryUsedBytes, memoryTotalBytes, totalCTs, totalVMs, runningCount,
            stoppedCount, netUpBps, netDownBps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.cpuUsagePercent = try c.decodeIfPresent(Double.self, forKey: .cpuUsagePercent) ?? 0
        self.memoryUsedBytes = try c.decodeIfPresent(Int64.self, forKey: .memoryUsedBytes) ?? 0
        self.memoryTotalBytes = try c.decodeIfPresent(Int64.self, forKey: .memoryTotalBytes) ?? 0
        self.totalCTs = try c.decodeIfPresent(Int.self, forKey: .totalCTs) ?? 0
        self.totalVMs = try c.decodeIfPresent(Int.self, forKey: .totalVMs) ?? 0
        self.runningCount = try c.decodeIfPresent(Int.self, forKey: .runningCount) ?? 0
        self.stoppedCount = try c.decodeIfPresent(Int.self, forKey: .stoppedCount) ?? 0
        self.netUpBps = try c.decodeIfPresent(Double.self, forKey: .netUpBps) ?? 0
        self.netDownBps = try c.decodeIfPresent(Double.self, forKey: .netDownBps) ?? 0
    }
}

struct JellyfinStats: Codable, Equatable {
    public var tvShows: Int
    public var movies: Int
    public init(tvShows: Int, movies: Int) {
        self.tvShows = tvShows
        self.movies = movies
    }
}

struct QBittorrentStats: Codable, Equatable {
    public var seeding: Int
    public var downloading: Int
    public var uploadSpeedBytesPerSec: Double
    public var downloadSpeedBytesPerSec: Double
    public init(
        seeding: Int, downloading: Int, uploadSpeedBytesPerSec: Double,
        downloadSpeedBytesPerSec: Double
    ) {
        self.seeding = seeding
        self.downloading = downloading
        self.uploadSpeedBytesPerSec = uploadSpeedBytesPerSec
        self.downloadSpeedBytesPerSec = downloadSpeedBytesPerSec
    }
}

enum ServiceStatsPayload: Codable, Equatable {
    case proxmox(ProxmoxStats)
    case jellyfin(JellyfinStats)
    case qbittorrent(QBittorrentStats)

    private enum CodingKeys: String, CodingKey { case type, proxmox, jellyfin, qbittorrent }
    private enum Discriminator: String, Codable { case proxmox, jellyfin, qbittorrent }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Discriminator.self, forKey: .type) {
        case .proxmox:
            self = .proxmox(try c.decode(ProxmoxStats.self, forKey: .proxmox))
        case .jellyfin:
            self = .jellyfin(try c.decode(JellyfinStats.self, forKey: .jellyfin))
        case .qbittorrent:
            self = .qbittorrent(try c.decode(QBittorrentStats.self, forKey: .qbittorrent))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .proxmox(let s):
            try c.encode(Discriminator.proxmox, forKey: .type)
            try c.encode(s, forKey: .proxmox)
        case .jellyfin(let s):
            try c.encode(Discriminator.jellyfin, forKey: .type)
            try c.encode(s, forKey: .jellyfin)
        case .qbittorrent(let s):
            try c.encode(Discriminator.qbittorrent, forKey: .type)
            try c.encode(s, forKey: .qbittorrent)
        }
    }
}

// MARK: - Widget Model

/// Represents a widget rendered on the Home grid for a specific service.
struct HomeWidget: Identifiable, Codable, Equatable {
    public var id: UUID
    public var serviceId: UUID

    // Layout
    public var size: HomeWidgetSize
    public var row: Int  // top-left row anchor
    public var column: Int  // top-left column anchor (0 or 1 in a 2-column grid)

    // Display
    public var titleOverride: String?
    public var metrics: WidgetMetricsSelection

    public init(
        id: UUID = UUID(),
        serviceId: UUID,
        size: HomeWidgetSize,
        row: Int,
        column: Int,
        titleOverride: String? = nil,
        metrics: WidgetMetricsSelection
    ) {
        self.id = id
        self.serviceId = serviceId
        self.size = size
        self.row = max(0, row)
        self.column = max(0, min(1, column))  // clamp to 2-column grid
        self.titleOverride = titleOverride
        self.metrics = metrics
        normalizeColumnForSize()
    }

    // For a 2-column grid, a large widget must start at column 0 to span both columns.
    public mutating func normalizeColumnForSize() {
        if size == .large {
            column = 0
        } else {
            column = max(0, min(1, column))
        }
    }

    var rowSpan: Int { size.rowSpan }
    var colSpan: Int { size.columnSpan }
}

// MARK: - Home Layout

/// A full layout for a given home (by name), containing ordered widgets.
/// Widgets are placed on a 2-column grid using their row/column anchors and spans.
struct HomeLayout: Codable, Equatable {
    public var homeName: String
    public var widgets: [HomeWidget]

    public init(homeName: String, widgets: [HomeWidget] = []) {
        self.homeName = homeName
        self.widgets = widgets.map { w in
            var ww = w
            ww.normalizeColumnForSize()
            return ww
        }
    }

    /// Rearranges widgets in a simple top-to-bottom flow, honoring widget sizes (2-column grid).
    /// Large: spans both columns for two rows; Small: occupies one cell.
    mutating func autoArrangeTwoColumns() {
        var arranged: [HomeWidget] = []
        var currentRow = 0
        var currentCol = 0  // 0 or 1

        for var w in widgets {
            w.normalizeColumnForSize()
            if w.size == .large {
                // Place at start of a row, span both columns and two rows
                w.row = currentRow
                w.column = 0
                currentRow += 2
                currentCol = 0
            } else {
                // Place in current cell
                w.row = currentRow
                w.column = currentCol
                currentCol += 1
                if currentCol >= 2 {
                    currentCol = 0
                    currentRow += 1
                }
            }
            arranged.append(w)
        }

        self.widgets = arranged
    }

    /// Ensures all widgets have valid columns for their size and de-duplicates overlaps naively by auto arranging.
    mutating func normalize() {
        for i in widgets.indices {
            widgets[i].normalizeColumnForSize()
            widgets[i].row = max(0, widgets[i].row)
        }
        // A simple approach to avoid overlap issues:
        autoArrangeTwoColumns()
    }

    /// Adds a widget and normalizes layout.
    mutating func addWidget(_ widget: HomeWidget) {
        widgets.append(widget)
        normalize()
    }

    /// Removes a widget by id and normalizes layout.
    mutating func removeWidget(id: UUID) {
        widgets.removeAll { $0.id == id }
        normalize()
    }

    /// Updates a widget if found (matching id) and normalizes layout.
    mutating func updateWidget(_ widget: HomeWidget) {
        guard let idx = widgets.firstIndex(where: { $0.id == widget.id }) else { return }
        widgets[idx] = widget
        normalize()
    }

    /// Moves a widget to a new index and normalizes layout.
    mutating func moveWidget(id: UUID, to newIndex: Int) {
        guard let currentIndex = widgets.firstIndex(where: { $0.id == id }) else { return }
        let clampedIndex = max(0, min(newIndex, max(0, widgets.count - 1)))
        if currentIndex == clampedIndex { return }
        let item = widgets.remove(at: currentIndex)
        widgets.insert(item, at: clampedIndex)
        normalize()
    }
}

// MARK: - Defaults and Utilities

enum HomeLayoutDefaults {
    /// Provide sensible default metrics for each kind and size.
    static func defaultMetrics(for kind: ServiceKind, size: HomeWidgetSize = .small)
        -> WidgetMetricsSelection
    {
        switch kind {
        case .proxmox:
            if size == .large {
                // Large default: CPU %, Memory %, Running, Net Up/Down
                return .proxmox([
                    .cpuPercent, .memoryPercent, .runningCount, .netUpBps, .netDownBps,
                ])
            } else {
                // Small default: CPU % and Memory Used
                return .proxmox([.cpuPercent, .memoryUsedBytes])
            }
        case .jellyfin:
            return .jellyfin([.tvShowsCount, .moviesCount])
        case .qbittorrent:
            return .qbittorrent([.seedingCount, .downloadingCount])
        }
    }

    /// Creates a default small widget for a service with metrics defaulted per kind.
    static func defaultWidget(for service: ServiceConfig) -> HomeWidget {
        HomeWidget(
            serviceId: service.id,
            size: .small,
            row: 0,
            column: 0,
            titleOverride: nil,
            metrics: defaultMetrics(for: service.kind, size: .small)
        )
    }

    /// Generates a basic layout (small widgets flowing top-to-bottom) for given services.
    static func generateLayout(homeName: String, services: [ServiceConfig]) -> HomeLayout {
        var layout = HomeLayout(homeName: homeName)
        for svc in services where svc.home == homeName {
            layout.widgets.append(defaultWidget(for: svc))
        }
        layout.autoArrangeTwoColumns()
        return layout
    }
}

// MARK: - Stats Formatting Helpers

enum StatFormatter {
    static func formatPercent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    static func formatBytes(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        f.includesUnit = true
        f.isAdaptive = true
        return f.string(fromByteCount: bytes)
    }

    static func formatRateBytesPerSec(_ bytesPerSec: Double) -> String {
        // e.g., "12.3 MB/s"
        let f = ByteCountFormatter()
        f.countStyle = .binary
        f.includesUnit = true
        f.isAdaptive = true
        let perSec = f.string(fromByteCount: Int64(bytesPerSec)) + "/s"
        return perSec
    }
}

// MARK: - Persistence Store

/// Manages persistence of layouts keyed by home name.
/// Uses UserDefaults with JSON-encoded dictionary [homeName: HomeLayout].
final class HomeLayoutStore: ObservableObject {
    static let shared = HomeLayoutStore()

    @Published private(set) var layouts: [String: HomeLayout] = [:]

    private let storageKey = "home.layouts.v1"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        load()
    }

    func layout(for homeName: String) -> HomeLayout {
        layouts[homeName] ?? HomeLayout(homeName: homeName)
    }

    func setLayout(_ layout: HomeLayout) {
        layouts[layout.homeName] = layout
        persist()
    }

    func addWidget(_ widget: HomeWidget, to homeName: String) {
        var l = layout(for: homeName)
        l.addWidget(widget)
        setLayout(l)
    }

    func updateWidget(_ widget: HomeWidget, in homeName: String) {
        var l = layout(for: homeName)
        l.updateWidget(widget)
        setLayout(l)
    }

    func removeWidget(id: UUID, from homeName: String) {
        var l = layout(for: homeName)
        l.removeWidget(id: id)
        setLayout(l)
    }

    func removeAll(for homeName: String) {
        layouts[homeName] = HomeLayout(homeName: homeName)
        persist()
    }

    func removeAllHomes() {
        layouts.removeAll()
        persist()
    }

    // MARK: Persistence

    private func persist() {
        do {
            let data = try encoder.encode(layouts)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[HomeLayoutStore] Persist error: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            layouts = try decoder.decode([String: HomeLayout].self, from: data)
        } catch {
            print("[HomeLayoutStore] Load error: \(error)")
            layouts = [:]
        }
    }
}
