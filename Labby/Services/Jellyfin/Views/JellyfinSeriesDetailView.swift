//
//  JellyfinSeriesDetailView.swift
//  Labby
//
//  Created by Assistant on 2025-01-27.
//

import SwiftUI
import Combine

struct JellyfinSeriesDetailView: View {
    let config: ServiceConfig
    let series: JellyfinItem
    @StateObject private var viewModel = JellyfinSeriesDetailViewModel()
    @State private var searchText = ""

    var filteredSeasons: [JellyfinItem] {
        if searchText.isEmpty {
            return viewModel.seasons
        } else {
            return viewModel.seasons.filter { season in
                season.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header section
                VStack(alignment: .leading, spacing: 12) {
                    Text(series.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    HStack {
                        if let year = series.productionYear {
                            Text("\(year)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let rating = series.officialRating {
                            Text(rating)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        if let communityRating = series.communityRating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", communityRating))
                            }
                            .font(.caption)
                        }

                        Spacer()
                    }

                    if let overview = series.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                // Series Stats
                VStack(alignment: .leading, spacing: 16) {
                    Text("Series Information")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        let seasonCount = viewModel.seasons.count
                        if seasonCount > 0 {
                            InfoCard(
                                title: "Seasons",
                                value: "\(seasonCount)",
                                icon: "tv.fill"
                            )
                        }

                        if let totalEpisodes = viewModel.totalEpisodes {
                            InfoCard(
                                title: "Episodes",
                                value: "\(totalEpisodes)",
                                icon: "list.number"
                            )
                        }

                        if let watchedEpisodes = viewModel.watchedEpisodes {
                            InfoCard(
                                title: "Watched",
                                value: "\(watchedEpisodes)",
                                icon: "checkmark.circle"
                            )
                        }

                        if let totalRuntime = viewModel.totalRuntime {
                            InfoCard(
                                title: "Total Runtime",
                                value: formatTotalRuntime(totalRuntime),
                                icon: "clock"
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                // Genres
                if let genres = series.genres, !genres.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Genres")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(genres, id: \.self) { genre in
                                Text(genre)
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Cast & Crew
                if !viewModel.cast.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Cast & Crew")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 12) {
                                ForEach(viewModel.cast.prefix(10), id: \.id) { person in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 60, height: 60)
                                            .overlay(
                                                Text(String(person.name.prefix(1)))
                                                    .font(.title2)
                                                    .fontWeight(.semibold)
                                                    .foregroundStyle(.white)
                                            )

                                        Text(person.name)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)

                                        if let role = person.role {
                                            Text(role)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(width: 80)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                // Seasons List
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Seasons")
                            .font(.headline)
                        Spacer()
                        if viewModel.seasons.count > 0 {
                            Text("\(viewModel.seasons.count) seasons")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)

                    if viewModel.isLoadingSeasons {
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Loading seasons...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else if let error = viewModel.seasonsError {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(.orange)
                            Text("Error loading seasons")
                                .font(.headline)
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task {
                                    await viewModel.loadSeasons(config: config, seriesId: series.id)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else if filteredSeasons.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "tv")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No seasons found")
                                .font(.headline)
                            if !searchText.isEmpty {
                                Text("Try adjusting your search")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredSeasons) { season in
                                NavigationLink(destination: JellyfinSeasonDetailView(config: config, season: season)) {
                                    SeasonRowView(season: season)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                        .refreshable {
                            await viewModel.refreshSeasons(config: config, seriesId: series.id)
                        }
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Series Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .searchable(text: $searchText, prompt: "Search seasons")
        .onAppear {
            Task {
                await viewModel.loadSeriesDetails(config: config, seriesId: series.id)
                await viewModel.loadSeasons(config: config, seriesId: series.id)
            }
        }
    }

    private func formatTotalRuntime(_ ticks: Int64) -> String {
        let totalSeconds = ticks / 10_000_000
        let hours = totalSeconds / 3600

        if hours >= 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            let minutes = totalSeconds / 60
            return "\(minutes)m"
        }
    }
}

struct SeasonRowView: View {
    let season: JellyfinItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(season.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    if let episodeCount = season.childCount {
                        Text("\(episodeCount) episodes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let year = season.productionYear {
                        Text("• \(year)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let overview = season.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Progress indicator for season watch progress
                if let userData = season.userData, let percentage = userData.playedPercentage, percentage > 0 {
                    ProgressView(value: percentage, total: 100)
                        .tint(.blue)
                        .scaleEffect(y: 0.5)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let userData = season.userData {
                    if userData.played == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if let percentage = userData.playedPercentage, percentage > 0 {
                        Text("\(Int(percentage))%")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - ViewModel

@MainActor
class JellyfinSeriesDetailViewModel: ObservableObject {
    @Published var seasons: [JellyfinItem] = []
    @Published var cast: [JellyfinPerson] = []
    @Published var totalEpisodes: Int?
    @Published var watchedEpisodes: Int?
    @Published var totalRuntime: Int64?
    @Published var isLoadingSeasons = false
    @Published var seasonsError: String?
    @Published var error: String?

    // In-memory per-series cache to avoid reloading seasons when navigating back.
    // Keyed by seriesId and kept for the app session.
    private static var seasonsCache: [String: [JellyfinItem]] = [:]

    func loadSeriesDetails(config: ServiceConfig, seriesId: String) async {
        do {
            let client = JellyfinClient(config: config)
            let detailedSeries = try await client.fetchItemDetails(itemId: seriesId)

            // Parse cast
            if let people = detailedSeries.people {
                cast = people.filter { $0.type == "Actor" || $0.type == "Director" }
            }

            // Calculate series statistics would require additional API calls
            // totalEpisodes = try await client.fetchTotalEpisodes(seriesId: seriesId)
            // watchedEpisodes = try await client.fetchWatchedEpisodes(seriesId: seriesId)
            // totalRuntime = try await client.fetchTotalRuntime(seriesId: seriesId)

        } catch {
            self.error = error.localizedDescription
        }
    }

    func loadSeasons(config: ServiceConfig, seriesId: String) async {
        // If we already have seasons cached for this series, use them and avoid network call.
        if let cached = Self.seasonsCache[seriesId], !cached.isEmpty {
            self.seasons = cached
            // Recalculate totals from cached seasons
            totalEpisodes = seasons.compactMap { $0.childCount }.reduce(0, +)
            self.seasonsError = nil
            self.isLoadingSeasons = false
            print("[JellyfinSeriesDetailViewModel] Using cached seasons for series: \(seriesId)")
            return
        }

        isLoadingSeasons = true
        seasonsError = nil

        do {
            let client = JellyfinClient(config: config)
            let fetched = try await client.fetchSeasons(seriesId: seriesId)
            self.seasons = fetched
            // Cache the fetched seasons for subsequent navigations
            Self.seasonsCache[seriesId] = fetched

            // Calculate totals from seasons
            totalEpisodes = seasons.compactMap { $0.childCount }.reduce(0, +)

        } catch {
            self.seasonsError = error.localizedDescription
        }

        isLoadingSeasons = false
    }

    // Force-refresh seasons for a series (clears cache and re-fetches).
    func refreshSeasons(config: ServiceConfig, seriesId: String) async {
        Self.seasonsCache[seriesId] = nil
        await loadSeasons(config: config, seriesId: seriesId)
    }
}
