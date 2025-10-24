import SwiftUI
import Combine

// MARK: - qBittorrent API Models (minimal but extensible)

// Matches /api/v2/torrents/info
// Note: Using server's snake_case keys to avoid custom CodingKeys and speed-up type-checking
struct QBTorrentInfo: Codable, Identifiable, Equatable {
    var id: String { hash }

    let hash: String
    let name: String?
    let state: String?
    let dlspeed: Int?
    let upspeed: Int?
    let progress: Double?
    let size: Int64?
    let downloaded: Int64?
    let uploaded: Int64?
    let eta: Int?
    let category: String?
    let num_seeds: Int?
    let num_leechs: Int?
    let added_on: Int?
}

// Matches /api/v2/torrents/properties
struct QBTorrentProperties: Codable, Equatable {
    let save_path: String?
    let total_size: Int64?
    let piece_size: Int64?
    let pieces_num: Int?
    let reannounce: Int?
    let last_seen: Int?
    let total_downloaded: Int64?
    let total_uploaded: Int64?
    let time_elapsed: Int?
    let seeding_time: Int?
    let nb_connections: Int?
    let nb_connections_limit: Int?
    let share_ratio: Double?
    let dl_speed_avg: Int?
    let up_speed_avg: Int?
    let dl_limit: Int?
    let up_limit: Int?
    let completed: Int64?
    let addition_date: Int?
    let completion_date: Int?
    let creation_date: Int?
}

// Matches /api/v2/torrents/files
struct QBTorrentFile: Codable, Identifiable, Equatable {
    var id: String { "\(name ?? "")-\(index ?? -1)" }
    let index: Int?
    let name: String?
    let size: Int64?
    let progress: Double?
    let priority: Int?
    let is_seed: Bool?
}

// Global speed limits
struct QBTGlobalLimits: Equatable {
    var downloadLimitBps: Int
    var uploadLimitBps: Int
    var alternativeModeEnabled: Bool
}

// MARK: - Client Extensions for qBittorrent controls

extension QBittorrentClient {

    // Shared (per process) simple cookie cache by service id
    private static var _cookieCache = [UUID: String]()
    private static let _cookieLock = NSLock()

    // Build a session respecting insecure TLS config
    private func makeSession() -> URLSession {
        if config.insecureSkipTLSVerify {
            return URLSession(
                configuration: .ephemeral,
                delegate: InsecureSessionDelegate(),
                delegateQueue: nil
            )
        } else {
            return URLSession(configuration: .ephemeral)
        }
    }

    private func cachedCookie() -> String? {
        Self._cookieLock.lock()
        defer { Self._cookieLock.unlock() }
        return Self._cookieCache[config.id]
    }

    private func storeCookie(_ cookie: String) {
        Self._cookieLock.lock()
        Self._cookieCache[config.id] = cookie
        Self._cookieLock.unlock()
    }

    // Login and return "SID=..." cookie pair
    private func loginAndGetCookie(session: URLSession) async throws -> String {
        let url = try config.url(appending: "/api/v2/auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        guard case .usernamePassword(let username, let passwordKey) = config.auth else {
            throw ServiceError.unknown
        }
        guard
            let passData = KeychainStorage.shared.loadSecret(forKey: passwordKey),
            let password = String(data: passData, encoding: .utf8)
        else {
            throw ServiceError.missingSecret
        }

        let form =
            "username=\(username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username)&password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? password)"
        request.httpBody = form.data(using: .utf8)

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }

