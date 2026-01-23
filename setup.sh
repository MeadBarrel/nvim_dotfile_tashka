#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say() { printf '[dotfiles] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

# ---- 1) Install latest *stable* Neovim from GitHub releases ----
install_latest_nvim() {
  if ! have curl; then
    say "curl missing; cannot install latest neovim"
    exit 1
  fi
  if ! have tar; then
    say "tar missing; cannot install latest neovim"
    exit 1
  fi

  arch="$(uname -m)"
  case "$arch" in
  x86_64 | amd64) asset="nvim-linux-x86_64.tar.gz" ;;
  aarch64 | arm64) asset="nvim-linux-arm64.tar.gz" ;;
  *)
    say "Unsupported arch: $arch (supported: x86_64, arm64)"
    exit 1

    ;;
  esac

  url="https://github.com/neovim/neovim/releases/latest/download/${asset}"
  say "Downloading latest stable Neovim: $url"

  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  curl -fsSL "$url" -o "$tmp/nvim.tar.gz"
  tar -xzf "$tmp/nvim.tar.gz" -C "$tmp"

  mkdir -p "$HOME/.local"
  rm -rf "$HOME/.local/nvim"
  mv "$tmp/nvim-linux-"* "$HOME/.local/nvim"

  mkdir -p "$HOME/.local/bin"
  ln -sf "$HOME/.local/nvim/bin/nvim" "$HOME/.local/bin/nvim"

  # Ensure PATH for future shells

  if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.bashrc"
  fi

  export PATH="$HOME/.local/bin:$PATH"

  say "Installed: $(nvim --version | head -n 1)"
}

# ---- 2) Link your LazyVim config ----
link_lazyvim() {
  mkdir -p "$HOME/.config"
  rm -rf "$HOME/.config/nvim"
  ln -s "$REPO_DIR/nvim" "$HOME/.config/nvim"
  say "Linked ~/.config/nvim -> $REPO_DIR/nvim"
}

install_latest_nvim
link_lazyvim
