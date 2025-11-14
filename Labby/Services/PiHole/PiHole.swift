import SwiftUI
import Combine

// MARK: - PiHole API Models (extended for detailed view)

// Use PiHoleQueryLogEntry from PiHoleClient
typealias PiHoleQueryLog = PiHoleQueryLogEntry

struct PiHoleTopClient: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let count: Int

    init(name: String, count: Int) {
        self.id = UUID()
        self.name = name
        self.count = count
    }
}

struct PiHoleTopDomain: Codable, Identifiable, Equatable {
    let id: UUID
    let domain: String
    let count: Int

    init(domain: String, count: Int) {
        self.id = UUID()
        self.domain = domain
        self.count = count
    }
}

struct PiHoleDetailedStats: Equatable {
    let summary: PiHoleStats
    let topClients: [PiHoleTopClient]
    let topBlockedDomains: [PiHoleTopDomain]
    let topPermittedDomains: [PiHoleTopDomain]
    let queryTypes: [String: Int]
    let recentQueries: [PiHoleQueryLog]
    let blockingEnabled: Bool
}

// MARK: - View Models

@MainActor
final class PiHoleViewModel: ObservableObject {
    let config: ServiceConfig
    private let client: PiHoleClient
    private var refreshTimer: Timer?

    @Published var stats: PiHoleStats?
    @Published var detailedStats: PiHoleDetailedStats?
    @Published var recentQueries: [PiHoleQueryLog] = []
    @Published var topClients: [PiHoleTopClient] = []
    @Published var topBlockedDomains: [PiHoleTopDomain] = []
    @Published var topPermittedDomains: [PiHoleTopDomain] = []
    @Published var queryTypes: [String: Int] = [:]
    @Published var blockingEnabled: Bool = true
    @Published var isLoading: Bool = false
    @Published var error: String?

    init(config: ServiceConfig) {
        self.config = config
        self.client = PiHoleClient(config: config)
    }

    func refresh() async {
        isLoading = true
        error = nil

        do {
            // Fetch basic stats
            if let payload = try await client.fetchStats().pihole {
                await MainActor.run {
                    self.stats = payload
                }
            }

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }

        await MainActor.run {
            self.isLoading = false
        }
    }

    private func fetchDetailedData() async {
        do {
            let blocking = try await client.fetchBlockingStatus()
            await MainActor.run {
                self.blockingEnabled = blocking
            }
        } catch {
            print("Failed to fetch blocking status: \(error)")
        }
    }

    private func fetchTopClients() async -> [PiHoleTopClient] {
        do {
            let clientData = try await client.fetchTopClients(limit: 5)
            return clientData.map { PiHoleTopClient(name: $0.0, count: $0.1) }
        } catch {
            print("Failed to fetch top clients: \(error)")
            return []
        }
    }

    private func fetchTopBlockedDomains() async -> [PiHoleTopDomain] {
        do {
            let blockedData = try await client.fetchTopBlockedDomains(limit: 5)
            return blockedData.map { PiHoleTopDomain(domain: $0.0, count: $0.1) }
        } catch {
            print("Failed to fetch top blocked domains: \(error)")
            return []
        }
    }

    func toggleBlocking() async {
        do {
            try await client.toggleBlocking(enable: !blockingEnabled)
            await MainActor.run {
                self.blockingEnabled.toggle()
            }
            await refresh()
        } catch {
            await MainActor.run {
                self.error = "Failed to toggle blocking: \(error.localizedDescription)"
            }
        }
    }

