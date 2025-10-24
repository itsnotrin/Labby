# Labby

Labby is a unified iOS dashboard for managing and monitoring your self-hosted services. Instead of juggling multiple web interfaces or mobile apps, Labby provides a single, native iOS experience for controlling your homelab infrastructure.

## Features

### 🏠 **Multi-Home Support**
- Organize services into different homes (e.g., "Home Lab", "Work", "Remote Sites")
- Switch between homes with a simple dropdown interface
- Customizable layouts for each home environment

### 📊 **Real-Time Monitoring**
- Live statistics and metrics for all connected services
- Customizable widget sizes and layouts on a 2-column grid
- Auto-refresh capabilities with configurable intervals (5-120 seconds)
- Smart widget sizing based on service content requirements

### 🔐 **Secure Authentication**
- Multiple authentication methods per service type
- Credentials stored securely in iOS Keychain
- Support for API tokens, username/password, and Proxmox-specific tokens  
- Optional SSL certificate verification bypass for self-signed certificates

### 🎨 **Native iOS Experience**
- SwiftUI-based modern interface
- Light/dark mode support with system appearance integration
- Drag-and-drop widget editing and rearrangement
- Native iOS design patterns and accessibility support

### ⚙️ **Advanced Configuration**
- Per-widget metric selection and customization
- Auto-layout algorithms for optimal widget placement
- Title overrides and refresh interval customization
- Comprehensive settings management

## Supported Services

| Service | Features | Authentication |
|---------|----------|----------------|
| **Proxmox VE** | VM/CT monitoring, resource usage, network stats, cluster status | API Tokens |
| **Jellyfin** | Library browsing, user management, media statistics, server info | Username/Password |
| **qBittorrent** | Torrent management, download/upload speeds, queue monitoring | Username/Password |
| **Pi-hole** | DNS statistics, blocking status, query metrics, gravity updates | Username/Password |

## Architecture

### Core Components

- **ServiceManager**: Centralized service configuration and client factory
- **HomeLayoutStore**: Widget layout persistence and management
- **KeychainStorage**: Secure credential storage using iOS Keychain
- **AppearanceManager**: Theme and appearance state management

### Service Integration

Each service implements the `ServiceClient` protocol:
```swift
protocol ServiceClient {
    var config: ServiceConfig { get }
    func testConnection() async throws -> String
    func fetchStats() async throws -> ServiceStatsPayload
}
```

Services are configured with:
- Display name and base URL
- Authentication configuration (stored securely)
- SSL verification settings
- Home assignment

### Widget System

Widgets are placed on a 2-column grid with multiple size options:
- **Small** (1×1): Basic metrics
- **Medium** (1×2): Detailed single-column stats  
- **Wide** (2×1): Horizontal layouts
- **Large** (2×2): Comprehensive dashboards
- **Tall** (1×3): Extended vertical metrics
- **Extra Wide** (2×3): Maximum information density

## Getting Started

### Requirements
- iOS 15.0+
- Xcode 14.0+ (for development)
- Network access to your self-hosted services

### Installation

#### For Users
1. Download the latest release from the [Releases](../../releases) page
2. Sideload using [AltStore](https://altstore.io/) or [Sideloadly](https://sideloadly.io/)
3. Launch Labby and add your services

#### For Developers
1. Clone the repository:
   ```bash
   git clone https://github.com/ryanwiecz/Labby.git
   cd Labby
   ```
2. Open `Labby.xcodeproj` in Xcode
3. Build and run on your device or simulator

### Quick Setup

1. **Add a Home**: Create homes for different environments (optional - "Default Home" is created automatically)
2. **Add Services**: Navigate to Services tab and add your self-hosted services
3. **Configure Widgets**: Return to Home tab to customize widget layouts and metrics
4. **Customize Settings**: Adjust refresh intervals, appearance, and other preferences

## Service Setup Guides

- [Proxmox VE Setup](docs/proxmox.md) - API token configuration
- [Jellyfin Setup](docs/jellyfin.md) - Media server integration
- [qBittorrent Setup](docs/qbittorrent.md) - Torrent client configuration  
- [Pi-hole Setup](docs/pihole.md) - DNS monitoring setup

## Development

### Adding New Services

1. Create a new service client implementing `ServiceClient`
2. Define service-specific models and metrics enums
3. Add authentication configuration to `ServiceAuthConfig`
4. Register the service in `ServiceManager.client(for:)`
5. Add default widget metrics in `HomeLayoutDefaults`

See [Adding New Services](docs/adding-new-services.md) for detailed instructions.

### Project Structure

```
Labby/
├── LabbyApp.swift              # App entry point
├── ContentView.swift           # Main tab interface
├── Managers/                   # Core system managers
│   ├── AppearanceManager.swift
│   └── KeychainStorage.swift
├── Models/                     # Data models
│   ├── ServiceModels.swift
│   └── HomeLayoutModels.swift
├── Services/                   # Service integrations
│   ├── ServiceClient.swift
│   ├── ServiceManager.swift
│   ├── Proxmox/
│   ├── Jellyfin/
│   ├── QBittorrent/
│   └── PiHole/
└── Views/                      # UI components
    └── Core/
        ├── HomeView.swift
        ├── ServicesView.swift
        └── SettingsView.swift
```

## Contributing

We welcome contributions! Please see our [Contributing Guide](docs/contributing.md) for:
- Code style guidelines
- Pull request process
- Testing requirements
- Development setup

### Reporting Issues

Found a bug or have a feature request? Please:
1. Check existing [Issues](../../issues) first
2. Create a new issue with detailed information
3. Include logs, screenshots, and reproduction steps

## Roadmap

### Near Term
- [ ] Home Assistant integration
- [ ] Plex media server support
- [ ] Enhanced Pi-hole controls (enable/disable blocking)
- [ ] Widget export/import functionality

### Future Plans
- [ ] iPad-optimized layouts
- [ ] watchOS companion app
- [ ] Notification support for service alerts
- [ ] Custom service plugin system
- [ ] Multi-server clustering support

## Privacy & Security

- **Local First**: All configuration stored locally on your device
- **Secure Storage**: Credentials encrypted in iOS Keychain
- **No Telemetry**: No usage data collection or external analytics
- **Open Source**: Full transparency with public source code

## License

Labby is licensed under the [GNU General Public License v3.0](LICENSE).

This means you can freely use, modify, and distribute Labby, but any derivatives must also be open source under the same license.

## Support

- **Documentation**: [docs/](docs/) directory
- **Issues**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)

---

**Made with ❤️ for the self-hosting community**