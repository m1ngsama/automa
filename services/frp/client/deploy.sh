#!/usr/bin/env bash
# Deploys frpc (FRP client) on home machine.
# Usage: INFRA_DIR=/path/to/infra/services/frp/client ./deploy.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../bin/lib/common.sh"

ENV_FILE="${INFRA_DIR:-.}/.env"
[ -f "$ENV_FILE" ] || { log_error "No .env found at $ENV_FILE"; exit 1; }
source "$ENV_FILE"

require_env FRP_SERVER_ADDR FRP_SERVER_PORT FRP_TOKEN

log_info "Downloading FRP..."
VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest \
    | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'][1:])")
ARCHIVE="frp_${VERSION}_linux_amd64.tar.gz"
wget -q "https://github.com/fatedier/frp/releases/download/v${VERSION}/${ARCHIVE}"
tar -xf "$ARCHIVE"
mkdir -p /opt/frp
cp "frp_${VERSION}_linux_amd64/frpc" /opt/frp/
chmod +x /opt/frp/frpc
rm -rf "$ARCHIVE" "frp_${VERSION}_linux_amd64"

log_info "Deploying config..."
envsubst < "${INFRA_DIR}/frpc.toml.example" > /opt/frp/frpc.toml

log_info "Installing service..."
cp "${INFRA_DIR}/frpc.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now frpc

log_info "FRP client deployed, connecting to ${FRP_SERVER_ADDR}:${FRP_SERVER_PORT}"
