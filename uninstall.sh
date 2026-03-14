#!/usr/bin/env bash
# ============================================================================
#  praxis — Uninstaller for Claude Code
#
#  Usage:
#    bash uninstall.sh    # Remove praxis skill
#
# ============================================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

info()    { echo -e "${CYAN}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

# ── Configuration ───────────────────────────────────────────────────────────
PLUGIN_NAME="praxis"
TARGET_DIR="${HOME}/.claude/skills/${PLUGIN_NAME}"

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   Praxis uninstaller                     ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
    echo ""

    if [[ ! -d "${TARGET_DIR}" ]]; then
        error "Praxis is not installed at ${TARGET_DIR}"
        exit 1
    fi

    echo -e "About to remove: ${BOLD}${PLUGIN_NAME}${NC}"
    echo -e "  Path: ${TARGET_DIR}"
    echo ""

    read -rp "Proceed with uninstall? [y/N] " answer
    if [[ ! "${answer}" =~ ^[Yy]$ ]]; then
        info "Uninstall cancelled."
        exit 0
    fi

    rm -rf "${TARGET_DIR}"
    success "Removed ${TARGET_DIR}"

    echo ""
    success "Uninstall complete."
    echo ""
}

main "$@"
