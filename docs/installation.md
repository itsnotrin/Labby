# Installation Guide

## Requirements

- iOS 15.0 or later
- Network access to your self-hosted services
- For development: Xcode 14.0+

## Installation Methods

### Method 1: Sideloading (Recommended for Users)

#### Using AltStore
1. Install [AltStore](https://altstore.io/) on your device
2. Download the latest Labby IPA from [Releases](../../../releases)
3. Open the IPA file with AltStore
4. Follow AltStore's installation prompts

#### Using Sideloadly
1. Download [Sideloadly](https://sideloadly.io/)
2. Download the latest Labby IPA from [Releases](../../../releases)
3. Connect your device to your computer
4. Use Sideloadly to install the IPA file

### Method 2: Building from Source

#### Prerequisites
- macOS with Xcode 14.0+
- Apple Developer Account (free or paid)
- iOS device or simulator

#### Steps
1. Clone the repository:
   ```bash
   git clone https://github.com/itsnotrin/Labby.git
   cd Labby
   ```

2. Open the project in Xcode:
   ```bash
   open Labby.xcodeproj
   ```

3. Configure signing:
   - Select the Labby target
   - Go to "Signing & Capabilities"
   - Select your development team
   - Ensure "Automatically manage signing" is checked

4. Build and run:
   - Select your device from the scheme dropdown
   - Press ⌘+R to build and run

## Post-Installation Setup

### Network Configuration
- Ensure your device can reach your self-hosted services
- For local services, make sure you're on the same network
- For remote access, configure VPN or port forwarding as needed

### Troubleshooting

#### Can't Connect to Services
- Verify network connectivity
- Check service URLs and ports
- Ensure authentication credentials are correct
- Try disabling SSL verification for self-signed certificates

## Updating Labby

### Sideloaded Installations
1. Download the latest release
2. Install using the same method as initial installation
3. Your configuration and data will be preserved

### Development Builds
1. Pull the latest changes from the repository
2. Build and run the updated version
3. Configuration is preserved between builds

## Next Steps

After installation, see the [Quick Start Guide](quick-start.md) to begin setting up your services and customizing your dashboard.