//
//  JellyfinSeasonDetailView.swift
//  Labby
//
//  Created by Assistant on 2025-01-27.
//

import SwiftUI
import Combine

struct JellyfinSeasonDetailView: View {
    let config: ServiceConfig
    let season: JellyfinItem
    @StateObject private var viewModel = JellyfinSeasonDetailViewModel()
    @State private var searchText = ""

    var filteredEpisodes: [JellyfinItem] {
        if searchText.isEmpty {
            return viewModel.episodes
        } else {
            return viewModel.episodes.filter { episode in
                episode.name.localizedCaseInsensitiveContains(searchText) ||
                (episode.overview?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading episodes...")
                        .foregroundStyle(.secondary)
                }
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Error loading episodes")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await viewModel.loadEpisodes(config: config, seasonId: season.id)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if filteredEpisodes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "tv")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No episodes found")
                        .font(.headline)
                    if !searchText.isEmpty {
                        Text("Try adjusting your search")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            } else {
                List {
                    // Season Header
                    Section {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(season.name)
                                .font(.title2)
                                .fontWeight(.bold)

                            if let overview = season.overview, !overview.isEmpty {
                                Text(overview)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }

                            HStack {
                                if let episodeCount = season.childCount {
                                    Text("\(episodeCount) episodes")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                if let year = season.productionYear {
                                    Text("• \(String(year))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()
                            }

                            // Season progress
                            if let userData = season.userData, let percentage = userData.playedPercentage, percentage > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Season Progress: \(Int(percentage))%")
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    ProgressView(value: percentage, total: 100)
                                        .tint(.blue)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Episodes
                    Section("Episodes") {
                        ForEach(filteredEpisodes) { episode in
                            NavigationLink(destination: JellyfinEpisodeDetailView(config: config, episode: episode)) {
                                EpisodeRowView(episode: episode)
                            }
                        }
                    }
                }
                .refreshable {
                    // Pull-to-refresh for episodes
                    await viewModel.refreshEpisodes(config: config, seasonId: season.id)
                }
                .searchable(text: $searchText, prompt: "Search episodes")
            }
        }
        .navigationTitle(season.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .onAppear {
            Task {
                await viewModel.loadEpisodes(config: config, seasonId: season.id)
            }
        }
    }
}

struct EpisodeRowView: View {
    let episode: JellyfinItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Episode number
            VStack {
                Text("\(episode.indexNumber ?? 0)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(.blue))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(episode.name)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    if let runtime = episode.runTimeTicks {
                        Text(formatRuntime(runtime))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let airDate = episode.premiereDate {
                        Text("• \(formatAirDate(airDate))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let overview = episode.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }

                // Progress indicator
                if let userData = episode.userData, let percentage = userData.playedPercentage, percentage > 0 && percentage < 100 {
                    ProgressView(value: percentage, total: 100)
                        .tint(.blue)
                        .scaleEffect(y: 0.5)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let userData = episode.userData {
                    if userData.played == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if userData.isFavorite == true {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatRuntime(_ ticks: Int64) -> String {
        let totalSeconds = ticks / 10_000_000
        let minutes = totalSeconds / 60
        return "\(minutes)m"
    }

    private func formatAirDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct JellyfinEpisodeDetailView: View {
    let config: ServiceConfig
    let episode: JellyfinItem
    @StateObject private var viewModel = JellyfinEpisodeDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header section
                VStack(alignment: .leading, spacing: 12) {
                    if let seriesName = episode.seriesName {
                        Text(seriesName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        if let seasonNumber = episode.parentIndexNumber, let episodeNumber = episode.indexNumber {
                            Text("S\(seasonNumber)E\(episodeNumber)")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.2))
                                .foregroundStyle(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        Spacer()
                    }

                    Text(episode.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    HStack {
                        if let airDate = episode.premiereDate {
                            Text(formatAirDate(airDate))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let communityRating = episode.communityRating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", communityRating))
                            }
                            .font(.caption)
                        }

                        Spacer()
                    }

                    if let overview = episode.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // Technical Information
                VStack(alignment: .leading, spacing: 16) {
                    Text("Episode Information")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        // Runtime
                        if let runtime = episode.runTimeTicks {
                            InfoCard(
                                title: "Runtime",
                                value: formatRuntime(runtime),
                                icon: "clock"
                            )
                        }

                        // Quality/Resolution
                        if let videoStream = viewModel.videoStream {
                            InfoCard(
                                title: "Quality",
                                value: formatResolution(videoStream),
                                icon: "tv"
                            )
                        }

                        // Finish time if started now
                        if let runtime = episode.runTimeTicks {
                            InfoCard(
                                title: "Finish Time",
                                value: calculateFinishTime(runtime),
                                icon: "clock.arrow.circlepath"
                            )
                        }

                        // File size
                        if let fileSize = viewModel.fileSize {
                            InfoCard(
                                title: "File Size",
                                value: formatFileSize(fileSize),
                                icon: "externaldrive"
                            )
                        }

                        // Video codec
                        if let codec = viewModel.videoStream?.codec {
                            InfoCard(
                                title: "Video Codec",
                                value: codec.uppercased(),
                                icon: "film"
                            )
                        }

                        // Audio codec
                        if let audioCodec = viewModel.audioStreams.first?.codec {
                            InfoCard(
                                title: "Audio Codec",
                                value: audioCodec.uppercased(),
                                icon: "speaker.wave.2"
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                // Audio & Subtitles
                VStack(alignment: .leading, spacing: 16) {
                    Text("Audio & Subtitles")
                        .font(.headline)
                        .padding(.horizontal)

                    VStack(spacing: 12) {
                        // Audio tracks
                        if !viewModel.audioStreams.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Audio Tracks")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                ForEach(viewModel.audioStreams.indices, id: \.self) { index in
                                    let audio = viewModel.audioStreams[index]
                                    HStack {
                                        Image(systemName: "speaker.wave.2")
                                            .foregroundStyle(.blue)

                                        VStack(alignment: .leading) {
                                            Text(audio.displayTitle ?? "Audio Track \(index + 1)")
                                                .font(.caption)
                                            if let language = audio.language {
                                                Text(language)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        if let channels = audio.channels {
                                            Text("\(channels)ch")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        // Subtitle tracks
                        if !viewModel.subtitleStreams.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Subtitles")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)

                                ForEach(viewModel.subtitleStreams.indices, id: \.self) { index in
                                    let subtitle = viewModel.subtitleStreams[index]
                                    HStack {
                                        Image(systemName: "captions.bubble")
                                            .foregroundStyle(.purple)

                                        VStack(alignment: .leading) {
                                            Text(subtitle.displayTitle ?? "Subtitle Track \(index + 1)")
                                                .font(.caption)
                                            if let language = subtitle.language {
                                                Text(language)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        } else {
                            HStack {
                                Image(systemName: "captions.bubble")
                                    .foregroundStyle(.gray)
                                Text("No subtitles available")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal)
                }

                // Watch Progress
                if let userData = episode.userData {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Watch Status")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 8) {
                            if userData.played == true {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                    Text("Watched")
                                        .font(.subheadline)
                                    Spacer()
                                }
                            } else if let percentage = userData.playedPercentage, percentage > 0 {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Progress: \(Int(percentage))%")
                                            .font(.subheadline)
                                        Spacer()
                                        if let runtime = episode.runTimeTicks {
                                            Text("~\(formatRemainingTime(runtime, percentage: percentage)) left")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }

                                    ProgressView(value: percentage, total: 100)
                                        .tint(.blue)
                                }
                            } else {
                                HStack {
                                    Image(systemName: "circle")
                                        .foregroundStyle(.gray)
                                    Text("Not watched")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                            }

                            if userData.isFavorite == true {
                                HStack {
                                    Image(systemName: "heart.fill")
                                        .foregroundStyle(.red)
                                    Text("Favorite")
                                        .font(.subheadline)
                                    Spacer()
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Episode Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            Task {
                await viewModel.loadEpisodeDetails(config: config, itemId: episode.id)
            }
        }
    }

    private func formatRuntime(_ ticks: Int64) -> String {
        let totalSeconds = ticks / 10_000_000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatRemainingTime(_ totalTicks: Int64, percentage: Double) -> String {
        let remainingTicks = Int64(Double(totalTicks) * (100 - percentage) / 100)
        return formatRuntime(remainingTicks)
    }

    private func calculateFinishTime(_ ticks: Int64) -> String {
        let totalSeconds = ticks / 10_000_000
        let finishTime = Date().addingTimeInterval(TimeInterval(totalSeconds))

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: finishTime)
    }

    private func formatResolution(_ stream: JellyfinMediaStream) -> String {
        if let width = stream.width, let height = stream.height {
            if height >= 2160 {
                return "4K (\(width)×\(height))"
            } else if height >= 1080 {
                return "1080p (\(width)×\(height))"
            } else if height >= 720 {
                return "720p (\(width)×\(height))"
            } else {
                return "\(width)×\(height)"
            }
        }
        return "Unknown"
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func formatAirDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .long
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

// MARK: - ViewModels

@MainActor
class JellyfinSeasonDetailViewModel: ObservableObject {
    @Published var episodes: [JellyfinItem] = []
    @Published var isLoading = false
    @Published var error: String?

    // Simple in-memory cache for episodes keyed by season id with TTL
    private struct CacheEntry {
        let items: [JellyfinItem]
        let timestamp: Date
    }
    private static var cache: [String: CacheEntry] = [:]
    private static let cacheTTL: TimeInterval = 5 * 60 // 5 minutes

    func loadEpisodes(config: ServiceConfig, seasonId: String) async {
        // Serve from cache if present and fresh
        if let entry = Self.cache[seasonId] {
            let age = Date().timeIntervalSince(entry.timestamp)
            if age < Self.cacheTTL {
                self.episodes = entry.items
                self.isLoading = false
                self.error = nil
                print("[JellyfinSeasonDetailViewModel] Using cached episodes for season: \(seasonId) (age: \(Int(age))s)")
                return
            } else {
                // stale - clear and fetch fresh
                Self.cache[seasonId] = nil
                print("[JellyfinSeasonDetailViewModel] Cache expired for season: \(seasonId) (age: \(Int(age))s). Refreshing.")
            }
        }

        isLoading = true
        error = nil

        do {
            let client = JellyfinClient(config: config)
            let fetched = try await client.fetchEpisodes(seasonId: seasonId)
            self.episodes = fetched
            // cache fetched episodes
            Self.cache[seasonId] = CacheEntry(items: fetched, timestamp: Date())
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // Force refresh helper for pull-to-refresh
    func refreshEpisodes(config: ServiceConfig, seasonId: String) async {
        Self.cache[seasonId] = nil
        await loadEpisodes(config: config, seasonId: seasonId)
    }
}

@MainActor
class JellyfinEpisodeDetailViewModel: ObservableObject {
    @Published var videoStream: JellyfinMediaStream?
    @Published var audioStreams: [JellyfinMediaStream] = []
    @Published var subtitleStreams: [JellyfinMediaStream] = []
    @Published var fileSize: Int64?
    @Published var isLoading = false
    @Published var error: String?

    // Cache detailed episode responses by itemId with TTL so navigating back doesn't refetch immediately
    private struct CacheEntry {
        let item: JellyfinItem
        let timestamp: Date
    }
    private static var cache: [String: CacheEntry] = [:]
    private static let cacheTTL: TimeInterval = 5 * 60 // 5 minutes

    func loadEpisodeDetails(config: ServiceConfig, itemId: String) async {
        // Try cache first
        if let entry = Self.cache[itemId] {
            let age = Date().timeIntervalSince(entry.timestamp)
            if age < Self.cacheTTL {
                let detailedItem = entry.item
                // Populate from cached item
                if let mediaStreams = detailedItem.mediaStreams {
                    videoStream = mediaStreams.first { $0.type == "Video" }
                    audioStreams = mediaStreams.filter { $0.type == "Audio" }
                    subtitleStreams = mediaStreams.filter { $0.type == "Subtitle" }
                    if let first = mediaStreams.first {
                        // Estimate file size if bitrate and runtime are available.
                        // Bitrate is typically in bits/sec; runtime is in ticks (10_000_000 ticks = 1s).
                        if let bitRate = first.bitRate, let runtimeTicks = detailedItem.runTimeTicks {
                            let seconds = Double(runtimeTicks) / 10_000_000.0
                            let bytesEstimate = Int64((Double(bitRate) * seconds) / 8.0)
                            fileSize = bytesEstimate
                        } else {
                            // No reliable size data available
                            fileSize = nil
                        }
                    }
                }
                isLoading = false
                error = nil
                print("[JellyfinEpisodeDetailViewModel] Using cached episode details for item: \(itemId) (age: \(Int(age))s)")
                return
            } else {
                // expired
                Self.cache[itemId] = nil
                print("[JellyfinEpisodeDetailViewModel] Cache expired for item: \(itemId) (age: \(Int(age))s). Refreshing.")
            }
        }

        isLoading = true
        error = nil

        do {
            let client = JellyfinClient(config: config)
            let detailedItem = try await client.fetchItemDetails(itemId: itemId)

            // Parse media streams
            if let mediaStreams = detailedItem.mediaStreams {
                videoStream = mediaStreams.first { $0.type == "Video" }
                audioStreams = mediaStreams.filter { $0.type == "Audio" }
                subtitleStreams = mediaStreams.filter { $0.type == "Subtitle" }
            }

            // File size
            if let mediaStreams = detailedItem.mediaStreams {
                if let first = mediaStreams.first {
                    // Estimate file size if bitrate and runtime are available.
                    // Bitrate is typically in bits/sec; runtime is in ticks (10_000_000 ticks = 1s).
                    if let bitRate = first.bitRate, let runtimeTicks = detailedItem.runTimeTicks {
                        let seconds = Double(runtimeTicks) / 10_000_000.0
                        let bytesEstimate = Int64((Double(bitRate) * seconds) / 8.0)
                        fileSize = bytesEstimate
                    } else {
                        // No reliable size data available
                        fileSize = nil
                    }
                }
            }

            // Cache the detailed item
            Self.cache[itemId] = CacheEntry(item: detailedItem, timestamp: Date())
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // Force refresh helper
    func refreshEpisodeDetails(config: ServiceConfig, itemId: String) async {
        Self.cache[itemId] = nil
        await loadEpisodeDetails(config: config, itemId: itemId)
    }
}
