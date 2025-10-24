# Pi-hole Setup Guide

This guide explains how to set up Pi-hole integration with Labby using username/password authentication to access DNS statistics and monitoring data.

## Prerequisites

- Pi-hole 5.0+ (recommended for best compatibility)
- Pi-hole web interface accessible from your iOS device
- Administrative access to Pi-hole settings
- Network connectivity between your device and the Pi-hole server

## Pi-hole Configuration

### Step 1: Enable Web Interface Authentication

Pi-hole's web interface should already have authentication enabled by default. If not:

1. SSH into your Pi-hole server
2. Run the Pi-hole configuration: `pihole -a -p`
3. Set a strong password for the web interface

### Step 2: Verify Web Interface Access

Before configuring Labby, ensure you can access the Pi-hole web interface:

1. Open your web browser
2. Navigate to your Pi-hole server (e.g., `http://192.168.1.100/admin`)
3. Log in with your admin password
4. Verify you can see the dashboard with DNS statistics

### Step 3: Check API Accessibility

Pi-hole's API endpoints should be accessible without additional configuration. You can test this by visiting:

- `http://your-pi-hole-ip/admin/api.php?summary` (basic stats)
- `http://your-pi-hole-ip/admin/api.php?summaryRaw` (detailed stats)

If you see JSON data, the API is working correctly.

## Configuring Labby

When adding a Pi-hole service in Labby:

### Required Settings

1. **Display Name**: A friendly name for your Pi-hole (e.g., "Home DNS", "Main Pi-hole")
2. **Server URL**: Your Pi-hole web interface URL
   - Format: `http://192.168.1.100` or `https://pihole.example.com`
   - Include the protocol (`http://` or `https://`)
   - **Do not** include `/admin` in the URL - Labby handles this automatically
3. **Username**: Leave blank (Pi-hole doesn't use usernames)
4. **Password**: Your Pi-hole admin password

### Optional Settings

- **Ignore SSL Certificate Errors**: Enable if using HTTPS with self-signed certificates
- **Home Assignment**: Choose which home this Pi-hole belongs to

### Example Configuration

```
Display Name: Home Pi-hole
Server URL: http://192.168.1.100
Username: (leave blank)
Password: your-admin-password
Ignore SSL Certificate Errors: No
Home: Default Home
```

## Available Metrics

Labby can display the following Pi-hole statistics in widgets:

### Core Metrics
- **DNS Queries Today**: Total DNS queries processed today
- **Ads Blocked Today**: Number of blocked queries today
- **Ads Percentage Today**: Percentage of queries blocked
- **Unique Clients**: Number of unique devices making queries
- **Blocking Status**: Whether Pi-hole blocking is enabled/disabled

### Advanced Metrics
- **Queries Forwarded**: DNS queries sent to upstream servers
- **Queries Cached**: DNS queries answered from cache
- **Domains Being Blocked**: Total domains in blocklists
- **Gravity Last Updated**: When blocklists were last updated

## Widget Configuration

### Small Widgets (1×1)
Best for basic monitoring:
- Blocking Status + Ads Blocked Today + Ads Percentage Today

### Medium Widgets (1×2)
Good for detailed stats:
- DNS Queries Today + Ads Blocked Today + Ads Percentage Today + Unique Clients

### Large Widgets (2×2)
Comprehensive dashboard:
- All available metrics for complete Pi-hole overview

## Troubleshooting

### Common Issues

**"Authentication failed"**
- Verify the admin password is correct
- Ensure you can log into the Pi-hole web interface manually
- Check that the Pi-hole web interface is enabled

**"Cannot connect to server"**
- Verify the server URL format (include `http://` or `https://`)
- Don't include `/admin` in the URL
- Test network connectivity to the Pi-hole server
- Check that the Pi-hole web server is running

**"SSL/Certificate error"**
- Enable "Ignore SSL Certificate Errors" in Labby
- Or configure proper SSL certificates on your Pi-hole server

**"No data/zero values"**
- Check that Pi-hole is processing DNS queries
- Verify the API endpoints are accessible (see Step 3 above)
- Ensure Pi-hole isn't in maintenance mode

**"Blocking status shows as unknown"**
- This can happen with newer Pi-hole versions using different API endpoints
- The legacy endpoints should still provide basic statistics

### Testing the Connection

You can test your Pi-hole API manually using curl:

```bash
# Test basic connectivity
curl "http://your-pi-hole-ip/admin/api.php?summary"

# Test authenticated endpoints (if needed)
curl -b "PHPSESSID=your-session" "http://your-pi-hole-ip/admin/api.php?summaryRaw"
```

### Checking Pi-hole Logs

If you're experiencing issues, check the Pi-hole logs:

```bash
# View Pi-hole logs
tail -f /var/log/pihole.log

# View lighttpd (web server) logs
tail -f /var/log/lighttpd/error.log
```

## API Compatibility

### Pi-hole v6.x (Latest)
Labby attempts to use the newer v6 API endpoints first:
- `/api/stats/summary`
- `/api/info/summary`
- `/api/dns/blocking`

### Pi-hole v5.x (Legacy)
Falls back to legacy endpoints:
- `/admin/api.php?summaryRaw`
- Standard web interface authentication

### Version Detection
Labby automatically detects and adapts to your Pi-hole version, trying modern endpoints first and falling back to legacy ones as needed.

## Security Best Practices

1. **Use HTTPS** when possible to encrypt authentication
2. **Strong Passwords** for your Pi-hole admin interface
3. **Network Isolation** - consider placing Pi-hole on a dedicated VLAN
4. **Regular Updates** - keep Pi-hole updated for security patches
5. **Monitor Access** - review Pi-hole logs periodically

## API Endpoints Used

Labby queries the following Pi-hole endpoints:

### Modern (v6+)
- `/api/info/version` - Version information
- `/api/dns/blocking` - Blocking status
- `/api/stats/summary` - Statistics summary

### Legacy (v5)
- `/admin/api.php?summaryRaw` - Raw statistics
- `/admin/scripts/pi-hole/php/auth.php` - Authentication

All queries are read-only and don't modify your Pi-hole configuration.

## Advanced Configuration

### Custom Port
If Pi-hole runs on a non-standard port:
```
Server URL: http://192.168.1.100:8080
```

### Subdirectory Installation
If Pi-hole is installed in a subdirectory:
```
Server URL: http://example.com/pihole
```

### Docker Installation
For Pi-hole running in Docker:
```
Server URL: http://docker-host-ip:port
```

Make sure the container's web port is properly exposed.

## Pi-hole Features Not Supported

Currently, Labby provides read-only Pi-hole integration. The following features are not yet supported but may be added in future versions:

- Enable/disable blocking
- Whitelist/blacklist management  
- Query log viewing
- Client management
- Gravity list updates

---

For more help with Pi-hole setup and configuration, visit the [official Pi-hole documentation](https://docs.pi-hole.net/).