        if let setCookie = http.value(forHTTPHeaderField: "Set-Cookie")
            ?? headerValue(http, for: "set-cookie"),
           let sid = extractSIDCookie(from: setCookie)
        {
            storeCookie(sid)
            return sid
        }
        throw ServiceError.httpStatus(http.statusCode)
    }

    private func getCookie(session: URLSession) async throws -> String {
        if let c = cachedCookie() { return c }
        return try await loginAndGetCookie(session: session)
    }

    // Small helpers copied here (can't access file-private ones across files)
    private func extractSIDCookie(from header: String) -> String? {
        guard let range = header.range(of: "SID=") else { return nil }
        let start = range.lowerBound
        let afterSID = header[start...]
        if let semicolon = afterSID.firstIndex(of: ";") {
            return String(afterSID[..<semicolon])
        } else {
            return String(afterSID)
        }
    }

    private func headerValue(_ http: HTTPURLResponse, for key: String) -> String? {
        for (k, v) in http.allHeaderFields {
            if String(describing: k).lowercased() == key.lowercased() {
                return v as? String
            }
        }
        return nil
    }

    private func makeAuthedRequest(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil,
        cookie: String,
        body: Data? = nil,
        contentType: String? = nil
    ) throws -> URLRequest {
        let url = try config.url(appending: path, queryItems: queryItems)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        req.setValue(cookie, forHTTPHeaderField: "Cookie")
        if let contentType = contentType {
            req.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        req.httpBody = body
        return req
    }

    // MARK: Public async APIs used by the views

    func listTorrents() async throws -> [QBTorrentInfo] {
        let session = makeSession()
        let cookie = try await getCookie(session: session)
        let req = try makeAuthedRequest(path: "/api/v2/torrents/info", cookie: cookie)
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ServiceError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode([QBTorrentInfo].self, from: data)
    }

    func pauseTorrent(hash: String) async throws {
        let session = makeSession()
        let cookie = try await getCookie(session: session)
        let body = "hashes=\(hash)".data(using: .utf8)
        let req = try makeAuthedRequest(
            path: "/api/v2/torrents/pause", method: "POST", cookie: cookie, body: body,
            contentType: "application/x-www-form-urlencoded"
        )
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ServiceError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    func resumeTorrent(hash: String) async throws {
        let session = makeSession()
        let cookie = try await getCookie(session: session)
        let body = "hashes=\(hash)".data(using: .utf8)
        let req = try makeAuthedRequest(
            path: "/api/v2/torrents/resume", method: "POST", cookie: cookie, body: body,
            contentType: "application/x-www-form-urlencoded"
        )
        let (_, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ServiceError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    func torrentProperties(hash: String) async throws -> QBTorrentProperties {
        let session = makeSession()
        let cookie = try await getCookie(session: session)
        let req = try makeAuthedRequest(
            path: "/api/v2/torrents/properties",
            queryItems: [URLQueryItem(name: "hash", value: hash)],
            cookie: cookie
        )
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ServiceError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode(QBTorrentProperties.self, from: data)
    }

    func torrentFiles(hash: String) async throws -> [QBTorrentFile] {
        let session = makeSession()
        let cookie = try await getCookie(session: session)
        let req = try makeAuthedRequest(
            path: "/api/v2/torrents/files",
            queryItems: [URLQueryItem(name: "hash", value: hash)],
            cookie: cookie
        )
        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ServiceError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return try JSONDecoder().decode([QBTorrentFile].self, from: data)
    }

    func globalLimits() async throws -> QBTGlobalLimits {
        let session = makeSession()
        let cookie = try await getCookie(session: session)

        // Download limit
        let dlReq = try makeAuthedRequest(path: "/api/v2/transfer/downloadLimit", cookie: cookie)
        let (dlData, dlResp) = try await session.data(for: dlReq)
        guard let dlHTTP = dlResp as? HTTPURLResponse, 200..<300 ~= dlHTTP.statusCode else {
            throw ServiceError.httpStatus((dlResp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let dlString = String(data: dlData, encoding: .utf8) ?? "0"
        let dlVal = Int(dlString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        // Upload limit
        let ulReq = try makeAuthedRequest(path: "/api/v2/transfer/uploadLimit", cookie: cookie)
        let (ulData, ulResp) = try await session.data(for: ulReq)
        guard let ulHTTP = ulResp as? HTTPURLResponse, 200..<300 ~= ulHTTP.statusCode else {
            throw ServiceError.httpStatus((ulResp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let ulString = String(data: ulData, encoding: .utf8) ?? "0"
        let ulVal = Int(ulString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

        // Mode
        let modeReq = try makeAuthedRequest(path: "/api/v2/transfer/speedLimitsMode", cookie: cookie)
        let (modeData, modeResp) = try await session.data(for: modeReq)
        guard let modeHTTP = modeResp as? HTTPURLResponse, 200..<300 ~= modeHTTP.statusCode else {
            throw ServiceError.httpStatus((modeResp as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let modeString = String(data: modeData, encoding: .utf8) ?? "0"
        let alt = (Int(modeString.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0) == 1

        return QBTGlobalLimits(downloadLimitBps: dlVal, uploadLimitBps: ulVal, alternativeModeEnabled: alt)
    }

    func setGlobalDownloadLimit(_ bytesPerSec: Int) async throws {
        let session = makeSession()
        let cookie = try await getCookie(session: session)
        let body = "limit=\(bytesPerSec)".data(using: .utf8)
        let req = try makeAuthedRequest(
            path: "/api/v2/transfer/setDownloadLimit", method: "POST", cookie: cookie, body: body,
            contentType: "application/x-www-form-urlencoded"
        )
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ServiceError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    func setGlobalUploadLimit(_ bytesPerSec: Int) async throws {
        let session = makeSession()
        let cookie = try await getCookie(session: session)
        let body = "limit=\(bytesPerSec)".data(using: .utf8)
        let req = try makeAuthedRequest(
            path: "/api/v2/transfer/setUploadLimit", method: "POST", cookie: cookie, body: body,
            contentType: "application/x-www-form-urlencoded"
        )
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ServiceError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }

    func toggleAlternativeSpeedLimits() async throws {
        let session = makeSession()
        let cookie = try await getCookie(session: session)
        let req = try makeAuthedRequest(
            path: "/api/v2/transfer/toggleSpeedLimitsMode", method: "POST", cookie: cookie
        )
        let (_, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw ServiceError.httpStatus((resp as? HTTPURLResponse)?.statusCode ?? -1)
        }
    }
}

// MARK: - View Models

@MainActor
final class QBittorrentViewModel: ObservableObject {
    let config: ServiceConfig
    private let client: QBittorrentClient

    @Published var torrents: [QBTorrentInfo] = []
    @Published var filtered: [QBTorrentInfo] = []
    @Published var searchText: String = ""
    @Published var isLoading: Bool = false
    @Published var error: String?
    @Published var limits: QBTGlobalLimits?

    private var timerTask: Task<Void, Never>?

    init(config: ServiceConfig) {
        self.config = config
        self.client = QBittorrentClient(config: config)
        bindSearch()
    }



    private func bindSearch() {
        // Simple local filter without Combine to avoid heavy generic type-check cost
        // Call updateFiltered() whenever torrents or searchText changes
        Task { @MainActor in
            self.updateFiltered()
        }
    }

    func updateFiltered() {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if q.isEmpty {
            filtered = torrents
        } else {
            filtered = torrents.filter { t in
                (t.name ?? "").lowercased().contains(q)
                || (t.category ?? "").lowercased().contains(q)
                || t.hash.lowercased().contains(q)
            }
        }
    }

    func refresh() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let list = try await client.listTorrents()
            torrents = list
            updateFiltered()
            if limits == nil {
                limits = try? await client.globalLimits()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        timerTask = Task { [weak self] in
            guard let self else { return }
            await self.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                await self.refresh()
            }
        }
    }

    func stopAutoRefresh() {
        timerTask?.cancel()
        timerTask = nil
    }

    func pauseOrResume(_ t: QBTorrentInfo) async {
        guard let st = t.state?.lowercased() else { return }
        do {
            if st.contains("paused") {
                try await client.resumeTorrent(hash: t.hash)
            } else {
                try await client.pauseTorrent(hash: t.hash)
            }
            await refresh()
        } catch {
            if error is CancellationError { return }
            self.error = error.localizedDescription
        }
    }

    func applyLimits(dlKiBps: Int, ulKiBps: Int, toggleAltMode: Bool?) async {
        do {
            let dl = max(0, dlKiBps) * 1024
            let ul = max(0, ulKiBps) * 1024
            try await client.setGlobalDownloadLimit(dl)
            try await client.setGlobalUploadLimit(ul)
            if let _ = toggleAltMode {
                try await client.toggleAlternativeSpeedLimits()
            }
            limits = try await client.globalLimits()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

@MainActor
final class QBTorrentDetailViewModel: ObservableObject {
    let config: ServiceConfig
    let torrent: QBTorrentInfo

    private let client: QBittorrentClient

    @Published var properties: QBTorrentProperties?
    @Published var files: [QBTorrentFile] = []
    @Published var latestInfo: QBTorrentInfo?
    @Published var error: String?

    // Local speed history (last N points) for sparkline
    @Published var dlHistory: [Double] = []
    @Published var ulHistory: [Double] = []
    private let historyMax = 60

    private var timerTask: Task<Void, Never>?

    init(config: ServiceConfig, torrent: QBTorrentInfo) {
        self.config = config
        self.torrent = torrent
        self.client = QBittorrentClient(config: config)
    }



    func load() async {
        self.error = nil
        do {
            async let props = client.torrentProperties(hash: torrent.hash)
            async let fs = client.torrentFiles(hash: torrent.hash)
            async let list = client.listTorrents()
            let (p, f, l) = try await (props, fs, list)
            self.properties = p
            self.files = f
            self.latestInfo = l.first(where: { $0.hash == torrent.hash }) ?? torrent
            if let dl = latestInfo?.dlspeed { appendHistory(&dlHistory, Double(dl)) }
            if let ul = latestInfo?.upspeed { appendHistory(&ulHistory, Double(ul)) }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func startAutoRefresh() {
        stopAutoRefresh()
        timerTask = Task { [weak self] in
            guard let self else { return }
            await self.load()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5s
                await self.load()
            }
        }
    }

    func stopAutoRefresh() {
        timerTask?.cancel()
        timerTask = nil
    }

    func pauseOrResume() async {
        guard let st = (latestInfo ?? torrent).state?.lowercased() else { return }
        do {
            if st.contains("paused") {
                try await client.resumeTorrent(hash: torrent.hash)
            } else {
                try await client.pauseTorrent(hash: torrent.hash)
            }
            await load()
        } catch {
            if error is CancellationError { return }
            self.error = error.localizedDescription
        }
    }

    private func appendHistory(_ arr: inout [Double], _ value: Double) {
        arr.append(value)
        if arr.count > historyMax { arr.removeFirst(arr.count - historyMax) }
    }
}

// MARK: - Views

struct QBittorrentView: View {
    let config: ServiceConfig
    @StateObject private var vm: QBittorrentViewModel

    @State private var showingLimitsSheet = false

    init(config: ServiceConfig) {
        self.config = config
        _vm = StateObject(wrappedValue: QBittorrentViewModel(config: config))
    }

    var body: some View {
        List {
            if let err = vm.error {
                Section {
                    Text(err).foregroundStyle(.red)
                }
            }

            if vm.filtered.isEmpty && !vm.isLoading {
                Section {
                    Text("No torrents found")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(vm.filtered) { t in
                        NavigationLink {
                            TorrentDetailView(config: config, torrent: t)
                        } label: {
                            TorrentRow(t: t) {
                                Task { await vm.pauseOrResume(t) }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("qBittorrent")
        .searchable(text: $vm.searchText)
        .onChange(of: vm.searchText) {
            vm.updateFiltered()
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingLimitsSheet = true
                } label: {
                    Image(systemName: "gauge.with.dots.needle.33percent")
                }
                Button {
                    Task { await vm.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .sheet(isPresented: $showingLimitsSheet) {
            GlobalLimitsSheet(
                initial: vm.limits,
                onApply: { dlKiB, ulKiB, toggle in
                    Task { await vm.applyLimits(dlKiBps: dlKiB, ulKiBps: ulKiB, toggleAltMode: toggle) }
                }
            )
            .presentationDetents([.medium, .large])
        }
        .onAppear { vm.startAutoRefresh() }
        .onDisappear { vm.stopAutoRefresh() }
    }

    struct TorrentRow: View {
        let t: QBTorrentInfo
        let onTogglePause: () -> Void

        private var name: String { t.name ?? "(unnamed)" }
        private var progressPercent: Double { (t.progress ?? 0) * 100.0 }
        private var dlRate: String { StatFormatter.formatRateBytesPerSec(Double(t.dlspeed ?? 0)) }
        private var ulRate: String { StatFormatter.formatRateBytesPerSec(Double(t.upspeed ?? 0)) }
        private func friendlyState(_ raw: String?) -> String {
            let s = (raw ?? "").lowercased()
            if s == "stoppedup" { return "Completed" }
            if s.contains("stalledup") || s.contains("stalleddl") || s.contains("stalled") { return "Stalled" }
            if s.contains("paused") { return "Paused" }
            if s.contains("queued") { return "Queued" }
            if s.contains("checking") { return "Checking" }
            if s.contains("forceddl") || s.contains("metadl") || s.contains("downloading") { return "Downloading" }
            if s.contains("forcedup") || s.contains("uploading") || s == "seeding" { return "Seeding" }
            if s.contains("moving") { return "Moving" }
            if s.contains("allocating") { return "Allocating" }
            if s.contains("missing") { return "Missing Files" }
            if s.contains("error") { return "Error" }
            return s.capitalized
        }
        private var stateText: String { friendlyState(t.state) }

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(name)
                        .font(.headline)
                        .lineLimit(2)
                    Spacer()
                    Button(action: onTogglePause) {
                        Image(systemName: (t.state ?? "").lowercased().contains("paused") ? "play.fill" : "pause.fill")
                    }
                    .buttonStyle(.borderless)
                    .tint(.blue)
                }

                ProgressView(value: progressPercent, total: 100)
                    .tint(.green)

                HStack(spacing: 12) {
                    Label(dlRate, systemImage: "arrow.down.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Label(ulRate, systemImage: "arrow.up.circle")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    Spacer()
                    Text(stateText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct TorrentDetailView: View {
    let config: ServiceConfig
    let torrent: QBTorrentInfo
    @StateObject private var vm: QBTorrentDetailViewModel

    init(config: ServiceConfig, torrent: QBTorrentInfo) {
        self.config = config
        self.torrent = torrent
        _vm = StateObject(wrappedValue: QBTorrentDetailViewModel(config: config, torrent: torrent))
    }

    private func friendlyState(_ raw: String?) -> String {
        let s = (raw ?? "").lowercased()
        if s == "stoppedup" { return "Completed" }
        if s.contains("stalledup") || s.contains("stalleddl") || s.contains("stalled") { return "Stalled" }
        if s.contains("paused") { return "Paused" }
        if s.contains("queued") { return "Queued" }
        if s.contains("checking") { return "Checking" }
        if s.contains("forceddl") || s.contains("metadl") || s.contains("downloading") { return "Downloading" }
        if s.contains("forcedup") || s.contains("uploading") || s == "seeding" { return "Seeding" }
        if s.contains("moving") { return "Moving" }
        if s.contains("allocating") { return "Allocating" }
        if s.contains("missing") { return "Missing Files" }
        if s.contains("error") { return "Error" }
        return s.capitalized
    }
    private var info: QBTorrentInfo { vm.latestInfo ?? torrent }

    var body: some View {
        List {
            if let err = vm.error {
                Section {
                    Text(err).foregroundStyle(.red)
                }
            }

            Section("Overview") {
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(info.name ?? "(unnamed)")
                            .font(.headline)
                            .lineLimit(2)
                        ProgressView(value: (info.progress ?? 0) * 100, total: 100)
                            .tint(.green)
                    }
                    Spacer()
                    Button {
                        Task { await vm.pauseOrResume() }
                    } label: {
                        Image(systemName: (info.state ?? "").lowercased().contains("paused") ? "play.fill" : "pause.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack(spacing: 16) {
                    StatPill(title: "Down", value: StatFormatter.formatRateBytesPerSec(Double(info.dlspeed ?? 0)), systemImage: "arrow.down.circle")
                    StatPill(title: "Up", value: StatFormatter.formatRateBytesPerSec(Double(info.upspeed ?? 0)), systemImage: "arrow.up.circle")
                    StatPill(title: "State", value: friendlyState(info.state), systemImage: "bolt.horizontal.circle")
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Speed (recent)")
                        .font(.subheadline).bold()
                    SpeedSparkline(
                        downloadPoints: vm.dlHistory,
                        uploadPoints: vm.ulHistory,
                        sampleSeconds: 1.5
                    )
                    .frame(height: 80)
                }
            }

            if let p = vm.properties {
                Section("Properties") {
                    KeyValueRow("Save Path", p.save_path ?? "-")
                    KeyValueRow("Size", StatFormatter.formatBytes(p.total_size ?? 0))
                    KeyValueRow("Pieces", "\(p.pieces_num ?? 0) @ \(StatFormatter.formatBytes(p.piece_size ?? 0))")
                    KeyValueRow("Share Ratio", String(format: "%.2f", p.share_ratio ?? 0))
                    KeyValueRow("Avg DL", StatFormatter.formatRateBytesPerSec(Double(p.dl_speed_avg ?? 0)))
                    KeyValueRow("Avg UP", StatFormatter.formatRateBytesPerSec(Double(p.up_speed_avg ?? 0)))
                }
            }

            Section("Files") {
                if vm.files.isEmpty {
                    Text("No files reported yet").foregroundStyle(.secondary)
                } else {
                    ForEach(vm.files) { f in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(f.name ?? "(file)")
                                .font(.subheadline)
                                .lineLimit(2)
                            ProgressView(value: (f.progress ?? 0) * 100, total: 100)
                                .tint(.blue)
                            HStack(spacing: 12) {
                                Text(StatFormatter.formatBytes(f.size ?? 0))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let pr = f.priority {
                                    Text("Priority: \(pr)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if f.is_seed == true {
                                    Image(systemName: "leaf.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Details")
        .onAppear { vm.startAutoRefresh() }
        .onDisappear { vm.stopAutoRefresh() }
    }

    struct StatPill: View {
        let title: String
        let value: String
        let systemImage: String
        var body: some View {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption2).foregroundStyle(.secondary)
                    Text(value).font(.caption).fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    struct KeyValueRow: View {
        let key: String
        let value: String
        init(_ key: String, _ value: String) {
            self.key = key
            self.value = value
        }
        var body: some View {
            HStack {
                Text(key).foregroundStyle(.secondary)
                Spacer()
                Text(value).multilineTextAlignment(.trailing)
            }
        }
    }

    struct SpeedSparkline: View {
            let downloadPoints: [Double]
            let uploadPoints: [Double]
            let sampleSeconds: Double

        private func path(for points: [Double], in rect: CGRect) -> Path {
            var path = Path()
            guard points.count > 1 else { return path }
            let maxVal = max(points.max() ?? 1, 1)
            let stepX = rect.width / CGFloat(max(points.count - 1, 1))
            for (i, v) in points.enumerated() {
                let x = CGFloat(i) * stepX
                let y = rect.height - (CGFloat(v) / CGFloat(maxVal)) * rect.height
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            return path
        }

        var body: some View {
            GeometryReader { outer in
                let maxVal = max(downloadPoints.max() ?? 1, uploadPoints.max() ?? 1, 1)
                let count = max(downloadPoints.count, uploadPoints.count)
                let totalSeconds = max(0, Double(max(count - 1, 0)) * sampleSeconds)
                HStack(spacing: 8) {
                    // Y-axis labels
                    VStack(alignment: .leading) {
                        Text(StatFormatter.formatRateBytesPerSec(maxVal))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(StatFormatter.formatRateBytesPerSec(maxVal / 2))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("0 B/s")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(width: 56)
                    // Chart area + X-axis labels
                    VStack(spacing: 4) {
                        GeometryReader { geo in
                            let rect = geo.frame(in: .local)
                            ZStack {
                                // Horizontal grid lines at 100%, 50%, 0%
                                ForEach([1.0, 0.5, 0.0], id: \.self) { frac in
                                    Path { p in
                                        let y = rect.height * (1 - frac)
                                        p.move(to: CGPoint(x: 0, y: y))
                                        p.addLine(to: CGPoint(x: rect.width, y: y))
                                    }
                                    .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                }
                                // Vertical grid at left, center, right
                                ForEach([0.0, 0.5, 1.0], id: \.self) { frac in
                                    Path { p in
                                        let x = rect.width * frac
                                        p.move(to: CGPoint(x: x, y: 0))
                                        p.addLine(to: CGPoint(x: x, y: rect.height))
                                    }
                                    .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                }
                                // Download line (blue)
                                Path { path in
                                    let pts = downloadPoints
                                    let n = pts.count
                                    if n > 0 {
                                        let stepX = rect.width / CGFloat(max(n - 1, 1))
                                        for i in 0..<n {
                                            let v = pts[i]
                                            let x = CGFloat(i) * stepX
                                            let y = rect.height - CGFloat(v / maxVal) * rect.height
                                            if i == 0 {
                                                path.move(to: CGPoint(x: x, y: y))
                                            } else {
                                                path.addLine(to: CGPoint(x: x, y: y))
                                            }
                                        }
                                    }
                                }
                                .stroke(Color.blue, lineWidth: 1.5)
                                // Upload line (green)
                                Path { path in
                                    let pts = uploadPoints
                                    let n = pts.count
                                    if n > 0 {
                                        let stepX = rect.width / CGFloat(max(n - 1, 1))
                                        for i in 0..<n {
                                            let v = pts[i]
                                            let x = CGFloat(i) * stepX
                                            let y = rect.height - CGFloat(v / maxVal) * rect.height
                                            if i == 0 {
                                                path.move(to: CGPoint(x: x, y: y))
                                            } else {
                                                path.addLine(to: CGPoint(x: x, y: y))
                                            }
                                        }
                                    }
                                }
                                .stroke(Color.green, lineWidth: 1.5)
                            }
                        }
                        // X-axis time labels
                        HStack {
                            Text(totalSeconds > 0 ? "\(Int(totalSeconds))s" : "0s")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(totalSeconds > 0 ? "\(Int(totalSeconds / 2))s" : "")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("0s")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Global Limits Sheet

struct GlobalLimitsSheet: View {
    let initial: QBTGlobalLimits?
    let onApply: (Int, Int, Bool?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var dlKiBps: String = ""
    @State private var ulKiBps: String = ""
    @State private var toggleAltMode: Bool = false

    init(initial: QBTGlobalLimits?, onApply: @escaping (Int, Int, Bool?) -> Void) {
        self.initial = initial
        self.onApply = onApply
        _dlKiBps = State(initialValue: initial.map { String(($0.downloadLimitBps) / 1024) } ?? "")
        _ulKiBps = State(initialValue: initial.map { String(($0.uploadLimitBps) / 1024) } ?? "")
        _toggleAltMode = State(initialValue: initial?.alternativeModeEnabled ?? false)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Global Speed Limits (KiB/s)")) {
                    HStack {
                        Text("Download")
                        Spacer()
                        TextField("0", text: $dlKiBps)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                    HStack {
                        Text("Upload")
                        Spacer()
                        TextField("0", text: $ulKiBps)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 100)
                    }
                }

                Section {
                    Toggle("Alternative Speed Limits Mode", isOn: $toggleAltMode)
                        .tint(.green)
                } footer: {
                    Text("Enabling alternative mode toggles the scheduler’s alternate limits.")
                }
            }
            .navigationTitle("Speed Limits")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        let dl = Int(dlKiBps) ?? 0
                        let ul = Int(ulKiBps) ?? 0
                        onApply(dl, ul, toggleAltMode)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}

// MARK: - Convenience entry points

extension QBittorrentView {
    // Usage:
    // - From ServicesView row tap:
    //   NavigationLink(destination: QBittorrentView(config: config)) { ... }
    // - From Home widget tap (for a service config):
    //   NavigationLink("", destination: QBittorrentView(config: config))
    static func make(config: ServiceConfig) -> QBittorrentView {
        QBittorrentView(config: config)
    }
}
