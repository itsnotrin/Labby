# qBittorrent Setup Guide

This guide explains how to set up qBittorrent integration with Labby using username/password authentication.

## Prerequisites

- qBittorrent server running and accessible on your network
- Web UI enabled in qBittorrent settings
- Admin access to your qBittorrent server
- Network connectivity between your device and the qBittorrent server

## Authentication

qBittorrent uses username/password authentication through its Web UI interface.

**Requirements:**
- A valid qBittorrent user account
- Web UI must be enabled in qBittorrent settings
- The user must have appropriate permissions

## Enabling Web UI

### Step 1: Open qBittorrent Settings

1. Launch qBittorrent on your server
2. Go to **Tools** → **Preferences** (or **Edit** → **Preferences** on some systems)

### Step 2: Enable Web UI

1. In the left sidebar, click **Web UI**
2. Check the box for **Web User Interface (Remote control)**
3. Configure the following settings:
   - **IP address**: Set to `0.0.0.0` for all interfaces or your specific IP
   - **Port**: Default is `8080`, but you can change it
   - **Username**: Create a username for web access
   - **Password**: Set a secure password
   - **Click "Apply" to save settings**

### Step 3: Restart qBittorrent

After enabling Web UI, restart qBittorrent for the changes to take effect.

## Configuring Labby

When adding a qBittorrent service in Labby:

1. **Server URL**: Your qBittorrent Web UI URL (e.g., `http://192.168.1.100:8080` or `https://qbittorrent.yourdomain.com`)
2. **Authentication Method**: Username & Password (only option available)
3. **Username**: The username you set in qBittorrent Web UI settings
4. **Password**: The password you set in qBittorrent Web UI settings
5. **Ignore SSL Certificate Errors**: Enable if using self-signed certificates

## Permissions

The qBittorrent user account needs appropriate permissions to:

- Access the Web UI interface
- View system information and version
- Monitor torrent status (for future features)

## Troubleshooting

### Common Issues

**"HTTP status code: 401"**
- Verify your username and password are correct
- Ensure the Web UI is enabled in qBittorrent settings
- Check that qBittorrent is running and accessible

**"Cannot connect to server"**
- Verify the server URL includes the correct port (usually `:8080`)
- Ensure the Web UI is enabled and accessible from your network
- Check firewall settings to allow connections on the Web UI port
- Verify qBittorrent is running

**"SSL/Certificate error"**
- Enable "Ignore SSL Certificate Errors" in Labby
- Or configure proper SSL certificates on your qBittorrent server

**"Invalid URL"**
- Ensure the URL format is correct (e.g., `http://192.168.1.100:8080`)
- Don't include trailing slashes
- Use the correct protocol (http/https)

### Testing the Connection

You can test your qBittorrent connection using curl:

```bash
# First, authenticate
curl -X POST "http://your-server:8080/api/v2/auth/login" \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "username=your-username&password=your-password"

# Then get version info (if authentication was successful)
curl -H "Cookie: SID=your-session-id" \
     "http://your-server:8080/api/v2/app/version"
```

A successful authentication should return "Ok." and a successful version request should return the qBittorrent version.

## Security Best Practices

1. **Use strong passwords**: Create a secure password for Web UI access
2. **Limit network access**: Only allow Web UI access from trusted networks
3. **Use HTTPS**: Enable SSL/TLS on your qBittorrent server for secure connections
4. **Regular password updates**: Periodically change your Web UI password
5. **Monitor access**: Regularly check for unauthorized access attempts
6. **Secure storage**: Labby stores credentials securely in the iOS Keychain

## API Endpoints Used

Labby queries the following qBittorrent API endpoints:

- `/api/v2/auth/login` - User authentication (username/password)
- `/api/v2/app/version` - Application version information

All endpoints are read-only operations that don't modify your qBittorrent configuration.

## Network Configuration

### Local Network Access

For local network access, ensure:

- qBittorrent Web UI is configured to bind to `0.0.0.0` or your local IP
- Firewall allows connections on the Web UI port (default: 8080)
- Your device and qBittorrent server are on the same network

### Remote Access

For remote access:

- Configure port forwarding on your router (Web UI port)
- Use a domain name with SSL certificate
- Consider using a reverse proxy (nginx, Traefik, etc.)
- Enable HTTPS in qBittorrent Web UI settings

## Version Compatibility

Labby has been tested with:
- qBittorrent 4.5.x
- qBittorrent 4.4.x
- qBittorrent 4.3.x

The integration uses qBittorrent's Web API v2 and should work with most recent versions.

## Advanced Configuration

### Custom Port

If you're using a custom port for the Web UI:

1. In qBittorrent settings, go to **Web UI**
2. Change the port number to your preferred port
3. Update the URL in Labby to include the custom port
4. Ensure your firewall allows connections on the custom port

### SSL/TLS Setup

For secure connections:

1. In qBittorrent settings, go to **Web UI**
2. Check **Use HTTPS instead of HTTP**
3. Configure your SSL certificate
4. Use `https://` URLs in Labby
5. Enable "Ignore SSL Certificate Errors" if using self-signed certificates
