#!/usr/bin/env bash
# Backup utility for all services
# Usage: ./bin/backup.sh [service]

set -euo pipefail

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

readonly BACKUP_ROOT="${BACKUP_ROOT:-./backups}"
readonly TIMESTAMP=$(date +%Y%m%d-%H%M%S)

backup_minecraft() {
  log_info "Backing up Minecraft server..."

  local backup_dir="$BACKUP_ROOT/minecraft/$TIMESTAMP"
  ensure_dir "$backup_dir"

  # Backup world data
  if [[ -d "minecraft/data" ]]; then
    log_info "  Archiving world data..."
    tar -czf "$backup_dir/world-data.tar.gz" -C minecraft data 2>/dev/null || {
      log_error "  Failed to backup world data"
      return 1
    }
    log_info "  ✓ World data backed up"
  fi

  # Backup configs
  if [[ -d "minecraft/configs" ]]; then
    log_info "  Archiving configs..."
    tar -czf "$backup_dir/configs.tar.gz" -C minecraft configs 2>/dev/null || {
      log_warn "  Failed to backup configs"
    }
  fi

  # Create manifest
  cat > "$backup_dir/manifest.txt" <<EOF
Minecraft Backup
Created: $(date)
Location: $backup_dir
Contents:
  - World data
  - Configuration files
EOF

  log_info "  ✓ Backup complete: $backup_dir"
}

backup_teamspeak() {
  log_info "Backing up TeamSpeak server..."

  local backup_dir="$BACKUP_ROOT/teamspeak/$TIMESTAMP"
  ensure_dir "$backup_dir"

  # Export Docker volume
  if docker volume ls | grep -q teamspeak_data; then
    log_info "  Exporting volume data..."
    docker run --rm -v teamspeak_data:/data -v "$PWD/$backup_dir":/backup \
      alpine tar -czf /backup/teamspeak-data.tar.gz -C /data . 2>/dev/null || {
      log_error "  Failed to export volume"
      return 1
    }
    log_info "  ✓ Volume data backed up"
  fi

  log_info "  ✓ Backup complete: $backup_dir"
}

backup_nextcloud() {
  log_info "Backing up Nextcloud..."

  local backup_dir="$BACKUP_ROOT/nextcloud/$TIMESTAMP"
  ensure_dir "$backup_dir"

  # Backup database
  log_info "  Backing up database..."
  docker exec nextcloud-db mariadb-dump -unextcloud -p"${MYSQL_PASSWORD:-ChangeDb123!}" nextcloud \
    > "$backup_dir/database.sql" 2>/dev/null || {
    log_error "  Database backup failed"
  }

  # Export volumes
  for vol in nextcloud_html nextcloud_data nextcloud_config nextcloud_apps; do
    if docker volume ls | grep -q "$vol"; then
      log_info "  Exporting $vol..."
      docker run --rm -v "$vol":/data -v "$PWD/$backup_dir":/backup \
        alpine tar -czf "/backup/${vol}.tar.gz" -C /data . 2>/dev/null || {
        log_warn "  Failed to export $vol"
      }
    fi
  done

  # Create manifest
  cat > "$backup_dir/manifest.txt" <<EOF
Nextcloud Backup
Created: $(date)
Location: $backup_dir
Contents:
  - MariaDB database dump
  - Application volumes
  - User data
EOF

  log_info "  ✓ Backup complete: $backup_dir"
}

list_backups() {
  log_info "Available backups:"
  echo

  for service in minecraft teamspeak nextcloud; do
    if [[ -d "$BACKUP_ROOT/$service" ]]; then
      echo "=== $service ==="
      ls -lh "$BACKUP_ROOT/$service" | tail -n +2
      echo
    fi
  done
}

cleanup_old_backups() {
  local keep_days="${1:-7}"

  log_info "Cleaning up backups older than $keep_days days..."

  find "$BACKUP_ROOT" -type f -name "*.tar.gz" -mtime +"$keep_days" -delete
  find "$BACKUP_ROOT" -type d -empty -delete

  log_info "  ✓ Cleanup complete"
}

main() {
  local action="${1:-backup}"
  local service="${2:-all}"

  case "$action" in
    backup)
      case "$service" in
        minecraft)
          backup_minecraft
          ;;
        teamspeak)
          backup_teamspeak
          ;;
        nextcloud)
          backup_nextcloud
          ;;
        all)
          backup_minecraft || true
          backup_teamspeak || true
          backup_nextcloud || true
          ;;
        *)
          echo "Usage: $0 backup [minecraft|teamspeak|nextcloud|all]"
          exit 1
          ;;
      esac
      ;;
    list)
      list_backups
      ;;
    cleanup)
      cleanup_old_backups "${service:-7}"
      ;;
    *)
      cat <<EOF
Usage: $0 <command> [options]

Commands:
  backup [service]      Create backup (default: all)
  list                  List available backups
  cleanup [days]        Remove backups older than N days (default: 7)

Services:
  minecraft, teamspeak, nextcloud, all

Examples:
  $0 backup minecraft
  $0 list
  $0 cleanup 30
EOF
      exit 1
      ;;
  esac
}

main "$@"
