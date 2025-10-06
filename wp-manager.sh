#!/usr/bin/env bash
# ====================================================================
# WordPress Management CLI
# --------------------------------------------------------------------
# Unified command-line interface for WordPress backup, restore, and
# staging operations with shared libraries and consistent interface.
# ====================================================================

set -euo pipefail

# === GLOBAL VARIABLES ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
INTERACTIVE_MODE=false
LOCAL_MODE=true
BACKUP_RETENTION_DAYS=7

# === SHARED LIBRARIES ===

# === LOGGING FUNCTIONS ===
log_info() {
    echo "ℹ️  $1"
}

log_success() {
    echo "✅ $1"
}

log_warning() {
    echo "⚠️  $1"
}

log_error() {
    echo "❌ $1" >&2
}

log_step() {
    echo "🔹 $1" >&2
}

# === ENVIRONMENT FUNCTIONS ===
load_environment() {
    if [ -f "$ENV_FILE" ]; then
        set -a
        source "$ENV_FILE"
        set +a
    else
        log_error ".env file not found at $ENV_FILE"
        log_error "Please create a .env file with your site configurations."
        exit 1
    fi
}

# === VALIDATION FUNCTIONS ===
validate_site_key() {
    local site_key="$1"
    if [ -z "$site_key" ]; then
        log_error "Site key is required"
        return 1
    fi

    # Convert to uppercase for consistency
    SITE_KEY=$(echo "$site_key" | tr '[:lower:]' '[:upper:]')

    # Check if required environment variables exist
    local required_vars=(
        "${SITE_KEY}_PROD_SSH"
        "${SITE_KEY}_STAGE_SSH"
        "${SITE_KEY}_PROD_PATH"
        "${SITE_KEY}_STAGE_PATH"
        "${SITE_KEY}_PROD_URL"
        "${SITE_KEY}_STAGE_URL"
    )

    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            log_error "Required variable '$var' not found in .env"
            log_error "Please ensure all required variables are set for site key: $SITE_KEY"
            return 1
        fi
    done

    return 0
}

validate_ssh_connections() {
    if [ "$LOCAL_MODE" = true ]; then
        log_step "Local mode: skipping SSH validation..."
        log_success "Local mode validation complete"
        return 0
    fi

    local prod_ssh="${!PROD_SSH_VAR}"
    local stage_ssh="${!STAGE_SSH_VAR}"

    log_step "Validating SSH connections..."

    # Test production SSH connection
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$prod_ssh" "echo 'SSH connection test'" >/dev/null 2>&1; then
        log_error "Cannot connect to production server: $prod_ssh"
        return 1
    fi

    # Test staging SSH connection
    if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$stage_ssh" "echo 'SSH connection test'" >/dev/null 2>&1; then
        log_error "Cannot connect to staging server: $stage_ssh"
        return 1
    fi

    log_success "SSH connections validated"
    return 0
}

# === COMMAND EXECUTION AGENTS ===
local_command_agent() {
    # Execute command locally using bash
    bash -c "$*"
}

remote_command_agent() {
    local ssh_target="$1"
    shift
    ssh "$ssh_target" "$@"
}

# === COMMAND CLIENT ===
command_client() {
    local target="$1"
    shift

    if [ "$LOCAL_MODE" = true ]; then
        local_command_agent "$*"
    else
        remote_command_agent "$target" "$@"
    fi
}

# === SERVER INTERFACE FUNCTIONS ===
ssh_prod() {
    command_client "${!PROD_SSH_VAR}" "$*"
}

ssh_stage() {
    command_client "${!STAGE_SSH_VAR}" "$*"
}

# === BACKUP FUNCTIONS ===
create_staging_backup() {
    local backup_timestamp=$(date +%Y%m%d-%H%M%S)
    local backup_file="staging-backup-${backup_timestamp}.sql"

    log_step "Creating staging backup..."

    if ssh_stage "cd ${!STAGE_PATH_VAR} && wp db check --quiet" 2>/dev/null; then
        ssh_stage "cd ${!STAGE_PATH_VAR} && wp db export ${backup_file} --quiet"
        log_success "Staging backup created: ${backup_file}"
        echo "${backup_file}"
    else
        log_warning "No existing staging database found, skipping backup"
        echo ""
    fi
}

