#!/usr/bin/env bash
# Health check script for all services
# Usage: ./bin/healthcheck.sh [service]

set -euo pipefail

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

check_container_health() {
  local container_name="$1"

  if ! docker ps --filter "name=$container_name" --format '{{.Names}}' | grep -q "$container_name"; then
    return 1
  fi

  local status
  status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null)

  if [[ "$status" == "running" ]]; then
    return 0
  else
    return 1
  fi
}

check_port() {
  local host="${1:-localhost}"
  local port="$2"

  if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

check_minecraft() {
  log_info "Checking Minecraft server..."

  if check_container_health "mc-fabric-1.21.1"; then
    log_info "  ✓ Container is running"
  else
    log_error "  ✗ Container is not running"
    return 1
  fi

  if check_port "localhost" 25565; then
    log_info "  ✓ Server port 25565 is accessible"
  else
    log_warn "  ⚠ Server port 25565 is not accessible"
  fi

  if check_port "localhost" 25575; then
    log_info "  ✓ RCON port 25575 is accessible"
  else
    log_warn "  ⚠ RCON port 25575 is not accessible"
  fi
}

check_teamspeak() {
  log_info "Checking TeamSpeak server..."

  if check_container_health "teamspeak-server"; then
    log_info "  ✓ Container is running"
  else
    log_error "  ✗ Container is not running"
    return 1
  fi

  if check_port "localhost" 10011; then
    log_info "  ✓ File transfer port 10011 is accessible"
  else
    log_warn "  ⚠ Port 10011 is not accessible"
  fi
}

check_nextcloud() {
  log_info "Checking Nextcloud..."

  if check_container_health "nextcloud"; then
    log_info "  ✓ Nextcloud container is running"
  else
    log_error "  ✗ Nextcloud container is not running"
    return 1
  fi

  if check_container_health "nextcloud-db"; then
    log_info "  ✓ Database container is running"
  else
    log_error "  ✗ Database container is not running"
  fi

  if check_container_health "nextcloud-redis"; then
    log_info "  ✓ Redis container is running"
  else
    log_warn "  ⚠ Redis container is not running"
  fi

  if check_port "localhost" 8080; then
    log_info "  ✓ Web interface port 8080 is accessible"
  else
    log_warn "  ⚠ Port 8080 is not accessible"
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
