//
//  HomeView.swift
//  Labby
//
//  Created by Ryan Wiecz on 27/07/2025.
//

import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var serviceManager = ServiceManager.shared

    @State private var homes: [String] = UserDefaults.standard.stringArray(forKey: "homes") ?? ["Default Home"]
    @State private var selectedHome: String = UserDefaults.standard.string(forKey: "selectedHome") ?? "Default Home"
    @State private var isAddingHome: Bool = false
    @State private var testingServiceId: UUID?
    @State private var testResult: String?
    @State private var testError: String?

    var body: some View {
        NavigationView {
            ScrollView {
                if serviceManager.services.isEmpty {
                    VStack(spacing: 24) {
                        Spacer(minLength: 0)
                        
                        Image(systemName: "server.rack")
                            .font(.system(size: 64))
                            .foregroundStyle(.secondary)
                        
                        VStack(spacing: 8) {
                            Text("No Services Added")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Add services in the Services tab to see them here")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        NavigationLink {
                            ServicesView()
                        } label: {
                            Label("Go to Services", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ForEach(serviceManager.services) { config in
                            ServiceCardView(config: config) {
                                Task {
                                    await testConnection(config)
                                }
                            }
                        }
                    }
                    .padding()
                }
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
                    NavigationLink {
                        ServicesView()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $isAddingHome) {
            AddHomeView(homes: $homes, selectedHome: $selectedHome)
        }
        .alert("Test Result", isPresented: .constant(testResult != nil || testError != nil)) {
            Button("OK") {
                testResult = nil
                testError = nil
            }
        } message: {
            if let result = testResult {
                Text(result)
            } else if let error = testError {
                Text(error)
            }
        }
    }

    private func testConnection(_ config: ServiceConfig) async {
        testingServiceId = config.id
        let client = serviceManager.client(for: config)
        do {
            let info = try await client.testConnection()
            print("[Service Test] \(config.displayName): \(info)")
            testResult = info
        } catch {
            print("[Service Test] \(config.displayName) error: \(error.localizedDescription)")
            testError = error.localizedDescription
        }
        testingServiceId = nil
    }

    struct ServiceCardView: View {
        let config: ServiceConfig
        let onTest: () -> Void
        
        @State private var isTesting = false

        var body: some View {
            Button(action: {
                isTesting = true
                onTest()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isTesting = false
                }
            }) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        serviceIcon
                            .font(.title2)
                        Spacer()
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            StatusBadgeView(status: .online)
                        }
                    }

                    Text(config.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(config.kind.displayName)
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
            .buttonStyle(.plain)
        }

        private var serviceIcon: Image {
            switch config.kind {
            case .proxmox:
                return Image(systemName: "server.rack")
            case .jellyfin:
                return Image(systemName: "tv")
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
