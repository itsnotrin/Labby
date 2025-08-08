//
//  QBittorrentClient.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Foundation

final class QBittorrentClient: ServiceClient {
    let config: ServiceConfig

    init(config: ServiceConfig) {
        self.config = config
    }

    func testConnection() async throws -> String {
        let session: URLSession
        if config.insecureSkipTLSVerify {
            session = URLSession(
                configuration: .ephemeral, delegate: InsecureSessionDelegate(), delegateQueue: nil)
        } else {
            session = URLSession(configuration: .ephemeral)
        }

        let sessionCookie = try await authenticate(session: session)

        guard let url = URL(string: config.baseURLString + "/api/v2/app/version") else {
            throw ServiceError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(sessionCookie, forHTTPHeaderField: "Cookie")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            if let versionString = String(data: data, encoding: .utf8) {
                return
                    "qBittorrent version: \(versionString.trimmingCharacters(in: .whitespacesAndNewlines))"
            } else {
                throw ServiceError.decoding(
                    NSError(
                        domain: "QBittorrent", code: 0,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid version response"]))
            }
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    private func authenticate(session: URLSession) async throws -> String {
        guard let url = URL(string: config.baseURLString + "/api/v2/auth/login") else {
            throw ServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        switch config.auth {
        case .usernamePassword(let username, let passwordKey):
            guard let passData = KeychainStorage.shared.loadSecret(forKey: passwordKey),
                let password = String(data: passData, encoding: .utf8)
            else {
                throw ServiceError.missingSecret
            }

            let formData =
                "username=\(username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username)&password=\(password.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? password)"
            request.httpBody = formData.data(using: .utf8)

            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                throw ServiceError.unknown
            }

            if let responseString = String(data: data, encoding: .utf8) {
                let trimmedResponse = responseString.trimmingCharacters(in: .whitespacesAndNewlines)

                if trimmedResponse == "Ok." {
                    // Extract the session cookie from response headers
                    if let setCookieHeader = http.allHeaderFields["Set-Cookie"] as? String {
                        // Extract the SID cookie value
                        let components = setCookieHeader.components(separatedBy: ";")
                        for component in components {
                            let trimmed = component.trimmingCharacters(in: .whitespaces)
                            if trimmed.hasPrefix("SID=") {
                                return trimmed
                            }
                        }
                    }
                    // If no SID cookie found, return a basic cookie format
                    return "SID=authenticated"
                } else if trimmedResponse == "Fails." {
                    throw ServiceError.httpStatus(401)
                } else {
                    throw ServiceError.httpStatus(http.statusCode)
                }
            }

            // If we can't parse the response, check the HTTP status code
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            throw ServiceError.unknown

        default:
            throw ServiceError.unknown
        }
    }
}
