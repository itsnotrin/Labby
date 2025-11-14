//
//  ServicesView.swift
//  Labby
//
//  Created by Ryan Wiecz on 27/07/2025.
//

import SwiftUI

struct ServicesView: View {
    @ObservedObject private var serviceManager = ServiceManager.shared
    @State private var isPresentingAdd = false
    @State private var testingServiceId: UUID?
    @State private var testResult: String?
    @State private var testError: String?
    @State private var selectedHome: String =
        UserDefaults.standard.string(forKey: "selectedHome") ?? "Default Home"
    private var filteredServices: [ServiceConfig] {
        serviceManager.services.filter { $0.home == selectedHome }
    }

    var body: some View {
        NavigationView {
            List {
                if filteredServices.isEmpty {
                    Section {
                        VStack(spacing: 16) {
                            Spacer(minLength: 0)

                            Image(systemName: "server.rack")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)

                            Text("No Services Added")
                                .font(.headline)

                            Text("Add your first service to get started")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.vertical, 32)
                    }
                } else {
                    Section {
                        ForEach(filteredServices) { config in
                            if config.kind == .qbittorrent {
                                NavigationLink {
                                    QBittorrentView(config: config)
                                } label: {
                                    ServiceRowView(
                                        config: config,
                                        isTesting: testingServiceId == config.id,
                                        asButton: false,
                                        showChevron: false
                                    ) {
                                        // No-op in NavigationLink label
                                    }
                                }
                            } else if config.kind == .jellyfin {
                                NavigationLink {
                                    JellyfinView(config: config)
                                } label: {
                                    ServiceRowView(
                                        config: config,
                                        isTesting: testingServiceId == config.id,
                                        asButton: false,
                                        showChevron: false
                                    ) {
                                        // No-op in NavigationLink label
                                    }
                                }
                            } else if config.kind == .pihole {
                                NavigationLink {
                                    PiHoleView(config: config)
                                } label: {
                                    ServiceRowView(
                                        config: config,
                                        isTesting: testingServiceId == config.id,
                                        asButton: false,
                                        showChevron: false
                                    ) {
                                        // No-op in NavigationLink label
                                    }
                                }
                            } else if config.kind == .proxmox {
                                NavigationLink {
                                    ProxmoxView(config: config)
                                } label: {
                                    ServiceRowView(
                                        config: config,
                                        isTesting: testingServiceId == config.id,
                                        asButton: false,
                                        showChevron: false
                                    ) {
                                        // No-op in NavigationLink label
                                    }
                                }
                            } else {
                                ServiceRowView(config: config, isTesting: testingServiceId == config.id) {
                                    Task {
                                        await testConnection(config)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let service = filteredServices[index]
                                serviceManager.removeService(id: service.id)
                            }
                        }
                    } header: {
                        Text("Active Services")
                    } footer: {
                        Text("Tap a service to test connection and log info to console")
                    }
                }

                Section {
                    Button {
                        isPresentingAdd = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add New Service")
                        }
                    }
                }
            }
            .navigationTitle("Services")
            .sheet(isPresented: $isPresentingAdd) {
                AddServiceView()
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
            .onAppear {
                selectedHome =
                    UserDefaults.standard.string(forKey: "selectedHome") ?? "Default Home"
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
}

struct ServiceRowView: View {
    let config: ServiceConfig
    let isTesting: Bool
    let asButton: Bool
    let showChevron: Bool
    let onTest: () -> Void

    init(config: ServiceConfig, isTesting: Bool, onTest: @escaping () -> Void) {
        self.config = config
        self.isTesting = isTesting
        self.asButton = true
        self.showChevron = true
        self.onTest = onTest
    }

    init(config: ServiceConfig, isTesting: Bool, asButton: Bool, showChevron: Bool = true, onTest: @escaping () -> Void) {
        self.config = config
        self.isTesting = isTesting
        self.asButton = asButton
        self.showChevron = showChevron
        self.onTest = onTest
    }

    var body: some View {
        Group {
            if asButton {
                Button(action: { onTest() }) {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack {
            serviceIcon
                .font(.title2)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading) {
                Text(config.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 8) {
                    Text(config.kind.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: "house.fill")
                        Text(config.home)
                    }
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            Spacer()

            if isTesting {
                ProgressView()
                    .scaleEffect(0.8)
            } else if showChevron {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }

    private var serviceIcon: Image {
        switch config.kind {
        case .proxmox:
            return Image(systemName: "server.rack")
        case .jellyfin:
            return Image(systemName: "tv")
        case .qbittorrent:
            return Image(systemName: "arrow.down.circle")
        case .pihole:
            return Image(systemName: "shield.lefthalf.filled")
        }
    }
}

#Preview {
    ServicesView()
}
