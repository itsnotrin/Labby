//
//  ServiceClient.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Foundation

// Uses ServiceConfig.url(...) helper for safe URL composition across clients.

/// Common interface all service clients implement.
/// Note: Concrete clients should reuse a single URLSession and use ServiceConfig.url(...) for composing endpoints.
protocol ServiceClient {
    var config: ServiceConfig { get }
    func testConnection() async throws -> String
    func fetchStats() async throws -> ServiceStatsPayload
}

/// URLSessionDelegate that trusts the server when config.insecureSkipTLSVerify is enabled.
/// Only used with .ephemeral sessions within clients.
final class InsecureSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(
        _ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let trust = challenge.protectionSpace.serverTrust
        {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
