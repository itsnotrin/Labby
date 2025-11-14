//
//  ProxmoxClient.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Foundation

final class ProxmoxClient: ServiceClient {
    private static var netSnapshots: [UUID: (ts: TimeInterval, inBytes: Int64, outBytes: Int64)] = [:]
    let config: ServiceConfig

    // Cache properties
    private var cachedNodes: [ProxmoxNodeData] = []
    private var cachedVMs: [ProxmoxVMData] = []
    private var cachedStorage: [ProxmoxStorageData] = []

    // Cache timestamps
    private var nodesTimestamp: Date?
    private var vmsTimestamp: Date?
    private var storageTimestamp: Date?

    // Cache expiry duration (5 minutes)
    private let cacheExpiryDuration: TimeInterval = 300

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

            let cpuPercents = nodes.compactMap { $0.cpu }.filter { $0.isFinite }.map { $0 * 100.0 }
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
            var runningVMs = 0
            var runningCTs = 0
            var totalNetIn: Int64 = 0
            var totalNetOut: Int64 = 0

            do {
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

                let allVMs = vmDecoded.data.filter { t in
                    let v = (t.type ?? "").lowercased()
                    return v == "qemu" || v == "vm"
                }
                let allCTs = vmDecoded.data.filter { ($0.type ?? "").lowercased() == "lxc" }

                totalVMs = allVMs.count
                totalCTs = allCTs.count

                runningVMs = allVMs.filter { ($0.status ?? "").lowercased() == "running" }.count
                runningCTs = allCTs.filter { ($0.status ?? "").lowercased() == "running" }.count

                runningCount = runningVMs + runningCTs
                stoppedCount = vmDecoded.data.count - runningCount
                totalNetIn = vmDecoded.data.compactMap { $0.netin }.reduce(0, +)
                totalNetOut = vmDecoded.data.compactMap { $0.netout }.reduce(0, +)
            } catch {
                print("ProxmoxClient: Failed to fetch VM/container data: \(error)")
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
                    downBps = max(0, dIn / dt)
                    upBps = max(0, dOut / dt)
                }
            }
            ProxmoxClient.netSnapshots[config.id] = (ts: now, inBytes: totalNetIn, outBytes: totalNetOut)

            let stats = ProxmoxStats(
                cpuUsagePercent: avgCPU,
                memoryUsedBytes: usedMem,
                memoryTotalBytes: totalMem,
                totalCTs: totalCTs,
                totalVMs: totalVMs,
                runningCount: runningCount,
                stoppedCount: stoppedCount,
                runningVMs: runningVMs,
                runningCTs: runningCTs,
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

    // MARK: - Extended API Methods for Detailed View

    func fetchNodes() async throws -> [ProxmoxNodeData] {
        // Check if cached data is still valid
        if let timestamp = nodesTimestamp,
           Date().timeIntervalSince(timestamp) < cacheExpiryDuration,
           !cachedNodes.isEmpty {
            let age = Date().timeIntervalSince(timestamp)
            print("ProxmoxClient: Using cached nodes data (\(cachedNodes.count) nodes, age: \(Int(age))s)")
            return cachedNodes
        }

        print("ProxmoxClient: Fetching fresh nodes data from API (cache miss)")
        let request = try makeRequest(path: "/api2/json/nodes")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct NodesResponse: Codable { let data: [ProxmoxNodeData] }
            let decoded = try JSONDecoder().decode(NodesResponse.self, from: data)

            // Cache the result
            cachedNodes = decoded.data
            nodesTimestamp = Date()
            print("ProxmoxClient: Cached \(decoded.data.count) nodes data")

            return decoded.data
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    func fetchVMs() async throws -> [ProxmoxVMData] {
        // Check if cached data is still valid
        if let timestamp = vmsTimestamp,
           Date().timeIntervalSince(timestamp) < cacheExpiryDuration,
           !cachedVMs.isEmpty {
            let age = Date().timeIntervalSince(timestamp)
            print("ProxmoxClient: Using cached VMs data (\(cachedVMs.count) VMs, age: \(Int(age))s)")
            return cachedVMs
        }

        print("ProxmoxClient: Fetching fresh VMs data from API (cache miss)")
        let request = try makeRequest(
            path: "/api2/json/cluster/resources",
            queryItems: [URLQueryItem(name: "type", value: "vm")]
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct VMResourcesResponse: Codable { let data: [ProxmoxVMData] }
            let decoded = try JSONDecoder().decode(VMResourcesResponse.self, from: data)

            // Cache the result
            cachedVMs = decoded.data
            vmsTimestamp = Date()
            print("ProxmoxClient: Cached \(decoded.data.count) VMs data")

            return decoded.data
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    func fetchStorage() async throws -> [ProxmoxStorageData] {
        // Check if cached data is still valid
        if let timestamp = storageTimestamp,
           Date().timeIntervalSince(timestamp) < cacheExpiryDuration,
           !cachedStorage.isEmpty {
            let age = Date().timeIntervalSince(timestamp)
            print("ProxmoxClient: Using cached storage data (\(cachedStorage.count) pools, age: \(Int(age))s)")
            return cachedStorage
        }

        print("ProxmoxClient: Fetching fresh storage data from API (cache miss)")
        let request = try makeRequest(
            path: "/api2/json/cluster/resources",
            queryItems: [URLQueryItem(name: "type", value: "storage")]
        )

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct StorageResponse: Codable { let data: [ProxmoxStorageData] }
            let decoded = try JSONDecoder().decode(StorageResponse.self, from: data)

            // Cache the result
            cachedStorage = decoded.data
            storageTimestamp = Date()
            print("ProxmoxClient: Cached \(decoded.data.count) storage data")

            return decoded.data
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    func fetchVMDetails(node: String, vmid: String, type: VMType) async throws -> ProxmoxVMDetails {
        let endpoint = type == .container ? "lxc" : "qemu"
        let request = try makeRequest(path: "/api2/json/nodes/\(node)/\(endpoint)/\(vmid)/config")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct VMDetailsResponse: Codable { let data: ProxmoxVMDetails }
            let decoded = try JSONDecoder().decode(VMDetailsResponse.self, from: data)
            return decoded.data
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    func controlVM(node: String, vmid: String, type: VMType, action: VMAction) async throws {
        let endpoint = type == .container ? "lxc" : "qemu"
        let request = try makeRequest(
            path: "/api2/json/nodes/\(node)/\(endpoint)/\(vmid)/status/\(action.rawValue)",
            method: "POST"
        )

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    func fetchBackups() async throws -> [ProxmoxBackupData] {
        let request = try makeRequest(path: "/api2/json/cluster/backup")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct BackupsResponse: Codable { let data: [ProxmoxBackupData] }
            let decoded = try JSONDecoder().decode(BackupsResponse.self, from: data)
            return decoded.data
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    // Cache invalidation methods
    func clearCache() {
        print("ProxmoxClient: Clearing all cached data")
        cachedNodes = []
        cachedVMs = []
        cachedStorage = []
        nodesTimestamp = nil
        vmsTimestamp = nil
        storageTimestamp = nil
    }

    func clearNodesCache() {
        print("ProxmoxClient: Clearing nodes cache")
        cachedNodes = []
        nodesTimestamp = nil
    }

    func clearVMsCache() {
        print("ProxmoxClient: Clearing VMs cache")
        cachedVMs = []
        vmsTimestamp = nil
    }

    func clearStorageCache() {
        print("ProxmoxClient: Clearing storage cache")
        cachedStorage = []
        storageTimestamp = nil
    }

    func createBackup(node: String, vmid: String) async throws {
        let request = try makeRequest(
            path: "/api2/json/nodes/\(node)/vzdump",
            method: "POST"
        )

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    func fetchNetworkConfig(node: String) async throws -> [ProxmoxNetworkInterface] {
        let request = try makeRequest(path: "/api2/json/nodes/\(node)/network")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct NetworkResponse: Codable { let data: [ProxmoxNetworkInterface] }
            let decoded = try JSONDecoder().decode(NetworkResponse.self, from: data)
            return decoded.data
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }
}

// MARK: - Extended Data Models

struct ProxmoxNodeData: Codable, Identifiable {
    let id: String
    let node: String
    let type: String
    let status: String
    let cpu: Double?
    let maxcpu: Int?
    let mem: Int64?
    let maxmem: Int64?
    let disk: Int64?
    let maxdisk: Int64?
    let uptime: Int64?
    let level: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.id = try container.decode(String.self, forKey: .id)
        self.node = try container.decode(String.self, forKey: .node)
        self.type = try container.decode(String.self, forKey: .type)
        self.status = try container.decode(String.self, forKey: .status)

        // Handle potential NaN/infinite values for CPU
        if let cpuValue = try container.decodeIfPresent(Double.self, forKey: .cpu) {
            self.cpu = cpuValue.isFinite ? cpuValue : nil
        } else {
            self.cpu = nil
        }

        self.maxcpu = try container.decodeIfPresent(Int.self, forKey: .maxcpu)
        self.mem = try container.decodeIfPresent(Int64.self, forKey: .mem)
        self.maxmem = try container.decodeIfPresent(Int64.self, forKey: .maxmem)
        self.disk = try container.decodeIfPresent(Int64.self, forKey: .disk)
        self.maxdisk = try container.decodeIfPresent(Int64.self, forKey: .maxdisk)
        self.uptime = try container.decodeIfPresent(Int64.self, forKey: .uptime)
        self.level = try container.decodeIfPresent(String.self, forKey: .level)
    }

    private enum CodingKeys: String, CodingKey {
        case id, node, type, status, cpu, maxcpu, mem, maxmem, disk, maxdisk, uptime, level
    }
}

struct ProxmoxVMData: Codable, Identifiable {
    let vmid: String
    let name: String?
    let type: String
    let status: String
    let node: String?
    let cpu: Double?
    let cpus: Int?
    let mem: Int64?
    let maxmem: Int64?
    let disk: Int64?
    let maxdisk: Int64?
    let netin: Int64?
    let netout: Int64?
    let uptime: Int64?
    let template: Int?
    let hastate: String?
    let tags: String?

    var id: String { vmid }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle vmid as either String or Number
        if let vmidString = try? container.decode(String.self, forKey: .vmid) {
            self.vmid = vmidString
        } else if let vmidInt = try? container.decode(Int.self, forKey: .vmid) {
            self.vmid = String(vmidInt)
        } else {
            self.vmid = "0"
        }

        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
        self.status = try container.decode(String.self, forKey: .status)
        self.node = try container.decodeIfPresent(String.self, forKey: .node)

        // Handle potential NaN/infinite values for CPU
        if let cpuValue = try container.decodeIfPresent(Double.self, forKey: .cpu) {
            self.cpu = cpuValue.isFinite ? cpuValue : nil
        } else {
            self.cpu = nil
        }

        self.cpus = try container.decodeIfPresent(Int.self, forKey: .cpus)
        self.mem = try container.decodeIfPresent(Int64.self, forKey: .mem)
        self.maxmem = try container.decodeIfPresent(Int64.self, forKey: .maxmem)
        self.disk = try container.decodeIfPresent(Int64.self, forKey: .disk)
        self.maxdisk = try container.decodeIfPresent(Int64.self, forKey: .maxdisk)
        self.netin = try container.decodeIfPresent(Int64.self, forKey: .netin)
        self.netout = try container.decodeIfPresent(Int64.self, forKey: .netout)
        self.uptime = try container.decodeIfPresent(Int64.self, forKey: .uptime)
        self.template = try container.decodeIfPresent(Int.self, forKey: .template)
        self.hastate = try container.decodeIfPresent(String.self, forKey: .hastate)
        self.tags = try container.decodeIfPresent(String.self, forKey: .tags)
    }

    private enum CodingKeys: String, CodingKey {
        case vmid, name, type, status, node, cpu, cpus, mem, maxmem, disk, maxdisk, netin, netout, uptime, template, hastate, tags
    }
}

struct ProxmoxStorageData: Codable, Identifiable {
    let storage: String
    let type: String
    let node: String?
    let content: String?
    let enabled: Int?
    let used: Int64?
    let total: Int64?
    let avail: Int64?
    let shared: Int?

    var id: String { storage }
}

struct ProxmoxVMDetails: Codable {
    // VM-specific fields
    let bootdisk: String?
    let cores: Int?
    let memory: Int64?
    let sockets: Int?
    let vcpus: Int?

    // Container-specific fields
    let arch: String?
    let cpuunits: Int?
    let hostname: String?
    let swap: Int64?
    let rootfs: String?
    let mem: Int64?
    let cpus: Int?

    // Common fields
    let name: String?
    let onboot: Int?
    let ostype: String?

    // Use a lenient decoder that ignores unknown fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        // VM fields
        bootdisk = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "bootdisk")!)
        cores = try? container.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "cores")!)
        memory = try? container.decodeIfPresent(Int64.self, forKey: DynamicCodingKeys(stringValue: "memory")!)
        sockets = try? container.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "sockets")!)
        vcpus = try? container.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "vcpus")!)

        // Container fields
        arch = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "arch")!)
        cpuunits = try? container.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "cpuunits")!)
        hostname = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "hostname")!)
        swap = try? container.decodeIfPresent(Int64.self, forKey: DynamicCodingKeys(stringValue: "swap")!)
        rootfs = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "rootfs")!)
        mem = try? container.decodeIfPresent(Int64.self, forKey: DynamicCodingKeys(stringValue: "mem")!)
        cpus = try? container.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "cpus")!)

        // Common fields
        name = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "name")!)
        onboot = try? container.decodeIfPresent(Int.self, forKey: DynamicCodingKeys(stringValue: "onboot")!)
        ostype = try? container.decodeIfPresent(String.self, forKey: DynamicCodingKeys(stringValue: "ostype")!)
    }
}

// Dynamic coding keys to handle unknown fields gracefully
struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = String(intValue)
    }
}

struct ProxmoxBackupData: Codable, Identifiable {
    let vmid: String
    let type: String
    let volid: String
    let size: Int64?
    let ctime: Int64?
    let vmtype: String?

    var id: String { volid }
}

struct ProxmoxNetworkInterface: Codable, Identifiable {
    let iface: String
    let type: String
    let active: Int?
    let address: String?
    let gateway: String?
    let netmask: String?
    let bridge_ports: String?

    var id: String { iface }
}

enum VMType: String, Codable {
    case vm = "qemu"
    case container = "lxc"
}

enum VMAction: String, CaseIterable {
    case start = "start"
    case stop = "stop"
    case shutdown = "shutdown"
    case reboot = "reboot"
    case suspend = "suspend"
    case resume = "resume"
}
