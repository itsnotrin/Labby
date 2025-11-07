# Labby

**A unified iOS dashboard for managing and monitoring your self-hosted services**

Instead of juggling multiple web interfaces or mobile apps, Labby provides a single, native iOS experience for controlling your homelab infrastructure.

## 💝 Support the Project

If Labby helps manage your homelab, consider supporting its development:

### Cryptocurrency
- **Bitcoin (BTC)**: `bc1q2seahuhpr2psu0cj6gacvjelyt8da22saf82d9`
- **Ethereum (ETH)**: `0x13FEb6D4608ab9cbe00A7D6b9a4684F752C1AD74`
- **Litecoin (LTC)**: `Li7jBnBTKtSQd4BajPLhgnGG2hSEQb54SW`

### Digital Payments
- **Apple Pay / Google Pay**: [Click Here](https://monzo.me/ryanwieczorkiewicz)
- **GitHub Sponsors**: [Click Here](https://github.com/sponsors/itsnotrin)

Every contribution helps cover development costs and enables new features! 🙏

## ✨ Features

<details>
<summary><strong>🏠 Multi-Home Support</strong></summary>

- Organize services into different homes (e.g., "Home Lab", "Work", "Remote Sites")
- Switch between homes with a simple dropdown interface
- Customizable layouts for each home environment

</details>

<details>
<summary><strong>📊 Real-Time Monitoring</strong></summary>

- Live statistics and metrics for all connected services
- Customizable widget sizes and layouts on a 2-column grid
- Auto-refresh capabilities with configurable intervals (5-120 seconds)
- Smart widget sizing based on service content requirements

</details>

<details>
<summary><strong>🔐 Secure Authentication</strong></summary>

- Multiple authentication methods per service type
- Credentials stored securely in iOS Keychain
- Support for API tokens, username/password, and custom authentication
- Optional SSL certificate verification bypass for self-signed certificates

</details>

<details>
<summary><strong>🎨 Native iOS Experience</strong></summary>

- SwiftUI-based modern interface with light/dark mode support
- Drag-and-drop widget editing and rearrangement
- Native iOS design patterns and accessibility support
- Six different widget sizes for optimal data presentation

</details>



<details>
<summary><strong>🛣️ Planned Features</strong></summary>

### Near Term
- [ ] Home Assistant integration
- [ ] Plex media server support
- [ ] Enhanced Pi-hole controls
- [ ] Widget export/import functionality

### Future Plans
- [ ] iPad-optimized layouts
- [ ] watchOS companion app
- [ ] Notification support for service alerts
- [ ] Custom service plugin system

</details>

[**📖 View all features**](docs/features.md)

## 🛠️ Supported Services

| Service | Features | Authentication |
|---------|----------|----------------|
| **Proxmox VE** | VM/CT monitoring, resource usage, cluster status | API Tokens |
| **Jellyfin** | Library stats, user management, server info | Username/Password |
| **qBittorrent** | Torrent management, download/upload speeds | Username/Password |
| **Pi-hole** | DNS statistics, blocking status, query metrics | Username/Password |

## 🚀 Quick Start

1. **Install Labby** - [Installation Guide](docs/installation.md)
2. **Add Your Services** - [Quick Start Guide](docs/quick-start.md)
3. **Customize Your Dashboard** - Drag, resize, and configure widgets
4. **Enjoy Your Unified Dashboard** 🎉

### Service Setup Guides
- [Proxmox VE Setup](docs/proxmox.md)
- [Jellyfin Setup](docs/jellyfin.md)
- [qBittorrent Setup](docs/qbittorrent.md)
- [Pi-hole Setup](docs/pihole.md)



## 📚 Documentation

- **[Installation Guide](docs/installation.md)** - Get Labby running on your device
- **[Quick Start Guide](docs/quick-start.md)** - Set up your first services
- **[Features Overview](docs/features.md)** - Detailed feature documentation
- **[Architecture Guide](docs/architecture.md)** - For developers and contributors
- **[FAQ](docs/faq.md)** - Common questions and answers
- **[Contributing](docs/contributing.md)** - How to contribute to the project

## 🤝 Contributing

We welcome contributions! Whether it's:
- 🐛 Bug reports and fixes
- 💡 Feature requests and implementations
- 📖 Documentation improvements
- 🧪 Testing and feedback

See our [Contributing Guide](docs/contributing.md) to get started.

## 🆘 Support

- **Documentation**: Check the [docs/](docs/) directory
- **Issues**: [GitHub Issues](../../issues) for bugs and feature requests
- **Discussions**: [GitHub Discussions](../../discussions) for questions and community chat
- **Detailed Support**: [Support Guide](docs/support.md)

## 🔒 Privacy & Security

- **🏠 Local First**: All configuration stored locally on your device
- **🔐 Secure Storage**: Credentials encrypted in iOS Keychain
- **🚫 No Telemetry**: No usage data collection or external analytics
- **📖 Open Source**: Full transparency with public source code

## 📄 License

Licensed under [GNU General Public License v3.0](LICENSE) - free to use, modify, and distribute. Derivatives must also be open source.

---

**Made with ❤️ for the self-hosting community**

*Star ⭐ this repo if Labby helps manage your homelab!*
