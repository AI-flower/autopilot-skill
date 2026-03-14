#!/usr/bin/env bash
# ============================================================================
#  praxis — One-click installer for Claude Code
#
#  Usage:
#    bash install.sh            # Install / upgrade
#    bash install.sh --check    # Check current installation status
#
#  What it does:
#    1. Copies plugin files to ~/.claude/skills/praxis/
#    2. Sets correct file permissions
#    3. Verifies installation
#
#  Requirements: bash 4+, python3
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
PLUGIN_VERSION="0.4.3"

# Source: where install.sh lives (the repo/distribution directory)
SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Target: Claude Code skills directory (correct path for skill discovery)
TARGET_DIR="${HOME}/.claude/skills/${PLUGIN_NAME}"

# ── Pre-flight checks ──────────────────────────────────────────────────────
preflight() {
    # Check bash version
    if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
        warn "Bash 4+ recommended (you have ${BASH_VERSION}). Proceeding anyway..."
    fi

    # Check python3
    if ! command -v python3 &>/dev/null; then
        error "python3 is required (used by scripts/report.py)."
        error "Install Python 3 and try again."
        exit 1
    fi

    # Check source files exist
    if [[ ! -f "${SOURCE_DIR}/SKILL.md" ]]; then
        error "SKILL.md not found in ${SOURCE_DIR}"
        error "Run this script from the praxis directory."
        exit 1
    fi

    if [[ ! -d "${SOURCE_DIR}/scripts" ]]; then
        error "scripts/ directory not found in ${SOURCE_DIR}"
        exit 1
    fi

    # Check Claude Code directory exists
    if [[ ! -d "${HOME}/.claude" ]]; then
        warn "${HOME}/.claude does not exist. Creating it..."
        mkdir -p "${HOME}/.claude"
    fi
}

# ── Check mode ──────────────────────────────────────────────────────────────
check_installation() {
    echo -e "${BOLD}=== Praxis Installation Status ===${NC}"
    echo ""

    # Check plugin directory
    if [[ -d "${TARGET_DIR}" ]]; then
        success "Plugin directory exists: ${TARGET_DIR}"

        if [[ -f "${TARGET_DIR}/SKILL.md" ]]; then
            local ver
            ver=$(grep -o 'version: [0-9.]*' "${TARGET_DIR}/SKILL.md" 2>/dev/null | head -1 | awk '{print $2}')
            success "SKILL.md found (version: ${ver:-unknown})"
        else
            error "SKILL.md missing"
        fi

        if [[ -f "${TARGET_DIR}/scripts/report.py" ]]; then
            success "scripts/report.py found"
        else
            error "scripts/report.py missing"
        fi

        if [[ -d "${TARGET_DIR}/references" ]]; then
            success "references/ directory found"
        else
            warn "references/ directory missing"
        fi

        if [[ -d "${TARGET_DIR}/templates" ]]; then
            success "templates/ directory found"
        else
            warn "templates/ directory missing"
        fi

        if [[ -f "${TARGET_DIR}/.claude-plugin/plugin.json" ]]; then
            success ".claude-plugin/plugin.json found"
        else
            error ".claude-plugin/plugin.json missing"
        fi
    else
        error "Plugin directory not found: ${TARGET_DIR}"
    fi

    echo ""
}

# ── Copy plugin files ───────────────────────────────────────────────────────
copy_files() {
    info "Copying plugin files to ${TARGET_DIR} ..."

    # Create target directory structure
    mkdir -p "${TARGET_DIR}/scripts"
    mkdir -p "${TARGET_DIR}/references"
    mkdir -p "${TARGET_DIR}/templates"

    # Copy core files
    cp "${SOURCE_DIR}/SKILL.md" "${TARGET_DIR}/SKILL.md"
    cp "${SOURCE_DIR}/skills.json" "${TARGET_DIR}/skills.json"
    cp "${SOURCE_DIR}/install.sh" "${TARGET_DIR}/install.sh"
    cp "${SOURCE_DIR}/uninstall.sh" "${TARGET_DIR}/uninstall.sh"

    # Copy scripts
    for f in "${SOURCE_DIR}/scripts/"*; do
        [[ -f "$f" ]] && cp "$f" "${TARGET_DIR}/scripts/"
    done

    # Copy references
    for f in "${SOURCE_DIR}/references/"*; do
        [[ -f "$f" ]] && cp "$f" "${TARGET_DIR}/references/"
    done

    # Copy templates
    if [[ -d "${SOURCE_DIR}/templates" ]]; then
        for f in "${SOURCE_DIR}/templates/"*; do
            [[ -f "$f" ]] && cp "$f" "${TARGET_DIR}/templates/"
        done
    fi

    # Set permissions
    chmod +x "${TARGET_DIR}/scripts/"*.sh 2>/dev/null || true
    chmod +x "${TARGET_DIR}/scripts/"*.py 2>/dev/null || true
    chmod +x "${TARGET_DIR}/install.sh"
    chmod +x "${TARGET_DIR}/uninstall.sh"

    success "Plugin files copied."
}

# ── Handle old version cleanup ──────────────────────────────────────────────
cleanup_old_versions() {
    # Clean up legacy plugins/cache/local path if it exists
    local legacy_dir="${HOME}/.claude/plugins/cache/local/${PLUGIN_NAME}"
    if [[ -d "${legacy_dir}" ]]; then
        warn "Found legacy install at ${legacy_dir}, removing..."
        rm -rf "${legacy_dir}"
        success "Removed legacy install."
    fi
    return
    # (version subdirectory logic no longer needed — skills/ is flat)
    local cache_dir="${HOME}/.claude/skills/${PLUGIN_NAME}"
    if [[ ! -d "${cache_dir}" ]]; then
        return
    fi

    for version_dir in "${cache_dir}"/*/; do
        local dir_version
        dir_version=$(basename "${version_dir}")

        # Skip current version
        if [[ "${dir_version}" == "${PLUGIN_VERSION}" ]]; then
            continue
        fi

        # Skip if not a version-like directory
        if [[ ! "${dir_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            continue
        fi

        warn "Found old version: ${dir_version}"
        read -rp "  Remove old version ${dir_version}? [y/N] " answer
        if [[ "${answer}" =~ ^[Yy]$ ]]; then
            rm -rf "${version_dir}"
            success "  Removed ${dir_version}"
        else
            info "  Kept ${dir_version}"
        fi
    done
}

# ── Main ────────────────────────────────────────────────────────────────────
main() {
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   Praxis installer v${PLUGIN_VERSION}              ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
    echo ""

    # Check mode
    if [[ "${1:-}" == "--check" ]]; then
        check_installation
        exit 0
    fi

    # Pre-flight
    preflight

    # Check for existing installation
    if [[ -d "${TARGET_DIR}" ]]; then
        warn "Existing installation found at ${TARGET_DIR}"
        read -rp "Overwrite? [Y/n] " answer
        if [[ "${answer}" =~ ^[Nn]$ ]]; then
            info "Installation cancelled."
            exit 0
        fi
    fi

    # Clean up old versions
    cleanup_old_versions

    # Copy files
    copy_files

    # Done
    echo ""
    echo -e "${BOLD}╔══════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   Installation Complete ✅                   ║${NC}"
    echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}"
    echo ""
    success "Praxis installed to: ${TARGET_DIR}"
    echo ""
    info "First time install? Open a new Claude Code window to activate."
    info "Upgrading?          Changes take effect immediately."
    echo ""
}

main "$@"
