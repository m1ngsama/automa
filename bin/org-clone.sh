#!/usr/bin/env bash
# Clone all repositories from a GitHub organization
# Requires: gh (GitHub CLI)
#
# Usage: ./org-clone.sh <org-name> [destination-dir]
# Example: ./org-clone.sh myorg ~/repos/myorg

set -euo pipefail

# Source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# Check prerequisites
check_prerequisites() {
  if ! command -v gh &>/dev/null; then
    log_error "GitHub CLI (gh) is not installed"
    log_info "Install from: https://cli.github.com/"
    exit 1
  fi

  if ! gh auth status &>/dev/null; then
    log_error "Not authenticated with GitHub CLI"
    log_info "Run: gh auth login"
    exit 1
  fi
}

# Show usage
usage() {
  cat <<EOF
Usage: $0 <org-name> [destination-dir]

Clone all repositories from a GitHub organization.

Arguments:
  org-name        GitHub organization name (required)
  destination-dir Target directory (default: current directory)

Examples:
  $0 myorg
  $0 myorg ~/repos/myorg

Requirements:
  - GitHub CLI (gh) installed and authenticated
EOF
  exit 1
}

# Main function
main() {
  local org_name="${1:-}"
  local dest_dir="${2:-.}"

  # Validate arguments
  if [[ -z "$org_name" ]]; then
    log_error "Organization name is required"
    usage
  fi

  check_prerequisites

  # Create destination directory if needed
  if [[ ! -d "$dest_dir" ]]; then
    log_info "Creating directory: $dest_dir"
    mkdir -p "$dest_dir"
  fi

  # Change to destination directory
  cd "$dest_dir" || {
    log_error "Cannot access directory: $dest_dir"
    exit 1
  }

  log_info "Cloning repositories from organization: $org_name"
  log_info "Destination: $(pwd)"

  # Count repositories
  local repo_count
  repo_count=$(gh repo list "$org_name" --limit 4000 --json name --jq '. | length')

  if [[ "$repo_count" -eq 0 ]]; then
    log_warn "No repositories found for organization: $org_name"
    exit 0
  fi

  log_info "Found $repo_count repositories"

  # Clone repositories
  local success=0
  local failed=0

  while IFS= read -r repo; do
    local repo_name="${repo##*/}"

    if [[ -d "$repo_name" ]]; then
      log_warn "Skipping $repo_name (already exists)"
      continue
    fi

    log_info "Cloning: $repo"

    if gh repo clone "$repo" "$repo_name" 2>/dev/null; then
      ((success++))
      log_info "✓ Successfully cloned: $repo_name"
    else
      ((failed++))
      log_error "✗ Failed to clone: $repo_name"
    fi
  done < <(gh repo list "$org_name" --limit 4000 --json nameWithOwner --jq '.[].nameWithOwner')

  # Summary
  echo
  log_info "=== Clone Summary ==="
  log_info "Success: $success"
  [[ $failed -gt 0 ]] && log_warn "Failed: $failed" || log_info "Failed: $failed"
  log_info "Total: $repo_count"
}

main "$@"
