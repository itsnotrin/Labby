//
//  JellyfinUsersView.swift
//  Labby
//
//  Created by Assistant on 2025-01-27.
//

import SwiftUI
import Combine

struct JellyfinUsersView: View {
    let config: ServiceConfig
    @StateObject private var viewModel = JellyfinUsersViewModel()
    @State private var searchText = ""

    var filteredUsers: [JellyfinUser] {
        if searchText.isEmpty {
            return viewModel.users
        } else {
            return viewModel.users.filter { user in
                user.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        Group {
            if viewModel.isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading users...")
                        .foregroundStyle(.secondary)
                }
            } else if let error = viewModel.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.orange)
                    Text("Error loading users")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry") {
                        Task {
                            await viewModel.loadUsers(config: config)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else if filteredUsers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No users found")
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
                    Section {
                        ForEach(filteredUsers) { user in
                            NavigationLink(destination: JellyfinUserDetailView(config: config, user: user)) {
                                UserRowView(user: user)
                            }
                        }
                    } header: {
                        Text("Users (\(filteredUsers.count))")
                    }
                }
                .searchable(text: $searchText, prompt: "Search users")
            }
        }
        .navigationTitle("Jellyfin Users")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.large)
        #endif
        .onAppear {
            Task {
                await viewModel.loadUsers(config: config)
            }
        }
    }
}

struct UserRowView: View {
    let user: JellyfinUser

