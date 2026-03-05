#!/usr/bin/env bash
# Deploys Galene video conferencing server.
# https://github.com/jech/galene
#
# Usage: INFRA_DIR=/path/to/infra/services/galene ./deploy.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../bin/lib/common.sh"

ENV_FILE="${INFRA_DIR:-.}/.env"
[ -f "$ENV_FILE" ] || { log_error "No .env found at $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

require_env GALENE_VERSION GALENE_HTTP_ADDR GALENE_TURN_ADDR

INSTALL_DIR="/opt/galene"
BIN="$INSTALL_DIR/galene"

if [[ -x "$BIN" ]]; then
    log_info "galene already at $BIN, skipping download"
else
    log_info "Downloading Galene ${GALENE_VERSION}..."
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *) log_error "Unsupported arch: $ARCH"; exit 1 ;;
    esac
    URL="https://github.com/jech/galene/releases/download/galene-${GALENE_VERSION}/galene-${GALENE_VERSION}-linux-${ARCH}.tar.gz"
    TMP="$(mktemp -d)"
    wget -qO "$TMP/galene.tar.gz" "$URL"
    mkdir -p "$INSTALL_DIR"
    tar -xf "$TMP/galene.tar.gz" -C "$INSTALL_DIR" --strip-components=1
    chmod +x "$BIN"
    rm -rf "$TMP"
fi

log_info "Creating directories..."
mkdir -p "$INSTALL_DIR"/{data,groups,static}

log_info "Deploying groups config from INFRA_DIR..."
if [[ -d "${INFRA_DIR}/groups" ]]; then
    cp -r "${INFRA_DIR}/groups/." "$INSTALL_DIR/groups/"
fi

log_info "Installing systemd service..."
cat > /etc/systemd/system/galene.service <<EOF
[Unit]
Description=Galene videoconference server
After=network.target

[Service]
Type=simple
WorkingDirectory=$INSTALL_DIR
ExecStart=$BIN \\
    -insecure \\
    -http ${GALENE_HTTP_ADDR} \\
    -static $INSTALL_DIR/static \\
    -groups $INSTALL_DIR/groups \\
    -data $INSTALL_DIR/data \\
    -turn ${GALENE_TURN_ADDR} \\
    -udp-range ${GALENE_UDP_RANGE:-10000-10100}
Restart=always
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now galene

log_info "Galene deployed"
echo "  Listening: ${GALENE_HTTP_ADDR}"
echo ""
echo "Remaining manual steps:"
echo "  1. Configure nginx reverse proxy (see infra/services/nginx/sites/)"
echo "  2. Get TLS cert for frontend domain"
echo "  3. Open UDP ports ${GALENE_UDP_RANGE:-10000-10100} in firewall"
