# Adding New Services to Labby

This guide provides detailed instructions for implementing new service integrations in Labby. By following these steps, you can add support for any service that exposes an API or web interface.

## Architecture Overview

Labby's service integration follows a protocol-based architecture where each service implements the `ServiceClient` protocol. The integration consists of several key components:

- **Service Models**: Data structures and enums specific to the service
- **Service Client**: Implementation of the `ServiceClient` protocol
- **Authentication**: Configuration for various auth methods
- **Widget Metrics**: Customizable statistics and monitoring data
- **UI Components**: Optional custom views for service-specific features

## Step-by-Step Implementation

### Step 1: Define Service Models

Create models for your service in the appropriate location (e.g., `Services/YourService/YourServiceModels.swift`):

```swift
// Define service-specific metrics for widgets
enum YourServiceMetric: String, Codable, CaseIterable, Identifiable {
    case activeConnections
    case totalUsers
    case cpuUsage
    case memoryUsage
    
    var id: String { rawValue }
}

// Define the statistics payload structure
struct YourServiceStats: Codable, Equatable {
    var activeConnections: Int
    var totalUsers: Int
    var cpuUsage: Double
    var memoryUsage: Int64
    
    init(activeConnections: Int, totalUsers: Int, cpuUsage: Double, memoryUsage: Int64) {
        self.activeConnections = activeConnections
        self.totalUsers = totalUsers
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
    }
}
```

### Step 2: Update Core Models

Add your service to the existing enums in `Models/ServiceModels.swift`:

```swift
enum ServiceKind: String, Codable, CaseIterable, Identifiable {
    case proxmox
    case jellyfin
    case qbittorrent
    case pihole
    case yourService // Add your service here
    
    var displayName: String {
        switch self {
        case .proxmox: return "Proxmox"
        case .jellyfin: return "Jellyfin"
        case .qbittorrent: return "qBittorrent"
        case .pihole: return "Pi-hole"
        case .yourService: return "Your Service"
        }
    }
}
```

Update `AuthMethodType` if your service requires a new authentication method:

```swift
enum AuthMethodType: String, Codable, CaseIterable, Identifiable {
    case apiToken
    case usernamePassword
    case proxmoxToken
    case yourServiceAuth // If needed
    
    var displayName: String {
        switch self {
        case .apiToken: return "API Token"
        case .usernamePassword: return "Username & Password"
        case .proxmoxToken: return "Proxmox API Token"
        case .yourServiceAuth: return "Your Service Auth"
        }
    }
}
```

### Step 3: Update Widget Metrics in HomeLayoutModels

Add your service metrics to `Models/HomeLayoutModels.swift`:

```swift
enum WidgetMetricsSelection: Codable, Equatable {
    case proxmox([ProxmoxMetric])
    case jellyfin([JellyfinMetric])
    case qbittorrent([QBittorrentMetric])
    case pihole([PiHoleMetric])
    case yourService([YourServiceMetric]) // Add this case
    
    // Update the coding implementation
    private enum Discriminator: String, Codable {
        case proxmox, jellyfin, qbittorrent, pihole, yourService
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(Discriminator.self, forKey: .type)
        switch type {
        // ... existing cases ...
        case .yourService:
            let metrics = try container.decode([YourServiceMetric].self, forKey: .yourService)
            self = .yourService(metrics)
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        // ... existing cases ...
        case .yourService(let metrics):
            try container.encode(Discriminator.yourService, forKey: .type)
            try container.encode(metrics, forKey: .yourService)
        }
    }
}
```

Add your service stats to the `ServiceStatsPayload` enum:

```swift
enum ServiceStatsPayload: Codable, Equatable {
    case proxmox(ProxmoxStats)
    case jellyfin(JellyfinStats)
    case qbittorrent(QBittorrentStats)
    case pihole(PiHoleStats)
    case yourService(YourServiceStats) // Add this case
    
    // Update coding implementations accordingly
}
```

### Step 4: Implement the Service Client

Create your service client in `Services/YourService/YourServiceClient.swift`:

