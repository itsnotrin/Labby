//
//  ProxmoxClient.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Foundation

final class ProxmoxClient: ServiceClient {
    let config: ServiceConfig

    init(config: ServiceConfig) {
        self.config = config
    }

    func testConnection() async throws -> String {
        guard let url = URL(string: config.baseURLString + "/api2/json/version") else { throw ServiceError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        switch config.auth {
        case .proxmoxToken(let tokenId, let tokenSecretKeychainKey):
            guard let secretData = KeychainStorage.shared.loadSecret(forKey: tokenSecretKeychainKey),
                  let secret = String(data: secretData, encoding: .utf8) else {
                throw ServiceError.missingSecret
            }
            let authHeader = "PVEAPIToken=\(tokenId)=\(secret)"
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        default:
            throw ServiceError.unknown
        }

        let session: URLSession
        if config.insecureSkipTLSVerify {
            session = URLSession(configuration: .ephemeral, delegate: InsecureSessionDelegate(), delegateQueue: nil)
        } else {
            session = URLSession(configuration: .ephemeral)
        }

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else { throw ServiceError.httpStatus(http.statusCode) }

            struct VersionResponse: Codable { let data: Version }
            struct Version: Codable { let release: String; let version: String }

            let decoded = try JSONDecoder().decode(VersionResponse.self, from: data)
            return "Proxmox version: \(decoded.data.version) (release \(decoded.data.release))"
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }
}

