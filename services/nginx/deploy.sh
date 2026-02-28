#!/usr/bin/env bash
# Deploys Nginx web server and vhost configs.
# Usage: INFRA_DIR=/path/to/infra/services/nginx ./deploy.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../bin/lib/common.sh"

ENV_FILE="${INFRA_DIR:-.}/.env"
[ -f "$ENV_FILE" ] || { log_error "No .env found at $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

require_env DOMAIN

log_info "Installing nginx..."
apt-get install -y nginx certbot python3-certbot-nginx

log_info "Deploying nginx.conf..."
cp "${INFRA_DIR}/nginx.conf" /etc/nginx/nginx.conf

log_info "Deploying vhost configs..."
mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

for conf in "${INFRA_DIR}/sites/"*.conf; do
    name="$(basename "$conf" .conf)"
    envsubst '${DOMAIN}${BLOG_DOMAIN}${CHAN_DOMAIN}${MAIL_DOMAIN}${GIT_DOMAIN}' < "$conf" > "/etc/nginx/sites-available/${name}"
    ln -sf "/etc/nginx/sites-available/${name}" "/etc/nginx/sites-enabled/${name}"
    log_info "  Deployed ${name}"
done

log_info "Testing nginx config..."
nginx -t

log_info "Nginx deployed. Remaining manual steps:"
echo "  1. Get TLS certs: certbot --nginx -d ${DOMAIN} -d ${CHAN_DOMAIN:-chan.${DOMAIN}} -d ${BLOG_DOMAIN:-blog.${DOMAIN}}"
echo "  2. systemctl reload nginx"
