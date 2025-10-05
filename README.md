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

2. Copy `.env.example` to `.env` and configure with your site details:
   ```bash
   cp .env.example .env
   # Edit .env with your actual site configurations
   ```

3. Test the installation:
   ```bash
   ./wp-manager.sh --help
   ```

## Commands Overview

The WordPress Management CLI provides five commands that work together to handle different aspects of WordPress management:

| Command | Data Flow | Local Storage | Remote Storage | Primary Use Case |
|---------|-----------|---------------|----------------|------------------|
| **`clone`** | Remote → Remote | ❌ No local files | ✅ Direct transfer | Development workflow |
| **`archive`** | Remote → Local | ✅ Creates files | ❌ Cleans up | Long-term backup |
| **`backup`** | Remote → Local | ✅ Creates files | ❌ Cleans up | Multi-site backup |
| **`restore`** | Local → Remote | ❌ Reads files | ✅ Restores data | Disaster recovery |
| **`list`** | Local only | ✅ Reads directory | ❌ No remote access | Backup management |

## Command Details

### `clone <site-key>`
Clone production WordPress to staging environment for development and testing.

**Data Flow:** Production Server → Staging Server (direct transfer)
- **Local Storage:** No local files created
- **Remote Storage:** Direct server-to-server database and file transfer
- **Purpose:** Development workflow, testing, staging updates

**Features:**
- Direct server-to-server database transfer (no local storage)
- wp-content synchronization via rsync
- URL replacement and staging configuration
- Automatic backup creation before cloning
- Cleanup of temporary files on remote servers

**Usage:**
```bash
./wp-manager.sh clone yoursite
./wp-manager.sh clone -i yoursite  # Interactive mode with confirmations
```

**When to Use:**
- Updating staging environment for testing
- Preparing for development work
- Syncing production changes to staging
- Automated staging updates (cron jobs)

### `archive <site-key>`
Archive a single WordPress site to local storage for long-term backup and compliance.

**Data Flow:** Production Server → Local Machine
- **Local Storage:** Creates timestamped backup files locally
- **Remote Storage:** Cleans up temporary files after download
- **Purpose:** Long-term backup, compliance, disaster recovery preparation

**Features:**
- Database export and download to local machine
- Files archive creation and download
- Timestamped backup organization
- Remote cleanup after successful download
- Individual site backup management

**Usage:**
```bash
./wp-manager.sh archive yoursite
```

**When to Use:**
- Creating long-term backups for compliance
- Preparing for server migration
- Manual backup before major changes
- Disaster recovery preparation

### `backup`
Backup multiple WordPress sites to local storage for comprehensive backup operations.

**Data Flow:** Multiple Remote Servers → Local Machine
- **Local Storage:** Creates timestamped backup files locally for each site
- **Remote Storage:** Cleans up temporary files after download
- **Purpose:** Multi-site backup operations, scheduled backups

**Features:**
- Multi-site backup support with individual site subdirectories
- Timestamped directory structure
- Bulk backup operations
- Remote cleanup after successful download
- Organized backup hierarchy

**Usage:**
```bash
./wp-manager.sh backup
```

**When to Use:**
- Scheduled multi-site backup operations
- Bulk backup maintenance
- Server migration preparation
- Regular backup maintenance

### `restore <timestamp>`
Restore WordPress from local backup files for disaster recovery and rollback operations.

**Data Flow:** Local Machine → Remote Server
- **Local Storage:** Reads existing backup files
- **Remote Storage:** Restores database and files to remote server
- **Purpose:** Disaster recovery, rollback from failed updates

**Features:**
- Database restoration from local backup files
- Files restoration from local archives
- Backup validation before restoration
- Remote cleanup after restoration
- Complete site restoration

**Usage:**
```bash
./wp-manager.sh restore 2025-07-20_23-59-00
```

**When to Use:**
- Disaster recovery scenarios
- Rolling back from failed updates
- Restoring from previous working state
- Testing with historical data

