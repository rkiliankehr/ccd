#!/bin/bash
#
# ccd installer
# https://github.com/rkiliankehr/ccd
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info() { echo -e "${CYAN}$1${NC}"; }
success() { echo -e "${GREEN}$1${NC}"; }
warn() { echo -e "${YELLOW}$1${NC}"; }
error() { echo -e "${RED}$1${NC}"; }

# Determine script location (works for both local and curl install)
if [ -f "ccd" ]; then
    SCRIPT_DIR="$(pwd)"
    CCD_SOURCE="$SCRIPT_DIR/ccd"
else
    # Downloaded via curl, fetch from GitHub
    info "Downloading ccd from GitHub..."
    CCD_SOURCE=$(mktemp)
    curl -fsSL https://raw.githubusercontent.com/rkiliankehr/ccd/main/ccd -o "$CCD_SOURCE"
    CLEANUP_SOURCE=1
fi

# Install location
INSTALL_DIR="$HOME/bin"
INSTALL_PATH="$INSTALL_DIR/ccd"

# Shell config
SHELL_FUNC='
# ccd - quick directory navigation
# https://github.com/rkiliankehr/ccd
function ccd() {
    source ~/bin/ccd "$@"
}'

echo ""
info "Installing ccd..."
echo ""

# Create bin directory
if [ ! -d "$INSTALL_DIR" ]; then
    info "Creating $INSTALL_DIR..."
    mkdir -p "$INSTALL_DIR"
fi

# Copy script
info "Installing to $INSTALL_PATH..."
cp "$CCD_SOURCE" "$INSTALL_PATH"
chmod +x "$INSTALL_PATH"
success "Script installed."

# Cleanup temp file if downloaded
[ "${CLEANUP_SOURCE:-}" = "1" ] && rm -f "$CCD_SOURCE"

# Detect shell and config file
detect_shell_config() {
    if [ -n "$ZSH_VERSION" ] || [ "$SHELL" = "$(which zsh)" ]; then
        echo "$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ] || [ "$SHELL" = "$(which bash)" ]; then
        echo "$HOME/.bashrc"
    else
        echo ""
    fi
}

SHELL_CONFIG=$(detect_shell_config)

# Add shell function
if [ -n "$SHELL_CONFIG" ]; then
    if grep -q "function ccd()" "$SHELL_CONFIG" 2>/dev/null; then
        warn "Shell function already exists in $SHELL_CONFIG"
    else
        info "Adding shell function to $SHELL_CONFIG..."
        echo "$SHELL_FUNC" >> "$SHELL_CONFIG"
        success "Shell function added."
    fi
else
    warn "Could not detect shell config. Add this to your shell config manually:"
    echo "$SHELL_FUNC"
fi

# Check for optional dependencies
echo ""
info "Checking dependencies..."

if command -v fzf >/dev/null 2>&1; then
    success "fzf: installed"
else
    warn "fzf: not found (recommended for interactive selection)"
    echo "  Install: brew install fzf (macOS) or apt install fzf (Linux)"
fi

if command -v fd >/dev/null 2>&1; then
    success "fd: installed"
else
    warn "fd: not found (optional, enables faster indexing)"
    echo "  Install: brew install fd (macOS) or apt install fd-find (Linux)"
fi

# Check if ~/bin is in PATH
if [[ ":$PATH:" != *":$HOME/bin:"* ]]; then
    echo ""
    warn "$HOME/bin is not in your PATH"
    echo "Add this to your shell config:"
    echo '  export PATH="$HOME/bin:$PATH"'
fi

# Done
echo ""
success "Installation complete!"
echo ""
info "Next steps:"
echo "  1. Reload your shell:  source $SHELL_CONFIG"
echo "  2. Build the cache:    ccd -n"
echo "  3. Jump to a directory: ccd <name>"
echo ""
info "Optional: Add keywords to frequently-used directories:"
echo "  cd /path/to/project && ccd -k"
echo ""
