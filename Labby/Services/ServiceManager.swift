//
//  ServiceManager.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Combine
import Foundation

final class ServiceManager: ObservableObject {
    static let shared = ServiceManager()

    @Published private(set) var services: [ServiceConfig] = []

    private let storageKey = "service.configs.v1"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private var clientCache: [UUID: ServiceClient] = [:]

    private init() {
        load()
    }

    func addService(_ config: ServiceConfig) {
        services.append(config)
        persist()
    }

    func removeService(id: UUID) {
        clientCache.removeValue(forKey: id)
        services.removeAll { $0.id == id }
        persist()
    }

    func updateService(_ config: ServiceConfig) {
        clientCache.removeValue(forKey: config.id)
        guard let idx = services.firstIndex(where: { $0.id == config.id }) else { return }
        services[idx] = config
        persist()
    }

    func client(for config: ServiceConfig) -> ServiceClient {
        if let cached = clientCache[config.id] {
            return cached
        }
        let newClient: ServiceClient
        switch config.kind {
        case .proxmox:
            newClient = ProxmoxClient(config: config)
        case .jellyfin:
            newClient = JellyfinClient(config: config)
        case .qbittorrent:
            newClient = QBittorrentClient(config: config)
        case .pihole:
            newClient = PiHoleClient(config: config)
        }
        clientCache[config.id] = newClient
        return newClient
    }

    // MARK: - Persistence

    private func persist() {
        do {
            let data = try encoder.encode(services)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("[ServiceManager] Failed to persist services: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return }
        do {
            services = try decoder.decode([ServiceConfig].self, from: data)
        } catch {
            print("[ServiceManager] Failed to load services: \(error)")
            services = []
        }
    }

    func resetAllData() {
        for config in services {
            switch config.auth {
            case .apiToken(let secretKeychainKey):
                KeychainStorage.shared.deleteSecret(forKey: secretKeychainKey)
            case .usernamePassword(_, let passwordKeychainKey):
                KeychainStorage.shared.deleteSecret(forKey: passwordKeychainKey)
            case .proxmoxToken(_, let tokenSecretKeychainKey):
                KeychainStorage.shared.deleteSecret(forKey: tokenSecretKeychainKey)
            }
        }
        clientCache.removeAll()
        services.removeAll()
        UserDefaults.standard.removeObject(forKey: storageKey)
        HomeLayoutStore.shared.removeAllHomes()
        UserDefaults.standard.removeObject(forKey: "homes")
        UserDefaults.standard.removeObject(forKey: "selectedHome")
    }
}