    var body: some View {
        HStack {
            // User avatar
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String(user.name.prefix(1)).uppercased())
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    // Admin badge
                    if user.policy?.isAdministrator == true {
                        Text("Admin")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.2))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }

                    // Status indicators
                    if user.policy?.isDisabled == true {
                        Text("Disabled")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .foregroundStyle(.gray)
                            .clipShape(Capsule())
                    } else if user.policy?.isHidden == true {
                        Text("Hidden")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundStyle(.orange)
                            .clipShape(Capsule())
                    } else {
                        Text("Active")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }

                // Last activity
                if let lastActivity = user.lastActivityDate {
                    Text("Last active: \(formatDate(lastActivity))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if user.hasPassword == true {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                }

                if user.enableAutoLogin == true {
                    Image(systemName: "key.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct JellyfinUserDetailView: View {
    let config: ServiceConfig
    let user: JellyfinUser

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header section
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color.blue.gradient)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text(String(user.name.prefix(1)).uppercased())
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        )

                    Text(user.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    HStack(spacing: 12) {
                        if user.policy?.isAdministrator == true {
                            Label("Administrator", systemImage: "crown.fill")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.2))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }

                        if user.policy?.isDisabled == true {
                            Label("Disabled", systemImage: "xmark.circle.fill")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.2))
                                .foregroundStyle(.gray)
                                .clipShape(Capsule())
                        } else {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.2))
                                .foregroundStyle(.green)
                                .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)

                // Basic Information
                VStack(alignment: .leading, spacing: 16) {
                    Text("Basic Information")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        if let lastLogin = user.lastLoginDate {
                            InfoCard(
                                title: "Last Login",
                                value: formatFullDate(lastLogin),
                                icon: "clock"
                            )
                        }

                        if let lastActivity = user.lastActivityDate {
                            InfoCard(
                                title: "Last Activity",
                                value: formatFullDate(lastActivity),
                                icon: "dot.radiowaves.left.and.right"
                            )
                        }

                        InfoCard(
                            title: "Has Password",
                            value: user.hasPassword == true ? "Yes" : "No",
                            icon: user.hasPassword == true ? "lock.fill" : "lock.open"
                        )

                        InfoCard(
                            title: "Auto Login",
                            value: user.enableAutoLogin == true ? "Enabled" : "Disabled",
                            icon: user.enableAutoLogin == true ? "key.fill" : "key"
                        )
                    }
                    .padding(.horizontal)
                }

                // Security & Permissions
                if let policy = user.policy {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Security & Permissions")
                            .font(.headline)
                            .padding(.horizontal)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 16) {
                            InfoCard(
                                title: "Administrator",
                                value: policy.isAdministrator == true ? "Yes" : "No",
                                icon: policy.isAdministrator == true ? "crown.fill" : "crown"
                            )

                            InfoCard(
                                title: "Hidden User",
                                value: policy.isHidden == true ? "Yes" : "No",
                                icon: policy.isHidden == true ? "eye.slash.fill" : "eye"
                            )

                            if let maxSessions = policy.maxActiveSessions {
                                InfoCard(
                                    title: "Max Sessions",
                                    value: "\(maxSessions)",
                                    icon: "person.2.fill"
                                )
                            }

                            if let maxParentalRating = policy.maxParentalRating {
                                InfoCard(
                                    title: "Parental Rating",
                                    value: "\(maxParentalRating)",
                                    icon: "hand.raised.fill"
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Media Access
                if let policy = user.policy {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Media Access")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            AccessRow(
                                title: "Media Playback",
                                isEnabled: policy.enableMediaPlayback == true,
                                icon: "play.fill"
                            )

                            AccessRow(
                                title: "Live TV Access",
                                isEnabled: policy.enableLiveTvAccess == true,
                                icon: "tv.fill"
                            )

                            AccessRow(
                                title: "Content Downloading",
                                isEnabled: policy.enableContentDownloading == true,
                                icon: "arrow.down.circle.fill"
                            )

                            AccessRow(
                                title: "Content Deletion",
                                isEnabled: policy.enableContentDeletion == true,
                                icon: "trash.fill"
                            )

                            AccessRow(
                                title: "Remote Access",
                                isEnabled: policy.enableRemoteAccess == true,
                                icon: "network"
                            )

                            AccessRow(
                                title: "Transcoding",
                                isEnabled: policy.enableVideoPlaybackTranscoding == true,
                                icon: "gearshape.fill"
                            )
                        }
                        .padding(.horizontal)
                    }
                }

                // User Configuration
                if let configuration = user.configuration {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("User Preferences")
                            .font(.headline)
                            .padding(.horizontal)

                        VStack(alignment: .leading, spacing: 12) {
                            if let subtitleLang = configuration.subtitleLanguagePreference {
                                PreferenceRow(
                                    title: "Subtitle Language",
                                    value: subtitleLang,
                                    icon: "captions.bubble"
                                )
                            }

                            if let subtitleMode = configuration.subtitleMode {
                                PreferenceRow(
                                    title: "Subtitle Mode",
                                    value: subtitleMode,
                                    icon: "captions.bubble.fill"
                                )
                            }

                            PreferenceRow(
                                title: "Auto-play Next Episode",
                                value: configuration.enableNextEpisodeAutoPlay == true ? "Enabled" : "Disabled",
                                icon: "forward.fill"
                            )

                            PreferenceRow(
                                title: "Remember Audio Selections",
                                value: configuration.rememberAudioSelections == true ? "Yes" : "No",
                                icon: "speaker.wave.2"
                            )

                            PreferenceRow(
                                title: "Remember Subtitle Selections",
                                value: configuration.rememberSubtitleSelections == true ? "Yes" : "No",
                                icon: "captions.bubble"
                            )
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("User Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func formatFullDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}

struct AccessRow: View {
    let title: String
    let isEnabled: Bool
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(isEnabled ? .green : .gray)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(isEnabled ? "Enabled" : "Disabled")
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isEnabled ? Color.green.opacity(0.2) : Color.gray.opacity(0.2))
                .foregroundStyle(isEnabled ? .green : .gray)
                .clipShape(Capsule())
        }
        .padding(.vertical, 2)
    }
}

struct PreferenceRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct JellyfinItemDetailView: View {
    let config: ServiceConfig
    let item: JellyfinItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    HStack {
                        Text(item.type)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.2))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())

                        if let year = item.productionYear {
                            Text(String(year))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }

                    if let overview = item.overview, !overview.isEmpty {
                        Text(overview)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal)

                if let genres = item.genres, !genres.isEmpty {
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
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Item Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

// MARK: - ViewModel

@MainActor
class JellyfinUsersViewModel: ObservableObject {
    @Published var users: [JellyfinUser] = []
    @Published var isLoading = false
    @Published var error: String?

    func loadUsers(config: ServiceConfig) async {
        isLoading = true
        error = nil

        do {
            let client = JellyfinClient(config: config)
            users = try await client.fetchUsers()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
