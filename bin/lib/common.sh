#!/usr/bin/env bash
# Shared utility library for all scripts
# Source this file: source "$(dirname "$0")/lib/common.sh"

# Prevent multiple sourcing
[[ -n "${_COMMON_SH_LOADED:-}" ]] && return
readonly _COMMON_SH_LOADED=1

# ============================================================================
# Color definitions
# ============================================================================
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# ============================================================================
# Logging functions
# ============================================================================
log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_debug() { [[ "${DEBUG:-}" == "1" ]] && echo -e "${BLUE}[DEBUG]${NC} $*"; }

# ============================================================================
# Container utilities
# ============================================================================

# Check if a container is running
# Usage: check_container_health "container_name"
# Returns: 0 if running, 1 otherwise
check_container_health() {
  local container_name="$1"

  if ! docker ps --filter "name=$container_name" --format '{{.Names}}' | grep -q "^${container_name}$"; then
    return 1
  fi

  local status
  status=$(docker inspect --format='{{.State.Status}}' "$container_name" 2>/dev/null)

  [[ "$status" == "running" ]]
}

# Check if a port is accessible
# Usage: check_port "host" "port"
# Returns: 0 if accessible, 1 otherwise
check_port() {
  local host="${1:-localhost}"
  local port="$2"

  if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$host/$port" 2>/dev/null; then
    return 0
  else
    return 1
  fi
}

# ============================================================================
# File utilities
# ============================================================================

# Ensure a directory exists
# Usage: ensure_dir "/path/to/dir"
ensure_dir() {
  local dir="$1"
  [[ -d "$dir" ]] || mkdir -p "$dir"
}

# Check if a command exists
# Usage: require_command "docker" "https://docs.docker.com/get-docker/"
require_command() {
  local cmd="$1"
  local install_url="${2:-}"

  if ! command -v "$cmd" &>/dev/null; then
    log_error "$cmd is not installed"
    [[ -n "$install_url" ]] && log_info "Install from: $install_url"
    return 1
  fi
  return 0
}

# ============================================================================
# Environment utilities
# ============================================================================

# Load .env file if it exists
# Usage: load_env "/path/to/.env"
load_env() {
  local env_file="${1:-.env}"

  if [[ -f "$env_file" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$env_file"
    set +a
    return 0
  fi
  return 1
}

# Validate that required environment variables are set
# Usage: require_env "VAR1" "VAR2" "VAR3"
require_env() {
  local missing=()
  for var in "$@"; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    log_error "Missing required environment variables: ${missing[*]}"
    return 1
  fi
  return 0
}
