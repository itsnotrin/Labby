//
//  JellyfinClient.swift
//  Labby
//
//  Created by Ryan Wiecz on 08/08/2025.
//

import Foundation

final class JellyfinClient: ServiceClient {
    let config: ServiceConfig
    private var cachedUserId: String?
    private var cachedAuthToken: String?
    private var authTokenTimestamp: Date?
    private let tokenExpiryDuration: TimeInterval = 3600 // 1 hour

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

    // Stable device id for Jellyfin "MediaBrowser" header
    private static let deviceIdKey = "JellyfinClient.deviceId"
    private static func stableDeviceId() -> String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: deviceIdKey) {
            return existing
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: deviceIdKey)
        return newId
    }

    init(config: ServiceConfig) {
        self.config = config
    }

    func testConnection() async throws -> String {
        print("[JellyfinClient] Starting authentication...")
        let authToken = try await authenticate()
        print("[JellyfinClient] Authentication successful, token: \(authToken.prefix(10))...")

        let url = try config.url(appending: "/System/Info")
        print("[JellyfinClient] Testing connection to: \(url)")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
            print("[JellyfinClient] System/Info response: \(http.statusCode)")
            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct Info: Codable {
                let ProductName: String?
                let Version: String?
                let OperatingSystem: String?
            }
            let decoded = try JSONDecoder().decode(Info.self, from: data)
            let name = decoded.ProductName ?? "Jellyfin"
            let version = decoded.Version ?? "?"
            return "\(name) version: \(version)"
        } catch let error as ServiceError {
            print("[JellyfinClient] ServiceError in testConnection: \(error)")
            throw error
        } catch {
            print("[JellyfinClient] Network error in testConnection: \(error)")
            throw ServiceError.network(error)
        }
    }

    private func authenticate() async throws -> String {
        // Check if we have a cached token that's still valid
        if let cachedToken = cachedAuthToken,
           let timestamp = authTokenTimestamp,
           Date().timeIntervalSince(timestamp) < tokenExpiryDuration {
            print("[JellyfinClient] Using cached auth token")
            return cachedToken
        }

        // Clear any stale cached data
        print("[JellyfinClient] Starting fresh authentication, clearing cached data")
        cachedAuthToken = nil
        authTokenTimestamp = nil
        cachedUserId = nil

        // API token path: read and return without network round-trip
        if case .apiToken(let secretKey) = config.auth {
            print("[JellyfinClient] Using API token authentication")
            guard let tokenData = KeychainStorage.shared.loadSecret(forKey: secretKey),
                let token = String(data: tokenData, encoding: .utf8)
            else {
                print("[JellyfinClient] API token not found in keychain")
                throw ServiceError.missingSecret
            }

            // Cache the API token
            cachedAuthToken = token
            authTokenTimestamp = Date()
            return token
        }

        // Username/password flow: POST to /Users/AuthenticateByName
        print("[JellyfinClient] Using username/password authentication")
        let url = try config.url(appending: "/Users/AuthenticateByName")
        print("[JellyfinClient] Auth URL: \(url)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let deviceId = Self.stableDeviceId()
        let authHeader =
            "MediaBrowser Client=\"Labby\", Device=\"iOS\", DeviceId=\"\(deviceId)\", Version=\"0.0.1\""
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        switch config.auth {
        case .usernamePassword(let username, let passwordKey):
            print("[JellyfinClient] Authenticating user: \(username)")
            guard let passData = KeychainStorage.shared.loadSecret(forKey: passwordKey),
                let password = String(data: passData, encoding: .utf8)
            else {
                print("[JellyfinClient] Password not found in keychain")
                throw ServiceError.missingSecret
            }

            let authBody: [String: Any] = [
                "Username": username,
                "Pw": password,
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: authBody)

            let (data, response) = try await session.data(for: request)

            guard let http = response as? HTTPURLResponse else {
                print("[JellyfinClient] Invalid response type")
                throw ServiceError.unknown
            }

            print("[JellyfinClient] Auth response status: \(http.statusCode)")
            guard 200..<300 ~= http.statusCode else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[JellyfinClient] Auth error response: \(responseString)")
                }
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct AuthResponse: Codable {
                let AccessToken: String?
                let User: UserInfo?
            }
            struct UserInfo: Codable {
                let Id: String?
                let Name: String?
            }

            let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
            guard let accessToken = authResponse.AccessToken else {
                print("[JellyfinClient] No access token in auth response")
                throw ServiceError.unknown
            }

            // Cache the user ID from the auth response
            if let user = authResponse.User, let userId = user.Id {
                cachedUserId = userId
                print("[JellyfinClient] Cached user ID: \(userId)")
            }

            print("[JellyfinClient] Authentication successful for user: \(authResponse.User?.Name ?? "unknown")")

            // Cache the access token
            cachedAuthToken = accessToken
            authTokenTimestamp = Date()

            return accessToken

        default:
            print("[JellyfinClient] Unsupported auth method")
            throw ServiceError.unknown
        }
    }

    func fetchStats() async throws -> ServiceStatsPayload {
        let authToken = try await authenticate()

        // Fetch item counts
        let countsUrl = try config.url(appending: "/Items/Counts")
        var countsRequest = URLRequest(url: countsUrl)
        countsRequest.httpMethod = "GET"
        countsRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        countsRequest.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        // Fetch user count
        let usersUrl = try config.url(appending: "/Users")
        var usersRequest = URLRequest(url: usersUrl)
        usersRequest.httpMethod = "GET"
        usersRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        usersRequest.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            // Fetch both counts and users concurrently
            let countsResponseTask = Task { try await session.data(for: countsRequest) }
            let usersResponseTask = Task { try await session.data(for: usersRequest) }

            let (countsData, countsHTTPResponse) = try await countsResponseTask.value
            let (usersData, usersHTTPResponse) = try await usersResponseTask.value

            // Validate counts response
            guard let countsHttp = countsHTTPResponse as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= countsHttp.statusCode else {
                throw ServiceError.httpStatus(countsHttp.statusCode)
            }

            // Validate users response
            guard let usersHttp = usersHTTPResponse as? HTTPURLResponse else { throw ServiceError.unknown }
            guard 200..<300 ~= usersHttp.statusCode else {
                throw ServiceError.httpStatus(usersHttp.statusCode)
            }

            // Parse counts
            struct Counts: Codable {
                let MovieCount: Int?
                let SeriesCount: Int?
            }
            let countsDecoded = try JSONDecoder().decode(Counts.self, from: countsData)
            let movies = countsDecoded.MovieCount ?? 0
            let tvShows = countsDecoded.SeriesCount ?? 0

            // Parse users (array of user objects)
            struct User: Codable {
                let Id: String?
                let Name: String?
            }
            let usersDecoded = try JSONDecoder().decode([User].self, from: usersData)
            let userCount = usersDecoded.count

            return .jellyfin(JellyfinStats(tvShows: tvShows, movies: movies, users: userCount))
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    func fetchLibraries() async throws -> [JellyfinLibrary] {
        let authToken = try await authenticate()
        let userId = try await getCurrentUserId(authToken: authToken)

        let url = try config.url(appending: "/Users/\(userId)/Views")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        print("[JellyfinClient] Libraries (Views) request URL: \(url)")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }

            print("[JellyfinClient] Libraries (Views) response status: \(http.statusCode)")

            if http.statusCode == 401 {
                print("[JellyfinClient] 401 in fetchLibraries, clearing cached token and retrying")
                cachedAuthToken = nil
                authTokenTimestamp = nil
                let freshToken = try await authenticate()
                let freshUserId = try await getCurrentUserId(authToken: freshToken)
                return try await fetchLibrariesWithToken(freshToken, userId: freshUserId)
            }

            guard 200..<300 ~= http.statusCode else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[JellyfinClient] Libraries error response: \(responseString.prefix(300))")
                }
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct ViewsResponse: Codable { let Items: [JellyfinLibrary] }
            let decoded = try JSONDecoder().decode(ViewsResponse.self, from: data)
            print("[JellyfinClient] Successfully decoded \(decoded.Items.count) libraries (views)")
            return decoded.Items
        } catch let error as ServiceError {
            throw error
        } catch {
            print("[JellyfinClient] Network error in fetchLibraries (Views): \(error)")
            throw ServiceError.network(error)
        }
    }

    private func fetchLibrariesWithToken(_ authToken: String, userId: String) async throws -> [JellyfinLibrary] {
        let url = try config.url(appending: "/Users/\(userId)/Views")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
        guard 200..<300 ~= http.statusCode else {
            throw ServiceError.httpStatus(http.statusCode)
        }

        struct ViewsResponse: Codable { let Items: [JellyfinLibrary] }
        let decoded = try JSONDecoder().decode(ViewsResponse.self, from: data)
        return decoded.Items
    }

    func fetchLibraryItemCount(libraryId: String) async throws -> Int {
        let authToken = try await authenticate()
        let userId = try await getCurrentUserId(authToken: authToken)

        // Use the same endpoint as fetchLibraryItems but only get the count
        let url = try config.url(appending: "/Users/\(userId)/Items", queryItems: [
            URLQueryItem(name: "ParentId", value: libraryId),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series"),
            URLQueryItem(name: "Recursive", value: "false"),
            URLQueryItem(name: "Limit", value: "0"), // Limit=0 returns only count metadata
            URLQueryItem(name: "Fields", value: "")  // Don't need any fields
        ])

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }

            if http.statusCode == 401 {
                print("[JellyfinClient] 401 in fetchLibraryItemCount, clearing cached token and retrying")
                cachedAuthToken = nil
                authTokenTimestamp = nil
                let freshToken = try await authenticate()
                return try await fetchLibraryItemCountWithToken(freshToken, userId: userId, libraryId: libraryId)
            }

            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct CountResponse: Codable {
                let Items: [JellyfinItem]
                let TotalRecordCount: Int?
            }
            let decoded = try JSONDecoder().decode(CountResponse.self, from: data)

            // Use TotalRecordCount if available, otherwise fall back to 0
            if let totalCount = decoded.TotalRecordCount {
                return totalCount
            } else {
                // With Limit=0, Items should be empty but TotalRecordCount should be accurate
                print("[JellyfinClient] Warning: TotalRecordCount not available for library \(libraryId)")
                return 0
            }
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    private func fetchLibraryItemCountWithToken(_ authToken: String, userId: String, libraryId: String) async throws -> Int {
        let url = try config.url(appending: "/Users/\(userId)/Items", queryItems: [
            URLQueryItem(name: "ParentId", value: libraryId),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series"),
            URLQueryItem(name: "Recursive", value: "false"),
            URLQueryItem(name: "Limit", value: "0"),
            URLQueryItem(name: "Fields", value: "")
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
        guard 200..<300 ~= http.statusCode else {
            throw ServiceError.httpStatus(http.statusCode)
        }

        struct CountResponse: Codable {
            let Items: [JellyfinItem]
            let TotalRecordCount: Int?
        }
        let decoded = try JSONDecoder().decode(CountResponse.self, from: data)

        if let totalCount = decoded.TotalRecordCount {
            return totalCount
        } else {
            // With Limit=0, Items should be empty but TotalRecordCount should be accurate
            print("[JellyfinClient] Warning: TotalRecordCount not available for library \(libraryId)")
            return 0
        }
    }

    func fetchLibraryItems(libraryId: String) async throws -> [JellyfinItem] {
        let authToken = try await authenticate()
        let userId = try await getCurrentUserId(authToken: authToken)

        // Prefer user-scoped endpoint for library contents
        let path = "/Users/\(userId)/Items"
        // Request only top-level Movies and Series for the library to avoid returning Seasons/Episodes here.
        let url = try config.url(appending: path, queryItems: [
            URLQueryItem(name: "ParentId", value: libraryId),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series"),
            URLQueryItem(name: "Recursive", value: "false"),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(name: "Fields", value: "Overview,Genres,People,MediaStreams,Studios,UserData")
        ])

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        print("[JellyfinClient] Library items (user-scoped) URL: \(url)")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }

            if http.statusCode == 401 {
                print("[JellyfinClient] 401 in fetchLibraryItems, clearing cached token and retrying")
                cachedAuthToken = nil
                authTokenTimestamp = nil
                let freshToken = try await authenticate()
                return try await fetchLibraryItemsWithToken(freshToken, userId: userId, libraryId: libraryId)
            }

            guard 200..<300 ~= http.statusCode else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[JellyfinClient] Library items error: \(responseString.prefix(300))")
                }
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct ItemsResponse: Codable { let Items: [JellyfinItem] }
            let decoded = try JSONDecoder().decode(ItemsResponse.self, from: data)

            // Filter to only top-level Series and Movie items to avoid mixing seasons/episodes
            let topLevel = decoded.Items.filter { $0.type == "Series" || $0.type == "Movie" }
            print("[JellyfinClient] Loaded \(decoded.Items.count) raw items, filtered to \(topLevel.count) top-level Series/Movie items for library \(libraryId)")
            return topLevel
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    private func fetchLibraryItemsWithToken(_ authToken: String, userId: String, libraryId: String) async throws -> [JellyfinItem] {
        // Prefer a non-recursive user-scoped Items query that returns only Movies and Series
        let url = try config.url(appending: "/Users/\(userId)/Items", queryItems: [
            URLQueryItem(name: "ParentId", value: libraryId),
            URLQueryItem(name: "IncludeItemTypes", value: "Movie,Series"),
            URLQueryItem(name: "Recursive", value: "false"),
            URLQueryItem(name: "SortBy", value: "SortName"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(name: "Fields", value: "Overview,Genres,People,MediaStreams,Studios,UserData")
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
        guard 200..<300 ~= http.statusCode else {
            if let responseString = String(data: data, encoding: .utf8) {
                print("[JellyfinClient] fetchLibraryItemsWithToken error response: \(responseString.prefix(300))")
            }
            throw ServiceError.httpStatus(http.statusCode)
        }

        struct ItemsResponse: Codable { let Items: [JellyfinItem] }
        let decoded = try JSONDecoder().decode(ItemsResponse.self, from: data)

        // Return only top-level Series and Movie items
        let topLevel = decoded.Items.filter { $0.type == "Series" || $0.type == "Movie" }
        print("[JellyfinClient] fetchLibraryItemsWithToken: raw \(decoded.Items.count) items -> \(topLevel.count) top-level Series/Movie items for library \(libraryId)")
        return topLevel
    }

    func fetchItemDetails(itemId: String) async throws -> JellyfinItem {
        let authToken = try await authenticate()
        let userId = try await getCurrentUserId(authToken: authToken)

        let url = try config.url(appending: "/Users/\(userId)/Items/\(itemId)?Fields=Overview,Genres,People,MediaStreams,Studios,UserData")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }

            if http.statusCode == 401 {
                print("[JellyfinClient] 401 error in fetchItemDetails, clearing cached token")
                cachedAuthToken = nil
                authTokenTimestamp = nil
                let freshToken = try await authenticate()
                return try await fetchItemDetailsWithToken(freshToken, itemId: itemId)
            }

            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            let decoded = try JSONDecoder().decode(JellyfinItem.self, from: data)
            return decoded
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    private func fetchItemDetailsWithToken(_ authToken: String, itemId: String) async throws -> JellyfinItem {
        let userId = try await getCurrentUserId(authToken: authToken)

        let url = try config.url(appending: "/Users/\(userId)/Items/\(itemId)?Fields=Overview,Genres,People,MediaStreams,Studios,UserData")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
        guard 200..<300 ~= http.statusCode else {
            throw ServiceError.httpStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode(JellyfinItem.self, from: data)
        return decoded
    }

    func fetchEpisodes(seasonId: String) async throws -> [JellyfinItem] {
        // Robust episode fetch that tries several endpoint shapes and uses queryItems
        // to avoid percent-encoding issues. Returns Episode items only. Falls back to
        // tokenized retry on 401.
        let authToken = try await authenticate()
        let userId = try await getCurrentUserId(authToken: authToken)

        // If the seasonId looks synthetic and embeds a series id, try to extract it to fetch by SeriesId
        var potentialSeriesId: String? = nil
        if seasonId.hasPrefix("synthetic-season-") {
            // synthetic-season-{seriesId}-{seasonIndex}-{hash} or series-{seriesId}-season-{index}
            let parts = seasonId.components(separatedBy: "-")
            if parts.count > 2 {
                // pick the part that looks like a long hex id (best-effort)
                if let found = parts.first(where: { $0.count >= 8 && $0.range(of: #"^[0-9a-fA-F]+"#, options: .regularExpression) != nil }) {
                    potentialSeriesId = found
                } else if parts.count >= 3 {
                    potentialSeriesId = parts[1]
                }
            }
        }

        // Attempt variants expressed as (basePath, queryItems) to construct proper URLs
        var attempts: [(String, [URLQueryItem])] = [
            // user-scoped Items where ParentId is used for seasons
            ("/Users/\(userId)/Items", [
                URLQueryItem(name: "ParentId", value: seasonId),
                URLQueryItem(name: "IncludeItemTypes", value: "Episode"),
                URLQueryItem(name: "Recursive", value: "false"),
                URLQueryItem(name: "SortBy", value: "IndexNumber"),
                URLQueryItem(name: "SortOrder", value: "Ascending"),
                URLQueryItem(name: "Fields", value: "Overview,MediaStreams,UserData,IndexNumber,RunTimeTicks,PremiereDate,ParentId,ParentIndexNumber,SeasonName")
            ]),
            // Shows-specific endpoint
            ("/Shows/\(seasonId)/Episodes", [
                URLQueryItem(name: "UserId", value: userId),
                URLQueryItem(name: "Fields", value: "Overview,MediaStreams,UserData,IndexNumber,RunTimeTicks,PremiereDate,ParentId,ParentIndexNumber,SeasonName")
            ]),
            // Generic Items endpoint using ParentId
            ("/Items", [
                URLQueryItem(name: "ParentId", value: seasonId),
                URLQueryItem(name: "IncludeItemTypes", value: "Episode"),
                URLQueryItem(name: "Recursive", value: "false"),
                URLQueryItem(name: "SortBy", value: "IndexNumber"),
                URLQueryItem(name: "SortOrder", value: "Ascending"),
                URLQueryItem(name: "Fields", value: "Overview,MediaStreams,UserData,IndexNumber,RunTimeTicks,PremiereDate,ParentId,ParentIndexNumber,SeasonName")
            ])
        ]

        // If we could guess a series id from a synthetic season, also try fetching episodes by SeriesId (recursive)
        if let seriesGuess = potentialSeriesId {
            attempts.insert(("/Items", [
                URLQueryItem(name: "SeriesId", value: seriesGuess),
                URLQueryItem(name: "IncludeItemTypes", value: "Episode"),
                URLQueryItem(name: "Recursive", value: "true"),
                URLQueryItem(name: "SortBy", value: "ParentIndexNumber,IndexNumber"),
                URLQueryItem(name: "SortOrder", value: "Ascending"),
                URLQueryItem(name: "Fields", value: "Overview,MediaStreams,UserData,IndexNumber,RunTimeTicks,PremiereDate,ParentId,ParentIndexNumber,SeasonName")
            ]), at: 0)
        }

        var lastHttpStatus: Int? = nil
        let decoder = JSONDecoder()
        struct ItemsWrapper: Codable { let Items: [JellyfinItem] }

        for (path, queryItems) in attempts {
            do {
                let url = try config.url(appending: path, queryItems: queryItems)
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

                print("[JellyfinClient] fetchEpisodes: attempting \(url)")
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }

                lastHttpStatus = http.statusCode
                print("[JellyfinClient] fetchEpisodes response status: \(http.statusCode) for \(url)")

                if http.statusCode == 401 {
                    print("[JellyfinClient] 401 in fetchEpisodes, clearing cached token and retrying with fresh token")
                    cachedAuthToken = nil
                    authTokenTimestamp = nil
                    let freshToken = try await authenticate()
                    return try await fetchEpisodesWithToken(freshToken, seasonId: seasonId)
                }

                if http.statusCode == 404 {
                    if let resp = String(data: data, encoding: .utf8), !resp.isEmpty {
                        print("[JellyfinClient] 404 from \(url): \(resp.prefix(300))")
                    } else {
                        print("[JellyfinClient] 404 from \(url) (no body)")
                    }
                    continue
                }

                guard 200..<300 ~= http.statusCode else {
                    if let resp = String(data: data, encoding: .utf8) {
                        print("[JellyfinClient] Unexpected status \(http.statusCode) from \(url): \(resp.prefix(500))")
                    } else {
                        print("[JellyfinClient] Unexpected status \(http.statusCode) from \(url) (no body)")
                    }
                    throw ServiceError.httpStatus(http.statusCode)
                }

                // Decode either wrapped { Items: [...] } or raw array [ ... ]
                var decodedItems: [JellyfinItem] = []
                if let wrapper = try? decoder.decode(ItemsWrapper.self, from: data) {
                    decodedItems = wrapper.Items
                } else if let arr = try? decoder.decode([JellyfinItem].self, from: data) {
                    decodedItems = arr
                } else {
                    if let resp = String(data: data, encoding: .utf8) {
                        print("[JellyfinClient] Unknown episodes response shape from \(url): \(resp.prefix(500))")
                    }
                    // try next attempt
                    continue
                }

                // Return only Episode items
                let episodes = decodedItems.filter { $0.type == "Episode" }
                print("[JellyfinClient] Successfully loaded \(episodes.count) episodes for season \(seasonId) from \(url)")
                return episodes
            } catch let err as ServiceError {
                if case .httpStatus(401) = err {
                    // Propagate 401 so higher-level logic can re-authenticate if needed
                    throw err
                }
                print("[JellyfinClient] ServiceError when attempting episodes path \(path): \(err)")
                continue
            } catch {
                print("[JellyfinClient] Network/decoding error when attempting episodes path \(path): \(error)")
                continue
            }
        }

        // If none of the attempts succeeded, return a meaningful error
        if let status = lastHttpStatus {
            print("[JellyfinClient] All fetchEpisodes attempts failed. Last HTTP status: \(status)")
            throw ServiceError.httpStatus(status)
        } else {
            print("[JellyfinClient] All fetchEpisodes attempts failed (no HTTP status available)")
            throw ServiceError.unknown
        }
    }

    private func fetchSeasonsWithToken(_ authToken: String, seriesId: String) async throws -> [JellyfinItem] {
        // Try several endpoints/patterns to accommodate Jellyfin server differences.
        // Some servers expose /Shows/{id}/Seasons, some expect Items with SeriesId,
        // and a few require ParentId to be used. We attempt in order and return on first success.
        let userId = try await getCurrentUserId(authToken: authToken)

        // Attempt variants expressed as (basePath, optional query items) so query parameters are passed
        // through the URL builder rather than embedded in the path (avoids percent-encoding of '?').
        let attemptVariants: [(String, [URLQueryItem]?)] = [
            ("/Users/\(userId)/Items", [
                URLQueryItem(name: "SeriesId", value: seriesId),
                URLQueryItem(name: "IncludeItemTypes", value: "Season"),
                URLQueryItem(name: "Recursive", value: "false"),
                URLQueryItem(name: "SortBy", value: "IndexNumber"),
                URLQueryItem(name: "SortOrder", value: "Ascending"),
                URLQueryItem(name: "Fields", value: "Overview,UserData,ChildCount,Name,IndexNumber")
            ]),
            ("/Users/\(userId)/Items", [
                URLQueryItem(name: "ParentId", value: seriesId),
                URLQueryItem(name: "IncludeItemTypes", value: "Season"),
                URLQueryItem(name: "Recursive", value: "false"),
                URLQueryItem(name: "SortBy", value: "IndexNumber"),
                URLQueryItem(name: "SortOrder", value: "Ascending"),
                URLQueryItem(name: "Fields", value: "Overview,UserData,ChildCount,Name,IndexNumber")
            ]),
            ("/Shows/\(seriesId)/Seasons", [
                URLQueryItem(name: "UserId", value: userId),
                URLQueryItem(name: "Fields", value: "Overview,UserData,ChildCount,Name,IndexNumber")
            ]),
            ("/Shows/\(seriesId)/Seasons", [
                URLQueryItem(name: "Fields", value: "Overview,UserData,ChildCount,Name,IndexNumber")
            ]),
            ("/Items", [
                URLQueryItem(name: "SeriesId", value: seriesId),
                URLQueryItem(name: "IncludeItemTypes", value: "Season"),
                URLQueryItem(name: "Recursive", value: "false"),
                URLQueryItem(name: "SortBy", value: "IndexNumber"),
                URLQueryItem(name: "SortOrder", value: "Ascending"),
                URLQueryItem(name: "Fields", value: "Overview,UserData,ChildCount,Name,IndexNumber")
            ]),
            ("/Items", [
                URLQueryItem(name: "ParentId", value: seriesId),
                URLQueryItem(name: "IncludeItemTypes", value: "Season"),
                URLQueryItem(name: "Recursive", value: "false"),
                URLQueryItem(name: "SortBy", value: "IndexNumber"),
                URLQueryItem(name: "SortOrder", value: "Ascending"),
                URLQueryItem(name: "Fields", value: "Overview,UserData,ChildCount,Name,IndexNumber")
            ])
        ]

        var lastHttpStatus: Int? = nil

        for (path, queryItems) in attemptVariants {
            do {
                let url = try config.url(appending: path, queryItems: queryItems)
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

                print("[JellyfinClient] fetchSeasonsWithToken: attempting \(url)")
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }

                lastHttpStatus = http.statusCode
                // If unauthorized, bubble up an HTTP 401 so the caller can clear cached token and retry.
                if http.statusCode == 401 {
                    print("[JellyfinClient] 401 from \(url) while fetching seasons")
                    throw ServiceError.httpStatus(401)
                }

                // If not found, try next fallback
                if http.statusCode == 404 {
                    if let resp = String(data: data, encoding: .utf8) {
                        print("[JellyfinClient] 404 from \(url): \(resp.prefix(300))")
                    } else {
                        print("[JellyfinClient] 404 from \(url) (no body)")
                    }
                    continue
                }

                guard 200..<300 ~= http.statusCode else {
                    if let resp = String(data: data, encoding: .utf8) {
                        print("[JellyfinClient] Unexpected status \(http.statusCode) from \(url): \(resp.prefix(500))")
                    } else {
                        print("[JellyfinClient] Unexpected status \(http.statusCode) from \(url) (no body)")
                    }
                    throw ServiceError.httpStatus(http.statusCode)
                }

                // Defensive decoding: server may return { \"Items\": [...] }, [ ... ], or { \"Seasons\": [...] }.
                var decodedItems: [JellyfinItem] = []
                struct ItemsWrapper: Codable { let Items: [JellyfinItem] }
                struct SeasonsWrapper: Codable { let Seasons: [JellyfinItem] }
                let decoder = JSONDecoder()

                if let wrapper = try? decoder.decode(ItemsWrapper.self, from: data) {
                    decodedItems = wrapper.Items
                    print("[JellyfinClient] Decoded Items wrapper with \(decodedItems.count) items from \(url)")
                } else if let arr = try? decoder.decode([JellyfinItem].self, from: data) {
                    decodedItems = arr
                    print("[JellyfinClient] Decoded raw array with \(decodedItems.count) items from \(url)")
                } else if let seasonsWrap = try? decoder.decode(SeasonsWrapper.self, from: data) {
                    decodedItems = seasonsWrap.Seasons
                    print("[JellyfinClient] Decoded Seasons wrapper with \(decodedItems.count) items from \(url)")
                } else {
                    if let resp = String(data: data, encoding: .utf8) {
                        print("[JellyfinClient] Unknown seasons response shape from \(url): \(resp.prefix(500))")
                    } else {
                        print("[JellyfinClient] Unknown seasons response shape from \(url) (no body)")
                    }
                    // Fall through to try next attempt rather than failing outright.
                    continue
                }

                // Filter to season items and return on success
                let seasons = decodedItems.filter { $0.type == "Season" }
                print("[JellyfinClient] fetchSeasonsWithToken: returning \(seasons.count) seasons from \(url) (filtered from \(decodedItems.count) items)")
                return seasons
            } catch let err as ServiceError {
                // If it's an HTTP 401, propagate so caller can re-authenticate and call fetchSeasonsWithToken again.
                if case .httpStatus(401) = err {
                    throw err
                }
                // Otherwise, log and try next attempt.
                print("[JellyfinClient] ServiceError when attempting path \(path): \(err)")
                continue
            } catch {
                print("[JellyfinClient] Network/decoding error when attempting path \(path): \(error)")
                continue
            }
        }

        // If we reached here, none of the attempts succeeded.
        if let status = lastHttpStatus {
            print("[JellyfinClient] All fetchSeasonsWithToken attempts failed. Last HTTP status: \(status)")
            throw ServiceError.httpStatus(status)
        } else {
            print("[JellyfinClient] All fetchSeasonsWithToken attempts failed (no HTTP status available)")
            throw ServiceError.unknown
        }
    }

    func fetchSeasons(seriesId: String) async throws -> [JellyfinItem] {
        // Use the Items endpoint to fetch seasons belonging to the given series.
        // This avoids inconsistent behavior from specialized endpoints that may return episodes or mislabel items.
        let authToken = try await authenticate()
        _ = try await getCurrentUserId(authToken: authToken)

        // Query Items with the SeriesId filter and request only Season item types, non-recursive.
        let url = try config.url(appending: "/Items", queryItems: [
            URLQueryItem(name: "SeriesId", value: seriesId),
            URLQueryItem(name: "IncludeItemTypes", value: "Season"),
            URLQueryItem(name: "Recursive", value: "false"),
            URLQueryItem(name: "SortBy", value: "IndexNumber"),
            URLQueryItem(name: "SortOrder", value: "Ascending"),
            URLQueryItem(name: "Fields", value: "Overview,UserData,ChildCount,Name,IndexNumber")
        ])
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        print("[JellyfinClient] Fetching seasons via Items endpoint: \(url)")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }

            print("[JellyfinClient] Fetch seasons response status: \(http.statusCode)")
            if http.statusCode == 401 {
                print("[JellyfinClient] 401 error in fetchSeasons, clearing cached token and retrying via tokenized fallback")
                cachedAuthToken = nil
                authTokenTimestamp = nil
                let freshToken = try await authenticate()
                return try await fetchSeasonsWithToken(freshToken, seriesId: seriesId)
            }

            // If Items endpoint returns 404, fall back to the Shows-specific endpoint which some servers require
            if http.statusCode == 404 {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[JellyfinClient] Fetch seasons 404 response: \(responseString.prefix(500))")
                }
                print("[JellyfinClient] Items endpoint returned 404 for series \(seriesId); falling back to /Shows/.../Seasons endpoint")
                // Try the tokenized Shows/.../Seasons endpoint
                return try await fetchSeasonsWithToken(authToken, seriesId: seriesId)
            }

            guard 200..<300 ~= http.statusCode else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[JellyfinClient] Fetch seasons error response: \(responseString.prefix(500))")
                }
                throw ServiceError.httpStatus(http.statusCode)
            }

            // Defensive decoding: server may return { "Items": [...] } or a raw array.
            var decodedItems: [JellyfinItem] = []
            struct ItemsWrapper: Codable { let Items: [JellyfinItem] }

            let decoder = JSONDecoder()
            if let wrapper = try? decoder.decode(ItemsWrapper.self, from: data) {
                decodedItems = wrapper.Items
                print("[JellyfinClient] Decoded Items wrapper with \(decodedItems.count) items for series \(seriesId)")
            } else if let arr = try? decoder.decode([JellyfinItem].self, from: data) {
                decodedItems = arr
                print("[JellyfinClient] Decoded raw array with \(decodedItems.count) items for series \(seriesId)")
            } else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[JellyfinClient] Unknown fetchSeasons response shape: \(responseString.prefix(500))")
                }
                throw ServiceError.unknown
            }

            // Ensure items are seasons
            var seasons = decodedItems.filter { $0.type == "Season" }
            print("[JellyfinClient] Successfully loaded \(seasons.count) seasons for series \(seriesId) (filtered from \(decodedItems.count) items)")

            // If the server returned items but none of them are Season (some servers return Episode rows),
            // try to synthesize seasons by fetching Episodes for the series and grouping by ParentId/ParentIndexNumber.
            if seasons.isEmpty {
                print("[JellyfinClient] No explicit Season items returned; attempting to synthesize seasons from Episodes for series \(seriesId)")

                // Fetch episodes for the series (recursive), then group them into seasons.
                let episodesURL = try config.url(appending: "/Items", queryItems: [
                    URLQueryItem(name: "SeriesId", value: seriesId),
                    URLQueryItem(name: "IncludeItemTypes", value: "Episode"),
                    URLQueryItem(name: "Recursive", value: "true"),
                    URLQueryItem(name: "SortBy", value: "ParentIndexNumber,IndexNumber"),
                    URLQueryItem(name: "SortOrder", value: "Ascending"),
                    URLQueryItem(name: "Fields", value: "Overview,UserData,ParentIndexNumber,IndexNumber,SeasonName,ParentId")
                ])
                var episodesRequest = URLRequest(url: episodesURL)
                episodesRequest.httpMethod = "GET"
                episodesRequest.setValue("application/json", forHTTPHeaderField: "Accept")
                episodesRequest.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

                print("[JellyfinClient] Fetching episodes to synthesize seasons: \(episodesURL)")
                do {
                    let (epData, epResponse) = try await session.data(for: episodesRequest)
                    guard let epHttp = epResponse as? HTTPURLResponse else { throw ServiceError.unknown }

                    if epHttp.statusCode == 401 {
                        print("[JellyfinClient] 401 when fetching episodes for synthesize; clearing token and retrying")
                        cachedAuthToken = nil
                        authTokenTimestamp = nil
                        let freshToken = try await authenticate()
                        // try once more with fresh token
                        episodesRequest.setValue(freshToken, forHTTPHeaderField: "X-Emby-Token")
                        let (epData2, epResponse2) = try await session.data(for: episodesRequest)
                        guard let epHttp2 = epResponse2 as? HTTPURLResponse else { throw ServiceError.unknown }
                        guard 200..<300 ~= epHttp2.statusCode else {
                            if let respStr = String(data: epData2, encoding: .utf8) {
                                print("[JellyfinClient] Episode fetch error (after re-auth): \(respStr.prefix(500))")
                            }
                            throw ServiceError.httpStatus(epHttp2.statusCode)
                        }
                        // decode from epData2
                        var epDecodedItems: [JellyfinItem] = []
                        if let wrapper = try? decoder.decode(ItemsWrapper.self, from: epData2) {
                            epDecodedItems = wrapper.Items
                        } else if let arr = try? decoder.decode([JellyfinItem].self, from: epData2) {
                            epDecodedItems = arr
                        }
                        if epDecodedItems.isEmpty {
                            print("[JellyfinClient] No episodes returned when attempting to synthesize seasons (after retry)")
                        } else {
                            // group and synthesize below using epDecodedItems
                            // Filter episodes to only those that belong to the requested series before grouping.
                            // This avoids mixing episodes from other series that might appear in the same response.
                            let epFiltered = epDecodedItems.filter { item in
                                // Prefer explicit seriesId on the item. Also allow items whose parentId equals the seriesId
                                // as a fallback for servers that populate parentId with the series identifier.
                                if let sId = item.seriesId, !sId.isEmpty {
                                    return sId == seriesId
                                }
                                if let pid = item.parentId, !pid.isEmpty {
                                    return pid == seriesId
                                }
                                return false
                            }
                            let grouped = Dictionary(grouping: epFiltered) { (item) -> String in
                                // Group by seriesId (if present) plus ParentId or ParentIndexNumber to avoid cross-series mixing.
                                // Use the seriesId returned by the item if available, otherwise fall back to the seriesId we were asked for.
                                let seriesKey = item.seriesId ?? seriesId
                                if let pid = item.parentId, !pid.isEmpty {
                                    return "\(seriesKey)|parent:\(pid)"
                                }
                                // fallback to parentIndexNumber key if parentId missing
                                return "\(seriesKey)|pidx:\(item.parentIndexNumber ?? -1)"
                            }

                            var syntheticSeasons: [JellyfinItem] = []
                            for (_, eps) in grouped {
                                guard !eps.isEmpty else { continue }
                                let first = eps.first!
                                let seasonIndex = first.parentIndexNumber ?? first.indexNumber ?? 0
                                let seasonName = first.seasonName ?? "Season \(seasonIndex)"
                                let firstSeriesId = first.seriesId ?? seriesId
                                let seasonId = first.parentId ?? "series-\(firstSeriesId)-season-\(seasonIndex)"
                                let childCount = eps.count
                                syntheticSeasons.append(JellyfinItem.syntheticSeason(id: seasonId, name: seasonName, index: seasonIndex, childCount: childCount, seriesId: firstSeriesId))
                            }
                            // Deduplicate synthesized seasons by (index + normalized name) to avoid multiple Season 1s from different groups
                            seasons = JellyfinItem.dedupeSeasons(syntheticSeasons)
                            seasons = seasons.sorted { ($0.indexNumber ?? 0) < ($1.indexNumber ?? 0) }
                            print("[JellyfinClient] Synthesized \(seasons.count) seasons from episodes (after re-auth)")
                            return seasons
                        }
                    } else {
                        guard 200..<300 ~= epHttp.statusCode else {
                            if let respStr = String(data: epData, encoding: .utf8) {
                                print("[JellyfinClient] Episode fetch error: \(respStr.prefix(500))")
                            }
                            throw ServiceError.httpStatus(epHttp.statusCode)
                        }
                        // decode episodes
                        var epDecodedItems: [JellyfinItem] = []
                        if let wrapper = try? decoder.decode(ItemsWrapper.self, from: epData) {
                            epDecodedItems = wrapper.Items
                        } else if let arr = try? decoder.decode([JellyfinItem].self, from: epData) {
                            epDecodedItems = arr
                        }

                        if epDecodedItems.isEmpty {
                            print("[JellyfinClient] No episodes returned when attempting to synthesize seasons")
                        } else {
                            // Filter episodes to only those that belong to the requested series before grouping.
                            let epFiltered = epDecodedItems.filter { item in
                                if let sId = item.seriesId, !sId.isEmpty {
                                    return sId == seriesId
                                }
                                if let pid = item.parentId, !pid.isEmpty {
                                    return pid == seriesId
                                }
                                return false
                            }
                            let grouped = Dictionary(grouping: epFiltered) { (item) -> String in
                                // Group by seriesId (if present) plus ParentId or ParentIndexNumber to avoid cross-series mixing.
                                let seriesKey = item.seriesId ?? seriesId
                                if let pid = item.parentId, !pid.isEmpty {
                                    return "\(seriesKey)|parent:\(pid)"
                                }
                                return "\(seriesKey)|pidx:\(item.parentIndexNumber ?? -1)"
                            }

                            var syntheticSeasons: [JellyfinItem] = []
                            for (_, eps) in grouped {
                                guard !eps.isEmpty else { continue }
                                let first = eps.first!
                                let seasonIndex = first.parentIndexNumber ?? first.indexNumber ?? 0
                                let seasonName = first.seasonName ?? "Season \(seasonIndex)"
                                let firstSeriesId = first.seriesId ?? seriesId
                                let seasonId = first.parentId ?? "series-\(firstSeriesId)-season-\(seasonIndex)"
                                let childCount = eps.count
                                syntheticSeasons.append(JellyfinItem.syntheticSeason(id: seasonId, name: seasonName, index: seasonIndex, childCount: childCount, seriesId: firstSeriesId))
                            }
                            // Deduplicate synthesized seasons by (index + normalized name) to avoid multiple Season 1s for the same series
                            seasons = JellyfinItem.dedupeSeasons(syntheticSeasons)
                            seasons = seasons.sorted { ($0.indexNumber ?? 0) < ($1.indexNumber ?? 0) }
                            print("[JellyfinClient] Synthesized \(seasons.count) seasons from episodes")
                            return seasons
                        }
                    }
                } catch {
                    print("[JellyfinClient] Error fetching episodes to synthesize seasons: \(error)")
                    // Fall through and return empty seasons array below (or propagate)
                }
            }

            return seasons
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    private func fetchEpisodesWithToken(_ authToken: String, seasonId: String) async throws -> [JellyfinItem] {
        // Similar to fetchEpisodes but uses the provided auth token directly and attempts multiple endpoints.
        let userId = try await getCurrentUserId(authToken: authToken)

        // Build attempt variants as (path, queryItems)
        let attemptVariants: [(String, [URLQueryItem])] = [
            ("/Users/\(userId)/Items", [
                URLQueryItem(name: "ParentId", value: seasonId),
                URLQueryItem(name: "IncludeItemTypes", value: "Episode"),
                URLQueryItem(name: "Recursive", value: "false"),
                URLQueryItem(name: "SortBy", value: "IndexNumber"),
                URLQueryItem(name: "SortOrder", value: "Ascending"),
                URLQueryItem(name: "Fields", value: "Overview,MediaStreams,UserData,IndexNumber,RunTimeTicks,PremiereDate,ParentId,ParentIndexNumber,SeasonName")
            ]),
            ("/Shows/\(seasonId)/Episodes", [
                URLQueryItem(name: "UserId", value: userId),
                URLQueryItem(name: "Fields", value: "Overview,MediaStreams,UserData,IndexNumber,RunTimeTicks,PremiereDate,ParentId,ParentIndexNumber,SeasonName")
            ]),
            ("/Items", [
                URLQueryItem(name: "ParentId", value: seasonId),
                URLQueryItem(name: "IncludeItemTypes", value: "Episode"),
                URLQueryItem(name: "Recursive", value: "false"),
                URLQueryItem(name: "SortBy", value: "IndexNumber"),
                URLQueryItem(name: "SortOrder", value: "Ascending"),
                URLQueryItem(name: "Fields", value: "Overview,MediaStreams,UserData,IndexNumber,RunTimeTicks,PremiereDate,ParentId,ParentIndexNumber,SeasonName")
            ])
        ]

        var lastHttpStatus: Int? = nil
        let decoder = JSONDecoder()
        struct ItemsWrapper: Codable { let Items: [JellyfinItem] }

        for (path, queryItems) in attemptVariants {
            do {
                let url = try config.url(appending: path, queryItems: queryItems)
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

                print("[JellyfinClient] fetchEpisodesWithToken: attempting \(url)")
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }

                lastHttpStatus = http.statusCode
                if http.statusCode == 401 {
                    print("[JellyfinClient] 401 in fetchEpisodesWithToken for \(path)")
                    throw ServiceError.httpStatus(401)
                }

                if http.statusCode == 404 {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("[JellyfinClient] 404 for \(url): \(responseString.prefix(300))")
                    } else {
                        print("[JellyfinClient] 404 for \(url) (no body)")
                    }
                    continue
                }

                guard 200..<300 ~= http.statusCode else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("[JellyfinClient] fetchEpisodesWithToken unexpected status \(http.statusCode): \(responseString.prefix(300))")
                    }
                    throw ServiceError.httpStatus(http.statusCode)
                }

                var decodedItems: [JellyfinItem] = []
                if let wrapper = try? decoder.decode(ItemsWrapper.self, from: data) {
                    decodedItems = wrapper.Items
                    print("[JellyfinClient] fetchEpisodesWithToken: decoded Items wrapper with \(decodedItems.count) items from \(url)")
                } else if let arr = try? decoder.decode([JellyfinItem].self, from: data) {
                    decodedItems = arr
                    print("[JellyfinClient] fetchEpisodesWithToken: decoded raw array with \(decodedItems.count) items from \(url)")
                } else {
                    if let responseString = String(data: data, encoding: .utf8) {
                        print("[JellyfinClient] fetchEpisodesWithToken: unknown response shape from \(url): \(responseString.prefix(500))")
                    }
                    continue
                }

                // Filter to episodes
                let episodes = decodedItems.filter { $0.type == "Episode" }
                print("[JellyfinClient] fetchEpisodesWithToken: returning \(episodes.count) episodes from \(url)")
                return episodes
            } catch let err as ServiceError {
                if case .httpStatus(401) = err {
                    throw err
                }
                print("[JellyfinClient] ServiceError when attempting episodes path \(path): \(err)")
                continue
            } catch {
                print("[JellyfinClient] Network/decoding error when attempting episodes path \(path): \(error)")
                continue
            }
        }

        if let status = lastHttpStatus {
            print("[JellyfinClient] All fetchEpisodesWithToken attempts failed. Last HTTP status: \(status)")
            throw ServiceError.httpStatus(status)
        } else {
            print("[JellyfinClient] All fetchEpisodesWithToken attempts failed (no HTTP status available)")
            throw ServiceError.unknown
        }
    }

    func fetchUsers() async throws -> [JellyfinUser] {
        let authToken = try await authenticate()

        let url = try config.url(appending: "/Users")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }

            if http.statusCode == 401 {
                print("[JellyfinClient] 401 error in fetchUsers, clearing cached token")
                cachedAuthToken = nil
                authTokenTimestamp = nil
                let freshToken = try await authenticate()
                return try await fetchUsersWithToken(freshToken)
            }

            guard 200..<300 ~= http.statusCode else {
                throw ServiceError.httpStatus(http.statusCode)
            }

            let decoded = try JSONDecoder().decode([JellyfinUser].self, from: data)
            return decoded
        } catch let error as ServiceError {
            throw error
        } catch {
            throw ServiceError.network(error)
        }
    }

    private func fetchUsersWithToken(_ authToken: String) async throws -> [JellyfinUser] {
        let url = try config.url(appending: "/Users")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }
        guard 200..<300 ~= http.statusCode else {
            throw ServiceError.httpStatus(http.statusCode)
        }

        let decoded = try JSONDecoder().decode([JellyfinUser].self, from: data)
        return decoded
    }

    private func getCurrentUserId(authToken: String) async throws -> String {
        // Return cached user ID if available
        if let cachedId = cachedUserId {
            print("[JellyfinClient] Using cached user ID: \(cachedId)")
            return cachedId
        }

        print("[JellyfinClient] Fetching user ID from /Users/Me")
        let url = try config.url(appending: "/Users/Me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authToken, forHTTPHeaderField: "X-Emby-Token")

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw ServiceError.unknown }

            print("[JellyfinClient] /Users/Me response status: \(http.statusCode)")

            guard 200..<300 ~= http.statusCode else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("[JellyfinClient] /Users/Me error response: \(responseString)")
                }
                throw ServiceError.httpStatus(http.statusCode)
            }

            struct UserResponse: Codable {
                let Id: String
                let Name: String?
            }
            let decoded = try JSONDecoder().decode(UserResponse.self, from: data)

            // Cache the user ID for future requests
            cachedUserId = decoded.Id
            print("[JellyfinClient] Fetched and cached user ID: \(decoded.Id) for user: \(decoded.Name ?? "unknown")")

            return decoded.Id
        } catch let error as ServiceError {
            print("[JellyfinClient] ServiceError in getCurrentUserId: \(error)")
            throw error
        } catch {
            print("[JellyfinClient] Network error in getCurrentUserId: \(error)")
            throw ServiceError.network(error)
        }
    }
}
