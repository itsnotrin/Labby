# Features Overview

Labby provides a comprehensive set of features designed to simplify the management and monitoring of your self-hosted services through a native iOS experience.

## 🏠 Multi-Home Support

### Organize Your Infrastructure
- **Multiple Homes**: Create separate environments for different physical locations or purposes
  - Home Lab
  - Work Environment
  - Remote Sites
  - Testing/Development
- **Easy Switching**: Quick dropdown interface to switch between homes
- **Independent Layouts**: Each home maintains its own widget configuration and layout
- **Contextual Organization**: Group related services logically by environment

### Use Cases
- **Home/Work Separation**: Keep personal and professional services organized
- **Geographic Distribution**: Manage services across multiple locations
- **Environment Staging**: Separate production, staging, and development services
- **Team Management**: Different homes for different team responsibilities

## 📊 Real-Time Monitoring

### Live Dashboard
- **Real-Time Updates**: Continuously updated metrics and statistics
- **Configurable Refresh**: Set refresh intervals from 5 seconds to 2 minutes
- **Automatic Retry**: Smart retry logic for failed connections
- **Background Updates**: Keep data fresh even when app is backgrounded

### Comprehensive Metrics
- **System Resources**: CPU, memory, disk, and network usage
- **Service Health**: Uptime, response times, and availability status
- **Custom Metrics**: Service-specific data points and KPIs
- **Historical Trends**: Track performance over time (where supported)

### Visual Indicators
- **Status Colors**: Green (healthy), yellow (warning), red (critical)
- **Progress Bars**: Visual representation of usage percentages
- **Trend Arrows**: Quick indication of increasing/decreasing metrics
- **Alert Badges**: Highlight services requiring attention

## 🎨 Advanced Widget System

### Flexible Grid Layout
- **2-Column Grid**: Optimized for phone and tablet viewing
- **Multiple Sizes**: Six different widget sizes for various data needs
- **Drag & Drop**: Intuitive widget rearrangement
- **Auto-Layout**: Intelligent positioning algorithms

### Widget Size Options
| Size | Dimensions | Best For |
|------|------------|----------|
| **Small** (1×1) | 160×120pt | Quick status checks, single metrics |
| **Medium** (1×2) | 160×260pt | Detailed single-column data |
| **Wide** (2×1) | 340×120pt | Horizontal charts, comparison data |
| **Large** (2×2) | 340×260pt | Comprehensive dashboards |
| **Tall** (1×3) | 160×400pt | Extended vertical metrics, lists |
| **Extra Wide** (2×3) | 340×400pt | Maximum data density, complex views |

### Widget Customization
- **Metric Selection**: Choose which data points to display
- **Title Override**: Custom widget titles and descriptions
- **Refresh Control**: Per-widget refresh interval settings
- **Color Themes**: Automatic light/dark mode adaptation

## 🔐 Security & Authentication

### Multiple Authentication Methods
- **API Tokens**: Secure token-based authentication
- **Username/Password**: Traditional credential authentication
- **Custom Headers**: Support for custom authentication headers
- **Per-Service Config**: Different auth methods per service

### Secure Storage
- **iOS Keychain**: All credentials stored in encrypted Keychain
- **Automatic Cleanup**: Credentials removed when services are deleted
- **No Plain Text**: Never store sensitive data in plain text
- **Local Only**: All data remains on your device

### SSL/TLS Support
- **Certificate Validation**: Full SSL certificate verification
- **Self-Signed Support**: Option to bypass verification for self-signed certificates
- **Per-Service Settings**: Configure SSL validation per service
- **Security Warnings**: Clear indicators when SSL is disabled

## 🎯 Service Integration

### Supported Services

#### Proxmox Virtual Environment
- **VM/Container Status**: Running, stopped, paused virtual machines and containers
- **Resource Monitoring**: CPU, memory, disk usage per VM/container
- **Cluster Information**: Node status, resource allocation
- **Network Statistics**: Traffic monitoring and interface status
- **Storage Insights**: Disk usage, backup status, storage pools

#### Jellyfin Media Server
- **Library Statistics**: Movie, TV show, music library sizes
- **Active Sessions**: Current streaming sessions and users
- **Server Performance**: CPU usage, memory consumption
- **User Management**: Active users, recent activity
- **Transcoding Status**: Active transcoding sessions