cleanup_old_backups() {
    log_step "Cleaning up old backups (older than ${BACKUP_RETENTION_DAYS} days)..."

    ssh_stage "
        find ${!STAGE_PATH_VAR} -name 'staging-backup-*.sql' -type f -mtime +${BACKUP_RETENTION_DAYS} -delete 2>/dev/null || true
    "

    log_success "Old backups cleaned up"
}

# === DATABASE FUNCTIONS ===
export_production_db() {
    local sql_dump="${SITE_KEY,,}-$(date +%Y%m%d-%H%M%S).sql"

    log_step "Exporting production database..."
    ssh_prod "cd ${!PROD_PATH_VAR} && wp db export ${sql_dump} --quiet"

    echo "$sql_dump"
}

import_to_staging() {
    local sql_dump="$1"

    if [ "$LOCAL_MODE" = true ]; then
        # Local mode - use direct copy
        log_step "Local mode: copying database dump..."
        cp "${!PROD_PATH_VAR}/${sql_dump}" "${!STAGE_PATH_VAR}/"
    else
        # Remote mode - use scp
        log_step "Copying database dump to staging server..."
        ssh_prod "scp ${!PROD_PATH_VAR}/${sql_dump} ${!STAGE_SSH_VAR}:${!STAGE_PATH_VAR}/"
    fi

    log_step "Importing database to staging..."
    ssh_stage "
        cd ${!STAGE_PATH_VAR} &&
        wp db reset --yes &&
        wp db import ${sql_dump} &&
        wp search-replace '${!PROD_URL_VAR}' '${!STAGE_URL_VAR}' --skip-columns=guid --quiet &&
        wp option update siteurl '${!STAGE_URL_VAR}' &&
        wp option update home '${!STAGE_URL_VAR}' &&
        wp option update blog_public 0 &&
        wp cache flush
    "

    log_success "Database imported and configured for staging"
}

cleanup_temp_files() {
    local sql_dump="$1"

    log_step "Cleaning up temporary database files..."
    ssh_prod "rm -f ${!PROD_PATH_VAR}/${sql_dump}" 2>/dev/null || true
    ssh_stage "rm -f ${!STAGE_PATH_VAR}/${sql_dump}" 2>/dev/null || true

    log_success "Temporary database files cleaned up"
}

# === FILE FUNCTIONS ===
sync_wp_content() {
    log_step "Syncing wp-content directory..."

    if [ "$LOCAL_MODE" = true ]; then
        # Local mode - use direct rsync
        log_step "Local mode: using direct rsync..."
        rsync -az --delete "${!PROD_PATH_VAR}/wp-content/" "${!STAGE_PATH_VAR}/wp-content/"
    else
        # Check if production and staging are on the same machine
        local prod_host=$(echo "${!PROD_SSH_VAR}" | cut -d'@' -f2)
        local stage_host=$(echo "${!STAGE_SSH_VAR}" | cut -d'@' -f2)

        if [ "$prod_host" = "$stage_host" ]; then
            # Same machine - use local rsync for efficiency
            log_step "Same machine detected, using local rsync..."
            ssh_prod "rsync -az --delete ${!PROD_PATH_VAR}/wp-content/ ${!STAGE_PATH_VAR}/wp-content/"
        else
            # Different machines - use remote rsync
            rsync -az --delete \
                "${!PROD_SSH_VAR}:${!PROD_PATH_VAR}/wp-content/" \
                "${!STAGE_SSH_VAR}:${!STAGE_PATH_VAR}/wp-content/"
        fi
    fi

    log_success "wp-content synchronized"
}

update_staging_config() {
    log_step "Updating staging-specific configuration..."

    ssh_stage "
        cd ${!STAGE_PATH_VAR} &&
        wp config set WP_DEBUG true --type=constant --quiet &&
        wp config set WP_DEBUG_LOG true --type=constant --quiet &&
        wp config set WP_DEBUG_DISPLAY false --type=constant --quiet &&
        wp config set WP_ENV 'staging' --type=constant --quiet 2>/dev/null || true
    "

    log_success "Staging configuration updated"
}

# === INTERACTIVE FUNCTIONS ===
confirm_operation() {
    if [ "$INTERACTIVE_MODE" = true ]; then
        echo ""
        log_warning "This will overwrite the current staging environment!"
        log_warning "Production: ${!PROD_URL_VAR} (${!PROD_PATH_VAR})"
        log_warning "Staging: ${!STAGE_URL_VAR} (${!STAGE_PATH_VAR})"
        echo ""

        read -p "Do you want to continue? (y/N): " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Operation cancelled by user"
            exit 0
        fi
    fi
}

