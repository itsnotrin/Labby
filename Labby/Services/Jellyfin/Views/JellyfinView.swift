//
//  JellyfinView.swift
//  Labby
//
//  Created by Assistant on 2025-01-27.
//

import SwiftUI
import Combine

struct JellyfinView: View {
    let config: ServiceConfig
    @StateObject private var viewModel = JellyfinViewModel()
    @State private var selectedLibrary: JellyfinLibrary?

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading Jellyfin libraries...")
                        .foregroundStyle(.secondary)
                }
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Error loading libraries")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await viewModel.loadLibraries(config: config)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                List {
                    Section("Libraries") {
                        ForEach(viewModel.libraries) { library in
                            NavigationLink(destination: JellyfinLibraryView(config: config, library: library)) {
                                LibraryRowView(library: library)
                            }
                        }
                    }

                    Section("Users") {
                        NavigationLink(destination: JellyfinUsersView(config: config)) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .font(.title2)
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading) {
                                    Text("Users")
                                        .font(.headline)
                                    Text("View all users")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Jellyfin")
        .onAppear {
            if viewModel.libraries.isEmpty && !viewModel.isLoading {
                Task {
                    await viewModel.loadLibraries(config: config)
                }
            }
        }
    }
}

struct LibraryRowView: View {
    let library: JellyfinLibrary

