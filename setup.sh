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

install_tmux() {

  if have tmux; then
    say "tmux already installed: $(tmux -V)"
    return 0
  fi

  # Prefer apt-get over apt for scripting
  if have apt-get; then
    say "Installing tmux via apt-get"
    sudo apt-get update -y
    sudo apt-get install -y tmux
    return 0

  fi

  if have apk; then

    say "Installing tmux via apk"
    sudo apk add --no-cache tmux
    return 0
  fi

  if have dnf; then
    say "Installing tmux via dnf"

    sudo dnf install -y tmux
    return 0
  fi

  if have yum; then
    say "Installing tmux via yum"
    sudo yum install -y tmux
    return 0
  fi

  if have pacman; then
    say "Installing tmux via pacman"

    sudo pacman -Sy --noconfirm tmux

    return 0
  fi

  say "No supported package manager found; skipping tmux install (config will still be linked)."
  return 0
}

link_tmux() {
  # Classic tmux location: ~/.tmux.conf
  if [ -f "$REPO_DIR/tmux/.tmux.conf" ]; then
    ln -sf "$REPO_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
    say "Linked ~/.tmux.conf -> $REPO_DIR/tmux/.tmux.conf"
  fi

  # Optional XDG location: ~/.config/tmux/tmux.conf
  if [ -f "$REPO_DIR/tmux/.config/tmux/tmux.conf" ]; then
    mkdir -p "$HOME/.config/tmux"
    ln -sf "$REPO_DIR/tmux/.config/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
    say "Linked ~/.config/tmux/tmux.conf -> $REPO_DIR/tmux/.config/tmux/tmux.conf"
  fi

}

# ---- 2) Link your LazyVim config ----
link_lazyvim() {
  mkdir -p "$HOME/.config"
  rm -rf "$HOME/.config/nvim"
  ln -s "$REPO_DIR/nvim" "$HOME/.config/nvim"
  say "Linked ~/.config/nvim -> $REPO_DIR/nvim"
}

install_fzf() {
  sudo apt install fzf
}

install_latest_nvim
link_lazyvim
install_tmux
link_tmux
install_fzf
