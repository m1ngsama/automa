#!/usr/bin/env bash
# automa installer
# Usage: curl -fsSL https://raw.githubusercontent.com/m1ngsama/automa/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/m1ngsama/automa.git"
INSTALL_DIR="${AUTOMA_DIR:-$HOME/automa}"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $*"; }
error() { echo -e "${RED}[-]${NC} $*" >&2; }

echo ""
echo -e "${CYAN}${BOLD}  automa installer${NC}"
echo ""

# Check prerequisites
for cmd in git docker; do
    if ! command -v "$cmd" &>/dev/null; then
        error "$cmd is required but not installed."
        exit 1
    fi
done

if ! docker compose version &>/dev/null 2>&1; then
    error "docker compose plugin is required."
    error "Install: https://docs.docker.com/compose/install/"
    exit 1
fi

# Clone or update
if [[ -d "$INSTALL_DIR/.git" ]]; then
    info "Updating existing installation..."
    git -C "$INSTALL_DIR" pull --ff-only
else
    info "Cloning automa to ${INSTALL_DIR}..."
    git clone "$REPO" "$INSTALL_DIR"
fi

chmod +x "$INSTALL_DIR/automa"

echo ""
info "Installed to ${INSTALL_DIR}"
echo ""
echo -e "  ${BOLD}Next steps:${NC}"
echo -e "    cd ${INSTALL_DIR}"
echo -e "    ./automa deploy"
echo ""
