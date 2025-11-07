# Architecture & Development Guide

This document provides an in-depth look at Labby's architecture, design patterns, and development guidelines.

## High-Level Architecture

Labby follows a modular, protocol-oriented architecture built with SwiftUI and modern iOS development patterns.

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   SwiftUI Views │    │    Managers      │    │  Service Layer  │
│                 │    │                  │    │                 │
│ • HomeView      │◄──►│ • ServiceManager │◄──►│ • ServiceClient │
│ • ServicesView  │    │ • LayoutStore    │    │ • ProxmoxClient │
│ • SettingsView  │    │ • AppearanceManager│  │ • JellyfinClient│
│ • WidgetViews   │    │ • KeychainStorage│    │ • QBittorrentClient│
└─────────────────┘    └──────────────────┘    └─────────────────┘
        │                        │                        │
        └────────────────────────┼────────────────────────┘
                                 │
                    ┌──────────────────┐
                    │   Data Models    │
                    │                  │
                    │ • ServiceConfig  │
                    │ • HomeLayout     │
                    │ • StatsPayload   │
                    │ • WidgetMetrics  │
                    └──────────────────┘
```

## Core Components

### 1. Service Layer

#### ServiceClient Protocol
The foundation of service integration. All services implement this protocol:

```swift
protocol ServiceClient {
    var config: ServiceConfig { get }
    func testConnection() async throws -> String
    func fetchStats() async throws -> ServiceStatsPayload
}
```

#### ServiceManager
Centralized factory for creating and managing service clients:
- Handles service registration and client instantiation
- Manages authentication and configuration
- Provides type-safe service access

#### Service Implementation Pattern
Each service follows a consistent structure:
```
Services/[ServiceName]/
├── [ServiceName]Client.swift      # Main client implementation
├── [ServiceName]Models.swift      # Service-specific data models
├── [ServiceName]API.swift         # API endpoints and requests
└── [ServiceName]Metrics.swift     # Available metrics definitions
```

### 2. Data Management

#### HomeLayoutStore
Manages widget layouts and persistence:
- Uses `@Published` properties for reactive UI updates
- Persists layouts to UserDefaults
- Handles widget positioning and sizing logic

#### KeychainStorage
Secure credential management:
- Stores sensitive data in iOS Keychain
- Provides type-safe credential access
- Automatic cleanup on service deletion

#### AppearanceManager
Global appearance and theme management:
- System appearance integration
- Dark/light mode switching
- Custom theme support

### 3. Widget System

#### Widget Architecture
Widgets are data-driven UI components that display service metrics:

```swift
struct ServiceWidget: View {
    let service: ServiceConfig
    let layout: WidgetLayout
    let stats: ServiceStatsPayload?
    
