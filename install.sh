#!/usr/bin/env bash
# smux — one-command tmux setup
set -euo pipefail

VERSION="1.0.0"
REPO="ShawnPana/smux"
BRANCH="main"
BASE_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}"
SMUX_DIR="$HOME/.smux"
BIN_DIR="$SMUX_DIR/bin"
BACKUP_DIR="$SMUX_DIR/backups"
TMUX_XDG_DIR="$HOME/.config/tmux"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

info()  { printf "${GREEN}[smux]${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}[smux]${NC} %s\n" "$*"; }
error() { printf "${RED}[smux]${NC} %s\n" "$*" >&2; exit 1; }

# --- OS / package manager detection ---

detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)  echo "linux" ;;
    *)      error "Unsupported OS: $(uname -s)" ;;
  esac
}

detect_pkg_manager() {
  if command -v brew >/dev/null 2>&1; then echo "brew"
  elif command -v apt-get >/dev/null 2>&1; then echo "apt"
  elif command -v dnf >/dev/null 2>&1; then echo "dnf"
  elif command -v pacman >/dev/null 2>&1; then echo "pacman"
  elif command -v apk >/dev/null 2>&1; then echo "apk"
  else echo "unknown"
  fi
}

pkg_install() {
  local pkg="$1"
  local mgr
  mgr=$(detect_pkg_manager)
  info "Installing $pkg via $mgr..."
  case "$mgr" in
    brew)   brew install "$pkg" ;;
    apt)    sudo apt-get update -qq && sudo apt-get install -y -qq "$pkg" ;;
    dnf)    sudo dnf install -y -q "$pkg" ;;
    pacman) sudo pacman -S --noconfirm "$pkg" ;;
    apk)    sudo apk add "$pkg" ;;
    *)      error "No supported package manager found. Install $pkg manually and re-run." ;;
  esac
}

# --- Helpers ---

check_tmux_version() {
  local ver
  ver=$(tmux -V 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' || echo "0.0")
  local major minor
  major=$(echo "$ver" | cut -d. -f1)
  minor=$(echo "$ver" | cut -d. -f2)
  if (( major < 3 || (major == 3 && minor < 2) )); then
    warn "tmux $ver detected. Version 3.2+ recommended for full visual features."
  fi
}

backup_existing() {
  local ts
  ts=$(date +%Y%m%d-%H%M%S)
  mkdir -p "$BACKUP_DIR"

  # Check XDG location
  if [[ -f "$TMUX_XDG_DIR/tmux.conf" && ! -L "$TMUX_XDG_DIR/tmux.conf" ]]; then
    cp "$TMUX_XDG_DIR/tmux.conf" "$BACKUP_DIR/tmux.conf.$ts"
    info "Backed up ~/.config/tmux/tmux.conf → ~/.smux/backups/tmux.conf.$ts"
  fi

  # Check legacy location
  if [[ -f "$HOME/.tmux.conf" ]]; then
    cp "$HOME/.tmux.conf" "$BACKUP_DIR/tmux.conf.legacy.$ts"
    info "Backed up ~/.tmux.conf → ~/.smux/backups/tmux.conf.legacy.$ts"
  fi
}

ensure_path() {
  if echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    return
  fi

  local rc_file=""
  case "${SHELL:-/bin/bash}" in
    */zsh)  rc_file="$HOME/.zshrc" ;;
    */bash) rc_file="$HOME/.bashrc" ;;
    *)      rc_file="$HOME/.profile" ;;
  esac

  local path_line='export PATH="$HOME/.smux/bin:$PATH"'

  if [[ -f "$rc_file" ]] && grep -qF '.smux/bin' "$rc_file"; then
    return
  fi

  info "Adding ~/.smux/bin to PATH in $rc_file"
  echo "" >> "$rc_file"
  echo "# smux" >> "$rc_file"
  echo "$path_line" >> "$rc_file"
  export PATH="$BIN_DIR:$PATH"
}

download() {
  local url="$1" dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    error "Neither curl nor wget found. Install one and re-run."
  fi
}

# --- Commands ---