### `list`
List and manage available local backup files for backup inventory and restore point identification.

**Data Flow:** Local only (no remote access)
- **Local Storage:** Reads local backup directory structure
- **Remote Storage:** No remote access required
- **Purpose:** Backup management, finding restore points

**Features:**
- Sorted by date (newest first)
- Size information for each backup
- Friendly date formatting
- Usage examples for restore operations
- Backup inventory management

**Usage:**
```bash
./wp-manager.sh list
```

**When to Use:**
- Finding available restore points
- Checking backup sizes and dates
- Backup inventory management
- Identifying which backup to restore from

## Configuration

The script uses a site-key based configuration system. Copy `.env.example` to `.env` and configure with your actual values:

### Site Key Configuration (Required)
```bash
# For each site, define 6 variables using the pattern: {SITE_KEY}_{ENVIRONMENT}_{TYPE}
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

### Global Configuration (Optional)
```bash
# Customize backup settings
LOCAL_BACKUP_DIR=./backups
BACKUP_RETENTION_DAYS=7

# Restore operation settings (when needed)
REMOTE_USER="your_username"
REMOTE_HOST="your-server.com"
REMOTE_BACKUP_DIR="wp_backups"
REMOTE_WP_PATH="/var/www/wordpress"
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

## Workflow Examples

### Development Workflow
A typical development workflow using the CLI commands:

```bash
# 1. Clone production to staging for testing
./wp-manager.sh clone -i yoursite

# 2. Archive before major changes (safety backup)
./wp-manager.sh archive yoursite

# 3. If something goes wrong, restore from backup
./wp-manager.sh list                    # Find available backups
./wp-manager.sh restore 2025-07-20_23-59-00  # Restore from specific backup
```

**Data Flow in Development Workflow:**
```
Production → Staging (clone)
Production → Local (archive)
Local → Production (restore)
```

### Backup Operations
Comprehensive backup management:

```bash
# 1. Create multi-site backup
./wp-manager.sh backup

# 2. Create individual site archive
./wp-manager.sh archive yoursite

# 3. List and manage backups
./wp-manager.sh list

# 4. Restore from backup when needed
./wp-manager.sh restore 2025-07-20_23-59-00
```

**Data Flow in Backup Operations:**
```
Multiple Sites → Local (backup)
Single Site → Local (archive)
Local → Production (restore)
```

### Disaster Recovery Workflow
Complete disaster recovery process:

```bash
# 1. List available backups
./wp-manager.sh list

# 2. Restore from most recent backup
./wp-manager.sh restore 2025-07-20_23-59-00

# 3. Clone to staging for testing
./wp-manager.sh clone -i yoursite

# 4. Create new backup after recovery
./wp-manager.sh archive yoursite
```

### Automated Operations (Cron Jobs)
```bash
# Daily staging clone (automated)
0 2 * * * /path/to/wp-manager.sh clone yoursite

# Weekly multi-site backup (automated)
0 3 * * 0 /path/to/wp-manager.sh backup

# Monthly single-site archive (automated)
0 4 1 * * /path/to/wp-manager.sh archive yoursite
```

## Command Relationships

### Backup Chain
```
archive/backup → list → restore
     ↓              ↓       ↓
  Create        Manage   Recover
```

### Development Chain
```
clone → (development work) → archive → restore (if needed)
  ↓                              ↓         ↓
Sync to staging              Safety    Recovery
```

### Data Flow Visualization
```
┌─────────────┐    clone     ┌─────────────┐
│ Production  │ ────────────→ │   Staging   │
│   Server    │              │   Server    │
└─────────────┘              └─────────────┘
       │
       │ archive/backup
       ↓
┌─────────────┐    restore    ┌─────────────┐
│    Local    │ ────────────→ │ Production  │
│   Storage   │              │   Server    │
└─────────────┘              └─────────────┘
       ↑
       │ list (read-only)
       │
┌─────────────┐
│   Backup    │
│ Management  │
└─────────────┘
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