    var body: some View {
        HStack {
            Image(systemName: iconForLibraryType(library.collectionType))
                .font(.title2)
                .foregroundStyle(colorForLibraryType(library.collectionType))

            VStack(alignment: .leading) {
                Text(library.name)
                    .font(.headline)
                if let itemCount = library.itemCount {
                    Text("\(itemCount) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func iconForLibraryType(_ type: String?) -> String {
        switch type?.lowercased() {
        case "movies":
            return "film"
        case "tvshows":
            return "tv"
        case "music":
            return "music.note"
        case "books":
            return "book"
        case "photos":
            return "photo"
        default:
            return "folder"
        }
    }

    private func colorForLibraryType(_ type: String?) -> Color {
        switch type?.lowercased() {
        case "movies":
            return .red
        case "tvshows":
            return .blue
        case "music":
            return .purple
        case "books":
            return .brown
        case "photos":
            return .green
        default:
            return .gray
        }
    }
}

// MARK: - Models

struct JellyfinLibrary: Identifiable, Codable {
    let id: String
    let name: String
    let collectionType: String?
    let itemCount: Int?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case collectionType = "CollectionType"
        case itemCount = "ChildCount"
    }
}

struct JellyfinItem: Identifiable, Codable {
    let id: String
    let name: String
    let overview: String?
    let type: String
    let userData: JellyfinUserData?
    let runTimeTicks: Int64?
    let productionYear: Int?
    let premiereDate: String?
    let communityRating: Double?
    let criticRating: Double?
    let officialRating: String?
    let genres: [String]?
    let studios: [JellyfinStudio]?
    let people: [JellyfinPerson]?
    let mediaStreams: [JellyfinMediaStream]?
    let seriesName: String?
    let seasonName: String?
    let indexNumber: Int?
    let parentIndexNumber: Int?
    let childCount: Int?
    let recursiveItemCount: Int?
    // Added fields to capture relationships returned by some Jellyfin server shapes
    let seriesId: String?
    let parentId: String?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case overview = "Overview"
        case type = "Type"
        case userData = "UserData"
        case runTimeTicks = "RunTimeTicks"
        case productionYear = "ProductionYear"
        case premiereDate = "PremiereDate"
        case communityRating = "CommunityRating"
        case criticRating = "CriticRating"
        case officialRating = "OfficialRating"
        case genres = "Genres"
        case studios = "Studios"
        case people = "People"
        case mediaStreams = "MediaStreams"
        case seriesName = "SeriesName"
        case seasonName = "SeasonName"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case childCount = "ChildCount"
        case recursiveItemCount = "RecursiveItemCount"
        case seriesId = "SeriesId"
        case parentId = "ParentId"
    }
}

// Convenience factory for creating lightweight synthetic Season placeholders when the server
// doesn't return explicit Season items but we still want to display season rows.
extension JellyfinItem {
    /// Create a lightweight synthetic Season item. Optionally attach the parent `seriesId`
    /// and `parentId` so downstream fetches/fallbacks can use them (e.g. when season ids are synthetic).
    static func syntheticSeason(id: String, name: String, index: Int, childCount: Int? = nil, seriesId: String? = nil, parentId: String? = nil) -> JellyfinItem {
        return JellyfinItem(
            id: id,
            name: name,
            overview: nil,
            type: "Season",
            userData: nil,
            runTimeTicks: nil,
            productionYear: nil,
            premiereDate: nil,
            communityRating: nil,
            criticRating: nil,
            officialRating: nil,
            genres: nil,
            studios: nil,
            people: nil,
            mediaStreams: nil,
            seriesName: nil,
            seasonName: name,
            indexNumber: index,
            parentIndexNumber: nil,
            childCount: childCount,
            recursiveItemCount: nil,
            seriesId: seriesId,
            parentId: parentId
        )
    }

    /// Deduplicate an array of synthesized Season items by (indexNumber + normalized name).
    /// When duplicates are found the function merges sensible fields (e.g. childCount) and
    /// preserves the first-seen id/name/type while preferring non-nil metadata where possible.
    static func dedupeSeasons(_ seasons: [JellyfinItem]) -> [JellyfinItem] {
        var seen: [String: JellyfinItem] = [:]
        for s in seasons {
            let idx = s.indexNumber ?? -1
            let nameKey = s.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let key = "\(idx)|\(nameKey)"

            if let existing = seen[key] {
                // merge child counts and prefer existing non-nil fields
                let mergedChildCount = max(existing.childCount ?? 0, s.childCount ?? 0)

                let merged = JellyfinItem(
                    id: existing.id,
                    name: existing.name,
                    overview: existing.overview ?? s.overview,
                    type: existing.type,
                    userData: existing.userData ?? s.userData,
                    runTimeTicks: existing.runTimeTicks ?? s.runTimeTicks,
                    productionYear: existing.productionYear ?? s.productionYear,
                    premiereDate: existing.premiereDate ?? s.premiereDate,
                    communityRating: existing.communityRating ?? s.communityRating,
                    criticRating: existing.criticRating ?? s.criticRating,
                    officialRating: existing.officialRating ?? s.officialRating,
                    genres: existing.genres ?? s.genres,
                    studios: existing.studios ?? s.studios,
                    people: existing.people ?? s.people,
                    mediaStreams: existing.mediaStreams ?? s.mediaStreams,
                    seriesName: existing.seriesName ?? s.seriesName,
                    seasonName: existing.seasonName ?? s.seasonName,
                    indexNumber: existing.indexNumber ?? s.indexNumber,
                    parentIndexNumber: existing.parentIndexNumber ?? s.parentIndexNumber,
                    childCount: mergedChildCount,
                    recursiveItemCount: existing.recursiveItemCount ?? s.recursiveItemCount,
                    seriesId: existing.seriesId ?? s.seriesId,
                    parentId: existing.parentId ?? s.parentId
                )

                seen[key] = merged
            } else {
                seen[key] = s
            }
        }

        // Return seasons sorted by indexNumber (fallback to 0), preserving merged entries
        let result = seen.values.sorted { ($0.indexNumber ?? 0) < ($1.indexNumber ?? 0) }
        return result
    }
}

struct JellyfinUserData: Codable {
    let playedPercentage: Double?
    let playCount: Int?
    let isFavorite: Bool?
    let lastPlayedDate: String?
    let played: Bool?
    let key: String?

    enum CodingKeys: String, CodingKey {
        case playedPercentage = "PlayedPercentage"
        case playCount = "PlayCount"
        case isFavorite = "IsFavorite"
        case lastPlayedDate = "LastPlayedDate"
        case played = "Played"
        case key = "Key"
    }
}

struct JellyfinStudio: Codable {
    let name: String
    let id: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
    }
}

struct JellyfinPerson: Codable {
    let name: String
    let id: String
    let role: String?
    let type: String

    enum CodingKeys: String, CodingKey {
        case name = "Name"
        case id = "Id"
        case role = "Role"
        case type = "Type"
    }
}

struct JellyfinMediaStream: Codable {
    let codec: String?
    let language: String?
    let displayTitle: String?
    let type: String
    let width: Int?
    let height: Int?
    let aspectRatio: String?
    let bitRate: Int?
    let channels: Int?
    let sampleRate: Int?

