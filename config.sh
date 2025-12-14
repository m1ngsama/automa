#!/usr/bin/env bash
# Centralized configuration for all services
# Source this file to get consistent container names and settings

# Prevent multiple sourcing
[[ -n "${_CONFIG_SH_LOADED:-}" ]] && return
readonly _CONFIG_SH_LOADED=1

# ============================================================================
# Container Names
# ============================================================================
# These are the canonical container names used across all scripts.
# Update here if container names change in docker-compose.yml files.

readonly CONTAINER_MINECRAFT="${CONTAINER_MINECRAFT:-mc-fabric-1.21.1}"
readonly CONTAINER_TEAMSPEAK="${CONTAINER_TEAMSPEAK:-teamspeak-server}"
readonly CONTAINER_NEXTCLOUD="${CONTAINER_NEXTCLOUD:-nextcloud}"
readonly CONTAINER_NEXTCLOUD_DB="${CONTAINER_NEXTCLOUD_DB:-nextcloud-db}"
readonly CONTAINER_NEXTCLOUD_REDIS="${CONTAINER_NEXTCLOUD_REDIS:-nextcloud-redis}"

# ============================================================================
# Service Ports
# ============================================================================
readonly PORT_MINECRAFT=25565
readonly PORT_MINECRAFT_RCON=25575
readonly PORT_TEAMSPEAK_VOICE=9987
readonly PORT_TEAMSPEAK_FILETRANSFER=30033
readonly PORT_TEAMSPEAK_QUERY=10011
readonly PORT_NEXTCLOUD_WEB=8080

# ============================================================================
# Backup Configuration
# ============================================================================
readonly BACKUP_ROOT="${BACKUP_ROOT:-./backups}"
readonly BACKUP_RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-7}"

# ============================================================================
# Helper function to get project root
# ============================================================================
get_project_root() {
  local script_path="${BASH_SOURCE[1]:-$0}"
  cd "$(dirname "$script_path")" && pwd
}
