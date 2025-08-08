//
//  ServiceClient.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Foundation

protocol ServiceClient {
    var config: ServiceConfig { get }
    func testConnection() async throws -> String
}

extension URLSessionConfiguration {
    static func ephemeralTLS(skipVerify: Bool) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        if skipVerify {
            config.serverTrustPolicyManager = ServerTrustPolicyManager(policies: [
                "*" : ServerTrustPolicy.disableEvaluation
            ])
            config.delegate = InsecureSessionDelegate()
        }
        return config
    }
}

final class InsecureSessionDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}

