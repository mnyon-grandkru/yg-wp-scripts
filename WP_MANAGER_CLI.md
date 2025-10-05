# WordPress Management CLI

A unified command-line interface for WordPress backup, restore, and staging operations with shared libraries and consistent interface.

## Features

- **Unified Interface**: Single command with multiple subcommands
- **Shared Libraries**: Common functions for logging, validation, SSH operations
- **Consistent Error Handling**: Standardized error messages and exit codes
- **Interactive Mode**: Optional confirmation prompts for safety
- **Multi-Site Support**: Handle multiple WordPress sites with site keys
- **Flexible Configuration**: Support for both legacy and new configuration patterns

## Installation

1. Make the script executable:
   ```bash
   chmod +x wp-manager.sh
   ```

2. Set up your `.env` file with site configurations

3. Test the installation:
   ```bash
   ./wp-manager.sh --help
   ```

## Commands

### `clone <site-key>`
Clone production WordPress to staging environment.

**Features:**
- Direct server-to-server database transfer
- wp-content synchronization
- URL replacement and staging configuration
- Automatic backup creation before cloning
- Cleanup of temporary files

**Usage:**
```bash
./wp-manager.sh clone yoursite
./wp-manager.sh clone -i yoursite  # Interactive mode
```

### `archive <site-key>`
Archive a single WordPress site to local storage.

**Features:**
- Database export and download
- Files archive creation and download
- Timestamped backup organization
- Remote cleanup after download

**Usage:**
```bash
./wp-manager.sh archive yoursite
```

### `backup`
Backup multiple WordPress sites to local storage.

**Features:**
- Multi-site backup support
- Timestamped directory structure
- Individual site subdirectories
- Remote cleanup after download

**Usage:**
```bash
./wp-manager.sh backup
```

### `restore <timestamp>`
Restore WordPress from local backup.

**Features:**
- Database restoration
- Files restoration
- Backup validation
- Remote cleanup

**Usage:**
```bash
./wp-manager.sh restore 2025-07-20_23-59-00
```

### `list`
List available local backups.

**Features:**
- Sorted by date (newest first)
- Size information
- Friendly date formatting
- Usage examples

**Usage:**
```bash
./wp-manager.sh list
```

## Configuration

### Site Key Configuration (Recommended)
```bash
# For each site, define 6 variables
YOURSITE_PROD_SSH="user@prod-server.com"
YOURSITE_STAGE_SSH="user@stage-server.com"
YOURSITE_PROD_PATH="/var/www/yoursite"
YOURSITE_STAGE_PATH="/var/www/yoursite-staging"
YOURSITE_PROD_URL="https://yoursite.com"
YOURSITE_STAGE_URL="https://staging.yoursite.com"

# Additional sites
BLOG_PROD_SSH="user@blog-prod.com"
BLOG_STAGE_SSH="user@blog-stage.com"
BLOG_PROD_PATH="/var/www/blog"
BLOG_STAGE_PATH="/var/www/blog-staging"
BLOG_PROD_URL="https://blog.yoursite.com"
BLOG_STAGE_URL="https://staging-blog.yoursite.com"
```

### Legacy Configuration (for backup/restore)
```bash
# Multi-site backup configuration
SITE_PATHS="public_html
staging_html
dev_html"

SITE_NAMES="production
staging
development"

# General settings
REMOTE_USER="your_username"
REMOTE_HOST="your-server.com"
LOCAL_BACKUP_DIR="~/wp_backups"
REMOTE_BACKUP_DIR="wp_backups"
```

## Options

### `-i, --interactive`
Run in interactive mode with confirmation prompts.

**Use Cases:**
- Manual operations requiring confirmation
- Safety-critical operations
- Testing and development

**Example:**
```bash
./wp-manager.sh clone -i yoursite
```

### `-h, --help`
Show help message and usage information.

## Examples

### Development Workflow
```bash
# Clone production to staging for testing
./wp-manager.sh clone -i yoursite

# Archive before major changes
./wp-manager.sh archive yoursite

# Restore if something goes wrong
./wp-manager.sh restore 2025-07-20_23-59-00
```

### Backup Operations
```bash
# Daily multi-site backup
./wp-manager.sh backup

# Single site archive
./wp-manager.sh archive yoursite

# List available backups
./wp-manager.sh list
```

### Cron Job Examples
```bash
# Daily staging clone (automated)
0 2 * * * /path/to/wp-manager.sh clone yoursite

# Weekly backup (automated)
0 3 * * 0 /path/to/wp-manager.sh backup
```

## Error Handling

The CLI provides consistent error handling:

- **Validation Errors**: Clear messages about missing configuration
- **SSH Errors**: Connection timeout and authentication issues
- **File Errors**: Missing backups, permission issues
- **Exit Codes**: Standardized exit codes for automation

## Debugging

### Enable Verbose Output
```bash
# Add debug output to any command
bash -x ./wp-manager.sh clone yoursite
```

### Check Configuration
```bash
# Validate environment loading
./wp-manager.sh --help  # Should show help without errors
```

### Test SSH Connections
```bash
# Test individual SSH connections
ssh user@prod-server.com "echo 'SSH test'"
ssh user@stage-server.com "echo 'SSH test'"
```

## Migration from Individual Scripts

### From wp_backup.zsh
```bash
# Old
./wp_backup.zsh

# New
./wp-manager.sh archive yoursite
```

### From wp_backup_new.zsh
```bash
# Old
./wp_backup_new.zsh

# New
./wp-manager.sh backup
```

### From wp_restore.zsh
```bash
# Old
./wp_restore.zsh 2025-07-20_23-59-00

# New
./wp-manager.sh restore 2025-07-20_23-59-00
```

### From clone-to-staging.sh
```bash
# Old
./clone-to-staging.sh yoursite

# New
./wp-manager.sh clone yoursite
```

## Benefits of Unified CLI

✅ **Consistent Interface**: All operations use the same command structure
✅ **Shared Libraries**: Common functions reduce code duplication
✅ **Easier Debugging**: Single codebase to maintain and debug
✅ **Better Error Handling**: Standardized error messages and codes
✅ **Simplified Documentation**: One set of docs for all operations
✅ **Easier Testing**: Single script to test all functionality
✅ **Future Extensibility**: Easy to add new commands and features

## Future Enhancements

- **Google Drive Integration**: Cloud backup support
- **Database Optimization**: Compression and encryption options
- **Monitoring**: Health checks and status reporting
- **Web Interface**: Optional web-based management
- **Plugin Support**: WordPress plugin for remote management