# === SUBCOMMANDS ===

# Clone production to staging
cmd_clone() {
    local site_key="$1"

    # Validate configuration first to set SITE_KEY
    if ! validate_site_key "$site_key"; then
        exit 1
    fi

    # Initialize variable names after SITE_KEY is set
    PROD_SSH_VAR="${SITE_KEY}_PROD_SSH"
    STAGE_SSH_VAR="${SITE_KEY}_STAGE_SSH"
    PROD_PATH_VAR="${SITE_KEY}_PROD_PATH"
    STAGE_PATH_VAR="${SITE_KEY}_STAGE_PATH"
    PROD_URL_VAR="${SITE_KEY}_PROD_URL"
    STAGE_URL_VAR="${SITE_KEY}_STAGE_URL"

    log_info "Starting WordPress production to staging clone for: $SITE_KEY"

    # Validate SSH connections
    if ! validate_ssh_connections; then
        exit 1
    fi

    # Confirm operation in interactive mode
    confirm_operation

    # Create staging backup
    local backup_file
    backup_file=$(create_staging_backup)

    # Export production database
    local sql_dump
    sql_dump=$(export_production_db)

    # Import to staging
    import_to_staging "$sql_dump"

    # Sync files
    sync_wp_content

    # Update staging configuration
    update_staging_config

    # Cleanup
    cleanup_temp_files "$sql_dump"
    cleanup_old_backups

    log_success "Clone completed successfully for $SITE_KEY!"

    if [ -n "$backup_file" ]; then
        log_info "Previous staging backup saved as: $backup_file"
    fi
}

# Archive single site to local storage
cmd_archive() {
    local site_key="$1"

    # Validate configuration first to set SITE_KEY
    if ! validate_site_key "$site_key"; then
        exit 1
    fi

    # Initialize variable names after SITE_KEY is set
    PROD_SSH_VAR="${SITE_KEY}_PROD_SSH"
    PROD_PATH_VAR="${SITE_KEY}_PROD_PATH"

    log_info "Starting WordPress archive for: $SITE_KEY"

    # Create local backup directory
    local timestamp=$(date +'%Y-%m-%d_%H-%M-%S')
    local local_backup_dir="${LOCAL_BACKUP_DIR:-./backups}/${timestamp}"
    mkdir -p "$local_backup_dir"

    # Export database
    local db_backup="${site_key}_db_backup_${timestamp}.sql"
    log_step "Exporting database..."
    ssh_prod "cd ${!PROD_PATH_VAR} && wp db export ${db_backup} --quiet"

    if [ "$LOCAL_MODE" = true ]; then
        # Local mode - copy files directly
        log_step "Local mode: copying database backup..."
        cp "${!PROD_PATH_VAR}/${db_backup}" "$local_backup_dir/"

        # Archive files
        local files_backup="${site_key}_files_backup_${timestamp}.tar.gz"
        log_step "Creating files archive..."
        tar --exclude='wp_backups' --exclude='node_modules' --exclude='.git' -czf "$local_backup_dir/${files_backup}" -C "$(dirname "${!PROD_PATH_VAR}")" "$(basename "${!PROD_PATH_VAR}")"

        # Cleanup local files
        log_step "Cleaning up local files..."
        rm -f "${!PROD_PATH_VAR}/${db_backup}"
    else
        # Remote mode - use scp
        # Download database
        log_step "Downloading database backup..."
        scp "${!PROD_SSH_VAR}:${!PROD_PATH_VAR}/${db_backup}" "$local_backup_dir/"

        # Archive files
        local files_backup="${site_key}_files_backup_${timestamp}.tar.gz"
        log_step "Creating files archive..."
        ssh_prod "cd ~ && tar --exclude='wp_backups' --exclude='node_modules' --exclude='.git' -czf ${files_backup} ${!PROD_PATH_VAR}"

        # Download files archive
        log_step "Downloading files archive..."
        scp "${!PROD_SSH_VAR}:~/${files_backup}" "$local_backup_dir/"

        # Cleanup remote files
        log_step "Cleaning up remote files..."
        ssh_prod "rm -f ${!PROD_PATH_VAR}/${db_backup} ~/${files_backup}"
    fi

    log_success "Archive completed successfully!"
    log_info "Backup saved in: $local_backup_dir"
}

