//
//  ServiceManager.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Foundation
import Combine

final class ServiceManager: ObservableObject {
    static let shared = ServiceManager()

    @Published private(set) var services: [ServiceConfig] = []

    private let storageKey = "service.configs.v1"
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private init() {
        load()
    }

    func addService(_ config: ServiceConfig) {
        services.append(config)
        persist()
    }

    func removeService(id: UUID) {
        services.removeAll { $0.id == id }
        persist()
    }

    func updateService(_ config: ServiceConfig) {
        guard let idx = services.firstIndex(where: { $0.id == config.id }) else { return }
        services[idx] = config
        persist()
    }

    func client(for config: ServiceConfig) -> ServiceClient {
        switch config.kind {
        case .proxmox:
            return ProxmoxClient(config: config)
        case .jellyfin:
            return JellyfinClient(config: config)
        }
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
}

