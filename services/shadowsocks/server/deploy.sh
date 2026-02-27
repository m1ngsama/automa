#!/usr/bin/env bash
# Installs shadowsocks-rust server and configures systemd service.
# Usage: INFRA_DIR=/path/to/infra/services/shadowsocks/server ./deploy.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../bin/lib/common.sh"

ENV_FILE="${INFRA_DIR:-.}/.env"
[ -f "$ENV_FILE" ] || { log_error "No .env found at $ENV_FILE"; exit 1; }
source "$ENV_FILE"

require_env SS_PORT SS_PASSWORD SS_METHOD

SSSERVER_BIN="/usr/local/bin/ssserver-rust"

if [[ -x "$SSSERVER_BIN" ]]; then
    log_info "ssserver-rust already at $SSSERVER_BIN ($($SSSERVER_BIN --version 2>&1 | head -1)), skipping download"
elif command -v ssserver &>/dev/null; then
    existing="$(command -v ssserver)"
    log_info "ssserver found at $existing, symlinking to $SSSERVER_BIN"
    ln -sf "$existing" "$SSSERVER_BIN"
else
    log_info "Downloading shadowsocks-rust..."
    VERSION=$(curl -s https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
    ARCHIVE="shadowsocks-${VERSION}.x86_64-unknown-linux-gnu.tar.xz"
    wget -q "https://github.com/shadowsocks/shadowsocks-rust/releases/download/${VERSION}/${ARCHIVE}"
    tar -xf "$ARCHIVE"
    cp ssserver "$SSSERVER_BIN"
    chmod +x "$SSSERVER_BIN"
    rm -f "$ARCHIVE" ssserver sslocal ssurl ssmanager redir tunnel
fi

log_info "Deploying config..."
mkdir -p /etc/shadowsocks-rust
envsubst < "${INFRA_DIR}/config.json.example" > /etc/shadowsocks-rust/config.json

log_info "Installing service..."
cp "${INFRA_DIR}/shadowsocks-rust.service" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now shadowsocks-rust

log_info "Shadowsocks server deployed on port ${SS_PORT}"
