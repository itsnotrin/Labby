//
//  ServiceModels.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Foundation

enum ServiceKind: String, Codable, CaseIterable, Identifiable {
    case proxmox
    case jellyfin
    case qbittorrent
    case pihole

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .proxmox: return "Proxmox"
        case .jellyfin: return "Jellyfin"
        case .qbittorrent: return "qBittorrent"
        case .pihole: return "Pi-hole"
        }
    }
}

enum AuthMethodType: String, Codable, CaseIterable, Identifiable {
    case apiToken
    case usernamePassword
    case proxmoxToken  // tokenId + tokenSecret

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apiToken: return "API Token"
        case .usernamePassword: return "Username & Password"
        case .proxmoxToken: return "Proxmox API Token"
        }
    }
}

// Auth configuration without embedding sensitive values directly.
enum ServiceAuthConfig: Codable, Equatable {
    case apiToken(secretKeychainKey: String)
    case usernamePassword(username: String, passwordKeychainKey: String)
    case proxmoxToken(tokenId: String, tokenSecretKeychainKey: String)

    enum CodingKeys: String, CodingKey {
        case type, username, secretKey, tokenId, passwordKey, tokenSecretKey
    }

    enum Discriminator: String, Codable { case apiToken, usernamePassword, proxmoxToken }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Discriminator.self, forKey: .type)
        switch type {
        case .apiToken:
            let key = try container.decode(String.self, forKey: .secretKey)
            self = .apiToken(secretKeychainKey: key)
        case .usernamePassword:
            let username = try container.decode(String.self, forKey: .username)
            let passwordKey = try container.decode(String.self, forKey: .passwordKey)
            self = .usernamePassword(username: username, passwordKeychainKey: passwordKey)
        case .proxmoxToken:
            let tokenId = try container.decode(String.self, forKey: .tokenId)
            let secretKey = try container.decode(String.self, forKey: .tokenSecretKey)
            self = .proxmoxToken(tokenId: tokenId, tokenSecretKeychainKey: secretKey)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .apiToken(let secretKeychainKey):
            try container.encode(Discriminator.apiToken, forKey: .type)
            try container.encode(secretKeychainKey, forKey: .secretKey)
        case .usernamePassword(let username, let passwordKeychainKey):
            try container.encode(Discriminator.usernamePassword, forKey: .type)
            try container.encode(username, forKey: .username)
            try container.encode(passwordKeychainKey, forKey: .passwordKey)
        case .proxmoxToken(let tokenId, let tokenSecretKeychainKey):
            try container.encode(Discriminator.proxmoxToken, forKey: .type)
            try container.encode(tokenId, forKey: .tokenId)
            try container.encode(tokenSecretKeychainKey, forKey: .tokenSecretKey)
        }
    }
}

struct ServiceConfig: Identifiable, Codable, Equatable {
    let id: UUID
    var displayName: String
    var kind: ServiceKind
    var baseURLString: String
    var auth: ServiceAuthConfig
    var insecureSkipTLSVerify: Bool
    var home: String

    enum CodingKeys: String, CodingKey {
        case id, displayName, kind, baseURLString, auth, insecureSkipTLSVerify, home
    }

    private static func defaultHome() -> String {
        UserDefaults.standard.string(forKey: "selectedHome") ?? "Default Home"
    }

    init(
        id: UUID = UUID(),
        displayName: String,
        kind: ServiceKind,
        baseURLString: String,
        auth: ServiceAuthConfig,
        insecureSkipTLSVerify: Bool,
        home: String = ServiceConfig.defaultHome()
    ) {
        self.id = id
        self.displayName = displayName
        self.kind = kind
        self.baseURLString = baseURLString
        self.auth = auth
        self.insecureSkipTLSVerify = insecureSkipTLSVerify
        self.home = home
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.kind = try container.decode(ServiceKind.self, forKey: .kind)
        self.baseURLString = try container.decode(String.self, forKey: .baseURLString)
        self.auth = try container.decode(ServiceAuthConfig.self, forKey: .auth)
        self.insecureSkipTLSVerify = try container.decode(Bool.self, forKey: .insecureSkipTLSVerify)
        self.home =
            try container.decodeIfPresent(String.self, forKey: .home) ?? ServiceConfig.defaultHome()
    }
}

extension ServiceConfig {
    /// Safely builds a URL by appending a path (and optional query items) to the baseURLString.
    /// - Parameters:
    ///   - path: The path to append. Leading "/" is optional and will be normalized.
    ///   - queryItems: Optional query items to include.
    /// - Throws: ServiceError.invalidURL when baseURLString or composed URL is invalid.
    /// - Returns: A composed URL based on baseURLString.
    func url(appending path: String, queryItems: [URLQueryItem]? = nil) throws -> URL {
        guard var comps = URLComponents(string: baseURLString) else {
            throw ServiceError.invalidURL
        }
        var basePath = comps.path
        if !basePath.hasSuffix("/") { basePath += "/" }
        let trimmed = path.hasPrefix("/") ? String(path.dropFirst()) : path
        comps.path = basePath + trimmed
        comps.queryItems = queryItems
        guard let url = comps.url else { throw ServiceError.invalidURL }
        return url
    }
}

enum ServiceError: Error, LocalizedError {
    case invalidURL
    case missingSecret
    case network(Error)
    case httpStatus(Int)
    case decoding(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .missingSecret: return "Missing secret in Keychain"
        case .network(let err): return "Network error: \(err.localizedDescription)"
        case .httpStatus(let code): return "HTTP status code: \(code)"
        case .decoding(let err): return "Decoding error: \(err.localizedDescription)"
        case .unknown: return "Unknown error"
        }
    }
}