    enum CodingKeys: String, CodingKey {
        case codec = "Codec"
        case language = "Language"
        case displayTitle = "DisplayTitle"
        case type = "Type"
        case width = "Width"
        case height = "Height"
        case aspectRatio = "AspectRatio"
        case bitRate = "BitRate"
        case channels = "Channels"
        case sampleRate = "SampleRate"
    }
}

struct JellyfinUser: Identifiable, Codable {
    let id: String
    let name: String
    let serverID: String?
    let hasPassword: Bool?
    let hasConfiguredPassword: Bool?
    let hasConfiguredEasyPassword: Bool?
    let enableAutoLogin: Bool?
    let lastLoginDate: String?
    let lastActivityDate: String?
    let configuration: JellyfinUserConfiguration?
    let policy: JellyfinUserPolicy?

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case serverID = "ServerId"
        case hasPassword = "HasPassword"
        case hasConfiguredPassword = "HasConfiguredPassword"
        case hasConfiguredEasyPassword = "HasConfiguredEasyPassword"
        case enableAutoLogin = "EnableAutoLogin"
        case lastLoginDate = "LastLoginDate"
        case lastActivityDate = "LastActivityDate"
        case configuration = "Configuration"
        case policy = "Policy"
    }
}

struct JellyfinUserConfiguration: Codable {
    let playDefaultAudioTrack: Bool?
    let subtitleLanguagePreference: String?
    let displayMissingEpisodes: Bool?
    let groupedFolders: [String]?
    let subtitleMode: String?
    let displayCollectionsView: Bool?
    let enableLocalPassword: Bool?
    let orderByviews: [String]?
    let latestItemsExcludes: [String]?
    let myMediaExcludes: [String]?
    let hidePlayedInLatest: Bool?
    let rememberAudioSelections: Bool?
    let rememberSubtitleSelections: Bool?
    let enableNextEpisodeAutoPlay: Bool?

    enum CodingKeys: String, CodingKey {
        case playDefaultAudioTrack = "PlayDefaultAudioTrack"
        case subtitleLanguagePreference = "SubtitleLanguagePreference"
        case displayMissingEpisodes = "DisplayMissingEpisodes"
        case groupedFolders = "GroupedFolders"
        case subtitleMode = "SubtitleMode"
        case displayCollectionsView = "DisplayCollectionsView"
        case enableLocalPassword = "EnableLocalPassword"
        case orderByviews = "OrderedViews"
        case latestItemsExcludes = "LatestItemsExcludes"
        case myMediaExcludes = "MyMediaExcludes"
        case hidePlayedInLatest = "HidePlayedInLatest"
        case rememberAudioSelections = "RememberAudioSelections"
        case rememberSubtitleSelections = "RememberSubtitleSelections"
        case enableNextEpisodeAutoPlay = "EnableNextEpisodeAutoPlay"
    }
}

struct JellyfinUserPolicy: Codable {
    let isAdministrator: Bool?
    let isHidden: Bool?
    let isDisabled: Bool?
    let maxParentalRating: Int?
    let blockedTags: [String]?
    let enableUserPreferenceAccess: Bool?
    let accessSchedules: [String]?
    let blockUnratedItems: [String]?
    let enableRemoteControlOfOtherUsers: Bool?
    let enableSharedDeviceControl: Bool?
    let enableRemoteAccess: Bool?
    let enableLiveTvManagement: Bool?
    let enableLiveTvAccess: Bool?
    let enableMediaPlayback: Bool?
    let enableAudioPlaybackTranscoding: Bool?
    let enableVideoPlaybackTranscoding: Bool?
    let enablePlaybackRemuxing: Bool?
    let forceRemoteSourceTranscoding: Bool?
    let enableContentDeletion: Bool?
    let enableContentDeletionFromFolders: [String]?
    let enableContentDownloading: Bool?
    let enableSyncTranscoding: Bool?
    let enableMediaConversion: Bool?
    let enabledDevices: [String]?
    let enableAllDevices: Bool?
    let enabledChannels: [String]?
    let enableAllChannels: Bool?
    let enabledFolders: [String]?
    let enableAllFolders: Bool?
    let invalidLoginAttemptCount: Int?
    let loginAttemptsBeforeLockout: Int?
    let maxActiveSessions: Int?
    let enablePublicSharing: Bool?
    let blockedMediaFolders: [String]?
    let blockedChannels: [String]?
    let remoteClientBitrateLimit: Int?
    let authenticationProviderId: String?
    let passwordResetProviderId: String?
    let syncPlayAccess: String?

