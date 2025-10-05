#!/bin/zsh

# ====================================================================
# WordPress Production to Staging Clone Script
# --------------------------------------------------------------------
# This script clones a WordPress production environment to staging
# for testing and development purposes. It creates a complete copy
# of the production database and files in a staging environment.
#
# Configuration is handled via a .env file in the same directory.
# ====================================================================

# === Load .env file ===
# Locates the .env file relative to the script's location.
ENV_FILE="${0:A:h}/.env"
if [ -f "$ENV_FILE" ]; then
  # Exports variables from the .env file for use in the script.
  export $(grep -v '^#' "$ENV_FILE" | xargs)
else
  echo "❌ .env file not found at $ENV_FILE"
  echo "Please create a .env file with the required configuration variables."
  exit 1
fi

# === SSH COMMAND WRAPPER ===
# A helper function to execute commands on the remote server.
# Simplifies running remote commands by handling the SSH connection details.
ssh_cmd() {
  ssh "${REMOTE_USER}@${REMOTE_HOST}" "$1"
}

# === VALIDATION FUNCTIONS ===
validate_config() {
  local missing_vars=()
  
  # Check required variables
  [ -z "$PROD_SITE_PATH" ] && missing_vars+=("PROD_SITE_PATH")
  [ -z "$STAGING_SITE_PATH" ] && missing_vars+=("STAGING_SITE_PATH")
  [ -z "$PROD_DB_NAME" ] && missing_vars+=("PROD_DB_NAME")
  [ -z "$STAGING_DB_NAME" ] && missing_vars+=("STAGING_DB_NAME")
  [ -z "$REMOTE_USER" ] && missing_vars+=("REMOTE_USER")
  [ -z "$REMOTE_HOST" ] && missing_vars+=("REMOTE_HOST")
  [ -z "$STAGING_URL" ] && missing_vars+=("STAGING_URL")
  
  if [ ${#missing_vars[@]} -gt 0 ]; then
    echo "❌ Missing required configuration variables:"
    printf "   - %s\n" "${missing_vars[@]}"
    echo "Please check your .env file."
    exit 1
  fi
}

# === BACKUP FUNCTIONS ===
create_staging_backup() {
  local timestamp=$(date +'%Y-%m-%d_%H-%M-%S')
  local backup_dir="${STAGING_BACKUP_DIR:-~/staging_backups}/${timestamp}"
  
  echo "📦 Creating backup of current staging environment..."
  ssh_cmd "mkdir -p ${backup_dir}"
  
  # Backup staging database if it exists
  if ssh_cmd "cd ~/${STAGING_SITE_PATH} && wp db check --quiet" 2>/dev/null; then
    echo "  - Backing up staging database..."
    ssh_cmd "cd ~/${STAGING_SITE_PATH} && wp db export ${backup_dir}/staging_db_backup_${timestamp}.sql --quiet"
  fi
  
  # Backup staging files if they exist
  if ssh_cmd "[ -d ~/${STAGING_SITE_PATH} ]"; then
    echo "  - Backing up staging files..."
    ssh_cmd "cd ~ && tar -czf ${backup_dir}/staging_files_backup_${timestamp}.tar.gz ${STAGING_SITE_PATH}"
  fi
  
  echo "  - Staging backup created at: ${backup_dir}"
}

# === CLONE FUNCTIONS ===
clone_database() {
  echo "🔄 Cloning production database to staging..."
  
  # Create staging database if it doesn't exist
  ssh_cmd "mysql -e 'CREATE DATABASE IF NOT EXISTS ${STAGING_DB_NAME};'"
  
  # Export production database
  local temp_db_file="/tmp/prod_db_export_$(date +%s).sql"
  echo "  - Exporting production database..."
  ssh_cmd "cd ~/${PROD_SITE_PATH} && wp db export ${temp_db_file} --quiet"
  
  # Import to staging database
  echo "  - Importing to staging database..."
  ssh_cmd "mysql ${STAGING_DB_NAME} < ${temp_db_file}"
  
  # Update staging database configuration
  echo "  - Updating staging database configuration..."
  ssh_cmd "cd ~/${STAGING_SITE_PATH} && wp config set DB_NAME ${STAGING_DB_NAME} --type=constant"
  ssh_cmd "cd ~/${STAGING_SITE_PATH} && wp config set DB_HOST ${STAGING_DB_HOST:-localhost} --type=constant"
  ssh_cmd "cd ~/${STAGING_SITE_PATH} && wp config set DB_USER ${STAGING_DB_USER:-${DB_USER}} --type=constant"
  ssh_cmd "cd ~/${STAGING_SITE_PATH} && wp config set DB_PASSWORD ${STAGING_DB_PASSWORD:-${DB_PASSWORD}} --type=constant"
  
  # Update site URLs
  echo "  - Updating site URLs..."
  ssh_cmd "cd ~/${STAGING_SITE_PATH} && wp search-replace '${PROD_URL}' '${STAGING_URL}' --all-tables --dry-run"
  ssh_cmd "cd ~/${STAGING_SITE_PATH} && wp search-replace '${PROD_URL}' '${STAGING_URL}' --all-tables"
  
  # Clean up temp file
  ssh_cmd "rm ${temp_db_file}"
  
  echo "  ✅ Database cloning completed!"
}

clone_files() {
  echo "📁 Cloning production files to staging..."
  
  # Create staging directory if it doesn't exist
  ssh_cmd "mkdir -p ~/${STAGING_SITE_PATH}"
  
  # Copy files from production to staging
  echo "  - Copying files..."
  ssh_cmd "rsync -av --delete ~/${PROD_SITE_PATH}/ ~/${STAGING_SITE_PATH}/"
  
  # Update wp-config.php for staging
  echo "  - Updating wp-config.php for staging..."
  ssh_cmd "cd ~/${STAGING_SITE_PATH} && wp config set WP_DEBUG true --type=constant"
  ssh_cmd "cd ~/${STAGING_SITE_PATH} && wp config set WP_DEBUG_LOG true --type=constant"
  ssh_cmd "cd ~/${STAGING_SITE_PATH} && wp config set WP_DEBUG_DISPLAY false --type=constant"
  
  # Add staging-specific configuration
  if [ -n "$STAGING_ENV" ]; then
    ssh_cmd "cd ~/${STAGING_SITE_PATH} && wp config set WP_ENV '${STAGING_ENV}' --type=constant"
  fi
  
  echo "  ✅ Files cloning completed!"
}

# === CLEANUP FUNCTIONS ===
cleanup_old_backups() {
  local backup_dir="${STAGING_BACKUP_DIR:-~/staging_backups}"
  local retention_days="${STAGING_BACKUP_RETENTION_DAYS:-7}"
  
  echo "🧹 Cleaning up old staging backups (older than ${retention_days} days)..."
  ssh_cmd "find ${backup_dir} -type d -mtime +${retention_days} -exec rm -rf {} + 2>/dev/null || true"
}

# === MAIN EXECUTION ===
main() {
  echo "🚀 Starting WordPress production to staging clone..."
  echo "   Production: ${PROD_URL} (${PROD_SITE_PATH})"
  echo "   Staging: ${STAGING_URL} (${STAGING_SITE_PATH})"
  echo ""
  
  # Validate configuration
  validate_config
  
  # Confirm before proceeding
  if [ "$1" != "--force" ]; then
    echo "⚠️  This will overwrite the current staging environment!"
    echo "   A backup will be created before proceeding."
    echo ""
    read "confirm?Do you want to continue? (y/N): "
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "❌ Operation cancelled."
      exit 0
    fi
  fi
  
  # Create backup of current staging
  create_staging_backup
  
  # Clone production to staging
  clone_database
  clone_files
  
  # Cleanup old backups
  cleanup_old_backups
  
  echo ""
  echo "✅ WordPress production to staging clone completed successfully!"
  echo "   Staging site: ${STAGING_URL}"
  echo "   Staging path: ${STAGING_SITE_PATH}"
  echo ""
  echo "🔧 Next steps:"
  echo "   - Test the staging site functionality"
  echo "   - Update any staging-specific plugins or themes"
  echo "   - Configure staging-specific settings"
}

# === SCRIPT EXECUTION ===
# Show usage if help is requested
if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "WordPress Production to Staging Clone Script"
  echo ""
  echo "Usage: $0 [--force]"
  echo ""
  echo "Options:"
  echo "  --force    Skip confirmation prompt"
  echo "  -h, --help Show this help message"
  echo ""
  echo "Configuration:"
  echo "  All configuration is handled via the .env file."
  echo "  See .env.example for required variables."
  exit 0
fi

# Run main function
main "$@"
