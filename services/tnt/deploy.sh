#!/usr/bin/env bash
# Deploys TNT terminal chat server.
# https://github.com/m1ngsama/TNT
#
# Usage: INFRA_DIR=/path/to/infra/services/tnt ./deploy.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../bin/lib/common.sh"

ENV_FILE="${INFRA_DIR:-.}/.env"
[ -f "$ENV_FILE" ] || { log_error "No .env found at $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

require_env TNT_PORT TNT_ACCESS_TOKEN

BIN="/usr/local/bin/tnt"
DATA_DIR="/var/lib/tnt"

if [[ -x "$BIN" ]]; then
    log_info "tnt already at $BIN, skipping download"
else
    log_info "Installing tnt via official installer..."
    curl -sSL https://raw.githubusercontent.com/m1ngsama/TNT/main/install.sh | sh
fi

log_info "Setting up data directory..."
mkdir -p "$DATA_DIR"

# Create unprivileged user if not exists
if ! id tnt &>/dev/null; then
    useradd --system --no-create-home --shell /usr/sbin/nologin tnt
fi
chown tnt:tnt "$DATA_DIR"

log_info "Installing systemd service..."
cat > /etc/systemd/system/tnt.service <<EOF
[Unit]
Description=TNT Terminal Chat Server
After=network.target

[Service]
Type=simple
User=tnt
Group=tnt
WorkingDirectory=$DATA_DIR
ExecStart=$BIN -p ${TNT_PORT}
Restart=always
RestartSec=5

Environment="TNT_ACCESS_TOKEN=${TNT_ACCESS_TOKEN}"
Environment="TNT_BIND_ADDR=${TNT_BIND_ADDR:-0.0.0.0}"
Environment="TNT_MAX_CONNECTIONS=${TNT_MAX_CONNECTIONS:-50}"
Environment="TNT_MAX_CONN_PER_IP=${TNT_MAX_CONN_PER_IP:-3}"

NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$DATA_DIR

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now tnt

log_info "TNT deployed on port ${TNT_PORT}"
echo "  Connect: ssh -p ${TNT_PORT} <host>"
