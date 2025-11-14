import SwiftUI
import Combine

// MARK: - Type aliases to avoid conflicts
typealias ClientVMType = VMType // VMType from ProxmoxClient.swift

// MARK: - Proxmox API Models (extended for detailed view)

struct ProxmoxNode: Codable, Identifiable, Equatable {
    let id: String
    let node: String
    let type: String
    let status: String
    let cpu: Double?
    let maxcpu: Int?
    let mem: Int64?
    let maxmem: Int64?
    let disk: Int64?
    let maxdisk: Int64?
    let uptime: Int64?
    let level: String?

    var cpuUsagePercent: Double {
        guard let cpuValue = cpu, cpuValue.isFinite else { return 0.0 }
        return cpuValue * 100.0
    }

    var memoryUsagePercent: Double {
        guard let mem = mem, let maxmem = maxmem, maxmem > 0 else { return 0.0 }
        return (Double(mem) / Double(maxmem)) * 100.0
    }

    var diskUsagePercent: Double {
        guard let disk = disk, let maxdisk = maxdisk, maxdisk > 0 else { return 0.0 }
        return (Double(disk) / Double(maxdisk)) * 100.0
    }

    var uptimeString: String {
        guard let uptime = uptime else { return "Unknown" }
        let days = uptime / 86400
        let hours = (uptime % 86400) / 3600
        let minutes = (uptime % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct ProxmoxVM: Codable, Identifiable, Equatable {
    let vmid: String
    let name: String?
    let type: String
    let status: String
    let node: String?
    let cpu: Double?
    let cpus: Int?
    let mem: Int64?
    let maxmem: Int64?
    let disk: Int64?
    let maxdisk: Int64?
    let netin: Int64?
    let netout: Int64?
    let uptime: Int64?
    let template: Int?
    let hastate: String?
    let tags: String?

    var id: String { vmid }

    var displayName: String {
        name ?? "VM \(vmid)"
    }

    var isRunning: Bool {
        status.lowercased() == "running"
    }

    var isTemplate: Bool {
        template == 1
    }

    var vmType: VMType {
        switch type.lowercased() {
        case "qemu": return .vm
        case "lxc": return .container
        default: return .unknown
        }
    }

    var cpuUsagePercent: Double {
        guard let cpuValue = cpu, cpuValue.isFinite else { return 0.0 }
        return cpuValue * 100.0
    }

    var memoryUsagePercent: Double {
        guard let mem = mem, let maxmem = maxmem, maxmem > 0 else { return 0.0 }
        return (Double(mem) / Double(maxmem)) * 100.0
    }

    var tagList: [String] {
        tags?.split(separator: ";").map(String.init) ?? []
    }

    enum VMType: String, CaseIterable {
        case vm = "VM"
        case container = "CT"
        case unknown = "Unknown"

        var icon: String {
            switch self {
            case .vm: return "desktopcomputer"
            case .container: return "shippingbox"
            case .unknown: return "questionmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .vm: return .blue
            case .container: return .green
            case .unknown: return .gray
            }
        }
    }
}

struct ProxmoxStorage: Codable, Identifiable, Equatable {
    let storage: String
    let type: String
    let node: String?
    let content: String?
    let enabled: Int?
    let used: Int64?
    let total: Int64?
    let avail: Int64?
    let shared: Int?

    var id: String { storage }

    var isEnabled: Bool {
        enabled == 1
    }

    var isShared: Bool {
        shared == 1
    }

    var usagePercent: Double {
        guard let used = used, let total = total, total > 0 else { return 0.0 }
        return (Double(used) / Double(total)) * 100.0
    }

    var contentTypes: [String] {
        content?.split(separator: ",").map(String.init) ?? []
    }

    var statusColor: Color {
        if !isEnabled { return .gray }
        let usage = usagePercent
        if usage > 90 { return .red }
        if usage > 75 { return .orange }
        return .green
    }
}

struct ProxmoxBackup: Codable, Identifiable, Equatable {
    let vmid: String
    let type: String
    let volid: String
    let size: Int64?
    let ctime: Int64?
    let vmtype: String?

    var id: String { volid }

    var creationDate: Date {
        Date(timeIntervalSince1970: TimeInterval(ctime ?? 0))
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: creationDate)
    }

    var sizeFormatted: String {
        guard let size = size else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

// MARK: - View Models

@MainActor
final class ProxmoxViewModel: ObservableObject {
    let config: ServiceConfig
    private let client: ProxmoxClient
    private var refreshTimer: Timer?

    @Published var stats: ProxmoxStats?
    @Published var nodes: [ProxmoxNode] = []
    @Published var vms: [ProxmoxVM] = []
    @Published var storage: [ProxmoxStorage] = []
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var lastCacheUpdate: Date?
    @Published var isUsingCachedData: Bool = false

    init(config: ServiceConfig) {
        self.config = config
        self.client = ProxmoxClient(config: config)
    }

    func refreshCache() {
        print("ProxmoxViewModel: Refreshing cache by clearing client cache")
        client.clearCache()
        Task {
            await refresh()
        }
    }

    func refresh() async {
        isLoading = true
        error = nil

        do {
            // Check if we're using cached data
            let beforeNodes = nodes.count
            let beforeVMs = vms.count
            let beforeStorage = storage.count

            // Fetch stats first for quick overview
            if case .proxmox(let proxmoxStats) = try await client.fetchStats() {
                await MainActor.run {
                    self.stats = proxmoxStats
                }
            }

            await fetchDetailedData()

            // Check if data came from cache
            let afterNodes = nodes.count
            let afterVMs = vms.count
            let afterStorage = storage.count
            let dataChanged = beforeNodes != afterNodes || beforeVMs != afterVMs || beforeStorage != afterStorage

            await MainActor.run {
                self.isUsingCachedData = !dataChanged && beforeNodes > 0
            }
        } catch {
            print("ProxmoxViewModel: Error refreshing: \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }

        await MainActor.run {
            self.isLoading = false
        }
    }

    private func fetchDetailedData() async {
        async let nodesData = fetchNodes()
        async let vmsData = fetchVMs()
        async let storageData = fetchStorage()

        let (nodes, vms, storage) = await (nodesData, vmsData, storageData)

        print("ProxmoxViewModel loaded: \(nodes.count) nodes, \(vms.count) VMs, \(storage.count) storage")

        await MainActor.run {
            self.nodes = nodes
            self.vms = self.mergeVMs(existing: self.vms, new: vms)
            self.storage = storage
            self.lastCacheUpdate = Date()
            self.isLoading = false
        }
    }

    private func fetchNodes() async -> [ProxmoxNode] {
        do {
            let nodeData = try await client.fetchNodes()
            return nodeData.map { node in
                ProxmoxNode(
                    id: node.id, node: node.node, type: node.type, status: node.status,
                    cpu: node.cpu, maxcpu: node.maxcpu, mem: node.mem, maxmem: node.maxmem,
                    disk: node.disk, maxdisk: node.maxdisk, uptime: node.uptime, level: node.level
                )
            }
        } catch {
            print("ProxmoxViewModel: Failed to fetch nodes: \(error)")
            print("Nodes API error details: \(error.localizedDescription)")
            return []
        }
    }

    private func fetchVMs() async -> [ProxmoxVM] {
        do {
            let vmData = try await client.fetchVMs()
            return vmData.map { vm in
                ProxmoxVM(
                    vmid: vm.vmid, name: vm.name, type: vm.type, status: vm.status,
                    node: vm.node, cpu: vm.cpu, cpus: vm.cpus, mem: vm.mem, maxmem: vm.maxmem,
                    disk: vm.disk, maxdisk: vm.maxdisk, netin: vm.netin, netout: vm.netout,
                    uptime: vm.uptime, template: vm.template, hastate: vm.hastate, tags: vm.tags
                )
            }
        } catch {
            print("ProxmoxViewModel: Failed to fetch VMs: \(error)")
            print("VMs API error details: \(error.localizedDescription)")
            return []
        }
    }

    private func fetchStorage() async -> [ProxmoxStorage] {
        do {
            let storageData = try await client.fetchStorage()
            return storageData.map { storage in
                ProxmoxStorage(
                    storage: storage.storage, type: storage.type, node: storage.node,
                    content: storage.content, enabled: storage.enabled, used: storage.used,
                    total: storage.total, avail: storage.avail, shared: storage.shared
                )
            }
        } catch {
            print("ProxmoxViewModel: Failed to fetch storage: \(error)")
            print("Storage API error details: \(error.localizedDescription)")
            return []
        }
    }

    func startAutoRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { _ in
            Task { await self.refresh() }
        }
        Task { await refresh() }
    }

    func stopAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func mergeVMs(existing: [ProxmoxVM], new: [ProxmoxVM]) -> [ProxmoxVM] {
        var vmDict: [String: ProxmoxVM] = [:]

        // Start with existing VMs to preserve object identity
        for vm in existing {
            vmDict[vm.vmid] = vm
        }

        // Update with new data, preserving object identity where possible
        for newVM in new {
            if let existingVM = vmDict[newVM.vmid] {
                // Update existing VM with new data if it has changed
                if existingVM != newVM {
                    vmDict[newVM.vmid] = newVM
                }
                // Otherwise keep existing object
            } else {
                // New VM, add it
                vmDict[newVM.vmid] = newVM
            }
        }

        return Array(vmDict.values).sorted { $0.vmid < $1.vmid }
    }
}

// MARK: - Views

struct ProxmoxView: View {
    let config: ServiceConfig
    @StateObject private var vm: ProxmoxViewModel

    init(config: ServiceConfig) {
        self.config = config
        _vm = StateObject(wrappedValue: ProxmoxViewModel(config: config))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Cache status indicator
                if vm.isUsingCachedData || vm.lastCacheUpdate != nil {
                    HStack(spacing: 8) {
                        if vm.isUsingCachedData {
                            Label("Cached", systemImage: "clock.fill")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }

                        if let lastUpdate = vm.lastCacheUpdate {
                            Text("Updated \(lastUpdate, style: .relative) ago")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                }

                if let error = vm.error {
                    ErrorCard(message: error)
                }

                if vm.isLoading && vm.stats == nil {
                    ProgressView("Loading Proxmox data...")
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else if let stats = vm.stats {
                    VStack(spacing: 16) {
                        // Cluster Overview
                        ClusterOverviewCard(stats: stats)

                        // Quick Stats Grid
                        ClusterStatsGrid(stats: stats)

                        // Resource Health
                        ResourceHealthCard(stats: stats)

                        // Quick Actions
                        QuickActionsCard(actions: [
                            ("Refresh All", "arrow.clockwise", .blue, {}),
                            ("Start All", "play.fill", .green, {}),
                            ("Backup", "archivebox", .orange, {})
                        ])

                        // Detailed Dashboard Link
                        NavigationLink {
                            ProxmoxDetailView(config: config, initialVMs: vm.vms, initialStorage: vm.storage, initialNodes: vm.nodes, initialStats: vm.stats)
                        } label: {
                            DetailedDashboardCard(subtitle: "Manage VMs, containers, storage, and network")
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding()
        }
            .navigationTitle("Proxmox")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            Task { await vm.refresh() }
                        } label: {
                            HStack {
                                Text("Refresh")
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(vm.isLoading)

                        Button {
                            vm.refreshCache()
                        } label: {
                            HStack {
                                Text("Clear Cache & Refresh")
                                Image(systemName: "trash")
                            }
                        }
                        .disabled(vm.isLoading)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(vm.isLoading)
                }
            }
            .onAppear { vm.startAutoRefresh() }
            .onDisappear { vm.stopAutoRefresh() }
    }
}

struct ClusterOverviewCard: View {
    let stats: ProxmoxStats

    private var clusterHealth: (String, Color) {
        let memUsage = stats.memoryTotalBytes > 0 ?
            (Double(stats.memoryUsedBytes) / Double(stats.memoryTotalBytes)) * 100 : 0
        let cpuUsage = stats.cpuUsagePercent

        if cpuUsage > 90 || memUsage > 95 {
            return ("Critical", .red)
        } else if cpuUsage > 75 || memUsage > 85 {
            return ("Warning", .orange)
        } else if cpuUsage > 60 || memUsage > 70 {
            return ("Good", .blue)
        } else {
            return ("Excellent", .green)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cluster Status")
                        .font(.headline)
                    Text(clusterHealth.0)
                        .font(.subheadline)
                        .foregroundColor(clusterHealth.1)
                }
                Spacer()
                Image(systemName: "server.rack")
                    .font(.title2)
                    .foregroundColor(.blue)
            }

            HStack(spacing: 20) {
                StatPill(
                    title: "Running VMs",
                    value: "\(stats.runningVMs + stats.runningCTs)",
                    systemImage: "play.circle.fill"
                )
                StatPill(
                    title: "Total VMs",
                    value: "\(stats.totalVMs + stats.totalCTs)",
                    systemImage: "rectangle.stack"
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct ClusterStatsGrid: View {
    let stats: ProxmoxStats

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            ResourceCard(
                title: "CPU Usage",
                value: String(format: "%.1f%%", stats.cpuUsagePercent),
                subtitle: "Cluster Wide",
                icon: "cpu",
                color: .blue,
                progress: stats.cpuUsagePercent.isFinite ? stats.cpuUsagePercent / 100.0 : 0
            )

            ResourceCard(
                title: "Memory",
                value: "\(ByteCountFormatter.string(fromByteCount: stats.memoryUsedBytes, countStyle: .memory))",
                subtitle: "of \(ByteCountFormatter.string(fromByteCount: stats.memoryTotalBytes, countStyle: .memory))",
                icon: "memorychip",
                color: .green,
                progress: {
                    guard stats.memoryTotalBytes > 0 else { return 0 }
                    let ratio = Double(stats.memoryUsedBytes) / Double(stats.memoryTotalBytes)
                    return ratio.isFinite ? ratio : 0
                }()
            )

            ResourceCard(
                title: "Virtual Machines",
                value: "\(stats.totalVMs)",
                subtitle: "\(stats.runningVMs) running",
                icon: "desktopcomputer",
                color: .purple,
                progress: {
                    guard stats.totalVMs > 0 else { return 0 }
                    let ratio = Double(stats.runningVMs) / Double(stats.totalVMs)
                    return ratio.isFinite ? ratio : 0
                }()
            )

            ResourceCard(
                title: "Containers",
                value: "\(stats.totalCTs)",
                subtitle: "\(stats.runningCTs) running",
                icon: "shippingbox",
                color: .orange,
                progress: {
                    guard stats.totalCTs > 0 else { return 0 }
                    let ratio = Double(stats.runningCTs) / Double(stats.totalCTs)
                    return ratio.isFinite ? ratio : 0
                }()
            )
        }
    }
}



struct ResourceHealthCard: View {
    let stats: ProxmoxStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resource Health")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Network")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 8) {
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text(StatFormatter.formatRateBytesPerSec(stats.netDownBps))
                                .font(.caption)
                        }
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.up")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text(StatFormatter.formatRateBytesPerSec(stats.netUpBps))
                                .font(.caption)
                        }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Online")
                            .font(.caption)
                    }
                }

                Spacer()
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}







// MARK: - Detailed View

struct ProxmoxDetailView: View {
    let config: ServiceConfig
    @StateObject private var vm: ProxmoxDetailViewModel
    @State private var isNavigating = false

    init(config: ServiceConfig, initialVMs: [ProxmoxVM] = [], initialStorage: [ProxmoxStorage] = [], initialNodes: [ProxmoxNode] = [], initialStats: ProxmoxStats? = nil) {
        self.config = config
        _vm = StateObject(wrappedValue: ProxmoxDetailViewModel(config: config, initialVMs: initialVMs, initialStorage: initialStorage, initialNodes: initialNodes, initialStats: initialStats))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let error = vm.error {
                        ErrorCard(message: error)
                    }

                    if vm.isLoading {
                        ProgressView("Loading detailed data...")
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else {
                        // Cluster Overview
                        ClusterStatusSection(stats: vm.stats)

                        // Navigation Grid
                        NavigationGridSection(config: config, vm: vm)

                        // Nodes Overview
                        NodesOverviewSection(nodes: vm.nodes)

                        // VMs and Containers Summary
                        VMsContainersSummarySection(vms: vm.vms)

                        // Storage Overview
                        StorageOverviewSection(storage: vm.storage)

                        // Cache status (for debugging)
                        if vm.isUsingCachedData || vm.lastCacheUpdate != nil {
                            VStack(alignment: .leading, spacing: 4) {
                                if vm.isUsingCachedData {
                                    Label("Using cached data", systemImage: "clock")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                if let lastUpdate = vm.lastCacheUpdate {
                                    Text("Last updated: \(lastUpdate, style: .relative) ago")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Proxmox Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            Task { await vm.refresh() }
                        } label: {
                            HStack {
                                Text("Refresh")
                                Image(systemName: "arrow.clockwise")
                            }
                        }
                        .disabled(vm.isLoading)

                        Button {
                            vm.refreshCache()
                        } label: {
                            HStack {
                                Text("Clear Cache & Refresh")
                                Image(systemName: "trash")
                            }
                        }
                        .disabled(vm.isLoading)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(vm.isLoading)
                }
            }
            .onAppear {
                vm.startAutoRefresh()
            }
            .onDisappear {
                vm.stopAutoRefresh()
            }
        }
    }

    @MainActor
    final class ProxmoxDetailViewModel: ObservableObject {
        let config: ServiceConfig
        private let client: ProxmoxClient
        private var refreshTimer: Timer?

        @Published var stats: ProxmoxStats = ProxmoxStats.empty()
        @Published var nodes: [ProxmoxNode] = []
        @Published var vms: [ProxmoxVM] = []
        @Published var storage: [ProxmoxStorage] = []
        @Published var isLoading: Bool = false
        @Published var error: String?
        @Published var lastCacheUpdate: Date?
        @Published var isUsingCachedData: Bool = false

        init(config: ServiceConfig, initialVMs: [ProxmoxVM] = [], initialStorage: [ProxmoxStorage] = [], initialNodes: [ProxmoxNode] = [], initialStats: ProxmoxStats? = nil) {
            self.config = config
            self.client = ProxmoxClient(config: config)

            // Use initial data if provided (from parent view cache)
            if !initialVMs.isEmpty {
                self.vms = initialVMs
                self.isUsingCachedData = true
                print("ProxmoxDetailViewModel: Using cached VMs data (\(initialVMs.count) VMs)")
            }

            if !initialStorage.isEmpty {
                self.storage = initialStorage
                print("ProxmoxDetailViewModel: Using cached storage data (\(initialStorage.count) pools)")
            }

            if !initialNodes.isEmpty {
                self.nodes = initialNodes
                self.isUsingCachedData = true
                print("ProxmoxDetailViewModel: Using cached nodes data (\(initialNodes.count) nodes)")
            }

            if let cachedStats = initialStats {
                self.stats = cachedStats
                print("ProxmoxDetailViewModel: Using cached stats data")
            }

            if isUsingCachedData {
                self.lastCacheUpdate = Date()
            }
        }

        func refreshCache() {
            print("ProxmoxDetailViewModel: Refreshing cache by clearing client cache")
            client.clearCache()
            isUsingCachedData = false
            Task {
                await refresh()
            }
        }

        func refresh() async {
            // Skip refresh if already loading to prevent conflicts
            guard !isLoading else { return }

            isLoading = true
            error = nil

            do {
                let beforeVMs = vms.count
                let beforeStorage = storage.count

                if case .proxmox(let proxmoxStats) = try await client.fetchStats() {
                    await MainActor.run {
                        self.stats = proxmoxStats
                    }
                }

                await loadDetailedData()

                let afterVMs = vms.count
                let afterStorage = storage.count
                let dataChanged = beforeVMs != afterVMs || beforeStorage != afterStorage

                await MainActor.run {
                    self.isLoading = false
                    if dataChanged {
                        print("ProxmoxDetailViewModel: Data changed - VMs: \(beforeVMs) -> \(afterVMs), Storage: \(beforeStorage) -> \(afterStorage)")
                    }
                }

            } catch {
                print("ProxmoxDetailViewModel.refresh() error: \(error)")
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isLoading = false
                }
            }
        }

        private func loadDetailedData() async {
            async let nodesData = fetchNodes()
            async let vmsData = fetchVMs()
            async let storageData = fetchStorage()

            let (nodes, vms, storage) = await (nodesData, vmsData, storageData)

            print("ProxmoxDetailViewModel loaded: \(nodes.count) nodes, \(vms.count) VMs, \(storage.count) storage")

            await MainActor.run {
                self.nodes = nodes
                // Only update VMs and storage if we got new data, otherwise keep initial data
                if !vms.isEmpty {
                    self.vms = self.mergeVMs(existing: self.vms, new: vms)
                }
                if !storage.isEmpty {
                    self.storage = storage
                }
            }
        }

        private func fetchNodes() async -> [ProxmoxNode] {
            do {
                let nodeData = try await client.fetchNodes()
                return nodeData.map { node in
                    ProxmoxNode(
                        id: node.id, node: node.node, type: node.type, status: node.status,
                        cpu: node.cpu, maxcpu: node.maxcpu, mem: node.mem, maxmem: node.maxmem,
                        disk: node.disk, maxdisk: node.maxdisk, uptime: node.uptime, level: node.level
                    )
                }
            } catch {
                print("Failed to fetch nodes: \(error)")
                print("Nodes API error details: \(error.localizedDescription)")
                return []
            }
        }

        private func fetchVMs() async -> [ProxmoxVM] {
            do {
                let vmData = try await client.fetchVMs()
                var result: [ProxmoxVM] = []
                for vm in vmData {
                    let proxmoxVM = createProxmoxVM(from: vm)
                    result.append(proxmoxVM)
                }
                return result
            } catch {
                print("ProxmoxDetailViewModel: Failed to fetch VMs: \(error)")
                print("VMs API error details: \(error.localizedDescription)")
                return []
            }
        }

        private func createProxmoxVM(from vm: ProxmoxVMData) -> ProxmoxVM {
            return ProxmoxVM(
                vmid: vm.vmid,
                name: vm.name,
                type: vm.type,
                status: vm.status,
                node: vm.node,
                cpu: vm.cpu,
                cpus: vm.cpus,
                mem: vm.mem,
                maxmem: vm.maxmem,
                disk: vm.disk,
                maxdisk: vm.maxdisk,
                netin: vm.netin,
                netout: vm.netout,
                uptime: vm.uptime,
                template: vm.template,
                hastate: vm.hastate,
                tags: vm.tags
            )
        }

        private func mergeVMs(existing: [ProxmoxVM], new: [ProxmoxVM]) -> [ProxmoxVM] {
            var vmDict: [String: ProxmoxVM] = [:]

            // Start with existing VMs to preserve object identity
            for vm in existing {
                vmDict[vm.vmid] = vm
            }

            // Update with new data, preserving object identity where possible
            for newVM in new {
                if let existingVM = vmDict[newVM.vmid] {
                    // Update existing VM with new data if it has changed
                    if existingVM != newVM {
                        vmDict[newVM.vmid] = newVM
                    }
                    // Otherwise keep existing object
                } else {
                    // New VM, add it
                    vmDict[newVM.vmid] = newVM
                }
            }

            return Array(vmDict.values).sorted { $0.vmid < $1.vmid }
        }

        private func fetchStorage() async -> [ProxmoxStorage] {
            do {
                let storageData = try await client.fetchStorage()
                return storageData.map { storage in
                    ProxmoxStorage(
                        storage: storage.storage, type: storage.type, node: storage.node,
                        content: storage.content, enabled: storage.enabled, used: storage.used,
                        total: storage.total, avail: storage.avail, shared: storage.shared
                    )
                }
            } catch {
                print("Failed to fetch storage: \(error)")
                print("Storage API error details: \(error.localizedDescription)")
                return []
            }
        }

        func startAutoRefresh() {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true) { _ in
                Task { await self.refresh() }
            }
            Task { await refresh() }
        }

        func stopAutoRefresh() {
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    // MARK: - Detail View Sections

    struct ClusterStatusSection: View {
        let stats: ProxmoxStats

        private var overallHealth: (String, Color) {
            let memUsage = stats.memoryTotalBytes > 0 ?
            (Double(stats.memoryUsedBytes) / Double(stats.memoryTotalBytes)) * 100 : 0
            let cpuUsage = stats.cpuUsagePercent

            if cpuUsage > 90 || memUsage > 95 {
                return ("Critical Load", .red)
            } else if cpuUsage > 75 || memUsage > 85 {
                return ("High Load", .orange)
            } else if cpuUsage > 50 || memUsage > 70 {
                return ("Moderate Load", .blue)
            } else {
                return ("Low Load", .green)
            }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cluster Overview")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(overallHealth.0)
                            .font(.subheadline)
                            .foregroundColor(overallHealth.1)
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Online")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }

                // Resource utilization cards
                HStack(spacing: 0) {
                    MetricCard(
                        title: "CPU Usage",
                        value: String(format: "%.1f%%", stats.cpuUsagePercent),
                        color: .blue,
                        isFirst: true
                    )

                    MetricCard(
                        title: "Memory",
                        value: {
                            let percentage = stats.memoryTotalBytes > 0 ?
                            (Double(stats.memoryUsedBytes) / Double(stats.memoryTotalBytes)) * 100 : 0
                            return "\(Int(percentage.isFinite ? percentage : 0))%"
                        }(),
                        subtitle: ByteCountFormatter.string(fromByteCount: stats.memoryUsedBytes, countStyle: .memory),
                        color: .green,
                        isFirst: false
                    )

                    MetricCard(
                        title: "VMs Running",
                        value: "\(stats.runningVMs + stats.runningCTs)",
                        subtitle: "of \(stats.totalVMs + stats.totalCTs)",
                        color: .purple,
                        isFirst: false,
                        isLast: true
                    )
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 1)
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }



    struct NavigationGridSection: View {
        let config: ServiceConfig
        let vm: ProxmoxDetailViewModel

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Management")
                    .font(.headline)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    NavigationLink(value: "vms") {
                        ManagementCard(
                            title: "Virtual Machines",
                            subtitle: "\(vm.vms.filter { $0.vmType == .vm }.count) VMs",
                            icon: "desktopcomputer",
                            color: .blue
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    NavigationLink(value: "containers") {
                        ManagementCard(
                            title: "Containers",
                            subtitle: "\(vm.vms.filter { $0.vmType == .container }.count) CTs",
                            icon: "shippingbox",
                            color: .green
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    NavigationLink(value: "storage") {
                        ManagementCard(
                            title: "Storage",
                            subtitle: "\(vm.storage.count) pools",
                            icon: "externaldrive",
                            color: .orange
                        )
                    }
                    .buttonStyle(PlainButtonStyle())

                    NavigationLink(value: "network") {
                        ManagementCard(
                            title: "Network",
                            subtitle: "Interfaces & bridges",
                            icon: "network",
                            color: .purple
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationDestination(for: String.self) { destination in
                switch destination {
                case "vms":
                    ProxmoxVMsView(config: config, vms: vm.vms.filter { $0.vmType == .vm })
                case "containers":
                    ProxmoxContainersView(config: config, containers: vm.vms.filter { $0.vmType == .container })
                case "storage":
                    ProxmoxStorageView(config: config, storage: vm.storage)
                case "network":
                    ProxmoxNetworkView(config: config)
                default:
                    EmptyView()
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }

    struct ManagementCard: View {
        let title: String
        let subtitle: String
        let icon: String
        let color: Color

        var body: some View {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(minHeight: 70, maxHeight: 70)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
            .shadow(radius: 1)
        }
    }

    struct NodesOverviewSection: View {
        let nodes: [ProxmoxNode]

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Cluster Nodes")
                    .font(.headline)

                if nodes.isEmpty {
                    Text("No nodes data available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    ForEach(nodes) { node in
                        NodeRow(node: node)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }

    struct NodeRow: View {
        let node: ProxmoxNode

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(node.node)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    HStack {
                        Text("CPU: \(String(format: "%.1f%%", node.cpuUsagePercent))")
                        Text("•")
                        Text("RAM: \(String(format: "%.1f%%", node.memoryUsagePercent))")
                        Text("•")
                        Text("Uptime: \(node.uptimeString)")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(node.status.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(node.status.lowercased() == "online" ? .green : .red)
                    Text("\(node.maxcpu ?? 0) cores")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
        }
    }

    struct VMsContainersSummarySection: View {
        let vms: [ProxmoxVM]

        private var runningVMs: [ProxmoxVM] {
            vms.filter { $0.isRunning && $0.vmType == .vm }
        }

        private var runningContainers: [ProxmoxVM] {
            vms.filter { $0.isRunning && $0.vmType == .container }
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Active Virtual Resources")
                        .font(.headline)
                    Spacer()
                    if !vms.isEmpty {
                        Text("\(vms.filter { $0.isRunning }.count) running")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if vms.isEmpty {
                    Text("No VMs or containers found")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    VStack(spacing: 8) {
                        if !runningVMs.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Virtual Machines")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)

                                ForEach(runningVMs.prefix(3)) { vm in
                                    VMSummaryRow(vm: vm)
                                }

                                if runningVMs.count > 3 {
                                    Text("and \(runningVMs.count - 3) more...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 8)
                                }
                            }
                        }

                        if !runningContainers.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Containers")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)

                                ForEach(runningContainers.prefix(3)) { vm in
                                    VMSummaryRow(vm: vm)
                                }

                                if runningContainers.count > 3 {
                                    Text("and \(runningContainers.count - 3) more...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 8)
                                }
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }

    struct VMSummaryRow: View {
        let vm: ProxmoxVM

        var body: some View {
            HStack {
                Image(systemName: vm.vmType.icon)
                    .font(.caption)
                    .foregroundColor(vm.vmType.color)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(vm.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Text("CPU: \(String(format: "%.1f%%", vm.cpuUsagePercent)) • RAM: \(String(format: "%.1f%%", vm.memoryUsagePercent))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("ID \(vm.vmid)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(6)
        }
    }

    struct StorageOverviewSection: View {
        let storage: [ProxmoxStorage]

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Storage Pools")
                    .font(.headline)

                if storage.isEmpty {
                    Text("No storage data available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    ForEach(storage) { pool in
                        StorageRow(storage: pool)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }

    struct StorageRow: View {
        let storage: ProxmoxStorage

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(storage.storage)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if storage.isShared {
                            Text("SHARED")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }

                    HStack {
                        Text(storage.type.uppercased())
                        Text("•")
                        if let used = storage.used, let total = storage.total {
                            Text("\(ByteCountFormatter.string(fromByteCount: used, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))")
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.1f%%", storage.usagePercent))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(storage.statusColor)

                    ProgressView(value: storage.usagePercent.isFinite ? storage.usagePercent / 100.0 : 0)
                        .tint(storage.statusColor)
                        .frame(width: 60)
                        .scaleEffect(y: 0.8)
                }
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
        }
    }

    struct ProxmoxVMsView: View {
        let config: ServiceConfig
        @State private var vms: [ProxmoxVM]
        @State private var isRefreshing = false
        private let client: ProxmoxClient

        init(config: ServiceConfig, vms: [ProxmoxVM]) {
            self.config = config
            self._vms = State(initialValue: vms)
            self.client = ProxmoxClient(config: config)
        }

        var body: some View {
            NavigationStack {
                List {
                    ForEach(vms) { vm in
                        NavigationLink(value: vm.vmid) {
                            VMRow(vm: vm)
                        }
                    }
                }
                .navigationDestination(for: String.self) { vmid in
                    if let vm = vms.first(where: { $0.vmid == vmid }) {
                        ProxmoxVMDetailView(config: config, vm: vm)
                    }
                }
                .refreshable {
                    await refreshData()
                }
                .navigationTitle("Virtual Machines (\(vms.count))")
            }
        }

        private func refreshData() async {
            isRefreshing = true
            do {
                let allVMs = try await client.fetchVMs()
                let filteredVMs = allVMs.map { vm in
                    ProxmoxVM(
                        vmid: vm.vmid, name: vm.name, type: vm.type, status: vm.status,
                        node: vm.node, cpu: vm.cpu, cpus: vm.cpus, mem: vm.mem, maxmem: vm.maxmem,
                        disk: vm.disk, maxdisk: vm.maxdisk, netin: vm.netin, netout: vm.netout,
                        uptime: vm.uptime, template: vm.template, hastate: vm.hastate, tags: vm.tags
                    )
                }.filter { $0.vmType == .vm }

                await MainActor.run {
                    self.vms = filteredVMs
                }
            } catch {
                print("Failed to refresh VMs: \(error)")
            }
            isRefreshing = false
        }
    }

    struct ProxmoxContainersView: View {
        let config: ServiceConfig
        @State private var containers: [ProxmoxVM]
        @State private var isRefreshing = false
        private let client: ProxmoxClient

        init(config: ServiceConfig, containers: [ProxmoxVM]) {
            self.config = config
            self._containers = State(initialValue: containers)
            self.client = ProxmoxClient(config: config)
        }

        var body: some View {
            NavigationStack {
                List {
                    ForEach(containers) { container in
                        NavigationLink(value: container.vmid) {
                            VMRow(vm: container)
                        }
                    }
                }
                .navigationDestination(for: String.self) { vmid in
                    if let container = containers.first(where: { $0.vmid == vmid }) {
                        ProxmoxVMDetailView(config: config, vm: container)
                    }
                }
                .refreshable {
                    await refreshData()
                }
                .navigationTitle("Containers (\(containers.count))")
            }
        }

        private func refreshData() async {
            isRefreshing = true
            do {
                let allVMs = try await client.fetchVMs()
                let filteredContainers = allVMs.map { vm in
                    ProxmoxVM(
                        vmid: vm.vmid, name: vm.name, type: vm.type, status: vm.status,
                        node: vm.node, cpu: vm.cpu, cpus: vm.cpus, mem: vm.mem, maxmem: vm.maxmem,
                        disk: vm.disk, maxdisk: vm.maxdisk, netin: vm.netin, netout: vm.netout,
                        uptime: vm.uptime, template: vm.template, hastate: vm.hastate, tags: vm.tags
                    )
                }.filter { $0.vmType == .container }

                await MainActor.run {
                    self.containers = filteredContainers
                }
            } catch {
                print("Failed to refresh containers: \(error)")
            }
            isRefreshing = false
        }
    }

    struct ProxmoxStorageView: View {
        let config: ServiceConfig
        @State private var storage: [ProxmoxStorage]
        @State private var isRefreshing = false
        private let client: ProxmoxClient

        init(config: ServiceConfig, storage: [ProxmoxStorage]) {
            self.config = config
            self._storage = State(initialValue: storage)
            self.client = ProxmoxClient(config: config)
        }

        var body: some View {
            NavigationStack {
                List {
                    ForEach(storage) { pool in
                        NavigationLink(value: pool.storage) {
                            StorageRow(storage: pool)
                        }
                    }
                }
                .navigationDestination(for: String.self) { storageId in
                    if let pool = storage.first(where: { $0.storage == storageId }) {
                        ProxmoxStorageDetailView(config: config, storage: pool)
                    }
                }
                .refreshable {
                    await refreshData()
                }
                .navigationTitle("Storage (\(storage.count))")
            }
        }

        private func refreshData() async {
            isRefreshing = true
            do {
                let storageData = try await client.fetchStorage()
                let updatedStorage = storageData.map { storage in
                    ProxmoxStorage(
                        storage: storage.storage, type: storage.type, node: storage.node,
                        content: storage.content, enabled: storage.enabled, used: storage.used,
                        total: storage.total, avail: storage.avail, shared: storage.shared
                    )
                }

                await MainActor.run {
                    self.storage = updatedStorage
                }
            } catch {
                print("Failed to refresh storage: \(error)")
            }
            isRefreshing = false
        }
    }

    struct ProxmoxNetworkView: View {
        let config: ServiceConfig

        var body: some View {
            List {
                Section("Network Interfaces") {
                    Text("Network management coming soon...")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Network")
        }
    }

    struct ProxmoxVMDetailView: View {
        let config: ServiceConfig
        let vmid: String
        let initialVM: ProxmoxVM
        @StateObject private var viewModel: ProxmoxVMDetailViewModel

        init(config: ServiceConfig, vm: ProxmoxVM) {
            self.config = config
            self.vmid = vm.vmid
            self.initialVM = vm
            _viewModel = StateObject(wrappedValue: ProxmoxVMDetailViewModel(config: config, vm: vm))
        }

        var body: some View {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let error = viewModel.error {
                        ErrorCard(message: error)
                    }

                    // VM Status and Controls
                    VMStatusSection(vm: viewModel.vm, viewModel: viewModel)

                    // Resource Usage
                    VMResourceSection(vm: viewModel.vm)

                    // Configuration Details
                    if let details = viewModel.vmDetails {
                        VMConfigurationSection(details: details)
                    }

                    // Network Information
                    VMNetworkSection(vm: viewModel.vm)

                    // Management Actions
                    VMManagementSection(vm: viewModel.vm, viewModel: viewModel)

                    // Recent Activity/Logs (placeholder)
                    VMActivitySection()
                }
                .padding()
            }
            .navigationTitle(viewModel.vm.displayName)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .onAppear {
                Task { await viewModel.loadVMDetails() }
                viewModel.startAutoRefresh()
            }
            .onDisappear {
                viewModel.stopAutoRefresh()
            }
        }
    }

    @MainActor
    final class ProxmoxVMDetailViewModel: ObservableObject {
        let config: ServiceConfig
        @Published var vm: ProxmoxVM
        private let client: ProxmoxClient
        private var refreshTimer: Timer?
        private var isViewVisible: Bool = false

        @Published var vmDetails: ProxmoxVMDetails?
        @Published var isLoading: Bool = false
        @Published var error: String?

        init(config: ServiceConfig, vm: ProxmoxVM) {
            self.config = config
            self._vm = Published(initialValue: vm)
            self.client = ProxmoxClient(config: config)
        }

        func loadVMDetails() async {
            guard vm.node != nil else { return }

            isLoading = true
            error = nil

            await loadVMDetailsOnly()

            await MainActor.run {
                self.isLoading = false
            }
        }

        private func loadVMDetailsOnly() async {
            guard let node = vm.node else { return }

            do {
                let clientVMType: ClientVMType = vm.vmType == .vm ? .vm : .container
                let details = try await client.fetchVMDetails(
                    node: node,
                    vmid: vm.vmid,
                    type: clientVMType
                )

                await MainActor.run {
                    self.vmDetails = details
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to load VM details: \(error.localizedDescription)"
                }
            }
        }

        func controlVM(action: VMAction) async {
            guard let node = vm.node else { return }

            isLoading = true
            error = nil

            do {
                let clientVMType: ClientVMType = vm.vmType == .vm ? .vm : .container
                try await client.controlVM(
                    node: node,
                    vmid: vm.vmid,
                    type: clientVMType,
                    action: action
                )

                // Wait a moment for the action to take effect
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds

                // Refresh VM data to show updated status
                await refreshVMStatus()

                await MainActor.run {
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to \(action.rawValue) VM: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }

        func refresh() async {
            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }

            // Refresh both VM status and details
            await refreshVMStatus()
            await loadVMDetailsOnly()

            await MainActor.run {
                self.isLoading = false
            }
        }

        private func refreshVMStatus() async {
            // Clear all caches to ensure fresh data
            client.clearCache()

            do {
                let freshVMs = try await client.fetchVMs()

                // Find the updated VM data
                if let updatedVM = freshVMs.first(where: { $0.vmid == vm.vmid }) {
                    await MainActor.run {
                        // Update with fresh VM data
                        self.vm = ProxmoxVM(
                            vmid: updatedVM.vmid,
                            name: updatedVM.name,
                            type: updatedVM.type,
                            status: updatedVM.status,
                            node: updatedVM.node,
                            cpu: updatedVM.cpu,
                            cpus: updatedVM.cpus,
                            mem: updatedVM.mem,
                            maxmem: updatedVM.maxmem,
                            disk: updatedVM.disk,
                            maxdisk: updatedVM.maxdisk,
                            netin: updatedVM.netin,
                            netout: updatedVM.netout,
                            uptime: updatedVM.uptime,
                            template: updatedVM.template,
                            hastate: updatedVM.hastate,
                            tags: updatedVM.tags
                        )
                    }
                }
            } catch {
                await MainActor.run {
                    self.error = "Failed to refresh VM status: \(error.localizedDescription)"
                }
            }
        }

        func startAutoRefresh() {
            isViewVisible = true
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                Task { @MainActor in
                    guard self.isViewVisible else { return }
                    await self.refresh()
                }
            }
        }

        func stopAutoRefresh() {
            isViewVisible = false
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }

    struct VMStatusSection: View {
        let vm: ProxmoxVM
        let viewModel: ProxmoxVMDetailViewModel

        private var statusColor: Color {
            vm.isRunning ? .green : .gray
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(vm.displayName)
                                .font(.title2)
                                .fontWeight(.bold)
                            if vm.isTemplate {
                                Text("TEMPLATE")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(6)
                            }
                        }

                        HStack {
                            Image(systemName: vm.vmType.icon)
                                .foregroundColor(vm.vmType.color)
                            Text(vm.vmType.rawValue)
                            Text("•")
                            Text("ID \(vm.vmid)")
                            if let node = vm.node {
                                Text("•")
                                Text(node)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            Text(vm.status.capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(statusColor)
                        }

                        if vm.isRunning, let uptime = vm.uptime {
                            let uptimeString = formatUptime(uptime)
                            Text("Uptime: \(uptimeString)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Quick action buttons
                if !vm.isTemplate {
                    HStack(spacing: 12) {
                        if vm.isRunning {
                            Button("Stop") {
                                Task { await viewModel.controlVM(action: .stop) }
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                            .controlSize(.small)

                            Button("Reboot") {
                                Task { await viewModel.controlVM(action: .reboot) }
                            }
                            .buttonStyle(.bordered)
                            .tint(.orange)
                            .controlSize(.small)

                            Button("Suspend") {
                                Task { await viewModel.controlVM(action: .suspend) }
                            }
                            .buttonStyle(.bordered)
                            .tint(.yellow)
                            .controlSize(.small)
                        } else {
                            Button("Start") {
                                Task { await viewModel.controlVM(action: .start) }
                            }
                            .buttonStyle(.bordered)
                            .tint(.green)
                            .controlSize(.small)
                        }

                        Spacer()
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }

        private func formatUptime(_ uptime: Int64) -> String {
            let days = uptime / 86400
            let hours = (uptime % 86400) / 3600
            let minutes = (uptime % 3600) / 60

            if days > 0 {
                return "\(days)d \(hours)h"
            } else if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }
    }

    struct VMResourceSection: View {
        let vm: ProxmoxVM

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Resource Usage")
                    .font(.headline)

                if vm.isRunning {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                        ResourceUsageCard(
                            title: "CPU",
                            value: String(format: "%.1f%%", vm.cpuUsagePercent),
                            subtitle: "\(vm.cpus ?? 0) vCPUs",
                            icon: "cpu",
                            color: .blue,
                            progress: vm.cpuUsagePercent.isFinite ? vm.cpuUsagePercent / 100.0 : 0
                        )

                        ResourceUsageCard(
                            title: "Memory",
                            value: String(format: "%.1f%%", vm.memoryUsagePercent),
                            subtitle: vm.maxmem != nil ? ByteCountFormatter.string(fromByteCount: vm.maxmem!, countStyle: .memory) : "Unknown",
                            icon: "memorychip",
                            color: .green,
                            progress: vm.memoryUsagePercent.isFinite ? vm.memoryUsagePercent / 100.0 : 0
                        )

                        ResourceUsageCard(
                            title: "Disk",
                            value: vm.disk != nil ? ByteCountFormatter.string(fromByteCount: vm.disk!, countStyle: .file) : "Unknown",
                            subtitle: vm.maxdisk != nil ? "of \(ByteCountFormatter.string(fromByteCount: vm.maxdisk!, countStyle: .file))" : "",
                            icon: "internaldrive",
                            color: .orange
                        )

                        ResourceUsageCard(
                            title: "Network",
                            value: "Active",
                            subtitle: vm.netin != nil && vm.netout != nil ?
                            "↓\(ByteCountFormatter.string(fromByteCount: vm.netin!, countStyle: .file)) ↑\(ByteCountFormatter.string(fromByteCount: vm.netout!, countStyle: .file))" : "No data",
                            icon: "network",
                            color: .purple
                        )
                    }
                } else {
                    Text("VM is not running - no resource usage data available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }



    struct VMConfigurationSection: View {
        let details: ProxmoxVMDetails

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Configuration")
                    .font(.headline)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    if let cores = details.cores {
                        ConfigItem(label: "CPU Cores", value: "\(cores)")
                    }

                    if let sockets = details.sockets {
                        ConfigItem(label: "CPU Sockets", value: "\(sockets)")
                    }

                    if let memory = details.memory {
                        ConfigItem(label: "Memory", value: ByteCountFormatter.string(fromByteCount: memory, countStyle: .memory))
                    }

                    if let bootdisk = details.bootdisk {
                        ConfigItem(label: "Boot Disk", value: bootdisk)
                    }

                    if let ostype = details.ostype {
                        ConfigItem(label: "OS Type", value: ostype)
                    }

                    if let onboot = details.onboot {
                        ConfigItem(label: "Start at Boot", value: onboot == 1 ? "Yes" : "No")
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }

    struct ConfigItem: View {
        let label: String
        let value: String

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(6)
        }
    }

    struct VMNetworkSection: View {
        let vm: ProxmoxVM

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Network Information")
                    .font(.headline)

                VStack(spacing: 8) {
                    if let netin = vm.netin, let netout = vm.netout {
                        HStack {
                            NetworkMetric(
                                title: "Data In",
                                value: ByteCountFormatter.string(fromByteCount: netin, countStyle: .file),
                                icon: "arrow.down.circle.fill",
                                color: .green
                            )

                            Spacer()

                            NetworkMetric(
                                title: "Data Out",
                                value: ByteCountFormatter.string(fromByteCount: netout, countStyle: .file),
                                icon: "arrow.up.circle.fill",
                                color: .blue
                            )
                        }
                    } else {
                        Text("No network statistics available")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 60)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }



    struct VMManagementSection: View {
        let vm: ProxmoxVM
        let viewModel: ProxmoxVMDetailViewModel

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Management Actions")
                    .font(.headline)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    if !vm.isTemplate {
                        ManagementButton(
                            title: vm.isRunning ? "Shutdown" : "Start",
                            icon: vm.isRunning ? "power" : "play.fill",
                            color: vm.isRunning ? .red : .green
                        ) {
                            Task {
                                await viewModel.controlVM(action: vm.isRunning ? .shutdown : .start)
                            }
                        }

                        if vm.isRunning {
                            ManagementButton(
                                title: "Reboot",
                                icon: "arrow.clockwise",
                                color: .orange
                            ) {
                                Task { await viewModel.controlVM(action: .reboot) }
                            }

                            ManagementButton(
                                title: "Suspend",
                                icon: "pause.fill",
                                color: .yellow
                            ) {
                                Task { await viewModel.controlVM(action: .suspend) }
                            }
                        }

                        ManagementButton(
                            title: "Backup",
                            icon: "archivebox.fill",
                            color: .blue
                        ) {
                            // Placeholder for backup functionality
                        }

                        ManagementButton(
                            title: "Console",
                            icon: "terminal.fill",
                            color: .purple
                        ) {
                            // Placeholder for console functionality
                        }

                        ManagementButton(
                            title: "Settings",
                            icon: "gearshape.fill",
                            color: .gray
                        ) {
                            // Placeholder for settings functionality
                        }
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }

    struct ManagementButton: View {
        let title: String
        let icon: String
        let color: Color
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title2)
                    Text(title)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(color)
            .controlSize(.small)
        }
    }

    struct VMActivitySection: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Recent Activity")
                    .font(.headline)

                Text("Activity logs and monitoring will be available in a future update")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }

    struct ProxmoxStorageDetailView: View {
        let config: ServiceConfig
        let storage: ProxmoxStorage
        @StateObject private var viewModel: ProxmoxStorageDetailViewModel

        init(config: ServiceConfig, storage: ProxmoxStorage) {
            self.config = config
            self.storage = storage
            _viewModel = StateObject(wrappedValue: ProxmoxStorageDetailViewModel(config: config, storage: storage))
        }

        var body: some View {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if let error = viewModel.error {
                        ErrorCard(message: error)
                    }

                    // Storage Overview
                    StorageStatusSection(storage: storage)

                    // Usage Statistics
                    StorageUsageSection(storage: storage)

                    // Content Types
                    StorageContentSection(storage: storage)

                    // Storage Performance
                    StoragePerformanceSection()

                    // Management Actions
                    StorageManagementSection(viewModel: viewModel)

                    // Storage Contents (VMs/Disks)
                    StorageContentsSection(viewModel: viewModel)
                }
                .padding()
            }
            .navigationTitle(storage.storage)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await viewModel.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .onAppear {
                Task { await viewModel.loadStorageDetails() }
            }
        }
    }

    @MainActor
    final class ProxmoxStorageDetailViewModel: ObservableObject {
        let config: ServiceConfig
        let storage: ProxmoxStorage
        private let client: ProxmoxClient

        @Published var storageContents: [StorageContent] = []
        @Published var isLoading: Bool = false
        @Published var error: String?

        init(config: ServiceConfig, storage: ProxmoxStorage) {
            self.config = config
            self.storage = storage
            self.client = ProxmoxClient(config: config)
        }

        func loadStorageDetails() async {
            isLoading = true
            error = nil

            // Load mock storage contents for demonstration
            await MainActor.run {
                self.storageContents = [
                    StorageContent(name: "vm-100-disk-0.qcow2", type: "disk", size: 42949672960, vmid: "100"),
                    StorageContent(name: "vm-101-disk-0.raw", type: "disk", size: 107374182400, vmid: "101"),
                    StorageContent(name: "backup-100-2024_01_15.tar.lz4", type: "backup", size: 5368709120, vmid: "100"),
                    StorageContent(name: "ubuntu-20.04-server.iso", type: "iso", size: 1073741824, vmid: nil)
                ]
                self.isLoading = false
            }
        }

        func refresh() async {
            await loadStorageDetails()
        }
    }

    struct StorageContent: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let type: String
        let size: Int64
        let vmid: String?

        var typeIcon: String {
            switch type.lowercased() {
            case "disk": return "internaldrive"
            case "backup": return "archivebox"
            case "iso": return "opticaldisc"
            case "template": return "doc.on.doc"
            default: return "doc"
            }
        }

        var typeColor: Color {
            switch type.lowercased() {
            case "disk": return .blue
            case "backup": return .green
            case "iso": return .orange
            case "template": return .purple
            default: return .gray
            }
        }

        var sizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }

    struct StorageStatusSection: View {
        let storage: ProxmoxStorage

        var body: some View {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(storage.storage)
                                .font(.title2)
                                .fontWeight(.bold)
                            if storage.isShared {
                                Text("SHARED")
                                    .font(.caption2)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(6)
                            }
                        }

                        HStack {
                            Text(storage.type.uppercased())
                            if let node = storage.node {
                                Text("•")
                                Text("Node: \(node)")
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(storage.isEnabled ? .green : .red)
                                .frame(width: 8, height: 8)
                            Text(storage.isEnabled ? "Enabled" : "Disabled")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(storage.isEnabled ? .green : .red)
                        }
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }

    struct StorageUsageSection: View {
        let storage: ProxmoxStorage

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Storage Usage")
                    .font(.headline)

                if let used = storage.used, let total = storage.total, let avail = storage.avail {
                    VStack(spacing: 16) {
                        // Usage progress bar
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Space Used")
                                    .font(.subheadline)
                                Spacer()
                                Text(String(format: "%.1f%%", storage.usagePercent))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(storage.statusColor)
                            }

                            ProgressView(value: storage.usagePercent.isFinite ? storage.usagePercent / 100.0 : 0)
                                .tint(storage.statusColor)
                                .scaleEffect(y: 2.0)
                        }

                        // Storage metrics
                        HStack(spacing: 0) {
                            MetricCard(
                                title: "Used",
                                value: ByteCountFormatter.string(fromByteCount: used, countStyle: .file),
                                color: .red,
                                isFirst: true
                            )

                            MetricCard(
                                title: "Available",
                                value: ByteCountFormatter.string(fromByteCount: avail, countStyle: .file),
                                color: .green,
                                isFirst: false
                            )

                            MetricCard(
                                title: "Total",
                                value: ByteCountFormatter.string(fromByteCount: total, countStyle: .file),
                                color: .blue,
                                isFirst: false,
                                isLast: true
                            )
                        }
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 1)
                    }
                } else {
                    Text("Storage usage information not available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }



    struct StorageContentSection: View {
        let storage: ProxmoxStorage

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Supported Content Types")
                    .font(.headline)

                if !storage.contentTypes.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(storage.contentTypes, id: \.self) { contentType in
                            ContentTypeChip(type: contentType)
                        }
                    }
                } else {
                    Text("No content type information available")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }

    struct ContentTypeChip: View {
        let type: String

        private var typeInfo: (String, String, Color) {
            switch type.lowercased() {
            case "images": return ("VM Disks", "internaldrive", .blue)
            case "backup": return ("Backups", "archivebox", .green)
            case "iso": return ("ISO Files", "opticaldisc", .orange)
            case "rootdir": return ("CT Root", "folder", .purple)
            case "vztmpl": return ("CT Templates", "doc.on.doc", .cyan)
            case "snippets": return ("Snippets", "doc.text", .gray)
            default: return (type.capitalized, "doc", .gray)
            }
        }

        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: typeInfo.1)
                    .font(.caption)
                    .foregroundColor(typeInfo.2)
                Text(typeInfo.0)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(typeInfo.2.opacity(0.1))
            .foregroundColor(typeInfo.2)
            .cornerRadius(6)
        }
    }

    struct StoragePerformanceSection: View {
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Performance Metrics")
                    .font(.headline)

                HStack(spacing: 16) {
                    PerformanceMetric(
                        title: "Read IOPS",
                        value: "2.4K",
                        icon: "arrow.down.circle",
                        color: .green
                    )

                    PerformanceMetric(
                        title: "Write IOPS",
                        value: "1.8K",
                        icon: "arrow.up.circle",
                        color: .blue
                    )

                    PerformanceMetric(
                        title: "Latency",
                        value: "12ms",
                        icon: "speedometer",
                        color: .orange
                    )

                    Spacer()
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }

    struct PerformanceMetric: View {
        let title: String
        let value: String
        let icon: String
        let color: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundColor(color)
                    Text(title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            }
        }
    }

    struct StorageManagementSection: View {
        let viewModel: ProxmoxStorageDetailViewModel

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text("Management Actions")
                    .font(.headline)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    StorageActionButton(
                        title: "Cleanup",
                        icon: "trash.circle",
                        color: .orange
                    ) {
                        // Placeholder for cleanup functionality
                    }

                    StorageActionButton(
                        title: "Backup",
                        icon: "archivebox",
                        color: .blue
                    ) {
                        // Placeholder for backup functionality
                    }

                    StorageActionButton(
                        title: "Monitor",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .purple
                    ) {
                        // Placeholder for monitoring functionality
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }

    struct StorageActionButton: View {
        let title: String
        let icon: String
        let color: Color
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title2)
                    Text(title)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
            .tint(color)
            .controlSize(.small)
        }
    }

    struct StorageContentsSection: View {
        let viewModel: ProxmoxStorageDetailViewModel

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Storage Contents")
                        .font(.headline)
                    Spacer()
                    if !viewModel.storageContents.isEmpty {
                        Text("\(viewModel.storageContents.count) items")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if viewModel.isLoading {
                    ProgressView("Loading contents...")
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else if viewModel.storageContents.isEmpty {
                    Text("No contents found")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    ForEach(viewModel.storageContents) { content in
                        StorageContentRow(content: content)
                    }
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))
            .cornerRadius(12)
        }
    }

    struct StorageContentRow: View {
        let content: StorageContent

        var body: some View {
            HStack {
                Image(systemName: content.typeIcon)
                    .font(.title2)
                    .foregroundColor(content.typeColor)

                VStack(alignment: .leading, spacing: 4) {
                    Text(content.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    HStack {
                        Text(content.type.capitalized)
                        if let vmid = content.vmid {
                            Text("•")
                            Text("VM \(vmid)")
                        }
                        Text("•")
                        Text(content.sizeFormatted)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    // Placeholder for content actions
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(8)
        }
    }

    struct VMRow: View {
        let vm: ProxmoxVM

        var body: some View {
            HStack {
                Image(systemName: vm.vmType.icon)
                    .font(.title2)
                    .foregroundColor(vm.vmType.color)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(vm.displayName)
                            .font(.headline)
                        if vm.isTemplate {
                            Text("TEMPLATE")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.2))
                                .foregroundColor(.orange)
                                .cornerRadius(4)
                        }
                    }

                    HStack {
                        Text("ID \(vm.vmid)")
                        Text("•")
                        Text(vm.node ?? "Unknown node")
                        if !vm.tagList.isEmpty {
                            Text("•")
                            Text(vm.tagList.joined(separator: ", "))
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    if vm.isRunning {
                        HStack {
                            Text("CPU: \(String(format: "%.1f%%", vm.cpuUsagePercent))")
                            Text("RAM: \(String(format: "%.1f%%", vm.memoryUsagePercent))")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(vm.status.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(vm.isRunning ? .green : .gray)

                    if let cpus = vm.cpus {
                        Text("\(cpus) vCPU")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }


}

// MARK: - Extensions

extension ProxmoxView {
    static func make(config: ServiceConfig) -> ProxmoxView {
        ProxmoxView(config: config)
    }
}

extension ServiceStatsPayload {
    var proxmox: ProxmoxStats? {
        if case .proxmox(let stats) = self {
            return stats
        }
        return nil
    }
}
