# Proxmox VE Setup Guide

This guide explains how to set up Proxmox VE integration with Labby using API tokens for secure authentication.

## Prerequisites

- Proxmox VE 6.2+ (API tokens were introduced in version 6.2)
- Access to the Proxmox web interface with administrative privileges
- Network connectivity between your device and the Proxmox server

## Creating an API Token

### Step 1: Access the Proxmox Web Interface

1. Open your web browser and navigate to your Proxmox server
2. Log in with your administrative credentials (usually `root`)

### Step 2: Navigate to API Tokens

1. In the left sidebar, expand **Datacenter**
2. Click on **Permissions**
3. Select **API Tokens**

### Step 3: Create a New Token

1. Click the **Add** button
2. Fill in the token details:
   - **User**: Select the user (e.g., `root@pam`)
   - **Token ID**: Enter a descriptive name (e.g., `labby`, `homelab`, `monitoring`)
   - **Expire**: Set an expiration date or leave blank for no expiration
   - **Comment**: Optional description for the token
   - **Privilege Separation**:
     - **Unchecked** (recommended): Token has same permissions as the user
     - **Checked**: Token has limited permissions (requires additional setup)

3. Click **Add**

### Step 4: Save the Token Information

⚠️ **Important**: The token secret will only be shown once. Make sure to copy both values:

- **Token ID**: Will be in format `username@realm!tokenname` (e.g., `root@pam!labby`)
- **Token Secret**: A long UUID-like string (e.g., `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`)

## Configuring Labby

When adding a Proxmox service in Labby:

1. **Server URL**: Your Proxmox server URL (e.g., `https://192.168.1.100:8006`)
2. **API Token ID**: The full token ID including user and realm (e.g., `root@pam!labby`)
3. **API Token Secret**: The secret string you copied from step 4
4. **Ignore SSL Certificate Errors**: Enable if using self-signed certificates

## Permissions

### Default Permissions (Privilege Separation Disabled)

When creating a token with privilege separation disabled, the token inherits all permissions from the associated user. For the `root@pam` user, this includes:

- Full cluster administration
- VM/Container management
- Storage access
- User management

### Custom Permissions (Privilege Separation Enabled)

If you enable privilege separation, you'll need to manually assign permissions. For Labby to work properly, the token needs:

- **Path**: `/` (root)
- **Role**: `PVEAuditor` (minimum for read-only monitoring)
- **Role**: `PVEAdmin` (for full management capabilities)

To assign permissions:
1. Go to **Datacenter → Permissions**
2. Click **Add → API Token Permission**
3. Select your token, path `/`, and appropriate role

## Troubleshooting

### Common Issues

**"Authentication failed - invalid API token"**
- Verify the Token ID includes the full format: `user@realm!tokenname`
- Ensure the Token Secret was copied correctly
- Check that the token hasn't expired

**"SSL/Certificate error"**
- Enable "Ignore SSL Certificate Errors" in Labby
- Or configure proper SSL certificates on your Proxmox server

**"Cannot connect to server"**
- Verify the server URL includes the correct port (usually `:8006`)
- Ensure the Proxmox web interface is accessible from your network
- Check firewall settings

**"Access forbidden"**
- If using privilege separation, ensure proper permissions are assigned
- Try recreating the token without privilege separation

### Testing the Token

You can test your API token using curl:

```bash
curl -k -H "Authorization: PVEAPIToken=root@pam!labby:your-secret-here" \
     https://your-server:8006/api2/json/version
```

A successful response should return version information about your Proxmox installation.

## Security Best Practices

1. **Use descriptive token names** to identify their purpose
2. **Set expiration dates** for tokens when possible
3. **Use privilege separation** for tokens that don't need full admin access
4. **Regularly audit and remove** unused tokens
5. **Store token secrets securely** - they provide full access to your Proxmox environment
6. **Consider using dedicated users** for API access rather than root

## API Endpoints Used

Labby queries the following Proxmox API endpoints:

- `/api2/json/version` - Token verification
- `/api2/json/cluster/status` - Cluster information
- `/api2/json/nodes` - Node status and resources
- `/api2/json/cluster/resources?type=vm` - Virtual machines
- `/api2/json/cluster/resources?type=lxc` - LXC containers
- `/api2/json/cluster/resources?type=storage` - Storage pools

All endpoints are read-only operations that don't modify your Proxmox configuration.
