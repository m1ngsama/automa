#!/usr/bin/env bash
# Backup utility for all services
# Usage: ./bin/backup.sh [command] [service]

set -euo pipefail

# Source shared library and config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/lib/common.sh"
source "$PROJECT_ROOT/config.sh"

readonly TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# ============================================================================
# Pre-flight checks
# ============================================================================
check_prerequisites() {
  if ! require_command "docker"; then
    log_error "Docker is required for backup operations"
    exit 1
  fi
}

check_container_running() {
  local container_name="$1"
  local service_name="$2"

  if ! check_container_health "$container_name"; then
    log_warn "$service_name container ($container_name) is not running"
    log_warn "Some backup operations may fail"
    return 1
  fi
  return 0
}

# ============================================================================
# Backup functions
# ============================================================================
backup_minecraft() {
  log_info "Backing up Minecraft server..."

  local backup_dir="$BACKUP_ROOT/minecraft/$TIMESTAMP"
  ensure_dir "$backup_dir"

  # Check if container is running (warning only)
  check_container_running "$CONTAINER_MINECRAFT" "Minecraft" || true

  # Backup world data
  if [[ -d "$PROJECT_ROOT/minecraft/data" ]]; then
    log_info "  Archiving world data..."
    tar -czf "$backup_dir/world-data.tar.gz" -C "$PROJECT_ROOT/minecraft" data 2>/dev/null || {
      log_error "  Failed to backup world data"
      return 1
    }
    log_info "  ✓ World data backed up"
  else
    log_warn "  No world data directory found"
  fi

  # Backup configs
  if [[ -d "$PROJECT_ROOT/minecraft/configs" ]]; then
    log_info "  Archiving configs..."
    tar -czf "$backup_dir/configs.tar.gz" -C "$PROJECT_ROOT/minecraft" configs 2>/dev/null || {
      log_warn "  Failed to backup configs"
    }
  fi

  # Create manifest
  cat > "$backup_dir/manifest.txt" <<EOF
Minecraft Backup
Created: $(date)
Location: $backup_dir
Container: $CONTAINER_MINECRAFT
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

  # Check if container is running
  check_container_running "$CONTAINER_TEAMSPEAK" "TeamSpeak" || true

  # Export Docker volume
  if docker volume ls | grep -q teamspeak_data; then
    log_info "  Exporting volume data..."
    docker run --rm -v teamspeak_data:/data -v "$PWD/$backup_dir":/backup \
      alpine tar -czf /backup/teamspeak-data.tar.gz -C /data . 2>/dev/null || {
      log_error "  Failed to export volume"
      return 1
    }
    log_info "  ✓ Volume data backed up"
  else
    log_warn "  No TeamSpeak volume found"
  fi

  log_info "  ✓ Backup complete: $backup_dir"
}

backup_nextcloud() {
  log_info "Backing up Nextcloud..."

  local backup_dir="$BACKUP_ROOT/nextcloud/$TIMESTAMP"
  ensure_dir "$backup_dir"

  # Load Nextcloud environment if available
  local nextcloud_env="$PROJECT_ROOT/nextcloud/.env"
  if [[ -f "$nextcloud_env" ]]; then
    log_info "  Loading Nextcloud environment..."
    load_env "$nextcloud_env"
  else
    log_warn "  No .env file found at $nextcloud_env"
    log_warn "  Using default credentials (not recommended)"
  fi

  # Validate required environment variables
  if [[ -z "${MYSQL_PASSWORD:-}" ]]; then
    log_warn "  MYSQL_PASSWORD not set, database backup may fail"
  fi

  # Check if database container is running
  if ! check_container_running "$CONTAINER_NEXTCLOUD_DB" "Nextcloud DB"; then
    log_error "  Database container must be running for backup"
    return 1
  fi

  # Backup database (use environment variable, no default password)
  log_info "  Backing up database..."
  if [[ -n "${MYSQL_PASSWORD:-}" ]]; then
    docker exec "$CONTAINER_NEXTCLOUD_DB" mariadb-dump \
      -u"${MYSQL_USER:-nextcloud}" \
      -p"$MYSQL_PASSWORD" \
      --single-transaction \
      "${MYSQL_DATABASE:-nextcloud}" > "$backup_dir/database.sql" 2>/dev/null || {
      log_error "  Database backup failed"
    }
  else
    log_error "  Skipping database backup: MYSQL_PASSWORD not set"
  fi

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
Containers: $CONTAINER_NEXTCLOUD, $CONTAINER_NEXTCLOUD_DB, $CONTAINER_NEXTCLOUD_REDIS
Contents:
  - MariaDB database dump
  - Application volumes
  - User data
EOF

  log_info "  ✓ Backup complete: $backup_dir"
}

# ============================================================================
# Utility functions
# ============================================================================
list_backups() {
  log_info "Available backups:"
  echo

  local found=0
  for service in minecraft teamspeak nextcloud; do
    if [[ -d "$BACKUP_ROOT/$service" ]]; then
      found=1
      echo "=== $service ==="
      ls -lh "$BACKUP_ROOT/$service" 2>/dev/null | tail -n +2 || echo "  (empty)"
      echo
    fi
  done

  if [[ $found -eq 0 ]]; then
    log_info "No backups found in $BACKUP_ROOT"
  fi
}

cleanup_old_backups() {
  local keep_days="${1:-$BACKUP_RETENTION_DAYS}"

  if [[ ! -d "$BACKUP_ROOT" ]]; then
    log_info "No backup directory found"
    return 0
  fi

  log_info "Cleaning up backups older than $keep_days days..."

  local count_before
  count_before=$(find "$BACKUP_ROOT" -type f -name "*.tar.gz" 2>/dev/null | wc -l)

  find "$BACKUP_ROOT" -type f -name "*.tar.gz" -mtime +"$keep_days" -delete 2>/dev/null || true
  find "$BACKUP_ROOT" -type f -name "*.sql" -mtime +"$keep_days" -delete 2>/dev/null || true
  find "$BACKUP_ROOT" -type f -name "manifest.txt" -mtime +"$keep_days" -delete 2>/dev/null || true
  find "$BACKUP_ROOT" -type d -empty -delete 2>/dev/null || true

  local count_after
  count_after=$(find "$BACKUP_ROOT" -type f -name "*.tar.gz" 2>/dev/null | wc -l)

  local removed=$((count_before - count_after))
  log_info "  ✓ Cleanup complete (removed $removed archive(s))"
}

# ============================================================================
# Main
# ============================================================================
show_usage() {
  cat <<EOF
Usage: $0 <command> [options]

Commands:
  backup [service]      Create backup (default: all)
  list                  List available backups
  cleanup [days]        Remove backups older than N days (default: $BACKUP_RETENTION_DAYS)

Services:
  minecraft, teamspeak, nextcloud, all

Examples:
  $0 backup minecraft
  $0 backup all
  $0 list
  $0 cleanup 30

Environment:
  BACKUP_ROOT           Backup directory (default: ./backups)
  BACKUP_RETENTION_DAYS Days to keep backups (default: 7)
EOF
  exit 1
}

main() {
  check_prerequisites

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
          log_error "Unknown service: $service"
          show_usage
          ;;
      esac
      ;;
    list)
      list_backups
      ;;
    cleanup)
      cleanup_old_backups "${service:-$BACKUP_RETENTION_DAYS}"
      ;;
    -h|--help|help)
      show_usage
      ;;
    *)
      log_error "Unknown command: $action"
      show_usage
      ;;
  esac
}

main "$@"
