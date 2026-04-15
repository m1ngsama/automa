#!/usr/bin/env bash
# automa installer
# Usage: curl -fsSL https://raw.githubusercontent.com/m1ngsama/automa/main/install.sh | bash
set -euo pipefail

REPO="https://github.com/m1ngsama/automa.git"
INSTALL_DIR="${AUTOMA_DIR:-$HOME/automa}"

RED='\033[0;31m'  GREEN='\033[0;32m'  CYAN='\033[0;36m'
BOLD='\033[1m'    DIM='\033[2m'       NC='\033[0m'

info()  { echo -e "  ${GREEN}\xe2\x9c\x94${NC}  $*"; }
error() { echo -e "  ${RED}\xe2\x9c\x98${NC}  $*" >&2; }
step()  { echo -e "  ${CYAN}\xe2\x96\xb6${NC}  ${BOLD}$*${NC}"; }

echo ""
echo -e "  ${BOLD}${CYAN}automa${NC}${BOLD} installer${NC}"
echo ""

# Check prerequisites
missing=0
for cmd in git docker; do
    if command -v "$cmd" &>/dev/null; then
        info "$cmd found"
    else
        error "$cmd is not installed"
        missing=1
    fi
done

if docker compose version &>/dev/null 2>&1; then
    info "docker compose plugin found"
else
    error "docker compose plugin is not installed"
    echo -e "     ${DIM}Install: https://docs.docker.com/compose/install/${NC}"
    missing=1
fi

if [[ $missing -eq 1 ]]; then
    echo ""
    error "Please install missing dependencies and try again"
    exit 1
fi

echo ""

# Clone or update
if [[ -d "$INSTALL_DIR/.git" ]]; then
    step "Updating existing installation..."
    git -C "$INSTALL_DIR" pull --ff-only --quiet
    info "Updated"
else
    step "Installing to ${INSTALL_DIR}..."
    git clone --quiet "$REPO" "$INSTALL_DIR"
    info "Cloned"
fi

chmod +x "$INSTALL_DIR/automa"

echo ""
echo -e "  ${GREEN}${BOLD}Ready!${NC}"
echo ""
echo -e "     ${DIM}Get started:${NC}"
echo -e "     ${BOLD}cd ${INSTALL_DIR}${NC}"
echo -e "     ${BOLD}./automa deploy${NC}"
echo ""
