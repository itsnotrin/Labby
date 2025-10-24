# Frequently Asked Questions (FAQ)

## General Questions

### What is Labby?

Labby is a native iOS dashboard application for managing and monitoring self-hosted services. It provides a unified interface to control multiple homelab services without switching between different web interfaces or apps.

### Which services does Labby support?

Currently, Labby supports:
- **Proxmox VE** - Virtual machine and container management
- **Jellyfin** - Media server monitoring and library browsing
- **qBittorrent** - Torrent client management
- **Pi-hole** - DNS filtering and statistics

More services are planned for future releases.

### Is Labby available on platforms other than iOS?

Currently, Labby is only available for iOS devices running iOS 15.0 or later. While there are no immediate plans for other platforms, the open-source nature of the project means community ports are possible.

### Does Labby cost money?

No, Labby is completely free and open-source under the GPL v3.0 license. There are no in-app purchases, subscriptions, or premium features.

### How is Labby different from other homelab management apps?

Labby focuses on:
- **Native iOS experience** with SwiftUI
- **Multi-home organization** for different environments
- **Customizable widget layouts** on a 2-column grid
- **Secure local-first approach** with no cloud dependencies
- **Comprehensive service integration** beyond basic monitoring

## Setup and Configuration

### How do I install Labby?

Since Labby isn't on the App Store, you'll need to sideload it:
1. Download the latest IPA from the GitHub releases
2. Use AltStore, Sideloadly, or similar sideloading tools
3. Install on your iOS device

### How do I add a new service?

1. Open Labby and go to the **Services** tab
2. Tap the **+** button in the top-right corner
3. Select your service type
4. Fill in the connection details (URL, credentials, etc.)
5. Test the connection and save
6. The service will appear in your current home's widget layout

### What are "Homes" and how do I use them?

Homes are organizational containers for grouping services by environment or location. For example:
- "Home Lab" - Your personal homelab services
- "Work" - Office infrastructure
- "Remote Site" - Services at another location

You can switch between homes using the dropdown in the Home tab's navigation bar.

### How do I customize widget layouts?

1. In the Home tab, tap **Edit** in the top-right corner
2. Drag widgets to rearrange them
3. Tap a widget to customize its size, metrics, and title
4. Use **Auto Layout** to automatically organize widgets
5. Tap **Done** when finished

## Technical Questions

### How does Labby store my login credentials?

All credentials are stored securely in the iOS Keychain, which provides hardware-level encryption on modern devices. Credentials never leave your device and are not transmitted to any third-party services.

### Does Labby work with self-signed SSL certificates?

Yes! When adding a service, you can enable "Skip SSL Verification" to bypass certificate validation. This is useful for homelab setups with self-signed certificates.

### How often does Labby refresh service data?

The refresh interval is configurable in Settings (5-120 seconds). Each widget can also have its own refresh interval override. Data is fetched asynchronously to maintain smooth UI performance.

### Can I export my Labby configuration?

Currently, there's no built-in export feature, but it's planned for a future release. Configuration is stored locally in iOS UserDefaults and Keychain.

### What network permissions does Labby need?

Labby only needs network access to communicate with your self-hosted services. It makes direct HTTP/HTTPS connections to the URLs you configure - no external services are contacted.

## Troubleshooting

### I can't connect to my service

**Check these common issues:**

1. **URL Format**: Ensure you include the protocol (`http://` or `https://`) and correct port
2. **Network Access**: Verify your device can reach the service (try opening the web interface in Safari)
3. **Credentials**: Double-check username/password or API tokens
4. **SSL Issues**: Enable "Skip SSL Verification" for self-signed certificates
5. **Firewall**: Ensure the service port is accessible from your network

### The app shows "Cannot find type" errors but builds successfully

This is typically a language server synchronization issue in development environments. The app should function normally despite these diagnostic warnings.

### Widgets show "Loading..." indefinitely

This usually indicates:
- Network connectivity issues
- Invalid credentials
- Service is offline or unreachable
- API endpoint changes in the service

Try using the "Test Connection" feature in the service configuration to diagnose the issue.

### The app crashes when opening certain services

1. Force-close and restart Labby
2. Check if the service's web interface is accessible
3. Try removing and re-adding the problematic service
4. Report the crash with details on GitHub Issues

### My Proxmox widgets show zero values

Ensure your API token has proper permissions:
- For read-only monitoring: `PVEAuditor` role
- For full access: `PVEAdmin` role
- Verify the token hasn't expired

### Jellyfin login fails

- Confirm the username/password works in the Jellyfin web interface
- Check if two-factor authentication is enabled (not currently supported)
- Verify the Jellyfin server URL is correct and accessible

## Privacy and Security

### Does Labby collect any data about me?

No. Labby is completely local-first with no telemetry, analytics, or data collection. All data stays on your device.

### Is it safe to store my service credentials in Labby?

Yes. All credentials are stored in the iOS Keychain, which provides hardware-level encryption and is considered the most secure storage method on iOS devices.

### Can I audit Labby's security?

Absolutely! Labby is open-source, so you can review the entire codebase on GitHub. The security-critical components are in the `KeychainStorage` and service client implementations.

## Development and Contributing

### How can I add support for a new service?

See the [Adding New Services](adding-new-services.md) guide for detailed instructions. The process involves:
1. Implementing the `ServiceClient` protocol
2. Creating service-specific data models
3. Adding authentication configuration
4. Registering with the service manager

### I found a bug - how do I report it?

1. Check if it's already reported in [GitHub Issues](https://github.com/ryanwiecz/Labby/issues)
2. Create a new issue with:
   - Steps to reproduce
   - Expected vs actual behavior
   - iOS version and device model
   - Screenshots or screen recordings if applicable

### Can I contribute to the project?

Yes! See the [Contributing Guide](contributing.md) for details on:
- Code style guidelines
- Pull request process
- Development setup
- Testing requirements

### What technologies does Labby use?

- **Language**: Swift 5.7+
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with ObservableObject
- **Networking**: URLSession with async/await
- **Storage**: UserDefaults + iOS Keychain
- **Target**: iOS 15.0+

---

**Still have questions?** Open a discussion on [GitHub Discussions](https://github.com/ryanwiecz/Labby/discussions) or create an issue for bug reports.