```swift
import Foundation

final class YourServiceClient: ServiceClient {
    let config: ServiceConfig
    
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
    
    func testConnection() async throws -> String {
        let url = try config.url(appending: "/api/status")
        var request = URLRequest(url: url)
        
        // Add authentication headers
        try addAuthentication(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.unknown
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            throw ServiceError.httpStatus(httpResponse.statusCode)
        }
        
        // Parse response to get version/status info
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let version = json["version"] as? String {
            return "Your Service v\(version)"
        }
        
        return "Connection successful"
    }
    
    func fetchStats() async throws -> ServiceStatsPayload {
        let url = try config.url(appending: "/api/stats")
        var request = URLRequest(url: url)
        
        try addAuthentication(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ServiceError.unknown
        }
        
        guard 200..<300 ~= httpResponse.statusCode else {
            throw ServiceError.httpStatus(httpResponse.statusCode)
        }
        
        // Parse the response into your stats structure
        let decoder = JSONDecoder()
        let apiResponse = try decoder.decode(YourServiceAPIResponse.self, from: data)
        
        let stats = YourServiceStats(
            activeConnections: apiResponse.connections,
            totalUsers: apiResponse.users,
            cpuUsage: apiResponse.cpu,
            memoryUsage: apiResponse.memory
        )
        
        return .yourService(stats)
    }
    
    private func addAuthentication(to request: inout URLRequest) throws {
        switch config.auth {
        case .apiToken(let keychainKey):
            guard let tokenData = KeychainStorage.shared.loadSecret(forKey: keychainKey),
                  let token = String(data: tokenData, encoding: .utf8) else {
                throw ServiceError.missingSecret
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            
        case .usernamePassword(let username, let passwordKey):
            guard let passwordData = KeychainStorage.shared.loadSecret(forKey: passwordKey),
                  let password = String(data: passwordData, encoding: .utf8) else {
                throw ServiceError.missingSecret
            }
            
            let credentials = "\(username):\(password)"
            let encodedCredentials = Data(credentials.utf8).base64EncodedString()
            request.setValue("Basic \(encodedCredentials)", forHTTPHeaderField: "Authorization")
            
        default:
            throw ServiceError.unknown
        }
    }
}

// Helper struct for API response parsing
private struct YourServiceAPIResponse: Codable {
    let connections: Int
    let users: Int
    let cpu: Double
    let memory: Int64
}
```

### Step 5: Register the Service

Update `ServiceManager.swift` to include your service in the client factory:

```swift
func client(for config: ServiceConfig) -> ServiceClient {
    switch config.kind {
    case .proxmox:
        return ProxmoxClient(config: config)
    case .jellyfin:
        return JellyfinClient(config: config)
    case .qbittorrent:
        return QBittorrentClient(config: config)
    case .pihole:
        return PiHoleClient(config: config)
    case .yourService:
        return YourServiceClient(config: config) // Add this case
    }
}
```

### Step 6: Add Default Widget Configuration

Update `HomeLayoutDefaults` in `HomeLayoutModels.swift`:

```swift
static func defaultMetrics(for kind: ServiceKind, size: HomeWidgetSize = .small) -> WidgetMetricsSelection {
    switch kind {
    // ... existing cases ...
    case .yourService:
        if size == .large {
            return .yourService([.activeConnections, .totalUsers, .cpuUsage, .memoryUsage])
        } else {
            return .yourService([.activeConnections, .totalUsers])
        }
    }
}

static func determineOptimalSize(for kind: ServiceKind) -> HomeWidgetSize {
    switch kind {
    // ... existing cases ...
    case .yourService:
        return .medium // Choose based on typical data density
    }
}
```

### Step 7: Update UI Components

Add your service to the widget display logic in `HomeView.swift`. Look for the `statLines()` method in `HomeWidgetCard` and add your case:

```swift
func statLines() -> [String] {
    guard let stats = stats else { return ["Loading..."] }
    
    switch stats {
    // ... existing cases ...
    case .yourService(let serviceStats):
        return formatYourServiceStats(serviceStats, metrics: widget.metrics)
    }
}

private func formatYourServiceStats(_ stats: YourServiceStats, metrics: WidgetMetricsSelection) -> [String] {
    guard case .yourService(let selectedMetrics) = metrics else { return [] }
    
    var lines: [String] = []
    
    for metric in selectedMetrics {
        switch metric {
        case .activeConnections:
            lines.append("Connections: \(stats.activeConnections)")
        case .totalUsers:
            lines.append("Users: \(stats.totalUsers)")
        case .cpuUsage:
            lines.append("CPU: \(String(format: "%.1f%%", stats.cpuUsage))")
        case .memoryUsage:
            lines.append("Memory: \(StatFormatter.formatBytes(stats.memoryUsage))")
        }
    }
    
    return lines
}
```

