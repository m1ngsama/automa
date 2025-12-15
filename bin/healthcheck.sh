#!/usr/bin/env bash
# Health check script for all services
# Usage: ./bin/healthcheck.sh [service]

set -euo pipefail

# Source shared library and config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
source "$SCRIPT_DIR/lib/common.sh"
source "$PROJECT_ROOT/config.sh"

check_minecraft() {
  log_info "Checking Minecraft server..."

  if check_container_health "$CONTAINER_MINECRAFT"; then
    log_info "  ✓ Container is running"
  else
    log_error "  ✗ Container is not running"
    return 1
  fi

  if check_port "localhost" "$PORT_MINECRAFT"; then
    log_info "  ✓ Server port $PORT_MINECRAFT is accessible"
  else
    log_warn "  ⚠ Server port $PORT_MINECRAFT is not accessible"
  fi

  if check_port "localhost" "$PORT_MINECRAFT_RCON"; then
    log_info "  ✓ RCON port $PORT_MINECRAFT_RCON is accessible"
  else
    log_warn "  ⚠ RCON port $PORT_MINECRAFT_RCON is not accessible"
  fi
}

check_teamspeak() {
  log_info "Checking TeamSpeak server..."

  if check_container_health "$CONTAINER_TEAMSPEAK"; then
    log_info "  ✓ Container is running"
  else
    log_error "  ✗ Container is not running"
    return 1
  fi

  if check_port "localhost" "$PORT_TEAMSPEAK_QUERY"; then
    log_info "  ✓ Query port $PORT_TEAMSPEAK_QUERY is accessible"
  else
    log_warn "  ⚠ Port $PORT_TEAMSPEAK_QUERY is not accessible"
  fi
}

check_nextcloud() {
  log_info "Checking Nextcloud..."

  if check_container_health "$CONTAINER_NEXTCLOUD"; then
    log_info "  ✓ Nextcloud container is running"
  else
    log_error "  ✗ Nextcloud container is not running"
    return 1
  fi

  if check_container_health "$CONTAINER_NEXTCLOUD_DB"; then
    log_info "  ✓ Database container is running"
  else
    log_error "  ✗ Database container is not running"
  fi

  if check_container_health "$CONTAINER_NEXTCLOUD_REDIS"; then
    log_info "  ✓ Redis container is running"
  else
    log_warn "  ⚠ Redis container is not running"
  fi

  if check_port "localhost" "$PORT_NEXTCLOUD_WEB"; then
    log_info "  ✓ Web interface port $PORT_NEXTCLOUD_WEB is accessible"
  else
    log_warn "  ⚠ Port $PORT_NEXTCLOUD_WEB is not accessible"
  fi
}

main() {
  local service="${1:-all}"

  case "$service" in
    minecraft)
      check_minecraft
      ;;
    teamspeak)
      check_teamspeak
      ;;
    nextcloud)
      check_nextcloud
      ;;
    all)
      echo "=== Health Check Report ==="
      echo
      check_minecraft || true
      echo
      check_teamspeak || true
      echo
      check_nextcloud || true
      ;;
    *)
      echo "Usage: $0 [minecraft|teamspeak|nextcloud|all]"
      exit 1
      ;;
  esac
}

main "$@"
