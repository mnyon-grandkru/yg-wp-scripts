# WordPress Management Scripts Comparison

This document explains the differences between the WordPress management scripts and when to use each one.

## Script Overview

| Script | Purpose | Data Flow | Storage | Retention | Use Case |
|--------|---------|-----------|---------|-----------|----------|
| `wp-archive-to-local.sh` | Archive single site | Remote → Local | Local files | Long-term | Compliance, disaster recovery |
| `wp-backup-multi-site.sh` | Backup multiple sites | Remote → Local | Local files | Long-term | Multi-site backup operations |
| `wp-restore-from-local.sh` | Restore from backup | Local → Remote | Local files | N/A | Disaster recovery, rollback |
| `wp-clone-prod-to-staging.sh` | Clone to staging | Remote → Remote | No local storage | Short-term (7 days) | Development, testing |

## Detailed Comparison

### wp-archive-to-local.sh (formerly wp_backup.zsh)
- **Purpose**: Archive a single WordPress site to local storage
- **Data Flow**: Production server → Local machine
- **Storage**: Creates timestamped backup files locally
- **Retention**: Manual management of local files
- **Use Cases**:
  - Compliance requirements
  - Long-term archival
  - Disaster recovery preparation
  - Manual backup before major changes

### wp-backup-multi-site.sh (formerly wp_backup_new.zsh)
- **Purpose**: Backup multiple WordPress sites to local storage
- **Data Flow**: Multiple remote servers → Local machine
- **Storage**: Creates timestamped backup files locally for each site
- **Retention**: Automatic cleanup of old remote backups (7+ days)
- **Use Cases**:
  - Scheduled multi-site backups
  - Bulk backup operations
  - Server migration preparation
  - Regular backup maintenance

### wp-restore-from-local.sh (formerly wp_restore.zsh)
- **Purpose**: Restore WordPress sites from local backup files
- **Data Flow**: Local machine → Remote server
- **Storage**: Reads from local backup files
- **Retention**: N/A (restores from existing backups)
- **Use Cases**:
  - Disaster recovery
  - Rollback from failed updates
  - Site restoration
  - Testing with historical data

### wp-clone-prod-to-staging.sh (formerly clone-to-staging.sh)
- **Purpose**: Clone production WordPress to staging environment
- **Data Flow**: Production server → Staging server (direct)
- **Storage**: No local storage, temporary files on remote servers only
- **Retention**: Automatic cleanup of staging backups (7 days)
- **Use Cases**:
  - Development workflow
  - Testing new features
  - Staging environment updates
  - Pre-deployment testing

## When to Use Each Script

### Use wp-archive-to-local.sh when:
- You need to archive a single site for compliance
- You want long-term local storage
- You're preparing for server migration
- You need manual control over backup timing

### Use wp-backup-multi-site.sh when:
- You manage multiple WordPress sites
- You want automated multi-site backups
- You need scheduled backup operations
- You want to backup several sites at once

### Use wp-restore-from-local.sh when:
- You need to restore from a previous backup
- You're recovering from a disaster
- You want to rollback changes
- You're testing with historical data

### Use wp-clone-prod-to-staging.sh when:
- You need to update your staging environment
- You're testing new features
- You want to sync production to staging
- You're preparing for deployment testing

## Configuration Requirements

### wp-archive-to-local.sh & wp-backup-multi-site.sh
- Require `LOCAL_BACKUP_DIR` in .env
- Use legacy configuration variables
- Download files to local machine

### wp-restore-from-local.sh
- Requires existing local backup files
- Uses legacy configuration variables
- Uploads files to remote server

### wp-clone-prod-to-staging.sh
- Uses new site-key configuration pattern
- No local storage requirements
- Direct server-to-server communication

## Migration Path

If you want to consolidate functionality:

1. **Keep all scripts** for different use cases
2. **Rename scripts** for clarity
3. **Update documentation** to explain differences
4. **Consider unified script** in the future if needed

## Future Considerations

- **Google Drive Integration**: Can be added to any script for cloud backup
- **Unified Script**: Could combine all functionality with mode flags
- **Configuration Standardization**: Could migrate all scripts to site-key pattern
