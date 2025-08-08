//
//  JellyfinClient.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Foundation

final class JellyfinClient: ServiceClient {
    let config: ServiceConfig

    init(config: ServiceConfig) {
        self.config = config
    }

    func testConnection() async throws -> String {
        let session: URLSession
        if config.insecureSkipTLSVerify {
            session = URLSession(configuration: .ephemeral, delegate: InsecureSessionDelegate(), delegateQueue: nil)
        } else {
            session = URLSession(configuration: .ephemeral)
        }

        let authToken = try await authenticate(session: session)

        guard let url = URL(string: config.baseURLString + "/System/Info") else { throw ServiceError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else { throw ServiceError.httpStatus(http.statusCode) }

            struct Info: Codable { let ProductName: String?; let Version: String?; let OperatingSystem: String? }
            let decoded = try JSONDecoder().decode(Info.self, from: data)
            let name = decoded.ProductName ?? "Jellyfin"
            let version = decoded.Version ?? "?"
            return "\(name) version: \(version)"
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    private func authenticate(session: URLSession) async throws -> String {
        guard let url = URL(string: config.baseURLString + "/Users/AuthenticateByName") else { throw ServiceError.invalidURL }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let deviceId = UUID().uuidString
        let authHeader = "MediaBrowser Client=\"Labby\", Device=\"iOS\", DeviceId=\"\(deviceId)\", Version=\"0.0.1\""
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        switch config.auth {
        case .apiToken(let secretKey):
            guard let tokenData = KeychainStorage.shared.loadSecret(forKey: secretKey),
                  let token = String(data: tokenData, encoding: .utf8) else { 
                throw ServiceError.missingSecret 
            }
            return token
            
        case .usernamePassword(let username, let passwordKey):
            guard let passData = KeychainStorage.shared.loadSecret(forKey: passwordKey),
                  let password = String(data: passData, encoding: .utf8) else { 
                throw ServiceError.missingSecret 
            }
            
            let authBody: [String: Any] = [
                "Username": username,
                "Pw": password
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: authBody)
            
            let (data, response) = try await session.data(for: request)
            
            guard let http = response as? HTTPURLResponse else { 
                throw ServiceError.unknown 
            }
            
            guard 200..<300 ~= http.statusCode else { 
                throw ServiceError.httpStatus(http.statusCode) 
            }
            
            struct AuthResponse: Codable {
                let AccessToken: String?
                let User: UserInfo?
            }
            struct UserInfo: Codable {
                let Name: String?
            }
            
            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            guard let accessToken = authResponse.AccessToken else {
                throw ServiceError.unknown
            }
            
            return accessToken
            
        default:
            throw ServiceError.unknown
        }
    }
}

