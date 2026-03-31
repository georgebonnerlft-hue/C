#!/usr/bin/env bash
set -euo pipefail

# Claude Code Installer
# Usage: curl -fsSL https://claude.ai/install.sh | bash

PACKAGE_NAME="@anthropic-ai/claude-code"
BINARY_NAME="claude"

# Terminal colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${BLUE}${BOLD}info${RESET}  $*"; }
success() { echo -e "${GREEN}${BOLD}success${RESET}  $*"; }
warn()    { echo -e "${YELLOW}${BOLD}warn${RESET}  $*"; }
error()   { echo -e "${RED}${BOLD}error${RESET}  $*" >&2; }
die()     { error "$*"; exit 1; }

# Detect OS
detect_os() {
  case "$(uname -s)" in
    Linux*)   echo "linux" ;;
    Darwin*)  echo "macos" ;;
    MINGW*|MSYS*|CYGWIN*) echo "windows" ;;
    *)        echo "unknown" ;;
  esac
}

# Detect architecture
detect_arch() {
  case "$(uname -m)" in
    x86_64|amd64) echo "x64" ;;
    arm64|aarch64) echo "arm64" ;;
    *)            echo "unknown" ;;
  esac
}

# Check if a command exists
has_cmd() {
  command -v "$1" &>/dev/null
}

# Get Node.js major version
node_major_version() {
  node --version 2>/dev/null | sed 's/v//' | cut -d. -f1
}

# Ensure Node.js >= 18 is available
check_node() {
  if ! has_cmd node; then
    return 1
  fi
  local ver
  ver=$(node_major_version)
  [[ "$ver" -ge 18 ]] 2>/dev/null
}

# Install Node.js via the appropriate method for the platform
install_node() {
  local os="$1"
  info "Node.js 18+ is required but was not found. Attempting to install..."

  if has_cmd brew; then
    info "Installing Node.js via Homebrew..."
    brew install node
  elif has_cmd apt-get; then
    info "Installing Node.js via apt..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
  elif has_cmd yum; then
    info "Installing Node.js via yum..."
    curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
    sudo yum install -y nodejs
  elif has_cmd dnf; then
    info "Installing Node.js via dnf..."
    curl -fsSL https://rpm.nodesource.com/setup_lts.x | sudo bash -
    sudo dnf install -y nodejs
  elif has_cmd pacman; then
    info "Installing Node.js via pacman..."
    sudo pacman -Sy --noconfirm nodejs npm
  elif has_cmd apk; then
    info "Installing Node.js via apk..."
    sudo apk add --no-cache nodejs npm
  else
    die "Could not install Node.js automatically. Please install Node.js 18+ from https://nodejs.org and re-run this script."
  fi

  if ! check_node; then
    die "Node.js installation failed or version is still below 18. Please install Node.js 18+ manually from https://nodejs.org"
  fi
  success "Node.js installed successfully."
}

# Determine the npm install flags based on available permissions
npm_install_args() {
  # If running as root, skip the --user flag concerns
  if [[ "$(id -u)" -eq 0 ]]; then
    echo "-g"
  else
    echo "-g"
  fi
}

main() {
  local os arch

  os=$(detect_os)
  arch=$(detect_arch)

  echo ""
  echo -e "${BOLD}Claude Code Installer${RESET}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  info "Platform: ${os}/${arch}"
  echo ""

  # --- Node.js check ---
  if ! check_node; then
    install_node "$os"
  else
    info "Node.js $(node --version) detected."
  fi

  # --- npm check ---
  if ! has_cmd npm; then
    die "npm is required but was not found. Please install Node.js 18+ from https://nodejs.org"
  fi

  # --- Install Claude Code ---
  info "Installing ${PACKAGE_NAME}..."

  local npm_flags
  npm_flags=$(npm_install_args)

  if npm install ${npm_flags} "${PACKAGE_NAME}" 2>&1; then
    echo ""
    success "${BOLD}Claude Code installed successfully!${RESET}"
  else
    # Retry with --force in case of peer dependency conflicts
    warn "Initial install encountered issues, retrying with --force..."
    if npm install ${npm_flags} --force "${PACKAGE_NAME}" 2>&1; then
      echo ""
      success "${BOLD}Claude Code installed successfully!${RESET}"
    else
      die "Failed to install ${PACKAGE_NAME}. Please check the output above for details."
    fi
  fi

  # --- Verify installation ---
  if has_cmd "$BINARY_NAME"; then
    local version
    version=$("$BINARY_NAME" --version 2>/dev/null || echo "unknown")
    info "Installed version: ${version}"
  else
    warn "'${BINARY_NAME}' binary not found in PATH after installation."
    warn "You may need to add npm's global bin directory to your PATH."
    warn "Run: npm bin -g"
  fi

  echo ""
  echo -e "${BOLD}Get started:${RESET}"
  echo "  ${BLUE}claude${RESET}              Start an interactive session"
  echo "  ${BLUE}claude \"<prompt>\"${RESET}   Run a one-shot prompt"
  echo "  ${BLUE}claude --help${RESET}       Show all options"
  echo ""
  echo "  Docs: https://docs.anthropic.com/claude-code"
  echo ""
}

main "$@"