    func flushLogs() async {
        do {
            try await client.flushLogs()
            await refresh()
        } catch {
            await MainActor.run {
                self.error = "Failed to flush logs: \(error.localizedDescription)"
            }
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
}

// MARK: - Views

struct PiHoleView: View {
    let config: ServiceConfig
    @StateObject private var vm: PiHoleViewModel

    init(config: ServiceConfig) {
        self.config = config
        _vm = StateObject(wrappedValue: PiHoleViewModel(config: config))
    }

    var body: some View {
        ScrollView {
                VStack(spacing: 16) {
                    if let error = vm.error {
                        ErrorCard(message: error)
                    }

                    if vm.isLoading && vm.stats == nil {
                        ProgressView("Loading Pi-hole data...")
                            .frame(maxWidth: .infinity, minHeight: 100)
                    } else if let stats = vm.stats {
                        VStack(spacing: 16) {
                            // Status Overview
                            StatusOverviewCard(stats: stats, blockingEnabled: vm.blockingEnabled) {
                                Task { await vm.toggleBlocking() }
                            }

                            // Quick Stats Grid
                            QuickStatsGrid(stats: stats)

                            // Network Health
                            NetworkHealthCard(stats: stats)

                            // Recent Activity Summary
                            RecentActivityCard(blockingEnabled: vm.blockingEnabled)

                            // Detailed Dashboard Link
                            NavigationLink {
                                PiHoleDetailView(config: config)
                            } label: {
                                DetailedDashboardCard(subtitle: "View logs, top domains, and advanced controls")
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Pi-hole")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task { await vm.refresh() }
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

struct StatusOverviewCard: View {
    let stats: PiHoleStats
    let blockingEnabled: Bool
    let onToggleBlocking: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pi-hole Status")
                        .font(.headline)
                    Text(blockingEnabled ? "Protection Active" : "Protection Disabled")
                        .font(.subheadline)
                        .foregroundColor(blockingEnabled ? .green : .orange)
                }
                Spacer()
                Button(action: onToggleBlocking) {
                    Image(systemName: blockingEnabled ? "shield.fill" : "shield.slash.fill")
                        .font(.title2)
                        .foregroundColor(blockingEnabled ? .green : .orange)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 20) {
                StatPill(
                    title: "Blocked Today",
                    value: "\(stats.adsBlockedToday)",
                    systemImage: "shield.checkerboard"
                )
                StatPill(
                    title: "Block Rate",
                    value: String(format: "%.1f%%", stats.adsPercentageToday),
                    systemImage: "chart.pie.fill"
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct QuickStatsGrid: View {
    let stats: PiHoleStats

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            StatCard(
                title: "Queries Today",
                value: "\(stats.dnsQueriesToday)",
                icon: "magnifyingglass.circle.fill",
                color: .blue
            )

            StatCard(
                title: "Domains Blocked",
                value: "\(stats.domainsBeingBlocked)",
                icon: "list.bullet.circle.fill",
                color: .red
            )

            StatCard(
                title: "Unique Clients",
                value: "\(stats.uniqueClients)",
                icon: "person.2.circle.fill",
                color: .green
            )

            StatCard(
                title: "Queries Forwarded",
                value: "\(stats.queriesForwarded)",
                icon: "arrow.forward.circle.fill",
                color: .orange
            )
        }
    }
}





struct NetworkHealthCard: View {
    let stats: PiHoleStats

    private var healthScore: Double {
        let blockingEfficiency = stats.adsPercentageToday / 100.0
        let queryVolume = min(Double(stats.dnsQueriesToday) / 10000.0, 1.0)
        return (blockingEfficiency * 0.7) + (queryVolume * 0.3)
    }

    private var healthStatus: (String, Color) {
        switch healthScore {
        case 0.8...1.0: return ("Excellent", .green)
        case 0.6..<0.8: return ("Good", .blue)
        case 0.4..<0.6: return ("Fair", .orange)
        default: return ("Needs Attention", .red)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Network Health")
                    .font(.headline)
                Spacer()
                Text(healthStatus.0)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(healthStatus.1)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protection Rate")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f%%", stats.adsPercentageToday))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(stats.adsPercentageToday > 20 ? .green : .orange)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Clients")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(stats.uniqueClients)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }

                Divider()

                VStack(alignment: .leading, spacing: 4) {
                    Text("Cache Efficiency")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let cacheRate = stats.dnsQueriesToday > 0 ?
                        (Double(stats.queriesCached) / Double(stats.dnsQueriesToday)) * 100 : 0
                    Text(String(format: "%.1f%%", cacheRate))
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(cacheRate > 30 ? .green : .orange)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct RecentActivityCard: View {
    let blockingEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("System Status")
                    .font(.headline)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(blockingEnabled ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(blockingEnabled ? "Active" : "Disabled")
                        .font(.caption)
                        .foregroundColor(blockingEnabled ? .green : .red)
                }
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "shield.checkered")
                            .foregroundColor(.blue)
                        Text("DNS Filtering")
                            .font(.subheadline)
                    }
                    Text(blockingEnabled ? "Protecting your network" : "Protection disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Text("Uptime")
                            .font(.subheadline)
                        Image(systemName: "clock")
                            .foregroundColor(.green)
                    }
                    Text("Active")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}



// MARK: - Detailed View

struct PiHoleDetailView: View {
    let config: ServiceConfig
    @StateObject private var vm: PiHoleDetailViewModel

    init(config: ServiceConfig) {
        self.config = config
        _vm = StateObject(wrappedValue: PiHoleDetailViewModel(config: config))
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if let error = vm.error {
                    ErrorCard(message: error)
                }

                if vm.isLoading && vm.stats == nil {
                    ProgressView("Loading detailed data...")
                        .frame(maxWidth: .infinity, minHeight: 100)
                } else {
                    // Status Overview
                    if let stats = vm.stats {
                        StatusOverviewSection(
                            stats: stats,
                            blockingEnabled: vm.blockingEnabled,
                            onToggleBlocking: { Task { await vm.toggleBlocking() } }
                        )
                    }

                    // Control Panel
                    ControlPanelSection(
                        blockingEnabled: vm.blockingEnabled,
                        onToggleBlocking: { Task { await vm.toggleBlocking() } },
                        onFlushLogs: { Task { await vm.flushLogs() } }
                    )

                    // Statistics Overview
                    if let stats = vm.stats {
                        StatisticsOverviewSection(stats: stats)
                    }

                    // Settings & Management
                    SettingsManagementSection(
                        blockingEnabled: vm.blockingEnabled,
                        onToggleBlocking: { Task { await vm.toggleBlocking() } },
                        onRefreshQueries: { Task { await vm.refresh() } },
                        onFlushLogs: { Task { await vm.flushLogs() } }
                    )

                    // Recent Queries
                    RecentQueriesSection(queries: vm.recentQueries)

                    // Top Clients
                    TopClientsSection(clients: vm.topClients)

                    // Top Blocked Domains
                    TopBlockedDomainsSection(domains: vm.topBlockedDomains)
                }
            }
            .padding()
        }
        .navigationTitle("Pi-hole Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await vm.refresh() }
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

@MainActor
final class PiHoleDetailViewModel: ObservableObject {
    let config: ServiceConfig
    private let client: PiHoleClient
    private var refreshTimer: Timer?

    @Published var stats: PiHoleStats?
    @Published var recentQueries: [PiHoleQueryLog] = []
    @Published var topClients: [PiHoleTopClient] = []
    @Published var topBlockedDomains: [PiHoleTopDomain] = []
    @Published var blockingEnabled: Bool = true
    @Published var isLoading: Bool = false
    @Published var error: String?

    init(config: ServiceConfig) {
        self.config = config
        self.client = PiHoleClient(config: config)
    }

    func refresh() async {
        isLoading = true
        error = nil

        do {
            if let payload = try await client.fetchStats().pihole {
                await MainActor.run {
                    self.stats = payload
                }
            }

            // Fetch additional detailed data
            await loadDetailedData()

        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }

        await MainActor.run {
            self.isLoading = false
        }
    }

    private func loadDetailedData() async {
        async let topClientsData = fetchTopClients()
        async let topBlockedData = fetchTopBlockedDomains()
        async let queryLogData = fetchQueryLog()
        async let blockingStatus = fetchBlockingStatus()

        let (clients, blocked, queries, blocking) = await (topClientsData, topBlockedData, queryLogData, blockingStatus)

        await MainActor.run {
            self.topClients = clients
            self.topBlockedDomains = blocked
            self.recentQueries = queries
            self.blockingEnabled = blocking
        }
    }

    private func fetchTopClients() async -> [PiHoleTopClient] {
        do {
            let clientData = try await client.fetchTopClients(limit: 10)
            return clientData.map { PiHoleTopClient(name: $0.0, count: $0.1) }
        } catch {
            print("Failed to fetch top clients: \(error)")
            return []
        }
    }

    private func fetchTopBlockedDomains() async -> [PiHoleTopDomain] {
        do {
            let blockedData = try await client.fetchTopBlockedDomains(limit: 10)
            return blockedData.map { PiHoleTopDomain(domain: $0.0, count: $0.1) }
        } catch {
            print("Failed to fetch top blocked domains: \(error)")
            return []
        }
    }

    private func fetchQueryLog() async -> [PiHoleQueryLog] {
        do {
            return try await client.fetchQueryLog(limit: 50)
        } catch {
            print("Failed to fetch query log: \(error)")
            return []
        }
    }

    private func fetchBlockingStatus() async -> Bool {
        do {
            return try await client.fetchBlockingStatus()
        } catch {
            print("Failed to fetch blocking status: \(error)")
            return true
        }
    }

    func toggleBlocking() async {
        do {
            try await client.toggleBlocking(enable: !blockingEnabled)
            await MainActor.run {
                self.blockingEnabled.toggle()
            }
            await refresh()
        } catch {
            await MainActor.run {
                self.error = "Failed to toggle blocking: \(error.localizedDescription)"
            }
        }
    }

    func flushLogs() async {
        do {
            try await client.flushLogs()
            await refresh()
        } catch {
            await MainActor.run {
                self.error = "Failed to flush logs: \(error.localizedDescription)"
            }
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

struct ControlPanelSection: View {
    let blockingEnabled: Bool
    let onToggleBlocking: () -> Void
    let onFlushLogs: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Control Panel")
                .font(.headline)

            HStack(spacing: 12) {
                Button(action: onToggleBlocking) {
                    HStack {
                        Image(systemName: blockingEnabled ? "shield.slash" : "shield")
                        Text(blockingEnabled ? "Disable Blocking" : "Enable Blocking")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(blockingEnabled ? .orange : .green)

                Button(action: onFlushLogs) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Flush Logs")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct StatisticsOverviewSection: View {
    let stats: PiHoleStats

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Statistics Overview")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                StatRow(title: "Total Queries", value: "\(stats.dnsQueriesToday)")
                StatRow(title: "Queries Blocked", value: "\(stats.adsBlockedToday)")
                StatRow(title: "Percent Blocked", value: String(format: "%.1f%%", stats.adsPercentageToday))
                StatRow(title: "Unique Clients", value: "\(stats.uniqueClients)")
                StatRow(title: "Domains on Blocklist", value: "\(stats.domainsBeingBlocked)")
                StatRow(title: "Queries Forwarded", value: "\(stats.queriesForwarded)")
                StatRow(title: "Queries Cached", value: "\(stats.queriesCached)")

                if let gravityUpdate = stats.gravityLastUpdatedRelative {
                    StatRow(title: "Gravity Last Updated", value: gravityUpdate)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct StatRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

struct RecentQueriesSection: View {
    let queries: [PiHoleQueryLog]
    @State private var selectedFilter: QueryFilter = .all

    enum QueryFilter: String, CaseIterable {
        case all = "All"
        case blocked = "Blocked"
        case allowed = "Allowed"
        case forwarded = "Forwarded"
        case cached = "Cached"
    }

    private var filteredQueries: [PiHoleQueryLog] {
        switch selectedFilter {
        case .all:
            return queries
        case .blocked:
            return queries.filter { $0.isBlocked }
        case .allowed:
            return queries.filter { !$0.isBlocked && $0.status != 2 && $0.status != 3 }
        case .forwarded:
            return queries.filter { $0.status == 2 }
        case .cached:
            return queries.filter { $0.status == 3 }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Queries")
                    .font(.headline)
                Spacer()
                if !queries.isEmpty {
                    Text("\(filteredQueries.count) of \(queries.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Filter picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(QueryFilter.allCases, id: \.self) { filter in
                        Button(filter.rawValue) {
                            selectedFilter = filter
                        }
                        .buttonStyle(.bordered)
                        .tint(selectedFilter == filter ? .blue : .gray)
                        .font(.caption)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal, 4)
            }

            if filteredQueries.isEmpty {
                Text(queries.isEmpty ? "No recent queries" : "No queries match the selected filter")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ForEach(filteredQueries.prefix(15)) { query in
                    QueryRow(query: query)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct QueryRow: View {
    let query: PiHoleQueryLog

    private var statusColor: Color {
        switch query.statusColor {
        case "red": return .red
        case "green": return .green
        case "blue": return .blue
        default: return .gray
        }
    }

    var body: some View {
        HStack {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(query.domain)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                HStack {
                    Text(query.formattedTime)
                    Text("•")
                    Text(query.client)
                    Text("•")
                    Text(query.queryType)
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(query.statusDescription)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(statusColor)
                if let responseTime = query.responseTime {
                    Text(String(format: "%.0fms", responseTime * 1000))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

struct TopClientsSection: View {
    let clients: [PiHoleTopClient]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Clients")
                .font(.headline)

            if clients.isEmpty {
                Text("No client data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ForEach(clients.prefix(5)) { client in
                    HStack {
                        Text(client.name)
                            .font(.subheadline)
                        Spacer()
                        Text("\(client.count) queries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct TopBlockedDomainsSection: View {
    let domains: [PiHoleTopDomain]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Top Blocked Domains")
                .font(.headline)

            if domains.isEmpty {
                Text("No blocked domains data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ForEach(domains.prefix(5)) { domain in
                    HStack {
                        Text(domain.domain)
                            .font(.subheadline)
                        Spacer()
                        Text("\(domain.count) blocked")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(8)
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct SettingsManagementSection: View {
    let blockingEnabled: Bool
    let onToggleBlocking: () -> Void
    let onRefreshQueries: () -> Void
    let onFlushLogs: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings & Management")
                .font(.headline)

            // Primary Controls
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("DNS Blocking")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(blockingEnabled ? "Currently protecting your network" : "Protection is disabled")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button(action: onToggleBlocking) {
                        HStack(spacing: 6) {
                            Image(systemName: blockingEnabled ? "shield.slash.fill" : "shield.fill")
                            Text(blockingEnabled ? "Disable" : "Enable")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                    }
                    .buttonStyle(.bordered)
                    .tint(blockingEnabled ? .orange : .green)
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(8)
            }

            // Management Tools
            VStack(alignment: .leading, spacing: 8) {
                Text("Management Tools")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                    Button(action: onRefreshQueries) {
                        VStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title2)
                            Text("Refresh Data")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)

                    Button(action: onFlushLogs) {
                        VStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                                .font(.title2)
                            Text("Flush Logs")
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }

            // Additional Settings
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Actions")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Button {
                        // Placeholder for future functionality
                    } label: {
                        HStack {
                            Image(systemName: "list.bullet")
                            Text("Blocklist")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)

                    Button {
                        // Placeholder for future functionality
                    } label: {
                        HStack {
                            Image(systemName: "network")
                            Text("Network")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)

                    Button {
                        // Placeholder for future functionality
                    } label: {
                        HStack {
                            Image(systemName: "gearshape")
                            Text("Settings")
                        }
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.gray)
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct StatusOverviewSection: View {
    let stats: PiHoleStats
    let blockingEnabled: Bool
    let onToggleBlocking: () -> Void

    private var blockingEffectiveness: String {
        if stats.adsBlockedToday == 0 {
            return "No threats blocked today"
        } else if stats.adsPercentageToday > 30 {
            return "High protection active"
        } else if stats.adsPercentageToday > 15 {
            return "Moderate protection active"
        } else {
            return "Light protection active"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with toggle
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pi-hole Dashboard")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(blockingEffectiveness)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: onToggleBlocking) {
                    Image(systemName: blockingEnabled ? "shield.fill" : "shield.slash.fill")
                        .font(.title)
                        .foregroundColor(blockingEnabled ? .green : .red)
                }
                .buttonStyle(.borderless)
            }

            // Key metrics at a glance
            HStack(spacing: 0) {
                MetricCard(
                    title: "Queries Today",
                    value: "\(stats.dnsQueriesToday)",
                    subtitle: "Total requests",
                    color: .blue,
                    isFirst: true
                )

                MetricCard(
                    title: "Blocked",
                    value: "\(stats.adsBlockedToday)",
                    subtitle: String(format: "%.1f%% blocked", stats.adsPercentageToday),
                    color: .red,
                    isFirst: false
                )

                MetricCard(
                    title: "Clients",
                    value: "\(stats.uniqueClients)",
                    subtitle: "Active devices",
                    color: .green,
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



// MARK: - Utility Views


// MARK: - Extensions

extension PiHoleView {
    static func make(config: ServiceConfig) -> PiHoleView {
        PiHoleView(config: config)
    }
}

extension ServiceStatsPayload {
    var pihole: PiHoleStats? {
        if case .pihole(let stats) = self {
            return stats
        }
        return nil
    }
}
