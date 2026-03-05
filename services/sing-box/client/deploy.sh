#!/usr/bin/env bash
# Deploys sing-box as a transparent proxy client (home machine / LAN gateway).
#
# Usage: INFRA_DIR=/path/to/infra/services/sing-box/client ./deploy.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../bin/lib/common.sh"

ENV_FILE="${INFRA_DIR:-.}/.env"
[ -f "$ENV_FILE" ] || { log_error "No .env found at $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

require_env SING_BOX_VERSION

INSTALL_DIR="/etc/sing-box"
BIN="$INSTALL_DIR/sing-box"

if [[ -x "$BIN" ]]; then
    log_info "sing-box already at $BIN, skipping download"
else
    log_info "Downloading sing-box ${SING_BOX_VERSION}..."
    ARCH="$(uname -m)"
    case "$ARCH" in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        *) log_error "Unsupported arch: $ARCH"; exit 1 ;;
    esac
    URL="https://github.com/SagerNet/sing-box/releases/download/v${SING_BOX_VERSION}/sing-box-${SING_BOX_VERSION}-linux-${ARCH}.tar.gz"
    TMP="$(mktemp -d)"
    wget -qO "$TMP/sing-box.tar.gz" "$URL"
    tar -xf "$TMP/sing-box.tar.gz" -C "$TMP"
    mkdir -p "$INSTALL_DIR"
    install -m 755 "$TMP/sing-box-${SING_BOX_VERSION}-linux-${ARCH}/sing-box" "$BIN"
    rm -rf "$TMP"
fi

log_info "Deploying client config..."
CONFIG_SRC="${INFRA_DIR}/sing_box_client.json"
[ -f "$CONFIG_SRC" ] || { log_error "sing_box_client.json not found in INFRA_DIR"; exit 1; }
cp "$CONFIG_SRC" "$INSTALL_DIR/config.json"

log_info "Installing systemd service..."
cat > /etc/systemd/system/sing-box-client.service <<'EOF'
[Unit]
Description=sing-box Client
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
ExecStart=/etc/sing-box/sing-box run -c /etc/sing-box/config.json
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=10
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now sing-box-client

log_info "sing-box client deployed"
