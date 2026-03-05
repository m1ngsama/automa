#!/usr/bin/env bash
# Deploys frps (FRP server) on VPS.
# Usage: INFRA_DIR=/path/to/infra/services/frp/server ./deploy.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../bin/lib/common.sh"

ENV_FILE="${INFRA_DIR:-.}/.env"
[ -f "$ENV_FILE" ] || { log_error "No .env found at $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

require_env FRP_TOKEN FRP_WEB_USER FRP_WEB_PASSWORD FRP_BIND_PORT

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

FRPS_BIN="/opt/frp/frps"

if [[ -x "$FRPS_BIN" ]]; then
    log_info "frps already at $FRPS_BIN, skipping download"
else
    log_info "Downloading FRP..."
    VERSION=$(curl -s https://api.github.com/repos/fatedier/frp/releases/latest \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'][1:])")
    ARCHIVE="frp_${VERSION}_linux_amd64.tar.gz"
    wget -q "https://github.com/fatedier/frp/releases/download/v${VERSION}/${ARCHIVE}"
    tar -xf "$ARCHIVE"
    mkdir -p /opt/frp
    cp "frp_${VERSION}_linux_amd64/frps" /opt/frp/
    chmod +x /opt/frp/frps
    rm -rf "$ARCHIVE" "frp_${VERSION}_linux_amd64"
fi

log_info "Deploying config..."
envsubst < "$(find_template frps.toml.example)" > /opt/frp/frps.toml

log_info "Installing service..."
cp "$(find_template frps.service)" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now frps

log_info "FRP server deployed on port ${FRP_BIND_PORT}"
