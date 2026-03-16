//
//  WelcomeView.swift
//  Labby
//
//  Created by Ryan Wiecz on 16/03/2026.
//

import SwiftUI

struct WelcomeView: View {
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup = false
    @State private var currentPage = 0
    @State private var showingAddService = false
    @State private var homeName: String = ""
    @ObservedObject private var serviceManager = ServiceManager.shared
    @State private var heartBeat = false
    @State private var serviceInfo: [UUID: (version: String, pingMs: Int)] = [:]
    @State private var probedServiceIDs: Set<UUID> = []

    private let totalPages = 5

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    welcomePage.tag(0)
                    servicesPage.tag(1)
                    setupHomePage.tag(2)
                    addServicePage.tag(3)
                    supportPage.tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentPage)

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
            }
        }
        .sheet(isPresented: $showingAddService, onDismiss: probeNewServices) {
            AddServiceView()
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "server.rack")
                .font(.system(size: 80))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Welcome to Labby")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your homelab dashboard.\nMonitor and manage all your self-hosted services in one place.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Page 2: Supported Services

    private var servicesPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("Supported Services")
                .font(.title)
                .fontWeight(.bold)

            Text("Labby connects to your favorite self-hosted applications.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                serviceRow(icon: "cpu", name: "Proxmox VE", description: "Virtual machines & containers", color: .orange)
                serviceRow(icon: "play.rectangle.fill", name: "Jellyfin", description: "Media server", color: .purple)
                serviceRow(icon: "arrow.down.circle.fill", name: "qBittorrent", description: "Torrent client", color: .blue)
                serviceRow(icon: "shield.fill", name: "Pi-hole", description: "Network-wide ad blocker", color: .red)
                moreServicesRow
            }
            .padding(.horizontal, 24)

            Spacer()
            Spacer()
        }
    }

    private func serviceRow(icon: String, name: String, description: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private var moreServicesRow: some View {
        Link(destination: URL(string: "https://github.com/itsnotrin/Labby/issues")!) {
            HStack(spacing: 16) {
                Image(systemName: "plus.bubble.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 40)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Want more?")
                        .font(.headline)
                    Text("Request a service on GitHub")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page 3: Set Up Home

    private var setupHomePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "house.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Name Your Home")
                    .font(.title)
                    .fontWeight(.bold)

                Text("A home groups your services together.\nGreat for separating local and remote setups.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                TextField("e.g. My Homelab", text: $homeName)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 40)

                HStack(spacing: 10) {
                    homePresetButton("My Homelab")
                    homePresetButton("Home")
                    homePresetButton("Remote")
                }
            }

            Text("You can add more homes later in settings.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
            Spacer()
        }
    }

    private func homePresetButton(_ name: String) -> some View {
        Button {
            homeName = name
        } label: {
            Text(name)
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
        .tint(homeName == name ? .accentColor : .secondary)
    }

    // MARK: - Page 4: Add First Service

    private var addedServices: [ServiceConfig] {
        let home = homeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let selectedHome = home.isEmpty ? "Default Home" : home
        return serviceManager.services.filter { $0.home == selectedHome }
    }

    private var addServicePage: some View {
        VStack(spacing: 24) {
            Spacer()

            if addedServices.isEmpty {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                VStack(spacing: 12) {
                    Text("Add Your First Service")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("Connect a service to start monitoring.\nYou'll need your server URL and credentials.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            } else {
                VStack(spacing: 12) {
                    Text(addedServices.count == 1 ? "Service Added" : "Services Added")
                        .font(.title)
                        .fontWeight(.bold)

                    ForEach(addedServices) { service in
                        addedServiceRow(service)
                    }
                }
                .padding(.horizontal, 24)
            }

            Button {
                saveHome()
                showingAddService = true
            } label: {
                Label(addedServices.isEmpty ? "Add a Service" : "Add Another Service", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)

            Text("You can always add more services later.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Spacer()
            Spacer()
        }
    }

    private func addedServiceRow(_ service: ServiceConfig) -> some View {
        let (icon, color) = serviceKindAppearance(service.kind)
        let info = serviceInfo[service.id]
        return HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(service.displayName)
                    .font(.headline)
                if let info {
                    Text("\(info.version) - \(info.pingMs)ms")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if probedServiceIDs.contains(service.id) {
                    Text(service.kind.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    private func serviceKindAppearance(_ kind: ServiceKind) -> (icon: String, color: Color) {
        switch kind {
        case .proxmox: return ("cpu", .orange)
        case .jellyfin: return ("play.rectangle.fill", .purple)
        case .qbittorrent: return ("arrow.down.circle.fill", .blue)
        case .pihole: return ("shield.fill", .red)
        }
    }

    // MARK: - Page 5: Support

    private var supportPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.fill")
                .font(.system(size: 64))
                .foregroundStyle(.pink)
                .scaleEffect(heartBeat ? 1.15 : 1.0)
                .animation(
                    .easeInOut(duration: 0.4)
                        .repeatForever(autoreverses: true),
                    value: heartBeat
                )
                .onAppear { heartBeat = true }

            VStack(spacing: 12) {
                Text("Support Labby")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Labby is built and maintained by an independent developer. If you find it useful, consider supporting its development.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Link(destination: URL(string: "https://github.com/sponsors/itsnotrin")!) {
                Label("Sponsor on GitHub", systemImage: "heart.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .padding(.horizontal, 40)

            Link(destination: URL(string: "https://github.com/itsnotrin")!) {
                Label("@itsnotrin on GitHub", systemImage: "link")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)

            Spacer()
            Spacer()
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack {
            if currentPage < totalPages - 1 {
                Button("Skip") {
                    saveHome()
                    hasCompletedSetup = true
                }
                .foregroundStyle(.secondary)
            } else {
                Spacer()
            }

            Spacer()

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.4))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            if currentPage < totalPages - 1 {
                Button("Next") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    if currentPage == 2 {
                        saveHome()
                    }
                    withAnimation {
                        currentPage += 1
                    }
                }
                .fontWeight(.semibold)
            } else {
                Button("Get Started") {
                    saveHome()
                    hasCompletedSetup = true
                }
                .fontWeight(.semibold)
            }
        }
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private func probeNewServices() {
        for service in addedServices where serviceInfo[service.id] == nil {
            let client = ServiceManager.shared.client(for: service)
            Task {
                let start = ContinuousClock.now
                do {
                    let version = try await client.testConnection()
                    let elapsed = start.duration(to: .now)
                    let ms = Int(elapsed.components.seconds * 1000
                                 + elapsed.components.attoseconds / 1_000_000_000_000_000)
                    serviceInfo[service.id] = (version: version, pingMs: ms)
                } catch {
                    probedServiceIDs.insert(service.id)
                }
            }
        }
    }

    private func saveHome() {
        let name = homeName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = name.isEmpty ? "Default Home" : name

        var homes = UserDefaults.standard.stringArray(forKey: DefaultsKeys.homes) ?? []
        if !homes.contains(finalName) {
            homes.append(finalName)
        }
        UserDefaults.standard.set(homes, forKey: DefaultsKeys.homes)
        UserDefaults.standard.set(finalName, forKey: DefaultsKeys.selectedHome)
    }
}

#Preview {
    WelcomeView()
}
