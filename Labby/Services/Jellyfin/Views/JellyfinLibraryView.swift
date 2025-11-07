//
//  JellyfinLibraryView.swift
//  Labby
//
//  Created by Assistant on 2025-01-27.
//

import SwiftUI
import Combine

struct JellyfinLibraryView: View {
    let config: ServiceConfig
    let library: JellyfinLibrary
    @StateObject private var viewModel = JellyfinLibraryViewModel()
    @State private var searchText = ""

    var filteredItems: [JellyfinItem] {
        if searchText.isEmpty {
            return viewModel.items
        } else {
            return viewModel.items.filter { item in
                item.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading \(library.name)...")
                        .foregroundStyle(.secondary)
                }
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Error loading items")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await viewModel.loadItems(config: config, libraryId: library.id)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if filteredItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No items found")
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
                    ForEach(filteredItems) { item in
                        NavigationLink(destination: destinationView(for: item)) {
                            JellyfinItemRowView(item: item)
                        }
                    }
                }
                .refreshable {
                    await viewModel.refresh(config: config, libraryId: library.id)
                }
                .searchable(text: $searchText, prompt: "Search \(library.name)")
            }
        }
        .navigationTitle(library.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .onAppear {
            Task {
                // Avoid reloading if we already have items cached in the view model.
                if viewModel.items.isEmpty {
                    await viewModel.loadItems(config: config, libraryId: library.id)
                }
            }
        }
    }

    @ViewBuilder
    private func destinationView(for item: JellyfinItem) -> some View {
        switch item.type {
        case "Movie":
            JellyfinMovieDetailView(config: config, item: item)
        case "Series":
            JellyfinSeriesDetailView(config: config, series: item)
        case "Season":
            JellyfinSeasonDetailView(config: config, season: item)
        case "Episode":
            JellyfinEpisodeDetailView(config: config, episode: item)
        default:
            JellyfinItemDetailView(config: config, item: item)
        }
    }
}

struct JellyfinItemRowView: View {
    let item: JellyfinItem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(item.type)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    if let rating = item.officialRating {
                        Text(rating)
                            .font(.caption)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    if let year = item.productionYear {
                        Text(String(year))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                if let overview = item.overview, !overview.isEmpty {
                    Text(overview)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // Progress indicator for partially watched content
                if let userData = item.userData, let percentage = userData.playedPercentage, percentage > 0 && percentage < 100 {
                    ProgressView(value: percentage, total: 100)
                        .tint(.blue)
                        .scaleEffect(y: 0.5)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if let runtime = item.runTimeTicks {
                    Text(formatRuntime(runtime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let userData = item.userData {
                    if userData.played == true {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else if userData.isFavorite == true {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                    }
                }

                // Show child count for series/seasons
                if let childCount = item.childCount, childCount > 0 {
                    Text("\(childCount) items")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatRuntime(_ ticks: Int64) -> String {
        let totalSeconds = ticks / 10_000_000 // Convert from ticks to seconds
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - ViewModel

@MainActor
class JellyfinLibraryViewModel: ObservableObject {
    // Cache entry stores items + timestamp so we can expire entries after TTL.
    private struct CacheEntry {
        let items: [JellyfinItem]
        let timestamp: Date
    }

    // In-memory cache keyed by library id for the app session.
    private static var cache: [String: CacheEntry] = [:]

    // Cache TTL in seconds (5 minutes)
    private static let cacheTTL: TimeInterval = 5 * 60

    @Published var items: [JellyfinItem] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadItems(config: ServiceConfig, libraryId: String) async {
        // Check cache first and respect TTL
        if let entry = Self.cache[libraryId] {
            let age = Date().timeIntervalSince(entry.timestamp)
            if age < Self.cacheTTL {
                self.items = entry.items
                self.isLoading = false
                self.error = nil
                print("[JellyfinLibraryViewModel] Using cached items for library: \(libraryId) (age: \(Int(age))s)")
                return
            } else {
                // expired - remove it and continue to fetch fresh data
                Self.cache[libraryId] = nil
                print("[JellyfinLibraryViewModel] Cache expired for library: \(libraryId) (age: \(Int(age))s). Refreshing.")
            }
        }

        isLoading = true
        error = nil

        do {
            let client = JellyfinClient(config: config)
            let fetched = try await client.fetchLibraryItems(libraryId: libraryId)
            self.items = fetched
            // Cache the result with current timestamp for subsequent navigations/back navigation
            Self.cache[libraryId] = CacheEntry(items: fetched, timestamp: Date())
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    // Force-refresh helper: clears cache and reloads
    func refresh(config: ServiceConfig, libraryId: String) async {
        Self.cache[libraryId] = nil
        await loadItems(config: config, libraryId: libraryId)
    }
}