#### qBittorrent
- **Download Management**: Active torrents, download/upload speeds
- **Queue Monitoring**: Queued, seeding, completed torrents
- **Bandwidth Usage**: Real-time transfer rates
- **Storage Information**: Available disk space, download location
- **Ratio Tracking**: Upload/download ratios

#### Pi-hole DNS
- **Query Statistics**: Total queries, blocked queries, percentage blocked
- **Top Domains**: Most requested domains and blocked domains
- **Client Activity**: Queries by client device
- **Gravity Updates**: Last update time, number of blocked domains
- **Network Overview**: Upstream DNS servers, response times

### Easy Service Addition
- **Auto-Discovery**: Automatic detection of common service ports
- **Connection Testing**: Built-in connectivity verification
- **Error Diagnostics**: Clear error messages for troubleshooting
- **Configuration Validation**: Real-time validation of service settings

## ⚙️ Customization & Settings

### Global Settings
- **Appearance**: Light mode, dark mode, or system automatic
- **Default Refresh**: Set global refresh interval for all widgets
- **SSL Policy**: Global SSL verification settings
- **Performance**: Memory and network usage optimization

### Per-Widget Configuration
- **Individual Refresh**: Override global refresh rates per widget
- **Metric Selection**: Choose specific metrics to display
- **Display Options**: Customize titles, units, and formatting
- **Layout Preferences**: Widget size and position preferences

### Home Management
- **Create/Delete**: Add and remove homes as needed
- **Rename**: Update home names and descriptions
- **Import/Export**: Backup and restore home configurations
- **Default Selection**: Set preferred home on app launch

## 📱 Native iOS Experience

### SwiftUI Interface
- **Modern Design**: Clean, intuitive interface following iOS design guidelines
- **Smooth Animations**: Fluid transitions and interactions
- **Accessibility**: Full VoiceOver and accessibility support
- **Responsive Layout**: Adapts to different screen sizes and orientations

### iOS Integration
- **System Appearance**: Automatic light/dark mode switching
- **Background Refresh**: Continue updating when app is backgrounded
- **Multitasking**: Split-screen and slide-over support on iPad
- **Keyboard Shortcuts**: External keyboard support for power users

### Performance Optimization
- **Efficient Rendering**: Optimized for smooth scrolling and interactions
- **Memory Management**: Intelligent caching and memory cleanup
- **Battery Conscious**: Minimal background activity to preserve battery
- **Network Efficiency**: Smart request batching and caching

## 🔧 Advanced Configuration

### Auto-Layout Features
- **Smart Positioning**: Automatic widget arrangement algorithms
- **Gap Detection**: Intelligent space utilization
- **Size Optimization**: Automatic size suggestions based on content
- **Layout Templates**: Predefined layouts for common scenarios

### Data Management
- **Caching Strategy**: Intelligent data caching for offline viewing
- **Sync Handling**: Conflict resolution for configuration changes
- **Backup/Restore**: Export and import configuration data
- **Migration Tools**: Seamless updates and data migration

### Developer Features
- **Debug Mode**: Enhanced logging and diagnostic information
- **API Testing**: Built-in tools for testing service connections
- **Performance Metrics**: Monitor app performance and resource usage
- **Custom Endpoints**: Support for non-standard service configurations

## 🚀 Performance Features

### Optimization
- **Lazy Loading**: Load widget data only when needed
- **Request Batching**: Combine multiple API calls for efficiency
- **Intelligent Caching**: Cache frequently accessed data
- **Background Processing**: Perform heavy operations off the main thread

### Monitoring
- **Response Time Tracking**: Monitor API response times
- **Error Rate Monitoring**: Track service reliability
- **Resource Usage**: Monitor app CPU and memory consumption
- **Network Analytics**: Track data usage and request patterns

## 🔮 Future-Ready Architecture

### Extensibility
- **Plugin System**: Foundation for third-party service plugins
- **API Abstraction**: Easy addition of new service types
- **Modular Design**: Independent service modules
- **Protocol-Oriented**: Consistent interfaces across all services

### Cross-Platform Potential
- **Shared Core**: Reusable business logic for other platforms
- **Universal Widgets**: Widget system designed for scalability
- **Data Synchronization**: Foundation for multi-device sync
- **Cloud Integration**: Ready for cloud-based features

---

These features combine to create a powerful, flexible, and user-friendly platform for managing your self-hosted infrastructure, all while maintaining the security and performance standards expected from a native iOS application.
