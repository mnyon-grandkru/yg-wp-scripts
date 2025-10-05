# Development Guide

This document provides detailed information for developers working on the WordPress Management CLI.

## Architecture Overview

The WordPress Management CLI is built as a unified bash script with the following architecture:

### Core Components
- **Main Script**: `wp-manager.sh` - Entry point with command parsing
- **Shared Libraries**: Common functions for logging, validation, SSH operations
- **Command Handlers**: Individual functions for each command (clone, archive, backup, restore, list)
- **Configuration**: Environment-based configuration via `.env` file

### Design Principles
- **Single Responsibility**: Each function has a clear, single purpose
- **Shared Libraries**: Common functionality is centralized to reduce duplication
- **Error Handling**: Consistent error handling with `set -euo pipefail`
- **Logging**: Standardized logging with emoji-based status messages
- **Validation**: Comprehensive input validation and SSH connection testing

## Code Structure

### Main Execution Flow
```bash
main() {
    # Parse command line arguments
    # Load environment configuration
    # Execute appropriate command handler
}
```

### Command Handlers
- `cmd_clone()` - Production to staging cloning
- `cmd_archive()` - Single site archiving
- `cmd_backup()` - Multi-site backup
- `cmd_restore()` - Restore from backup
- `cmd_list()` - List available backups

### Shared Libraries
- **Logging Functions**: `log_info()`, `log_success()`, `log_warning()`, `log_error()`, `log_step()`
- **Validation Functions**: `validate_site_key()`, `validate_ssh_connections()`
- **SSH Wrappers**: `ssh_prod()`, `ssh_stage()`
- **Database Functions**: `export_production_db()`, `import_to_staging()`, `cleanup_temp_files()`
- **File Functions**: `sync_wp_content()`, `update_staging_config()`
- **Backup Functions**: `create_staging_backup()`, `cleanup_old_backups()`

## Development Workflow

### Local Development
1. **Clone the repository**
2. **Set up environment**: Copy `.env.example` to `.env` and configure with your site details
3. **Test commands**: Use `--help` to verify installation
4. **Debug mode**: Use `bash -x wp-manager.sh <command>` for debugging

### Testing
```bash
# Test help command
./wp-manager.sh --help

# Test with debug output
bash -x ./wp-manager.sh clone yoursite

# Test validation
./wp-manager.sh clone  # Should show error for missing site key
```

### Adding New Commands

1. **Add command handler function**:
```bash
cmd_newcommand() {
    local site_key="$1"
    # Implementation here
}
```

2. **Add to main() function**:
```bash
case "$command" in
    newcommand)
        cmd_newcommand "${args[0]}"
        ;;
esac
```

3. **Update help documentation**:
```bash
show_usage() {
    # Add new command to usage
}
```

## Configuration Management

### Environment Variables
The script uses a site-key based configuration system. Copy `.env.example` to `.env` and configure:

#### Site Key Pattern (Required)
```bash
# For each site, define 6 variables using the pattern: {SITE_KEY}_{ENVIRONMENT}_{TYPE}
YOURSITE_PROD_SSH="user@prod-server.com"
YOURSITE_STAGE_SSH="user@stage-server.com"
YOURSITE_PROD_PATH="/path/to/production"
YOURSITE_STAGE_PATH="/path/to/staging"
YOURSITE_PROD_URL="https://yoursite.com"
YOURSITE_STAGE_URL="https://staging.yoursite.com"
```

#### Global Configuration (Optional)
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

### Configuration Validation
- **Site Key Validation**: Checks for all 6 required variables per site
- **SSH Connection Testing**: Validates connections before operations
- **Path Validation**: Ensures directories exist and are accessible

## Error Handling

### Error Handling Strategy
- **`set -euo pipefail`**: Exit on errors, undefined variables, pipe failures
- **Consistent Logging**: All errors use `log_error()` function
- **Exit Codes**: Standardized exit codes for automation
- **Graceful Degradation**: Operations fail fast with clear error messages

### Common Error Scenarios
- **Missing Configuration**: Clear messages about missing environment variables
- **SSH Connection Failures**: Timeout and authentication error handling
- **File System Errors**: Permission and disk space error handling
- **Database Errors**: wp-cli command failure handling

## Security Considerations

### SSH Security
- **Key-based Authentication**: Scripts assume SSH keys are configured
- **Connection Timeouts**: 10-second timeout for SSH connections
- **Batch Mode**: Uses `BatchMode=yes` to prevent password prompts

### File Security
- **Environment Files**: `.env` files are gitignored
- **Temporary Files**: Automatic cleanup of temporary files
- **Backup Files**: Proper permissions and cleanup

### Data Security
- **No Local Storage**: Clone command doesn't store data locally
- **Secure Transfers**: Uses SSH/SCP for all data transfers
- **Cleanup**: Automatic cleanup of temporary files

## Performance Considerations

### Optimization Strategies
- **Direct Server Transfer**: Clone uses direct server-to-server transfer
- **Parallel Operations**: Where possible, operations run in parallel
- **Efficient File Transfer**: Uses rsync for file synchronization
- **Minimal Local Storage**: Only archive/backup commands use local storage

### Resource Management
- **Memory Usage**: Minimal memory footprint
- **Disk Usage**: Automatic cleanup of temporary files
- **Network Usage**: Efficient transfer protocols

## Debugging

### Debug Techniques
```bash
# Enable debug output
bash -x ./wp-manager.sh clone yoursite

# Test individual functions
source wp-manager.sh
validate_site_key "yoursite"

# Check environment loading
source .env
echo $YOURSITE_PROD_SSH
```

### Common Debug Scenarios
- **SSH Connection Issues**: Test SSH connections manually
- **Configuration Problems**: Verify environment variables
- **Permission Issues**: Check file and directory permissions
- **wp-cli Issues**: Test wp-cli commands manually

## Testing

### Manual Testing
```bash
# Test each command
./wp-manager.sh clone yoursite
./wp-manager.sh archive yoursite
./wp-manager.sh backup
./wp-manager.sh list
./wp-manager.sh restore <timestamp>
```

### Automated Testing
```bash
# Test validation
./wp-manager.sh clone  # Should fail
./wp-manager.sh restore  # Should fail

# Test help
./wp-manager.sh --help  # Should show help
```

## Deployment

### Production Deployment
1. **Copy script to production server**
2. **Set up environment configuration**
3. **Test with non-critical site first**
4. **Set up cron jobs for automation**

### Cron Job Setup
```bash
# Daily staging clone
0 2 * * * /path/to/wp-manager.sh clone yoursite

# Weekly backup
0 3 * * 0 /path/to/wp-manager.sh backup
```

## Maintenance

### Regular Maintenance Tasks
- **Monitor log files**: Check for errors in cron job logs
- **Update configurations**: Keep environment variables current
- **Clean up old backups**: Monitor disk usage
- **Test restore procedures**: Regularly test backup restoration

### Troubleshooting
- **Check SSH connections**: Verify SSH key authentication
- **Validate configurations**: Ensure all required variables are set
- **Test wp-cli**: Verify WordPress CLI is working
- **Check permissions**: Ensure proper file and directory permissions

## Future Enhancements

### Planned Features
- **Google Drive Integration**: Cloud backup support
- **Database Optimization**: Compression and encryption
- **Monitoring**: Health checks and status reporting
- **Web Interface**: Optional web-based management
- **Plugin Support**: WordPress plugin for remote management

### Extension Points
- **New Commands**: Easy to add new command handlers
- **New Validation**: Extensible validation framework
- **New Storage**: Pluggable storage backends
- **New Protocols**: Support for additional transfer protocols