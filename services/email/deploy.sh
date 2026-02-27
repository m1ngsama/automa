#!/usr/bin/env bash
# Deploys Postfix + Dovecot + OpenDKIM + SpamAssassin email stack.
# Usage: INFRA_DIR=/path/to/infra/services/email ./deploy.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../bin/lib/common.sh"

ENV_FILE="${INFRA_DIR:-.}/.env"
[ -f "$ENV_FILE" ] || { log_error "No .env found at $ENV_FILE"; exit 1; }
set -a; source "$ENV_FILE"; set +a

require_env DOMAIN MAIL_HOST MAIL_USER

log_info "Installing packages..."
apt-get install -y postfix dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd \
    dovecot-sieve opendkim opendkim-tools spamassassin spamc

log_info "Deploying Postfix config..."
envsubst < "${INFRA_DIR}/postfix/main.cf" > /etc/postfix/main.cf
cp "${INFRA_DIR}/postfix/aliases" /etc/aliases
newaliases

log_info "Deploying Dovecot config..."
cp "${INFRA_DIR}/dovecot/dovecot.conf" /etc/dovecot/dovecot.conf
cp "${INFRA_DIR}/dovecot/99-stats-fix.conf" /etc/dovecot/conf.d/99-stats-fix.conf

log_info "Adding postfix to dovecot group..."
usermod -aG dovecot postfix

log_info "Enabling services..."
systemctl enable --now postfix dovecot opendkim spamassassin

log_info "Email stack deployed. Remaining manual steps:"
echo "  1. Run certbot for mail.${DOMAIN}"
echo "  2. Generate DKIM key: opendkim-genkey -b 2048 -d ${DOMAIN} -s mail -D /etc/opendkim/keys/${DOMAIN}/"
echo "  3. Add DNS records (see services/email/README.md)"
