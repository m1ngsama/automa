#!/usr/bin/env bash
# Installs shadowsocks-rust client (sslocal) + privoxy proxy chain.
# Usage: INFRA_DIR=/path/to/infra/services/shadowsocks/client ./deploy.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../bin/lib/common.sh"

ENV_FILE="${INFRA_DIR:-.}/.env"
[ -f "$ENV_FILE" ] || { log_error "No .env found at $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

require_env SS_SERVER SS_PORT SS_PASSWORD SS_METHOD

# Find a template file: prefer INFRA_DIR override, fall back to bundled default.
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

SSLOCAL_BIN="/usr/local/bin/sslocal"

# Install sslocal — skip if already present, symlink if installed elsewhere.
if [[ -x "$SSLOCAL_BIN" ]]; then
    log_info "sslocal already at $SSLOCAL_BIN ($($SSLOCAL_BIN --version 2>&1 | head -1)), skipping download"
elif command -v sslocal &>/dev/null; then
    existing="$(command -v sslocal)"
    log_info "sslocal found at $existing, symlinking to $SSLOCAL_BIN"
    ln -sf "$existing" "$SSLOCAL_BIN"
else
    log_info "Downloading shadowsocks-rust client..."
    VERSION=$(curl -s https://api.github.com/repos/shadowsocks/shadowsocks-rust/releases/latest \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])")
    ARCHIVE="shadowsocks-${VERSION}.x86_64-unknown-linux-gnu.tar.xz"
    wget -q "https://github.com/shadowsocks/shadowsocks-rust/releases/download/${VERSION}/${ARCHIVE}"
    tar -xf "$ARCHIVE"
    cp sslocal "$SSLOCAL_BIN"
    chmod +x "$SSLOCAL_BIN"
    rm -f "$ARCHIVE" ssserver sslocal ssurl ssmanager redir tunnel
fi

log_info "Installing privoxy..."
if command -v pacman &>/dev/null; then
    pacman -S --noconfirm --needed privoxy
else
    apt-get install -y privoxy
fi

log_info "Deploying configs..."
mkdir -p /etc/shadowsocks-rust
envsubst < "$(find_template config.json.example)" > /etc/shadowsocks-rust/client.json
cp "$(find_template privoxy.conf.example)" /etc/privoxy/config

log_info "Stopping any existing shadowsocks service on port 1080..."
systemctl stop shadowsocks 2>/dev/null || true

log_info "Installing service..."
cp "$(find_template shadowsocks-client.service)" /etc/systemd/system/
systemctl daemon-reload
systemctl enable --now shadowsocks-client
systemctl enable --now privoxy

log_info "Proxy chain ready: SOCKS5 at 127.0.0.1:1080, HTTP at 127.0.0.1:8118"
