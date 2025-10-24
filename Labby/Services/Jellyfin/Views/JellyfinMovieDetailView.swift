//
//  JellyfinMovieDetailView.swift
//  Labby
//
//  Created by Assistant on 2025-01-27.
//

import SwiftUI
import Combine

struct JellyfinMovieDetailView: View {
    let config: ServiceConfig
    let item: JellyfinItem
    @StateObject private var viewModel = JellyfinMovieDetailViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header section
                VStack(alignment: .leading, spacing: 12) {
                    Text(item.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    HStack {
                        if let year = item.productionYear {
                            Text("\(year)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        if let rating = item.officialRating {
                            Text(rating)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange.opacity(0.2))
                                .foregroundStyle(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        if let communityRating = item.communityRating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", communityRating))
                            }
                            .font(.caption)
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

                // Technical Information
                VStack(alignment: .leading, spacing: 16) {
                    Text("Technical Information")
                        .font(.headline)
                        .padding(.horizontal)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        // Runtime
                        if let runtime = item.runTimeTicks {
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
                        if let runtime = item.runTimeTicks {
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

                        // Codec
                        if let codec = viewModel.videoStream?.codec {
                            InfoCard(
                                title: "Video Codec",
                                value: codec.uppercased(),
                                icon: "film"
                            )
                        }

                        // Bitrate
                        if let bitrate = viewModel.videoStream?.bitRate {
                            InfoCard(
                                title: "Bitrate",
                                value: formatBitrate(bitrate),
                                icon: "speedometer"
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

                // Genres & Studios
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

                // Watch Progress
                if let userData = item.userData {
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
                                        if let runtime = item.runTimeTicks {
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
        .navigationTitle("Movie Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            Task {
                await viewModel.loadMovieDetails(config: config, itemId: item.id)
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

    private func formatBitrate(_ bitrate: Int) -> String {
        let mbps = Double(bitrate) / 1_000_000
        return String(format: "%.1f Mbps", mbps)
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.blue)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - ViewModel

@MainActor
class JellyfinMovieDetailViewModel: ObservableObject {
    @Published var videoStream: JellyfinMediaStream?
    @Published var audioStreams: [JellyfinMediaStream] = []
    @Published var subtitleStreams: [JellyfinMediaStream] = []
    @Published var cast: [JellyfinPerson] = []
    @Published var fileSize: Int64?
    @Published var isLoading = false
    @Published var error: String?

    func loadMovieDetails(config: ServiceConfig, itemId: String) async {
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

            // Parse cast
            if let people = detailedItem.people {
                cast = people.filter { $0.type == "Actor" || $0.type == "Director" }
            }

            // Get file info (would need additional API call in real implementation)
            // fileSize = try await client.fetchFileSize(itemId: itemId)

        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}
