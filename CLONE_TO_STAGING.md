# WordPress Production to Staging Clone Script (Hybrid Approach)

This script clones a WordPress production environment to staging with support for both interactive and automated modes. It combines the best features of both simple and comprehensive approaches.

## Features

- **Multi-Site Support**: Handle multiple sites with different configurations using site keys
- **Dual Mode Operation**: Interactive mode for manual operations, automated mode for cron jobs
- **Object-Oriented Design**: Clean, maintainable code with separate classes for different operations
- **Complete Environment Cloning**: Copies both database and files from production to staging
- **Automatic Backup**: Creates a backup of the current staging environment before cloning
- **URL Replacement**: Automatically updates all URLs from production to staging
- **Staging-Specific Settings**: Configures debug mode and other staging-specific options
- **Safety Features**: Includes validation, SSH connection testing, and confirmation prompts
- **Cleanup**: Automatically removes old staging backups and temporary files

## Prerequisites

- SSH access to both production and staging servers
- WordPress CLI (wp-cli) installed on both servers
- MySQL access for database operations
- Proper file permissions for the staging directory
- Bash shell (version 4.0 or higher)

## Configuration

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Update the `.env` file with your site configurations using the pattern:
   ```bash
   SITEKEY_PROD_SSH="user@prod-server.com"
   SITEKEY_STAGE_SSH="user@stage-server.com"
   SITEKEY_PROD_PATH="/path/to/production/wordpress"
   SITEKEY_STAGE_PATH="/path/to/staging/wordpress"
   SITEKEY_PROD_URL="https://yoursite.com"
   SITEKEY_STAGE_URL="https://staging.yoursite.com"
   ```

## Usage

### Interactive Mode (Manual Operations)
```bash
./clone-to-staging.sh --interactive yoursite
./clone-to-staging.sh -i yoursite
```

### Automated Mode (Cron Jobs)
```bash
./clone-to-staging.sh yoursite
```

### Help
```bash
./clone-to-staging.sh --help
```

## What the Script Does

1. **Validation**: 
   - Checks that all required configuration variables are set for the site key
   - Validates SSH connections to both production and staging servers
2. **Confirmation**: Prompts for user confirmation in interactive mode
3. **Backup**: Creates a backup of the current staging environment
4. **Database Clone**: 
   - Exports production database
   - Uploads dump to staging server
   - Resets staging database and imports production data
   - Replaces all URLs from production to staging
   - Updates WordPress options for staging environment
5. **Files Clone**: 
   - Syncs wp-content directory from production to staging
   - Updates wp-config.php for staging environment
   - Enables debug mode and staging-specific settings
6. **Cleanup**: Removes temporary files and old staging backups

## Configuration Variables

### Required Variables (per site)
Each site requires 6 variables with the pattern `SITEKEY_VARIABLE`:

- `SITEKEY_PROD_SSH`: SSH connection string for production server
- `SITEKEY_STAGE_SSH`: SSH connection string for staging server
- `SITEKEY_PROD_PATH`: Path to production WordPress installation
- `SITEKEY_STAGE_PATH`: Path to staging WordPress installation
- `SITEKEY_PROD_URL`: Production site URL
- `SITEKEY_STAGE_URL`: Staging site URL

### Example Configuration
```bash
# For a site called 'yoursite'
YOURSITE_PROD_SSH="user@prod-server.com"
YOURSITE_STAGE_SSH="user@stage-server.com"
YOURSITE_PROD_PATH="/var/www/yoursite"
YOURSITE_STAGE_PATH="/var/www/yoursite-staging"
YOURSITE_PROD_URL="https://yoursite.com"
YOURSITE_STAGE_URL="https://staging.yoursite.com"
```

### Global Configuration
- `BACKUP_RETENTION_DAYS`: Days to keep staging backups (default: 7)

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


