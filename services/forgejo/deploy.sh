#!/usr/bin/env bash
# Deploys Forgejo (self-hosted git) via Docker on a VPS.
# Usage: INFRA_DIR=/path/to/infra/services/forgejo ./deploy.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../bin/lib/common.sh"

ENV_FILE="${INFRA_DIR:-.}/.env"
[ -f "$ENV_FILE" ] || { log_error "No .env found at $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

require_env GIT_DOMAIN
require_command docker "https://docs.docker.com/engine/install/"

find_template() {
    local f="$1"
    if [[ -n "${INFRA_DIR:-}" && -f "${INFRA_DIR}/$f" ]]; then
        echo "${INFRA_DIR}/$f"
    elif [[ -f "$SCRIPT_DIR/$f" ]]; then
        echo "$SCRIPT_DIR/$f"
    else
        log_error "Template not found: $f"
        return 1
    fi
}

DEPLOY_DIR="/opt/forgejo"
log_info "Creating deploy directory $DEPLOY_DIR..."
mkdir -p "$DEPLOY_DIR/data"

log_info "Deploying docker-compose.yml..."
cp "$(find_template docker-compose.yml)" "$DEPLOY_DIR/docker-compose.yml"

log_info "Starting Forgejo container..."
docker compose -f "$DEPLOY_DIR/docker-compose.yml" up -d

log_info "Deploying nginx vhost for ${GIT_DOMAIN}..."
envsubst '${GIT_DOMAIN}' < "$(find_template nginx.conf.example)" > "/etc/nginx/sites-available/forgejo"
ln -sf /etc/nginx/sites-available/forgejo /etc/nginx/sites-enabled/forgejo
nginx -t
systemctl reload nginx

# Optional: set up GitHub mirror sync cron
if [[ -n "${GITHUB_USER:-}" && -n "${GITHUB_TOKEN:-}" && -n "${FORGEJO_URL:-}" && -n "${FORGEJO_TOKEN:-}" ]]; then
    SYNC_SCRIPT="$(find_template migrate_github_to_forgejo.py 2>/dev/null || true)"
    if [[ -n "$SYNC_SCRIPT" ]]; then
        log_info "Installing GitHub mirror sync script..."
        cp "$SYNC_SCRIPT" "$DEPLOY_DIR/migrate_github_to_forgejo.py"
        mkdir -p "$DEPLOY_DIR/logs"

        CRON_LINE="0 3 * * * cd $DEPLOY_DIR && GITHUB_USER=${GITHUB_USER} GITHUB_TOKEN=${GITHUB_TOKEN} FORGEJO_URL=${FORGEJO_URL} FORGEJO_TOKEN=${FORGEJO_TOKEN} python3 migrate_github_to_forgejo.py >> $DEPLOY_DIR/logs/mirror-sync.log 2>&1"
        (crontab -l 2>/dev/null | grep -v "migrate_github_to_forgejo"; echo "$CRON_LINE") | crontab -
        log_info "Cron sync installed (daily 03:00)"
    else
        log_warn "migrate_github_to_forgejo.py not found in INFRA_DIR — skipping cron setup"
    fi
else
    log_info "GitHub sync vars not set — skipping cron setup"
fi

log_info "Forgejo deployed at http://localhost:3000"
echo ""
echo "Remaining manual steps:"
echo "  1. Get TLS cert: certbot --nginx -d ${GIT_DOMAIN}"
echo "  2. Complete Forgejo initial setup at https://${GIT_DOMAIN}"
echo "  3. Generate Forgejo API token: https://${GIT_DOMAIN}/user/settings/applications"