### Step 8: Add Service Icon

Add an icon for your service in the `iconName(for:)` method:

```swift
func iconName(for kind: ServiceKind) -> String {
    switch kind {
    case .proxmox: return "server.rack"
    case .jellyfin: return "tv"
    case .qbittorrent: return "arrow.down.circle"
    case .pihole: return "shield"
    case .yourService: return "gear" // Choose an appropriate SF Symbol
    }
}
```

## Testing Your Integration

### Unit Testing

Create unit tests for your service client:

```swift
import XCTest
@testable import Labby

class YourServiceClientTests: XCTestCase {
    func testStatsDecoding() throws {
        let json = """
        {
            "connections": 42,
            "users": 15,
            "cpu": 23.5,
            "memory": 1073741824
        }
        """
        
        let data = json.data(using: .utf8)!
        let stats = try JSONDecoder().decode(YourServiceStats.self, from: data)
        
        XCTAssertEqual(stats.activeConnections, 42)
        XCTAssertEqual(stats.totalUsers, 15)
        XCTAssertEqual(stats.cpuUsage, 23.5)
        XCTAssertEqual(stats.memoryUsage, 1073741824)
    }
}
```

### Manual Testing

1. **Build and run** the app on a device or simulator
2. **Add your service** in the Services tab
3. **Test connection** using the test button
4. **Verify widget display** in the Home tab
5. **Test different widget sizes** and metric combinations

## Best Practices

### Error Handling

- Always handle network errors gracefully
- Provide meaningful error messages
- Use appropriate `ServiceError` types
- Implement timeouts for long-running requests

### Performance

- Use async/await for all network operations
- Implement request caching where appropriate
- Avoid blocking the main thread
- Consider rate limiting for frequent API calls

### Security

- Never hardcode credentials or API keys
- Always use KeychainStorage for sensitive data
- Support SSL verification bypass for self-signed certificates
- Validate all input data from APIs

### User Experience

- Provide clear service setup documentation
- Use descriptive metric names and formatting
- Handle loading states appropriately
- Support both light and dark modes

## Advanced Features

### Custom Views

For services that need custom UI beyond basic widgets, create dedicated views:

```swift
struct YourServiceDetailView: View {
    let config: ServiceConfig
    @State private var client: YourServiceClient
    
    var body: some View {
        // Custom UI implementation
    }
}
```

### Background Refresh

Implement background refresh capabilities:

```swift
extension YourServiceClient {
    func backgroundRefresh() async throws {
        // Optimized refresh for background execution
    }
}
```

### Notifications

Add support for service-specific notifications:

```swift
extension YourServiceClient {
    func checkForAlerts() async throws -> [ServiceAlert] {
        // Check for service alerts/notifications
    }
}
```

## Common Patterns

### REST API Services

Most services follow this pattern:
- Base URL + endpoint paths
- JSON request/response bodies
- Standard HTTP authentication

### Authentication Flows

- **API Tokens**: Simple bearer token or custom header
- **Basic Auth**: Username/password base64 encoded
- **Session-based**: Login to get session cookie/token

### Data Transformation

- Parse API responses into clean data models
- Handle missing or null values gracefully
- Normalize data formats (dates, numbers, etc.)

## Troubleshooting

### Common Issues

1. **"Cannot find type" errors**: Ensure all imports are correct
2. **Authentication failures**: Verify credential storage and retrieval
3. **JSON decoding errors**: Check API response format matches models
4. **Network timeouts**: Implement appropriate timeout values
5. **Widget not updating**: Verify ServiceStatsPayload enum is updated

### Debugging Tips

- Use Xcode's Network debugging to inspect API calls
- Add logging statements for key operations
- Test with Charles Proxy or similar tools
- Verify JSON responses match your data models

## Resources

- [Swift Documentation](https://docs.swift.org/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [URLSession Guide](https://developer.apple.com/documentation/foundation/urlsession)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)

---

**Need help?** Open an issue on GitHub or start a discussion with the community.