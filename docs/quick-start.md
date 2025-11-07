# Quick Start Guide

Get up and running with Labby in just a few minutes! This guide will walk you through setting up your first services and customizing your dashboard.

## Step 1: Initial Setup

### First Launch
1. Open Labby on your device
2. You'll see the main dashboard with a "Default Home" already created
3. The Services and Settings tabs are available at the bottom

### Understanding Homes
- **Homes** are containers for organizing your services (e.g., "Home Lab", "Work", "Remote Sites")
- You can have multiple homes and switch between them
- Each home has its own widget layout and configuration

## Step 2: Add Your First Service

1. Tap the **Services** tab at the bottom
2. Tap the **"+"** button to add a new service
3. Fill in the service details:
   - **Name**: Choose a display name (e.g., "Main Proxmox")
   - **Type**: Select your service type
   - **URL**: Enter the base URL (e.g., `https://192.168.1.100:8006`)
   - **Home**: Select which home to add it to

### Service-Specific Setup
- **Proxmox**: Requires API token - see [Proxmox Setup Guide](proxmox.md)
- **Jellyfin**: Uses username/password - see [Jellyfin Setup Guide](jellyfin.md)
- **qBittorrent**: Uses username/password - see [qBittorrent Setup Guide](qbittorrent.md)
- **Pi-hole**: Uses username/password - see [Pi-hole Setup Guide](pihole.md)

## Step 3: Test Connection

1. After entering service details, tap **"Test Connection"**
2. If successful, you'll see a green checkmark
3. If it fails, double-check:
   - URL format and accessibility
   - Authentication credentials
   - Network connectivity
   - SSL certificate settings (try disabling SSL verification for self-signed certs)

## Step 4: Customize Your Dashboard

### Return to Home View
1. Tap the **Home** tab
2. You'll see your new service as a widget
3. Tap **"Edit Layout"** to customize

### Widget Management
- **Resize**: Drag the corners of widgets to change size
- **Move**: Long press and drag widgets to new positions
- **Configure**: Tap the settings icon on each widget to:
  - Choose which metrics to display
  - Set custom refresh intervals
  - Override the widget title

### Widget Sizes
- **Small** (1×1): Basic metrics
- **Medium** (1×2): Detailed stats
- **Wide** (2×1): Horizontal layout
- **Large** (2×2): Comprehensive view
- **Tall** (1×3): Extended metrics
- **Extra Wide** (2×3): Maximum information

## Step 5: Configure Settings

### Global Settings
1. Go to **Settings** tab
2. Configure:
   - **Default Refresh Interval**: How often widgets update (5-120 seconds)
   - **Appearance**: Light/Dark mode preferences
   - **SSL Verification**: Global setting for certificate validation

### Per-Service Settings
- Each service can have individual refresh intervals
- Authentication can be updated per service
- SSL verification can be configured per service

## Common Tasks

### Adding Multiple Homes
1. Go to Settings > Homes
2. Tap "+" to create a new home
3. Name your home (e.g., "Work Lab", "Remote Sites")
4. Switch between homes using the dropdown in the Home tab

### Organizing Services
- Group related services in the same home
- Use descriptive names for easy identification
- Consider creating separate homes for different physical locations

### Troubleshooting Widgets
- **Widget shows "Error"**: Check service connectivity and credentials
- **Widget not updating**: Verify refresh interval and network connection
- **Widget too small**: Resize to show more metrics
- **Layout feels cluttered**: Use different homes to organize services

## Next Steps

### Explore Advanced Features
- Set up multiple homes for different environments
- Experiment with different widget layouts
- Configure custom refresh intervals per widget
- Try different metric combinations

### Get More Services
- Add more service types as you expand your homelab
- Check the [supported services](../README.md#supported-services) list
- Request new service integrations in [GitHub Issues](../../issues)

### Need Help?
- Check the [FAQ](faq.md) for common questions
- Browse [documentation](../docs/) for detailed guides
- Create an issue on [GitHub](../../issues) for bugs or feature requests

## Pro Tips

1. **Start Simple**: Begin with one or two services and gradually add more
2. **Test Locally First**: Ensure services work on your local network before setting up remote access
3. **Use Descriptive Names**: Clear service names make dashboard management easier
4. **Regular Backups**: Consider backing up your homelab configurations
5. **Monitor Performance**: Use Labby to track resource usage and plan capacity

---

**You're all set!** Your Labby dashboard is now configured and ready to help you monitor your self-hosted services. Enjoy having all your homelab metrics in one place! 🎉