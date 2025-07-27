//
//  HomeView.swift
//  Labby
//
//  Created by Ryan Wiecz on 27/07/2025.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(0..<4) { _ in
                        ServiceCardView()
                    }
                }
                .padding()
            }
            .navigationTitle("Labby")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Add service action
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct ServiceCardView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "server.rack")
                    .font(.title2)
                Spacer()
                StatusBadgeView(status: .online)
            }

            Text("Service Name")
                .font(.headline)

            Text("Status: Running")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background {
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.quaternary, lineWidth: 0.5)
        }
    }
}

struct StatusBadgeView: View {
    enum Status {
        case online
        case offline
        case warning

        var color: Color {
            switch self {
            case .online: return .green
            case .offline: return .red
            case .warning: return .yellow
            }
        }
    }

    let status: Status

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 10, height: 10)
            .overlay {
                Circle()
                    .stroke(status.color.opacity(0.3), lineWidth: 2)
                    .scaleEffect(1.5)
            }
    }
}

#Preview {
    HomeView()
}
