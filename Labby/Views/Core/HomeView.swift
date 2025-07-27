//
//  HomeView.swift
//  Labby
//
//  Created by Ryan Wiecz on 27/07/2025.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var homes: [String] = UserDefaults.standard.stringArray(forKey: "homes") ?? ["Default Home"]
    @State private var selectedHome: String = UserDefaults.standard.string(forKey: "selectedHome") ?? "Default Home"
    @State private var isAddingHome: Bool = false

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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(homes, id: \.self) { home in
                            Button(action: {
                                selectedHome = home
                                UserDefaults.standard.set(home, forKey: "selectedHome")
                            }) {
                                HStack {
                                    Text(home)
                                        .fontWeight(selectedHome == home ? .bold : .regular)
                                    Spacer()
                                    if selectedHome == home {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        Divider()
                        Button(action: {
                            isAddingHome = true
                        }) {
                            Label("Add New Home", systemImage: "plus")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(selectedHome)
                                .font(.title)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Image(systemName: "chevron.down")
                                .font(.title2)
                        }
                        .foregroundStyle(.primary)
                        .buttonStyle(.borderless)
                    }
                }
            }
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
        .sheet(isPresented: $isAddingHome) {
            AddHomeView(homes: $homes, selectedHome: $selectedHome)
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
}

#Preview("HomeView") {
    NavigationView {
        HomeView()
    }
}
