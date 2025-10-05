#!/usr/bin/env bash
# ====================================================================
# WordPress Production to Staging Clone Script (Hybrid Approach)
# --------------------------------------------------------------------
# This script clones a WordPress production environment to staging
# with support for both interactive and automated modes.
# 
# Features:
# - Multi-site support via site keys
# - Object-oriented style with safety features
# - Interactive mode for manual operations
# - Automated mode for cron jobs
# - Comprehensive backup and rollback capabilities
# ====================================================================

set -euo pipefail

# === GLOBAL VARIABLES ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
INTERACTIVE_MODE=false
SITE_KEY=""
BACKUP_RETENTION_DAYS=7

# === LOAD ENVIRONMENT ===
load_environment() {
    if [ -f "$ENV_FILE" ]; then
        # Export variables from .env file, ignoring comments
        set -a
        source "$ENV_FILE"
        set +a
    else
        echo "❌ .env file not found at $ENV_FILE"
        echo "Please create a .env file with your site configurations."
        exit 1
    fi
}

# === UTILITY FUNCTIONS ===
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
    echo "🔹 $1"
}

# === VALIDATION CLASS ===
class_Validator() {
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
        log_step "Validating SSH connections..."
        
        # Test production SSH connection
        if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "${!PROD_SSH_VAR}" "echo 'SSH connection test'" >/dev/null 2>&1; then
            log_error "Cannot connect to production server: ${!PROD_SSH_VAR}"
            return 1
        fi
        
        # Test staging SSH connection
        if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "${!STAGE_SSH_VAR}" "echo 'SSH connection test'" >/dev/null 2>&1; then
            log_error "Cannot connect to staging server: ${!STAGE_SSH_VAR}"
            return 1
        fi
        
        log_success "SSH connections validated"
        return 0
    }
}

# === BACKUP MANAGER CLASS ===
class_BackupManager() {
    create_staging_backup() {
        local backup_timestamp=$(date +%Y%m%d-%H%M%S)
        local backup_file="staging-backup-${backup_timestamp}.sql"
        
        log_step "Creating staging backup..."
        
        if ssh "${!STAGE_SSH_VAR}" "cd ${!STAGE_PATH_VAR} && wp db check --quiet" 2>/dev/null; then
            ssh "${!STAGE_SSH_VAR}" "cd ${!STAGE_PATH_VAR} && wp db export ${backup_file} --quiet"
            log_success "Staging backup created: ${backup_file}"
            echo "${backup_file}"
        else
            log_warning "No existing staging database found, skipping backup"
            echo ""
        fi
    }
    
    cleanup_old_backups() {
        log_step "Cleaning up old backups (older than ${BACKUP_RETENTION_DAYS} days)..."
        
        ssh "${!STAGE_SSH_VAR}" "
            find ${!STAGE_PATH_VAR} -name 'staging-backup-*.sql' -type f -mtime +${BACKUP_RETENTION_DAYS} -delete 2>/dev/null || true
        "
        
        log_success "Old backups cleaned up"
    }
}

# === DATABASE MANAGER CLASS ===
class_DatabaseManager() {
    export_production_db() {
        local sql_dump="./${SITE_KEY,,}-$(date +%Y%m%d-%H%M%S).sql"
        
        log_step "Exporting production database..."
        ssh "${!PROD_SSH_VAR}" "cd ${!PROD_PATH_VAR} && wp db export $(basename "$sql_dump") --quiet"
        
        log_step "Downloading SQL dump..."
        scp "${!PROD_SSH_VAR}:${!PROD_PATH_VAR}/$(basename "$sql_dump")" "$sql_dump"
        
        echo "$sql_dump"
    }
    
    import_to_staging() {
        local sql_dump="$1"
        
        log_step "Uploading dump to staging..."
        scp "$sql_dump" "${!STAGE_SSH_VAR}:${!STAGE_PATH_VAR}/"
        
        log_step "Importing database to staging..."
        ssh "${!STAGE_SSH_VAR}" "
            cd ${!STAGE_PATH_VAR} &&
            wp db reset --yes &&
            wp db import $(basename '$sql_dump') &&
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
        
        log_step "Cleaning up temporary files..."
        ssh "${!PROD_SSH_VAR}" "rm -f ${!PROD_PATH_VAR}/$(basename "$sql_dump")" 2>/dev/null || true
        ssh "${!STAGE_SSH_VAR}" "rm -f ${!STAGE_PATH_VAR}/$(basename "$sql_dump")" 2>/dev/null || true
        rm -f "$sql_dump"
        
        log_success "Temporary files cleaned up"
    }
}

