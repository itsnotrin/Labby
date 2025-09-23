//
//  ProxmoxClient.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Foundation

final class ProxmoxClient: ServiceClient {
    private static var netSnapshots: [UUID: (ts: TimeInterval, inBytes: Int64, outBytes: Int64)] =
        [:]
    let config: ServiceConfig

    // Reuse a single URLSession per client (respecting insecure TLS option)
    private lazy var session: URLSession = {
        if config.insecureSkipTLSVerify {
            return URLSession(
                configuration: .ephemeral,
                delegate: InsecureSessionDelegate(),
                delegateQueue: nil
            )
        } else {
            return URLSession(configuration: .ephemeral)
        }
    }()

    init(config: ServiceConfig) {
        self.config = config
    }

    // Build an authorized JSON request with safe URL composition
    private func makeRequest(
        path: String,
        method: String = "GET",
        queryItems: [URLQueryItem]? = nil
    ) throws -> URLRequest {
        let url = try config.url(appending: path, queryItems: queryItems)
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        switch config.auth {
        case .proxmoxToken(let tokenId, let tokenSecretKeychainKey):
            guard
                let secretData = KeychainStorage.shared.loadSecret(forKey: tokenSecretKeychainKey),
                let secret = String(data: secretData, encoding: .utf8)
            else {
                throw ServiceError.missingSecret
            }
            let authHeader = "PVEAPIToken=\(tokenId)=\(secret)"
            request.setValue(authHeader, forHTTPHeaderField: "Authorization")
        default:
            throw ServiceError.unknown
        }

        return request
    }

    func testConnection() async throws -> String {
        let request = try makeRequest(path: "/api2/json/version")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct VersionResponse: Codable { let data: Version }
            struct Version: Codable {
                let release: String
                let version: String
            }

            let decoded = try JSONDecoder().decode(VersionResponse.self, from: data)
            return "Proxmox version: \(decoded.data.version) (release \(decoded.data.release))"
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    func fetchStats() async throws -> ServiceStatsPayload {
        let request = try makeRequest(path: "/api2/json/nodes")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct NodesResponse: Codable { let data: [Node] }
            struct Node: Codable {
                let cpu: Double?
                let mem: Int64?
                let maxmem: Int64?
            }

            let decoded = try JSONDecoder().decode(NodesResponse.self, from: data)
            let nodes = decoded.data

            let cpuPercents = nodes.compactMap { $0.cpu }.map { $0 * 100.0 }
            let avgCPU =
                cpuPercents.isEmpty
                ? 0.0
                : cpuPercents.reduce(0.0, +) / Double(cpuPercents.count)

            let usedMem: Int64 = nodes.compactMap { $0.mem }.reduce(0, +)
            let totalMem: Int64 = nodes.compactMap { $0.maxmem }.reduce(0, +)

            var totalCTs = 0
            var totalVMs = 0
            var runningCount = 0
            var stoppedCount = 0
            var totalNetIn: Int64 = 0
            var totalNetOut: Int64 = 0

            do {
                // Fetch VM/LXC resources (optional best-effort)
                let vmRequest = try makeRequest(
                    path: "/api2/json/cluster/resources",
                    queryItems: [URLQueryItem(name: "type", value: "vm")]
                )

                struct VMResourcesResponse: Codable { let data: [VMResource] }
                struct VMResource: Codable {
                    let type: String?
                    let status: String?
                    let netin: Int64?
                    let netout: Int64?
                }

                let (vmData, vmResp) = try await session.data(for: vmRequest)
                guard let vmHTTP = vmResp as? HTTPURLResponse, 200..<300 ~= vmHTTP.statusCode else {
                    throw ServiceError.unknown
                }
                let vmDecoded = try JSONDecoder().decode(VMResourcesResponse.self, from: vmData)

                totalCTs = vmDecoded.data.filter { ($0.type ?? "").lowercased() == "lxc" }.count
                totalVMs =
                    vmDecoded.data.filter { t in
                        let v = (t.type ?? "").lowercased()
                        return v == "qemu" || v == "vm"
                    }.count
                runningCount =
                    vmDecoded.data.filter { ($0.status ?? "").lowercased() == "running" }.count
                stoppedCount = vmDecoded.data.count - runningCount
                totalNetIn = vmDecoded.data.compactMap { $0.netin }.reduce(0, +)
                totalNetOut = vmDecoded.data.compactMap { $0.netout }.reduce(0, +)
            } catch {
                // Ignore errors from this optional stats fetch
            }

            let now = Date().timeIntervalSince1970
            let prev = ProxmoxClient.netSnapshots[config.id]
            var upBps = 0.0
            var downBps = 0.0
            if let prev = prev {
                let dt = now - prev.ts
                if dt > 0 {
                    let dIn = Double(totalNetIn - prev.inBytes)
                    let dOut = Double(totalNetOut - prev.outBytes)
                    // Ensure non-negative (counters can reset on reboot)
                    downBps = max(0, dIn / dt)
                    upBps = max(0, dOut / dt)
                }
            }
            ProxmoxClient.netSnapshots[config.id] = (
                ts: now, inBytes: totalNetIn, outBytes: totalNetOut
            )

            let stats = ProxmoxStats(
                cpuUsagePercent: avgCPU,
                memoryUsedBytes: usedMem,
                memoryTotalBytes: totalMem,
                totalCTs: totalCTs,
                totalVMs: totalVMs,
                runningCount: runningCount,
                stoppedCount: stoppedCount,
                netUpBps: upBps,
                netDownBps: downBps
            )
            return .proxmox(stats)
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }
}
