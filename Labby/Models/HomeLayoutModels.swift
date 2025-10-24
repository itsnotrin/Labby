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
    case medium // 1x2 (one column, two rows tall)
    case wide   // 2x1 (two columns, one row)
    case large  // 2x2 (spans both columns and two rows)
    case tall   // 1x3 (one column, three rows tall)
    case extraWide // 2x3 (two columns, three rows)
    case auto   // Dynamically sized based on content

    public var id: String { rawValue }

    public var columnSpan: Int {
        switch self {
        case .small: return 1
        case .medium: return 1
        case .wide: return 2
        case .large: return 2
        case .tall: return 1
        case .extraWide: return 2
        case .auto: return 1 // Default to 1, will be dynamically adjusted
        }
    }

    public var rowSpan: Int {
        switch self {
        case .small: return 1
        case .medium: return 2
        case .wide: return 1
        case .large: return 2
        case .tall: return 3
        case .extraWide: return 3
        case .auto: return 1 // Default to 1, will be dynamically adjusted
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
    case userCount

    public var id: String { rawValue }
}

enum QBittorrentMetric: String, Codable, CaseIterable, Identifiable {
    case seedingCount
    case downloadingCount
    case uploadSpeedBytesPerSec
    case downloadSpeedBytesPerSec

    public var id: String { rawValue }
}


enum PiHoleMetric: String, Codable, CaseIterable, Identifiable {
    case dnsQueriesToday
    case adsBlockedToday
    case adsPercentageToday
    case uniqueClients
    case queriesForwarded
    case queriesCached
    case domainsBeingBlocked
    case gravityLastUpdatedRelative
    case blockingStatus

    public var id: String { rawValue }
}

// MARK: - Widget Metric Selection

enum WidgetMetricsSelection: Codable, Equatable {
    case proxmox([ProxmoxMetric])
    case jellyfin([JellyfinMetric])
    case qbittorrent([QBittorrentMetric])
    case pihole([PiHoleMetric])

    private enum CodingKeys: String, CodingKey {
        case type, proxmox, jellyfin, qbittorrent, pihole
    }

    private enum Discriminator: String, Codable {
        case proxmox, jellyfin, qbittorrent, pihole
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
        case .pihole:
            let metrics = try container.decode([PiHoleMetric].self, forKey: .pihole)
            self = .pihole(metrics)
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
        case .pihole(let metrics):
            try container.encode(Discriminator.pihole, forKey: .type)
            try container.encode(metrics, forKey: .pihole)
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
    public var users: Int
    public init(tvShows: Int, movies: Int, users: Int = 0) {
        self.tvShows = tvShows
        self.movies = movies
        self.users = users
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


public struct PiHoleStats: Codable, Equatable {
    public var status: String?
    public var domainsBeingBlocked: Int
    public var dnsQueriesToday: Int
    public var adsBlockedToday: Int
    public var adsPercentageToday: Double
    public var uniqueClients: Int
    public var queriesForwarded: Int
    public var queriesCached: Int
    public var gravityLastUpdatedRelative: String?
    public var gravityLastUpdatedAbsolute: Int?

    public init(
        status: String?,
        domainsBeingBlocked: Int,
        dnsQueriesToday: Int,
        adsBlockedToday: Int,
        adsPercentageToday: Double,
        uniqueClients: Int,
        queriesForwarded: Int,
        queriesCached: Int,
        gravityLastUpdatedRelative: String?,
        gravityLastUpdatedAbsolute: Int?
    ) {
        self.status = status
        self.domainsBeingBlocked = domainsBeingBlocked
        self.dnsQueriesToday = dnsQueriesToday
        self.adsBlockedToday = adsBlockedToday
        self.adsPercentageToday = adsPercentageToday
        self.uniqueClients = uniqueClients
        self.queriesForwarded = queriesForwarded
        self.queriesCached = queriesCached
        self.gravityLastUpdatedRelative = gravityLastUpdatedRelative
        self.gravityLastUpdatedAbsolute = gravityLastUpdatedAbsolute
    }
}

enum ServiceStatsPayload: Codable, Equatable {
    case proxmox(ProxmoxStats)
    case jellyfin(JellyfinStats)
    case qbittorrent(QBittorrentStats)
    case pihole(PiHoleStats)

    private enum CodingKeys: String, CodingKey { case type, proxmox, jellyfin, qbittorrent, pihole }
    private enum Discriminator: String, Codable { case proxmox, jellyfin, qbittorrent, pihole }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Discriminator.self, forKey: .type) {
        case .proxmox:
            self = .proxmox(try c.decode(ProxmoxStats.self, forKey: .proxmox))
        case .jellyfin:
            self = .jellyfin(try c.decode(JellyfinStats.self, forKey: .jellyfin))
        case .qbittorrent:
            self = .qbittorrent(try c.decode(QBittorrentStats.self, forKey: .qbittorrent))
        case .pihole:
            self = .pihole(try c.decode(PiHoleStats.self, forKey: .pihole))
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
        case .pihole(let s):
            try c.encode(Discriminator.pihole, forKey: .type)
            try c.encode(s, forKey: .pihole)
        }
    }
}

// MARK: - Widget Model
struct HomeWidget: Identifiable, Codable, Equatable {
    public var id: UUID
    public var serviceId: UUID


    public var size: HomeWidgetSize
    public var row: Int  // top-left row anchor
    public var column: Int  // top-left column anchor (0 or 1 in a 2-column grid)


    public var titleOverride: String?
    public var metrics: WidgetMetricsSelection


    public var refreshIntervalOverride: Double?

    public init(
        id: UUID = UUID(),
        serviceId: UUID,
        size: HomeWidgetSize,
        row: Int,
        column: Int,
        titleOverride: String? = nil,
        metrics: WidgetMetricsSelection,
        refreshIntervalOverride: Double? = nil
    ) {
        self.id = id
        self.serviceId = serviceId
        self.refreshIntervalOverride = refreshIntervalOverride
        self.size = size
        self.row = max(0, row)
        self.column = max(0, min(1, column))  // clamp to 2-column grid
        self.titleOverride = titleOverride
        self.metrics = metrics
        normalizeColumnForSize()
    }


    public mutating func normalizeColumnForSize() {
        if size.columnSpan > 1 {
            column = 0
        } else {
            column = max(0, min(1, column))
        }
    }

    var rowSpan: Int { size.rowSpan }
    var colSpan: Int { size.columnSpan }
}

// MARK: - Home Layout
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


    mutating func autoArrangeTwoColumns() {
        var arranged: [HomeWidget] = []
        var currentRow = 0
        var currentCol = 0  // 0 or 1

        for var w in widgets {
            w.normalizeColumnForSize()
            if w.size.columnSpan > 1 {
                if currentCol != 0 {
                    currentRow += 1
                    currentCol = 0
                }
                w.row = currentRow
                w.column = 0
                currentRow += w.size.rowSpan
                currentCol = 0
            } else {
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


    mutating func autoArrangeFlexible() {
        var arranged: [HomeWidget] = []
        var currentRow = 0
        var currentCol = 0

        for var w in widgets {
            if w.size == .auto {
                w.size = determineOptimalSizeForWidget(w)
            }

            w.normalizeColumnForSize()

            if w.size == .large {
                if currentCol != 0 {
                    currentRow += 1
                    currentCol = 0
                }
                w.row = currentRow
                w.column = 0
                currentRow += 2
                currentCol = 0
            } else {
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


    mutating func autoArrangeSmart() {
        var arranged: [HomeWidget] = []
        var currentRow = 0


        for var w in widgets {
            if w.size == .auto {
                w.size = determineOptimalSizeForWidget(w)
            }
            arranged.append(w)
        }


        arranged.sort { widget1, widget2 in
            if widget1.size.columnSpan > 1 && widget2.size.columnSpan == 1 {
                return true
            } else if widget1.size.columnSpan == 1 && widget2.size.columnSpan > 1 {
                return false
            }

            return widget1.size.rowSpan > widget2.size.rowSpan
        }


        var finalArranged: [HomeWidget] = []
        var singleColumnBuffer: [HomeWidget] = []

        for var w in arranged {
            w.normalizeColumnForSize()

            if w.size.columnSpan > 1 {
                if singleColumnBuffer.count == 1 {
                    var buffered = singleColumnBuffer[0]
                    buffered.row = currentRow
                    buffered.column = 0
                    finalArranged.append(buffered)
                    currentRow += buffered.size.rowSpan
                    singleColumnBuffer.removeAll()
                } else if singleColumnBuffer.count >= 2 {
                    for i in stride(from: 0, to: singleColumnBuffer.count, by: 2) {
                        var w1 = singleColumnBuffer[i]
                        w1.row = currentRow
                        w1.column = 0
                        finalArranged.append(w1)

                        if i + 1 < singleColumnBuffer.count {
                            var w2 = singleColumnBuffer[i + 1]
                            w2.row = currentRow
                            w2.column = 1
                            finalArranged.append(w2)
                        }
                        let maxRowSpan = max(w1.size.rowSpan, (i + 1 < singleColumnBuffer.count) ? singleColumnBuffer[i + 1].size.rowSpan : 1)
                        currentRow += maxRowSpan
                    }
                    singleColumnBuffer.removeAll()
                }
                w.row = currentRow
                w.column = 0
                currentRow += w.size.rowSpan
                finalArranged.append(w)
            } else {
                singleColumnBuffer.append(w)


                if singleColumnBuffer.count == 2 {
                    var w1 = singleColumnBuffer[0]
                    var w2 = singleColumnBuffer[1]
                    w1.row = currentRow
                    w1.column = 0
                    w2.row = currentRow
                    w2.column = 1
                    finalArranged.append(w1)
                    finalArranged.append(w2)

                    let maxRowSpan = max(w1.size.rowSpan, w2.size.rowSpan)
                    currentRow += maxRowSpan
                    singleColumnBuffer.removeAll()
                }
            }
        }


        for (index, var w) in singleColumnBuffer.enumerated() {
            w.row = currentRow
            w.column = index % 2
            finalArranged.append(w)
            if index % 2 == 1 {
                currentRow += max(w.size.rowSpan, singleColumnBuffer[index - 1].size.rowSpan)
            } else if index == singleColumnBuffer.count - 1 {
                currentRow += w.size.rowSpan
            }
        }

        self.widgets = finalArranged
    }


    private func determineOptimalSizeForWidget(_ widget: HomeWidget) -> HomeWidgetSize {
        switch widget.metrics {
        case .proxmox(let metrics):
            let hasDetailedMetrics = metrics.contains(.memoryUsedBytes) || metrics.contains(.netUpBps) || metrics.contains(.netDownBps)
            if metrics.count > 5 {
                return .extraWide
            } else if metrics.count > 3 || hasDetailedMetrics {
                return .large
            } else if metrics.count > 1 {
                return .medium
            } else {
                return .small
            }
        case .pihole(let metrics):
            let hasDetailedMetrics = metrics.contains(.gravityLastUpdatedRelative) || metrics.contains(.domainsBeingBlocked)
            if metrics.count > 5 {
                return .large
            } else if metrics.count > 3 || hasDetailedMetrics {
                return .medium
            } else {
                return .small
            }
        case .jellyfin(let metrics):
            return metrics.count >= 3 ? .medium : .small
        case .qbittorrent(let metrics):
            let hasSpeedMetrics = metrics.contains(.uploadSpeedBytesPerSec) || metrics.contains(.downloadSpeedBytesPerSec)
            if metrics.count > 2 && hasSpeedMetrics {
                return .wide
            } else if hasSpeedMetrics {
                return .medium
            } else {
                return .small
            }
        }
    }


    mutating func normalize() {
        for i in widgets.indices {
            widgets[i].normalizeColumnForSize()
            widgets[i].row = max(0, widgets[i].row)
        }

        autoArrangeTwoColumns()
    }


    mutating func addWidget(_ widget: HomeWidget) {
        widgets.append(widget)
        normalize()
    }


    mutating func removeWidget(id: UUID) {
        widgets.removeAll { $0.id == id }
        normalize()
    }


    mutating func updateWidget(_ widget: HomeWidget) {
        guard let idx = widgets.firstIndex(where: { $0.id == widget.id }) else { return }
        widgets[idx] = widget
        normalize()
    }


    mutating func moveWidget(id: UUID, to newIndex: Int) {
        guard let currentIndex = widgets.firstIndex(where: { $0.id == id }) else { return }
        let clampedIndex = max(0, min(newIndex, max(0, widgets.count - 1)))
        if currentIndex == clampedIndex { return }
        let item = widgets.remove(at: currentIndex)
        widgets.insert(item, at: clampedIndex)
        normalize()
    }


    mutating func applyAutoLayout(services: [ServiceConfig]) {

        for i in widgets.indices {
            let widget = widgets[i]
            if let service = services.first(where: { $0.id == widget.serviceId }) {
                let optimalSize = HomeLayoutDefaults.determineOptimalSize(for: service.kind)
                widgets[i].size = optimalSize
                widgets[i].metrics = HomeLayoutDefaults.defaultMetrics(for: service.kind, size: optimalSize)
            }
        }


        let existingServiceIds = Set(widgets.map { $0.serviceId })
        for service in services where service.home == homeName && !existingServiceIds.contains(service.id) {
            let optimalSize = HomeLayoutDefaults.determineOptimalSize(for: service.kind)
            let newWidget = HomeWidget(
                serviceId: service.id,
                size: optimalSize,
                row: 0,
                column: 0,
                titleOverride: nil,
                metrics: HomeLayoutDefaults.defaultMetrics(for: service.kind, size: optimalSize)
            )
            widgets.append(newWidget)
        }


        autoArrangeSmart()
    }


    static func validateWidgetSize(_ size: HomeWidgetSize, for metrics: WidgetMetricsSelection, serviceKind: ServiceKind, tolerance: Bool = true) -> Bool {
        let estimatedLines = estimateContentLines(for: metrics, serviceKind: serviceKind)
        let maxLines = maxLinesForSize(size)

        if tolerance {
            let toleranceLines = size == .small ? 1 : 2
            return estimatedLines <= (maxLines + toleranceLines)
        } else {
            return estimatedLines <= maxLines
        }
    }


    private static func estimateContentLines(for metrics: WidgetMetricsSelection, serviceKind: ServiceKind) -> Int {
        let baseLines = 1

        switch metrics {
        case .proxmox(let metricsArray):
            return baseLines + metricsArray.count
        case .jellyfin(let metricsArray):
            return baseLines + metricsArray.count
        case .qbittorrent(let metricsArray):
            return baseLines + metricsArray.count
        case .pihole(let metricsArray):
            return baseLines + metricsArray.count
        }
    }


    private static func maxLinesForSize(_ size: HomeWidgetSize) -> Int {
        switch size {
        case .small: return 4
        case .medium: return 7
        case .wide: return 4
        case .large: return 9
        case .tall: return 12
        case .extraWide: return 15
        case .auto: return Int.max
        }
    }


    static func minimumSizeForContent(_ metrics: WidgetMetricsSelection, serviceKind: ServiceKind, strict: Bool = false) -> HomeWidgetSize {
        let contentLines = estimateContentLines(for: metrics, serviceKind: serviceKind)


        let orderedSizes: [HomeWidgetSize] = [.small, .medium, .wide, .large, .tall, .extraWide]

        for size in orderedSizes {
            let maxLines = maxLinesForSize(size)
            let threshold = strict ? maxLines : maxLines + (size == .small ? 1 : 2)
            if threshold >= contentLines {
                return size
            }
        }

        return .extraWide
    }
}

// MARK: - Defaults and Utilities

enum HomeLayoutDefaults {

    static func defaultMetrics(for kind: ServiceKind, size: HomeWidgetSize = .small)
        -> WidgetMetricsSelection
    {
        switch kind {
        case .proxmox:
            if size == .large {
                return .proxmox([
                    .cpuPercent, .memoryPercent, .runningCount, .netUpBps, .netDownBps,
                ])
            } else {
                return .proxmox([.cpuPercent, .memoryUsedBytes])
            }
        case .jellyfin:
            return .jellyfin([.tvShowsCount, .moviesCount, .userCount])
        case .qbittorrent:
            return .qbittorrent([.seedingCount, .downloadingCount])
        case .pihole:
            if size == .large {
                return .pihole([
                    .dnsQueriesToday, .adsBlockedToday, .adsPercentageToday, .uniqueClients,
                    .queriesForwarded, .queriesCached, .blockingStatus,
                ])
            } else {
                return .pihole([.blockingStatus, .adsBlockedToday, .adsPercentageToday])
            }
        }
    }


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


    static func generateLayout(homeName: String, services: [ServiceConfig]) -> HomeLayout {
        var layout = HomeLayout(homeName: homeName)
        for svc in services where svc.home == homeName {
            layout.widgets.append(defaultWidget(for: svc))
        }
        layout.autoArrangeTwoColumns()
        return layout
    }


    static func generateAutoLayout(homeName: String, services: [ServiceConfig]) -> HomeLayout {
        var layout = HomeLayout(homeName: homeName)
        for svc in services where svc.home == homeName {
            let autoWidget = HomeWidget(
                serviceId: svc.id,
                size: .auto,
                row: 0,
                column: 0,
                titleOverride: nil,
                metrics: defaultMetrics(for: svc.kind, size: determineOptimalSize(for: svc.kind))
            )
            layout.widgets.append(autoWidget)
        }
        layout.autoArrangeSmart()
        return layout
    }


    static func determineOptimalSize(for kind: ServiceKind) -> HomeWidgetSize {
        switch kind {
        case .proxmox:
            return .extraWide
        case .pihole:
            return .large
        case .jellyfin:
            return .medium
        case .qbittorrent:
            return .wide
        }
    }
}

// MARK: - Stats Formatting Helpers

enum StatFormatter {
    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter
    }()

    static func formatPercent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    static func formatBytes(_ bytes: Int64) -> String {
        byteFormatter.string(fromByteCount: bytes)
    }

    static func formatRateBytesPerSec(_ bytesPerSec: Double) -> String {
        return byteFormatter.string(fromByteCount: Int64(bytesPerSec)) + "/s"
    }
}

// MARK: - Persistence Store


final class HomeLayoutStore: ObservableObject {
    static let shared = HomeLayoutStore()

    @Published private(set) var layouts: [String: HomeLayout] = [:]

    private let storageKey = "home.layouts.v1"
    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

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

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try Self.encoder.encode(layouts)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[HomeLayoutStore] Persist error: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            layouts = try Self.decoder.decode([String: HomeLayout].self, from: data)
        } catch {
            print("[HomeLayoutStore] Load error: \(error)")
            layouts = [:]
        }
    }
}