cmd_install() {
  local os
  os=$(detect_os)
  info "Installing smux ($os)..."

  # 1. Install tmux if missing
  if ! command -v tmux >/dev/null 2>&1; then
    info "tmux not found. Installing..."
    if [[ "$os" == "macos" ]] && ! command -v brew >/dev/null 2>&1; then
      error "Homebrew is required to install tmux on macOS. Install it from https://brew.sh and re-run."
    fi
    pkg_install tmux
  fi
  check_tmux_version

  # 2. Install clipboard tool on Linux if missing
  if [[ "$os" == "linux" ]]; then
    if ! command -v xclip >/dev/null 2>&1 && ! command -v xsel >/dev/null 2>&1; then
      info "No clipboard tool found. Installing xclip..."
      pkg_install xclip
    fi
  fi

  # 3. Create directories
  mkdir -p "$SMUX_DIR" "$BIN_DIR" "$BACKUP_DIR"

  # 4. Back up existing config
  backup_existing

  # 5. Download tmux.conf
  info "Downloading tmux.conf..."
  download "$BASE_URL/.tmux.conf" "$SMUX_DIR/tmux.conf"

  # 6. Symlink tmux config
  mkdir -p "$TMUX_XDG_DIR"
  ln -sf "$SMUX_DIR/tmux.conf" "$TMUX_XDG_DIR/tmux.conf"

  # 7. Download tmux-bridge
  info "Downloading tmux-bridge..."
  download "$BASE_URL/scripts/tmux-bridge" "$BIN_DIR/tmux-bridge"
  chmod +x "$BIN_DIR/tmux-bridge"

  # 8. Save smux CLI
  info "Installing smux CLI..."
  download "$BASE_URL/install.sh" "$BIN_DIR/smux"
  chmod +x "$BIN_DIR/smux"

  # 9. Ensure PATH
  ensure_path

  # 10. Reload tmux if running
  if tmux list-sessions &>/dev/null; then
    tmux source-file "$SMUX_DIR/tmux.conf" 2>/dev/null && info "Reloaded tmux config." || true
  fi

  # 11. Done
  echo ""
  printf "${GREEN}${BOLD}smux installed!${NC}\n"
  echo ""
  echo "  Config:       ~/.smux/tmux.conf"
  echo "  tmux-bridge:  ~/.smux/bin/tmux-bridge"
  echo "  smux CLI:     ~/.smux/bin/smux"
  echo ""
  echo "  Run 'smux help' for commands."
  if ! echo "$PATH" | tr ':' '\n' | grep -qx "$BIN_DIR"; then
    echo ""
    warn "Restart your shell or run: export PATH=\"\$HOME/.smux/bin:\$PATH\""
  fi
}

cmd_update() {
  info "Updating smux..."

  mkdir -p "$SMUX_DIR" "$BIN_DIR" "$BACKUP_DIR"
  backup_existing

  info "Downloading tmux.conf..."
  download "$BASE_URL/.tmux.conf" "$SMUX_DIR/tmux.conf"

  info "Downloading tmux-bridge..."
  download "$BASE_URL/scripts/tmux-bridge" "$BIN_DIR/tmux-bridge"
  chmod +x "$BIN_DIR/tmux-bridge"

  info "Updating smux CLI..."
  download "$BASE_URL/install.sh" "$BIN_DIR/smux"
  chmod +x "$BIN_DIR/smux"

  if tmux list-sessions &>/dev/null; then
    tmux source-file "$SMUX_DIR/tmux.conf" 2>/dev/null && info "Reloaded tmux config." || true
  fi

  printf "${GREEN}${BOLD}smux updated to v${VERSION}!${NC}\n"
}

cmd_uninstall() {
  info "Uninstalling smux..."

  # Remove symlink
  if [[ -L "$TMUX_XDG_DIR/tmux.conf" ]]; then
    rm "$TMUX_XDG_DIR/tmux.conf"
    info "Removed symlink ~/.config/tmux/tmux.conf"
  fi

  # Check for backups to restore
  local latest_backup
  latest_backup=$(ls -t "$BACKUP_DIR"/tmux.conf.* 2>/dev/null | head -1 || true)
  if [[ -n "$latest_backup" ]]; then
    info "Restoring backup: $latest_backup"
    mkdir -p "$TMUX_XDG_DIR"
    cp "$latest_backup" "$TMUX_XDG_DIR/tmux.conf"
  fi

  # Remove smux directory
  rm -rf "$SMUX_DIR"
  info "Removed ~/.smux/"

  echo ""
  printf "${GREEN}${BOLD}smux uninstalled.${NC}\n"
  echo ""
  echo "  Note: You may want to remove the PATH line from your shell rc file:"
  echo "    export PATH=\"\$HOME/.smux/bin:\$PATH\""
}

cmd_version() {
  echo "smux $VERSION"
}

cmd_help() {
  cat <<'EOF'
smux — one-command tmux setup

Usage: smux <command>

Commands:
  install     Install smux (tmux config + tmux-bridge)
  update      Update to the latest version
  uninstall   Remove smux and restore previous config
  version     Print version
  help        Show this help

Files:
  ~/.smux/tmux.conf          tmux configuration
  ~/.smux/bin/tmux-bridge    cross-pane communication CLI
  ~/.smux/bin/smux           this CLI
  ~/.smux/backups/           config backups
EOF
}

# --- Main ---

# When invoked as the installed `smux` CLI, default to help (no-op).
# When invoked as install.sh (curl-pipe or `bash install.sh`), default to install.
_smux_script="${BASH_SOURCE[0]:-}"
if [[ -n "$_smux_script" && "$(basename "$_smux_script")" == "smux" ]]; then
  _smux_default="help"
else
  _smux_default="install"
fi

case "${1:-$_smux_default}" in
  install)                    cmd_install ;;
  update)                     cmd_update ;;
  uninstall|remove)           cmd_uninstall ;;
  version|--version|-v|-V)    cmd_version ;;
  help|--help|-h)             cmd_help ;;
  *)                          error "Unknown command: $1. Run 'smux help' for usage." ;;
esac