# Backup multiple sites to local storage
cmd_backup() {
    log_info "Starting multi-site backup..."

    # Create timestamped directory
    local timestamp=$(date +'%Y-%m-%d_%H-%M-%S')
    local local_backup_dir="${LOCAL_BACKUP_DIR:-./backups}/${timestamp}"
    mkdir -p "$local_backup_dir"

    # Convert site paths and names to arrays
    local sites_array=($(echo "$SITE_PATHS" | tr '\n' ' '))
    local names_array=($(echo "$SITE_NAMES" | tr '\n' ' '))

    # Backup each site
    for i in "${!sites_array[@]}"; do
        local site_path="${sites_array[$i]}"
        local site_name="${names_array[$i]}"

        if [ -z "$site_name" ] || [ -z "$site_path" ]; then
            log_warning "Skipping entry due to missing site name or path."
            continue
        fi

        log_info "Processing site: ${site_name} (Path: ${site_path})"

        # Create site subdirectory
        local site_backup_dir="${local_backup_dir}/${site_name}"
        mkdir -p "$site_backup_dir"

        # Export database
        local db_backup="${site_name}_db_backup_${timestamp}.sql"
        log_step "Exporting database for ${site_name}..."
        ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ~/${site_path} && wp db export ${db_backup} --quiet"

        # Download database
        scp "${REMOTE_USER}@${REMOTE_HOST}:~/${site_path}/${db_backup}" "$site_backup_dir/"

        # Archive files
        local files_backup="${site_name}_files_backup_${timestamp}.tar.gz"
        log_step "Creating files archive for ${site_name}..."
        ssh "${REMOTE_USER}@${REMOTE_HOST}" "cd ~ && tar --exclude='wp_backups' --exclude='node_modules' --exclude='.git' -czf ${files_backup} ${site_path}"

        # Download files archive
        scp "${REMOTE_USER}@${REMOTE_HOST}:~/${files_backup}" "$site_backup_dir/"

        # Cleanup remote files
        ssh "${REMOTE_USER}@${REMOTE_HOST}" "rm -f ~/${site_path}/${db_backup} ~/${files_backup}"
    done

    log_success "Multi-site backup completed successfully!"
    log_info "All backups saved in: $local_backup_dir"
}

# Restore from local backup
cmd_restore() {
    local backup_timestamp="$1"

    if [ -z "$backup_timestamp" ]; then
        log_error "Backup timestamp is required"
        log_info "Usage: $0 restore <backup-timestamp>"
        exit 1
    fi

    local backup_dir="${LOCAL_BACKUP_DIR:-./backups}/${backup_timestamp}"

    if [ ! -d "$backup_dir" ]; then
        log_error "Backup directory not found: $backup_dir"
        exit 1
    fi

    log_info "Starting restore from backup: $backup_timestamp"

    # Find backup files
    local db_backup=$(find "$backup_dir" -name "*_db_backup_*.sql" | head -1)
    local files_backup=$(find "$backup_dir" -name "*_files_backup_*.tar.gz" | head -1)

    if [ -z "$db_backup" ] || [ -z "$files_backup" ]; then
        log_error "Backup files not found in $backup_dir"
        exit 1
    fi

    # Extract site name from backup filename (format: sitename_db_backup_timestamp.sql)
    local site_name=$(basename "$db_backup" | sed 's/_db_backup_.*//')
    local site_path="${REMOTE_HOME_DIRECTORY}/public_html/${site_name}"

    log_info "Restoring site: $site_name to path: $site_path"

    # Upload and restore database
    log_step "Uploading database backup..."
    scp "$db_backup" "${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_BACKUP_DIR}/"

    log_step "Restoring database..."
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "
        cd ~/${site_path} &&
        wp db import ~/${REMOTE_BACKUP_DIR}/$(basename '$db_backup') --quiet
    "

    # Upload and restore files
    log_step "Uploading files backup..."
    scp "$files_backup" "${REMOTE_USER}@${REMOTE_HOST}:~/${REMOTE_BACKUP_DIR}/"

    log_step "Restoring files..."
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "
        tar -xzf ~/${REMOTE_BACKUP_DIR}/$(basename '$files_backup') -C ~ --overwrite
    "

    # Cleanup
    log_step "Cleaning up uploaded files..."
    ssh "${REMOTE_USER}@${REMOTE_HOST}" "
        rm -f ~/${REMOTE_BACKUP_DIR}/$(basename '$db_backup') ~/${REMOTE_BACKUP_DIR}/$(basename '$files_backup')
    "

    log_success "Restore completed successfully!"
}