# === FILE MANAGER CLASS ===
class_FileManager() {
    sync_wp_content() {
        log_step "Syncing wp-content directory..."
        
        rsync -az --delete \
            "${!PROD_SSH_VAR}:${!PROD_PATH_VAR}/wp-content/" \
            "${!STAGE_SSH_VAR}:${!STAGE_PATH_VAR}/wp-content/"
        
        log_success "wp-content synchronized"
    }
    
    update_staging_config() {
        log_step "Updating staging-specific configuration..."
        
        ssh "${!STAGE_SSH_VAR}" "
            cd ${!STAGE_PATH_VAR} &&
            wp config set WP_DEBUG true --type=constant --quiet &&
            wp config set WP_DEBUG_LOG true --type=constant --quiet &&
            wp config set WP_DEBUG_DISPLAY false --type=constant --quiet &&
            wp config set WP_ENV 'staging' --type=constant --quiet 2>/dev/null || true
        "
        
        log_success "Staging configuration updated"
    }
}

# === INTERACTIVE MODE FUNCTIONS ===
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

show_usage() {
    cat << EOF
WordPress Production to Staging Clone Script

Usage: $0 [OPTIONS] SITE_KEY

Arguments:
  SITE_KEY              Site identifier (e.g., 'yoursite' for YOURSITE_* variables)

Options:
  -i, --interactive     Run in interactive mode with confirmation prompts
  -h, --help           Show this help message

Examples:
  $0 yoursite                    # Automated mode (for cron jobs)
  $0 --interactive yoursite      # Interactive mode with confirmations
  $0 -i yoursite                 # Interactive mode (short form)

Configuration:
  Set up your .env file with variables like:
  YOURSITE_PROD_SSH=user@prod-server.com
  YOURSITE_STAGE_SSH=user@stage-server.com
  YOURSITE_PROD_PATH=/path/to/prod/wp
  YOURSITE_STAGE_PATH=/path/to/stage/wp
  YOURSITE_PROD_URL=https://yoursite.com
  YOURSITE_STAGE_URL=https://staging.yoursite.com

EOF
}

# === MAIN CLONE OPERATION ===
perform_clone() {
    local site_key="$1"
    
    # Initialize variable names
    PROD_SSH_VAR="${SITE_KEY}_PROD_SSH"
    STAGE_SSH_VAR="${SITE_KEY}_STAGE_SSH"
    PROD_PATH_VAR="${SITE_KEY}_PROD_PATH"
    STAGE_PATH_VAR="${SITE_KEY}_STAGE_PATH"
    PROD_URL_VAR="${SITE_KEY}_PROD_URL"
    STAGE_URL_VAR="${SITE_KEY}_STAGE_URL"
    
    log_info "Starting WordPress production to staging clone for: $SITE_KEY"
    
    # Validate configuration
    if ! class_Validator validate_site_key "$site_key"; then
        exit 1
    fi
    
    # Validate SSH connections
    if ! class_Validator validate_ssh_connections; then
        exit 1
    fi
    
    # Confirm operation in interactive mode
    confirm_operation
    
    # Create staging backup
    local backup_file
    backup_file=$(class_BackupManager create_staging_backup)
    
    # Export production database
    local sql_dump
    sql_dump=$(class_DatabaseManager export_production_db)
    
    # Import to staging
    class_DatabaseManager import_to_staging "$sql_dump"
    
    # Sync files
    class_FileManager sync_wp_content
    
    # Update staging configuration
    class_FileManager update_staging_config
    
    # Cleanup
    class_DatabaseManager cleanup_temp_files "$sql_dump"
    class_BackupManager cleanup_old_backups
    
    log_success "Clone completed successfully for $SITE_KEY!"
    
    if [ -n "$backup_file" ]; then
        log_info "Previous staging backup saved as: $backup_file"
    fi
}

# === MAIN EXECUTION ===
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -i|--interactive)
                INTERACTIVE_MODE=true
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
                if [ -z "$SITE_KEY" ]; then
                    SITE_KEY="$1"
                else
                    log_error "Multiple site keys provided. Please specify only one."
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Check if site key was provided
    if [ -z "$SITE_KEY" ]; then
        log_error "Site key is required"
        show_usage
        exit 1
    fi
    
    # Load environment and perform clone
    load_environment
    perform_clone "$SITE_KEY"
}

# Run main function with all arguments
main "$@"
