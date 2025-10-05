# WordPress Production to Staging Clone Script

This script clones a WordPress production environment to staging for testing and development purposes.

## Features

- **Complete Environment Cloning**: Copies both database and files from production to staging
- **Automatic Backup**: Creates a backup of the current staging environment before cloning
- **URL Replacement**: Automatically updates all URLs from production to staging
- **Database Configuration**: Updates database settings for staging environment
- **Staging-Specific Settings**: Configures debug mode and other staging-specific options
- **Safety Features**: Includes confirmation prompts and validation
- **Cleanup**: Automatically removes old staging backups

## Prerequisites

- SSH access to the server
- WordPress CLI (wp-cli) installed on the server
- MySQL access for database operations
- Proper file permissions for the staging directory

## Configuration

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Update the `.env` file with your specific configuration:
   - SSH connection details
   - Production and staging paths
   - Database credentials
   - URLs for both environments

## Usage

### Basic Usage
```bash
./clone-to-staging.sh
```

### Force Mode (Skip Confirmation)
```bash
./clone-to-staging.sh --force
```

### Help
```bash
./clone-to-staging.sh --help
```

## What the Script Does

1. **Validation**: Checks that all required configuration variables are set
2. **Confirmation**: Prompts for user confirmation (unless using --force)
3. **Backup**: Creates a backup of the current staging environment
4. **Database Clone**: 
   - Exports production database
   - Creates/updates staging database
   - Updates database configuration
   - Replaces all URLs from production to staging
5. **Files Clone**: 
   - Copies all files from production to staging
   - Updates wp-config.php for staging environment
   - Enables debug mode for staging
6. **Cleanup**: Removes old staging backups

## Configuration Variables

### Required Variables
- `PROD_SITE_PATH`: Path to production WordPress installation
- `STAGING_SITE_PATH`: Path to staging WordPress installation
- `PROD_URL`: Production site URL
- `STAGING_URL`: Staging site URL
- `PROD_DB_NAME`: Production database name
- `STAGING_DB_NAME`: Staging database name
- `REMOTE_USER`: SSH username
- `REMOTE_HOST`: SSH hostname

### Optional Variables
- `STAGING_DB_HOST`: Staging database host (default: localhost)
- `STAGING_DB_USER`: Staging database user
- `STAGING_DB_PASSWORD`: Staging database password
- `STAGING_ENV`: Staging environment identifier
- `STAGING_BACKUP_DIR`: Directory for staging backups
- `STAGING_BACKUP_RETENTION_DAYS`: Days to keep staging backups

## Safety Features

- **Backup Creation**: Always creates a backup before making changes
- **Confirmation Prompt**: Requires user confirmation unless using --force
- **Validation**: Checks all required configuration before proceeding
- **Error Handling**: Comprehensive error checking and reporting
- **Rollback Capability**: Backups can be used to restore previous staging state

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure the script has execute permissions and SSH access
2. **Database Connection**: Verify database credentials in the .env file
3. **Path Issues**: Check that all paths in the .env file are correct
4. **WP-CLI Not Found**: Ensure WordPress CLI is installed and accessible

### Logs

The script provides detailed output during execution. Check the console output for any error messages.

## Related Scripts

- `wp_backup_new.zsh`: Multi-site backup script
- `wp_restore.zsh`: Restore script for backups

## Security Notes

- Keep your `.env` file secure and never commit it to version control
- Use strong database passwords
- Ensure SSH keys are properly configured
- Regularly update staging backups