    enum CodingKeys: String, CodingKey {
        case isAdministrator = "IsAdministrator"
        case isHidden = "IsHidden"
        case isDisabled = "IsDisabled"
        case maxParentalRating = "MaxParentalRating"
        case blockedTags = "BlockedTags"
        case enableUserPreferenceAccess = "EnableUserPreferenceAccess"
        case accessSchedules = "AccessSchedules"
        case blockUnratedItems = "BlockUnratedItems"
        case enableRemoteControlOfOtherUsers = "EnableRemoteControlOfOtherUsers"
        case enableSharedDeviceControl = "EnableSharedDeviceControl"
        case enableRemoteAccess = "EnableRemoteAccess"
        case enableLiveTvManagement = "EnableLiveTvManagement"
        case enableLiveTvAccess = "EnableLiveTvAccess"
        case enableMediaPlayback = "EnableMediaPlayback"
        case enableAudioPlaybackTranscoding = "EnableAudioPlaybackTranscoding"
        case enableVideoPlaybackTranscoding = "EnableVideoPlaybackTranscoding"
        case enablePlaybackRemuxing = "EnablePlaybackRemuxing"
        case forceRemoteSourceTranscoding = "ForceRemoteSourceTranscoding"
        case enableContentDeletion = "EnableContentDeletion"
        case enableContentDeletionFromFolders = "EnableContentDeletionFromFolders"
        case enableContentDownloading = "EnableContentDownloading"
        case enableSyncTranscoding = "EnableSyncTranscoding"
        case enableMediaConversion = "EnableMediaConversion"
        case enabledDevices = "EnabledDevices"
        case enableAllDevices = "EnableAllDevices"
        case enabledChannels = "EnabledChannels"
        case enableAllChannels = "EnableAllChannels"
        case enabledFolders = "EnabledFolders"
        case enableAllFolders = "EnableAllFolders"
        case invalidLoginAttemptCount = "InvalidLoginAttemptCount"
        case loginAttemptsBeforeLockout = "LoginAttemptsBeforeLockout"
        case maxActiveSessions = "MaxActiveSessions"
        case enablePublicSharing = "EnablePublicSharing"
        case blockedMediaFolders = "BlockedMediaFolders"
        case blockedChannels = "BlockedChannels"
        case remoteClientBitrateLimit = "RemoteClientBitrateLimit"
        case authenticationProviderId = "AuthenticationProviderId"
        case passwordResetProviderId = "PasswordResetProviderId"
        case syncPlayAccess = "SyncPlayAccess"
    }
}

// MARK: - ViewModel

@MainActor
class JellyfinViewModel: ObservableObject {
    @Published var libraries: [JellyfinLibrary] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadLibraries(config: ServiceConfig) async {
        // Prevent multiple concurrent calls
        if isLoading {
            print("[JellyfinViewModel] Already loading libraries, skipping...")
            return
        }

        isLoading = true
        error = nil

        do {
            let client = JellyfinClient(config: config)
            print("[JellyfinView] Loading libraries from: \(config.baseURLString)")
            libraries = try await client.fetchLibraries()
            print("[JellyfinView] Successfully loaded \(libraries.count) libraries")
        } catch {
            print("[JellyfinView] Error loading libraries: \(error)")
            if let serviceError = error as? ServiceError {
                switch serviceError {
                case .httpStatus(let code):
                    self.error = "HTTP Error \(code): Check your Jellyfin server URL and credentials"
                case .network(let networkError):
                    self.error = "Network Error: \(networkError.localizedDescription)"
                case .missingSecret:
                    self.error = "Missing authentication credentials"
                case .unknown:
                    self.error = "Unknown error occurred"
                case .invalidURL:
                    self.error = "Invalid Jellyfin server URL"
                case .decoding(let decodingError):
                    self.error = "Failed to decode response from Jellyfin server: \(decodingError.localizedDescription)"
                }

            } else {
                self.error = error.localizedDescription
            }
        }

        isLoading = false
    }
}