    var body: some View {
        // Widget implementation
    }
}
```

#### Widget Sizing System
Grid-based layout with predefined sizes:
- **Small** (1×1): 160×120 points
- **Medium** (1×2): 160×260 points  
- **Wide** (2×1): 340×120 points
- **Large** (2×2): 340×260 points
- **Tall** (1×3): 160×400 points
- **Extra Wide** (2×3): 340×400 points

#### Metric System
Each service defines available metrics through enums:

```swift
enum ProxmoxMetrics: String, CaseIterable, MetricDefinition {
    case cpuUsage = "CPU Usage"
    case memoryUsage = "Memory Usage"
    case vmCount = "Virtual Machines"
    // ...
}
```

## Design Patterns

### 1. Protocol-Oriented Programming
- Services implement common protocols for consistency
- Enables type-safe polymorphism
- Simplifies testing and mocking

### 2. Reactive Programming
- Uses `@Published` and `@ObservableObject` for state management
- Automatic UI updates when data changes
- Unidirectional data flow

### 3. Factory Pattern
- ServiceManager acts as a factory for service clients
- Encapsulates service creation logic
- Enables dependency injection for testing

### 4. Repository Pattern
- Data stores abstract persistence logic
- Consistent interface for data operations
- Easy to swap implementations (UserDefaults, Core Data, etc.)

## Data Flow

### 1. Service Data Fetching
```
Timer → ServiceManager → ServiceClient → API → Response → StatsPayload → Widget
```

### 2. Configuration Updates
```
UI → Manager → Store → Persistence → State Update → UI Refresh
```

### 3. Authentication Flow
```
User Input → KeychainStorage → Service Config → API Client → Authenticated Request
```

## Development Guidelines

### Adding New Services

1. **Create Service Directory Structure**
   ```
   Services/[ServiceName]/
   ├── [ServiceName]Client.swift
   ├── [ServiceName]Models.swift
   ├── [ServiceName]API.swift
   └── [ServiceName]Metrics.swift
   ```

2. **Implement ServiceClient Protocol**
   ```swift
   class MyServiceClient: ServiceClient {
       let config: ServiceConfig
       
       func testConnection() async throws -> String { }
       func fetchStats() async throws -> ServiceStatsPayload { }
   }
   ```

3. **Define Service Models**
   - API response models
   - Metrics enum conforming to `MetricDefinition`
   - Authentication configuration

4. **Register in ServiceManager**
   ```swift
   func client(for config: ServiceConfig) -> ServiceClient? {
       switch config.type {
       case .myService:
           return MyServiceClient(config: config)
       // ...
       }
   }
   ```

5. **Add Default Metrics**
   Update `HomeLayoutDefaults` with default widget configuration

### Code Style Guidelines

#### Naming Conventions
- **Files**: PascalCase (e.g., `ServiceManager.swift`)
- **Classes/Structs**: PascalCase (e.g., `ServiceClient`)
- **Variables/Functions**: camelCase (e.g., `fetchStats`)
- **Constants**: camelCase (e.g., `defaultRefreshInterval`)

#### Error Handling
- Use `Result` types for operations that can fail
- Throw specific, descriptive errors
- Handle async operations with proper error propagation

#### Documentation
- Document public APIs with Swift documentation comments
- Include usage examples for complex functions
- Maintain inline comments for business logic

### Testing Strategy

#### Unit Tests
- Test service clients with mocked responses
- Verify data parsing and transformation
- Test error handling scenarios

#### Integration Tests
- Test complete service integration flows
- Verify authentication mechanisms
- Test widget rendering with real data

#### UI Tests
- Test critical user workflows
- Verify accessibility compliance
- Test layout on different screen sizes

## Performance Considerations

### Memory Management
- Use weak references to prevent retain cycles
- Dispose of network requests when views disappear
- Cache frequently accessed data appropriately

### Network Efficiency
- Implement proper request debouncing
- Use connection pooling for HTTP requests
- Handle network failures gracefully

### UI Performance
- Optimize widget rendering for smooth scrolling
- Use lazy loading for large datasets
- Minimize state updates and view refreshes

## Security Guidelines

### Credential Storage
- Always use Keychain for sensitive data
- Never log authentication credentials
- Implement proper credential rotation

### Network Security
- Support SSL certificate validation
- Provide option to disable SSL for self-signed certificates
- Use secure transport protocols (HTTPS)

### Data Privacy
- Store minimal necessary data
- Implement proper data cleanup
- No telemetry or external data transmission

## Future Architecture Considerations

### Scalability
- Plugin system for third-party service integrations
- Dynamic widget loading and registration
- Modular service discovery

### Platform Expansion
- Shared core logic for macOS/watchOS
- Cross-platform data synchronization
- Universal widget system

### Advanced Features
- Real-time updates via WebSocket
- Push notification integration
- Background data refresh capabilities

## Debugging and Diagnostics

### Logging Strategy
- Use structured logging with categories
- Include request/response debugging
- Implement log level filtering

### Performance Monitoring
- Track widget refresh times
- Monitor memory usage patterns
- Measure network request latency

### Error Reporting
- Collect crash reports for debugging
- Track API error patterns
- Monitor authentication failures

---

This architecture provides a solid foundation for extending Labby while maintaining code quality, performance, and security standards.