# List available backups
cmd_list() {
    local backup_dir="${LOCAL_BACKUP_DIR:-./backups}"

    log_info "Available local backups:"
    echo ""

    if [ ! -d "$backup_dir" ]; then
        log_error "Local backup directory not found: $backup_dir"
        exit 1
    fi

    # Find all backup directories and sort by date (newest first)
    local backup_dirs=$(find "$backup_dir" -maxdepth 1 -type d -name "20*" | sort -r)

    if [ -z "$backup_dirs" ]; then
        log_error "No backups found in $backup_dir"
        exit 1
    fi

    printf "%-15s %-25s %-20s %-8s %s\n" "SITE" "DATE" "TIMESTAMP" "SIZE" "PATH"
    printf "%-15s %-25s %-20s %-8s %s\n" "----" "----" "---------" "----" "----"

    while IFS= read -r backup_dir_path; do
        if [ -n "$backup_dir_path" ]; then
            local timestamp=$(basename "$backup_dir_path")
            local size=$(du -sh "$backup_dir_path" 2>/dev/null | awk '{print $1}')
            local friendly_date=$(date -d "${timestamp//_/ }" "+%b %d, %Y at %I:%M %p" 2>/dev/null || echo "$timestamp")

            printf "%-15s %-25s %-20s %-8s %s\n" "backup" "$friendly_date" "$timestamp" "$size" "$backup_dir_path"
        fi
    done <<< "$backup_dirs"

    echo ""
    log_info "Usage: $0 restore <backup-timestamp>"
    log_info "Example: $0 restore 2025-07-20_23-59-00"
}

# === HELP FUNCTIONS ===
show_usage() {
    cat << EOF
WordPress Management CLI

Usage: $0 <command> [options] [arguments]

Commands:
  clone <site-key>           Clone production to staging
  archive <site-key>         Archive single site to local storage
  backup                     Backup multiple sites to local storage
  restore <timestamp>        Restore from local backup
  list                       List available local backups

Options:
  -i, --interactive          Run in interactive mode with confirmation prompts
  -l, --local               Run in local mode (default: script runs on same machine as WordPress)
  -r, --remote              Run in remote mode (use SSH connections)
  -h, --help                Show this help message

Examples:
  $0 clone yoursite                    # Clone yoursite to staging (local mode, default)
  $0 clone -i yoursite                 # Interactive clone with confirmations
  $0 clone -r yoursite                 # Remote mode clone (use SSH connections)
  $0 archive yoursite                  # Archive yoursite to local storage
  $0 backup                            # Backup all configured sites
  $0 restore 2025-07-20_23-59-00      # Restore from specific backup
  $0 list                              # List available backups

Configuration:
  Set up your .env file with site-specific variables:
  YOURSITE_PROD_SSH=user@prod-server.com
  YOURSITE_STAGE_SSH=user@stage-server.com
  YOURSITE_PROD_PATH=/path/to/production/wordpress
  YOURSITE_STAGE_PATH=/path/to/staging/wordpress
  YOURSITE_PROD_URL=https://yoursite.com
  YOURSITE_STAGE_URL=https://staging.yoursite.com

EOF
}

# === MAIN EXECUTION ===
main() {
    # Parse command line arguments
    local command=""
    local args=()

    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--interactive)
                INTERACTIVE_MODE=true
                shift
                ;;
            -l|--local)
                LOCAL_MODE=true
                shift
                ;;
            -r|--remote)
                LOCAL_MODE=false
                shift
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
            *)
                if [ -z "$command" ]; then
                    command="$1"
                else
                    args+=("$1")
                fi
                shift
                ;;
        esac
    done

    # Check if command was provided
    if [ -z "$command" ]; then
        log_error "Command is required"
        show_usage
        exit 1
    fi

    # Load environment
    load_environment

    # Execute command
    case "$command" in
        clone)
            if [ ${#args[@]} -eq 0 ]; then
                log_error "Site key is required for clone command"
                exit 1
            fi
            cmd_clone "${args[0]}"
            ;;
        archive)
            if [ ${#args[@]} -eq 0 ]; then
                log_error "Site key is required for archive command"
                exit 1
            fi
            cmd_archive "${args[0]}"
            ;;
        backup)
            cmd_backup
            ;;
        restore)
            if [ ${#args[@]} -eq 0 ]; then
                log_error "Backup timestamp is required for restore command"
                exit 1
            fi
            cmd_restore "${args[0]}"
            ;;
        list)
            cmd_list
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
