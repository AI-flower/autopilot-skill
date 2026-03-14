#!/bin/bash
# Praxis - Environment Detection Script
# Outputs JSON summary of user's environment for smart recommendations

set -e

OS=$(uname -s)
ARCH=$(uname -m)

# Detect package manager
PKG_MANAGER="none"
if command -v brew &>/dev/null; then PKG_MANAGER="brew"
elif command -v apt-get &>/dev/null; then PKG_MANAGER="apt"
elif command -v yum &>/dev/null; then PKG_MANAGER="yum"
elif command -v pacman &>/dev/null; then PKG_MANAGER="pacman"
fi

# Detect installed tools
detect() { command -v "$1" &>/dev/null && echo "true" || echo "false"; }

cat <<EOF
{
  "os": "$OS",
  "arch": "$ARCH",
  "pkg_manager": "$PKG_MANAGER",
  "tools": {
    "git": $(detect git),
    "node": $(detect node),
    "python3": $(detect python3),
    "docker": $(detect docker),
    "go": $(detect go),
    "rust": $(detect cargo),
    "java": $(detect java),
    "ruby": $(detect ruby),
    "php": $(detect php),
    "ffmpeg": $(detect ffmpeg),
    "imagemagick": $(detect convert),
    "pandoc": $(detect pandoc),
    "jq": $(detect jq),
    "gh": $(detect gh),
    "curl": $(detect curl),
    "wget": $(detect wget),
    "sqlite3": $(detect sqlite3),
    "redis-cli": $(detect redis-cli),
    "psql": $(detect psql),
    "mysql": $(detect mysql),
    "msmtp": $(detect msmtp),
    "sendmail": $(detect sendmail)
  },
  "configs": {
    "ssh_key": $([ -f ~/.ssh/id_ed25519 ] || [ -f ~/.ssh/id_rsa ] && echo "true" || echo "false"),
    "git_configured": $(git config --global user.email &>/dev/null && echo "true" || echo "false"),
    "docker_running": $(docker info &>/dev/null 2>&1 && echo "true" || echo "false"),
    "has_env_file": $([ -f ~/.env ] || [ -f .env ] && echo "true" || echo "false"),
    "has_praxis_config": $([ -f ~/.ai-praxis/config.json ] && echo "true" || echo "false")
  }
}
EOF
