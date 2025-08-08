# Jellyfin Setup Guide

This guide explains how to set up Jellyfin integration with Labby using either username/password authentication or API keys.

## Prerequisites

- Jellyfin server running and accessible on your network
- Admin access to your Jellyfin server
- Network connectivity between your device and the Jellyfin server

## Authentication Methods

Labby supports two authentication methods for Jellyfin:

### 1. Username & Password

This is the most common method and uses your existing Jellyfin user account.

**Requirements:**
- A valid Jellyfin user account with appropriate permissions
- The user must have access to the `/System/Info` endpoint

**Setup:**
1. Ensure your Jellyfin user account exists and has the correct permissions
2. Use your username and password in Labby
3. Labby will automatically handle the authentication flow

### 2. API Key

For more secure, token-based authentication.

**Requirements:**
- API key generated from your Jellyfin server
- The API key must have appropriate permissions

## Creating an API Key

### Step 1: Access Jellyfin Admin Dashboard

1. Open your web browser and navigate to your Jellyfin server
2. Log in with an administrator account

### Step 2: Generate API Key

1. Go to **Dashboard** → **Advanced** → **API Keys**
2. Click **New API Key**
3. Fill in the details:
   - **Name**: Enter a descriptive name (e.g., `Labby`, `Mobile App`)
   - **User**: Select the user account (optional, leave blank for admin access)
   - **Permissions**: Ensure it has access to System Information

4. Click **Create**
5. **Important**: Copy the API key immediately - it won't be shown again

### Step 3: Save the API Key

Store the API key securely. You'll need it when configuring Labby.

## Configuring Labby

When adding a Jellyfin service in Labby:

1. **Server URL**: Your Jellyfin server URL (e.g., `http://192.168.1.100:8096` or `https://jellyfin.yourdomain.com`)
2. **Authentication Method**: Choose between:
   - **Username & Password**: Enter your Jellyfin username and password
   - **API Key**: Enter the API key you generated
3. **Ignore SSL Certificate Errors**: Enable if using self-signed certificates

## Permissions

### Username & Password Authentication

When using username/password authentication, the user account needs:

- **Minimum**: Access to `/System/Info` endpoint for basic information
- **Recommended**: Admin access for full functionality

### API Key Authentication

API keys inherit the permissions of the associated user account. For full functionality, ensure the API key has:

- System Information access
- User management (if needed)
- Library access (if needed)

## Troubleshooting

### Common Issues

**"Authentication failed - invalid credentials"**
- Verify your username and password are correct
- Ensure the user account exists and is not disabled
- Check that the user has appropriate permissions

**"HTTP status code: 401"**
- Verify the API key is correct and not expired
- Ensure the API key has the necessary permissions
- Check that the server URL is correct

**"Cannot connect to server"**
- Verify the server URL includes the correct port (usually `:8096`)
- Ensure the Jellyfin web interface is accessible from your network
- Check firewall settings

**"SSL/Certificate error"**
- Enable "Ignore SSL Certificate Errors" in Labby
- Or configure proper SSL certificates on your Jellyfin server

**"Error processing request"**
- Ensure you're using the correct authentication method
- Verify the server URL format (no trailing slash)
- Check that Jellyfin is running and accessible

### Testing the Connection

You can test your Jellyfin connection using curl:

**Username/Password:**
```bash
curl -X POST "http://your-server:8096/Users/AuthenticateByName" \
     -H "Content-Type: application/json" \
     -H "Authorization: MediaBrowser Client=\"Test\", Device=\"curl\", DeviceId=\"test\", Version=\"1.0.0\"" \
     -d '{"Username":"your-username","Pw":"your-password"}'
```

**API Key:**
```bash
curl -H "X-Emby-Token: your-api-key" \
     "http://your-server:8096/System/Info"
```

A successful response should return information about your Jellyfin installation.

## Security Best Practices

1. **Use API keys for production**: API keys are more secure than username/password
2. **Limit API key permissions**: Only grant necessary permissions to API keys
3. **Use HTTPS**: Enable SSL/TLS on your Jellyfin server for secure connections
4. **Regular key rotation**: Periodically regenerate API keys
5. **Monitor access**: Regularly review API key usage and permissions
6. **Secure storage**: Labby stores credentials securely in the iOS Keychain

## API Endpoints Used

Labby queries the following Jellyfin API endpoints:

- `/Users/AuthenticateByName` - User authentication (username/password)
- `/System/Info` - System information and version

All endpoints are read-only operations that don't modify your Jellyfin configuration.

## Network Configuration

### Local Network Access

For local network access, ensure:

- Jellyfin is configured to bind to `0.0.0.0` or your local IP
- Firewall allows connections on port 8096 (default)
- Your device and Jellyfin server are on the same network

### Remote Access

For remote access:

- Configure port forwarding on your router (port 8096)
- Use a domain name with SSL certificate
- Consider using a reverse proxy (nginx, Traefik, etc.)
- Enable HTTPS in Jellyfin settings