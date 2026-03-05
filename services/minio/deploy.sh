#!/usr/bin/env bash
# Deploys MinIO object storage server.
# https://min.io/docs/minio/linux/index.html
#
# Usage: INFRA_DIR=/path/to/infra/services/minio ./deploy.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../bin/lib/common.sh"

ENV_FILE="${INFRA_DIR:-.}/.env"
[ -f "$ENV_FILE" ] || { log_error "No .env found at $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

require_env MINIO_ROOT_USER MINIO_ROOT_PASSWORD MINIO_VOLUMES

BIN="/usr/local/bin/minio"

if [[ -x "$BIN" ]]; then
    log_info "minio already at $BIN, skipping download"
else
    log_info "Downloading MinIO..."
    wget -qO "$BIN" https://dl.min.io/server/minio/release/linux-amd64/minio
    chmod +x "$BIN"
fi

log_info "Creating minio-user..."
if ! id minio-user &>/dev/null; then
    useradd --system --no-create-home --shell /usr/sbin/nologin minio-user
fi

log_info "Creating data directory: ${MINIO_VOLUMES}..."
mkdir -p "${MINIO_VOLUMES}"
chown minio-user:minio-user "${MINIO_VOLUMES}"

log_info "Writing /etc/default/minio..."
cat > /etc/default/minio <<EOF
MINIO_ROOT_USER=${MINIO_ROOT_USER}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
MINIO_VOLUMES=${MINIO_VOLUMES}
MINIO_OPTS=${MINIO_OPTS:---console-address :9001}
MINIO_BROWSER_REDIRECT_URL=${MINIO_BROWSER_REDIRECT_URL:-}
MINIO_SERVER_URL=${MINIO_SERVER_URL:-}
EOF
chmod 640 /etc/default/minio
chown root:minio-user /etc/default/minio

log_info "Installing systemd service..."
cat > /etc/systemd/system/minio.service <<'EOF'
[Unit]
Description=MinIO
Documentation=https://min.io/docs/minio/linux/index.html
Wants=network-online.target
After=network-online.target
AssertFileIsExecutable=/usr/local/bin/minio

[Service]
WorkingDirectory=/usr/local
User=minio-user
Group=minio-user
EnvironmentFile=/etc/default/minio
ExecStartPre=/bin/bash -c 'if [ -z "${MINIO_VOLUMES}" ]; then echo "MINIO_VOLUMES not set"; exit 1; fi'
ExecStart=/usr/local/bin/minio server $MINIO_OPTS $MINIO_VOLUMES
Restart=always
LimitNOFILE=65536
TasksMax=infinity
TimeoutStopSec=infinity
SendSIGKILL=no

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now minio

log_info "MinIO deployed"
echo "  API:     http://localhost:9000"
echo "  Console: http://localhost:9001"
echo ""
echo "Remaining manual steps:"
echo "  1. Configure nginx reverse proxy (see infra/services/nginx/sites/)"
echo "  2. Get TLS cert: certbot --nginx -d ${MINIO_SERVER_URL#https://}"
