//
//  SharedComponents.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import SwiftUI

// MARK: - Error Handling Components

struct ErrorCard: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .foregroundColor(.red)
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Statistics Components

struct StatPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption)
                .foregroundColor(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let color: Color
    let isFirst: Bool
    let isLast: Bool

    init(title: String, value: String, subtitle: String? = nil, color: Color, isFirst: Bool, isLast: Bool = false) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.color = color
        self.isFirst = isFirst
        self.isLast = isLast
    }

    var body: some View {
        VStack(spacing: 8) {
            VStack(spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 12)
        .background(
            Rectangle()
                .fill(Color.clear)
                .overlay(
                    HStack {
                        if !isLast {
                            Spacer()
                            Divider()
                        }
                    }
                )
        )
    }
}

struct ResourceCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    let progress: Double?

    init(title: String, value: String, subtitle: String? = nil, icon: String, color: Color, progress: Double? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.progress = progress
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if let progress = progress {
                ProgressView(value: progress)
                    .tint(color)
                    .scaleEffect(y: 0.8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}

// MARK: - Loading Components

struct LoadingCard: View {
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct EmptyStateCard: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundColor(.secondary)

            VStack(spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Status Components

struct StatusIndicator: View {
    let status: String
    let color: Color
    let showDot: Bool

    init(status: String, color: Color, showDot: Bool = true) {
        self.status = status
        self.color = color
        self.showDot = showDot
    }

    var body: some View {
        HStack(spacing: 4) {
            if showDot {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
            }
            Text(status)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

struct ProgressCard: View {
    let title: String
    let progress: Double
    let color: Color
    let showPercentage: Bool

    init(title: String, progress: Double, color: Color, showPercentage: Bool = true) {
        self.title = title
        self.progress = progress
        self.color = color
        self.showPercentage = showPercentage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if showPercentage {
                    Text(String(format: "%.1f%%", progress * 100))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            ProgressView(value: progress)
                .tint(color)
                .scaleEffect(y: 1.5)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Action Components

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(color)
        .controlSize(.small)
    }
}

struct CompactActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
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

struct NavigationCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}

// MARK: - Information Components

struct InfoRow: View {
    let label: String
    let value: String
    let icon: String?

    init(label: String, value: String, icon: String? = nil) {
        self.label = label
        self.value = value
        self.icon = icon
    }

    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 16)
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Network Components

struct NetworkMetric: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct NetworkTrafficCard: View {
    let downloadRate: Double
    let uploadRate: Double

    var body: some View {
        HStack(spacing: 20) {
            NetworkMetric(
                title: "Download",
                value: StatFormatter.formatRateBytesPerSec(downloadRate),
                icon: "arrow.down.circle.fill",
                color: .green
            )

            NetworkMetric(
                title: "Upload",
                value: StatFormatter.formatRateBytesPerSec(uploadRate),
                icon: "arrow.up.circle.fill",
                color: .blue
            )
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 1)
    }
}

// MARK: - Tag Components

struct TagView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(6)
    }
}

struct TagsContainer: View {
    let tags: [String]
    let maxTags: Int

    init(tags: [String], maxTags: Int = 3) {
        self.tags = tags
        self.maxTags = maxTags
    }

    var body: some View {
        HStack {
            ForEach(Array(tags.prefix(maxTags).enumerated()), id: \.offset) { _, tag in
                TagView(text: tag, color: .blue)
            }

            if tags.count > maxTags {
                TagView(text: "+\(tags.count - maxTags)", color: .gray)
            }
        }
    }
}

// MARK: - Health Indicators

struct HealthIndicator: View {
    let title: String
    let status: HealthStatus
    let showIcon: Bool

    init(title: String, status: HealthStatus, showIcon: Bool = true) {
        self.title = title
        self.status = status
        self.showIcon = showIcon
    }

    enum HealthStatus {
        case excellent, good, warning, critical, unknown

        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .warning: return .orange
            case .critical: return .red
            case .unknown: return .gray
            }
        }

        var icon: String {
            switch self {
            case .excellent: return "checkmark.circle.fill"
            case .good: return "checkmark.circle"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "xmark.circle.fill"
            case .unknown: return "questionmark.circle"
            }
        }

        var description: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .warning: return "Warning"
            case .critical: return "Critical"
            case .unknown: return "Unknown"
            }
        }
    }

    var body: some View {
        HStack {
            if showIcon {
                Image(systemName: status.icon)
                    .foregroundColor(status.color)
            }
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(status.description)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(status.color)
        }
    }
}

// MARK: - Dashboard Components

struct DetailedDashboardCard: View {
    let title: String
    let subtitle: String

    init(title: String = "Detailed Dashboard", subtitle: String) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct QuickActionsCard: View {
    let title: String
    let actions: [(String, String, Color, () -> Void)]

    init(title: String = "Quick Actions", actions: [(String, String, Color, () -> Void)]) {
        self.title = title
        self.actions = actions
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(0..<min(actions.count, 4), id: \.self) { index in
                    let (title, _, color, action) = actions[index]
                    Button(title) {
                        action()
                    }
                    .buttonStyle(.bordered)
                    .tint(color)
                    .font(.caption)
                    .controlSize(.small)

                    if index < min(actions.count, 4) - 1 {
                        Spacer()
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct OverviewCard: View {
    let title: String
    let status: String
    let statusColor: Color
    let icon: String
    let iconColor: Color
    let metrics: [(String, String, String)]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(status)
                        .font(.subheadline)
                        .foregroundColor(statusColor)
                }
                Spacer()
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
            }

            HStack(spacing: 20) {
                ForEach(metrics, id: \.0) { metric in
                    StatPill(
                        title: metric.0,
                        value: metric.1,
                        systemImage: metric.2
                    )
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(12)
    }
}

struct ResourceUsageCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color
    let progress: Double?

    init(title: String, value: String, subtitle: String, icon: String, color: Color, progress: Double? = nil) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.progress = progress
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            if let progress = progress {
                ProgressView(value: progress)
                    .tint(color)
                    .scaleEffect(y: 0.8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}
