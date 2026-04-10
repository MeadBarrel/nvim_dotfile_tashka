#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say() { printf '[dotfiles] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

NVIM_VERSION="${NVIM_VERSION:-v0.12.1}"

ensure_local_bin_on_path() {
  mkdir -p "$HOME/.local/bin"

  if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.bashrc"
  fi

  export PATH="$HOME/.local/bin:$PATH"
}

disable_broken_yarn_repo() {
  if ! have apt-get; then
    return 0
  fi

  if grep -Rqs "dl.yarnpkg.com" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
    say "Disabling Yarn apt source because its signing key is broken"
    sudo sh -c '
      for f in /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources /etc/apt/sources.list; do
        [ -e "$f" ] || continue
        if grep -qs "dl.yarnpkg.com" "$f"; then
          cp "$f" "$f.bak-dotfiles" 2>/dev/null || true
          sed -i "s|^deb |# deb |g" "$f" 2>/dev/null || true
        fi
      done
    '
  fi
}

apt_update_safe() {
  disable_broken_yarn_repo
  sudo apt-get update
}

install_nvim_from_source() {
  if have nvim; then
    say "nvim already installed: $(nvim --version | head -n 1)"
    return 0
  fi

  if ! have apt-get; then
    say "This script currently expects apt-get to build Neovim on this system."
    exit 1
  fi

  say "Installing build dependencies for Neovim ${NVIM_VERSION}"
  apt_update_safe
  sudo apt-get install -y \
    ninja-build \
    gettext \
    cmake \
    unzip \
    curl \
    build-essential \
    git

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  say "Cloning Neovim ${NVIM_VERSION}"
  git clone --depth 1 --branch "$NVIM_VERSION" https://github.com/neovim/neovim.git "$tmp/neovim"

  say "Building Neovim ${NVIM_VERSION} from source"
  cd "$tmp/neovim"
  make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$HOME/.local"

  say "Installing Neovim ${NVIM_VERSION} into $HOME/.local"
  make install

  ensure_local_bin_on_path
  hash -r

  say "Installed: $(nvim --version | head -n 1)"
}

install_tmux() {
  if have tmux; then
    say "tmux already installed: $(tmux -V)"
    return 0
  fi

  if have apt-get; then
    say "Installing tmux via apt-get"
    apt_update_safe
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

  say "No supported package manager found; skipping tmux install."
}

link_tmux() {
  if [ -f "$REPO_DIR/tmux/.tmux.conf" ]; then
    ln -sf "$REPO_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"
    say "Linked ~/.tmux.conf -> $REPO_DIR/tmux/.tmux.conf"
  fi

  if [ -f "$REPO_DIR/tmux/.config/tmux/tmux.conf" ]; then
    mkdir -p "$HOME/.config/tmux"
    ln -sf "$REPO_DIR/tmux/.config/tmux/tmux.conf" "$HOME/.config/tmux/tmux.conf"
    say "Linked ~/.config/tmux/tmux.conf -> $REPO_DIR/tmux/.config/tmux/tmux.conf"
  fi
}

link_lazyvim() {
  mkdir -p "$HOME/.config"
  rm -rf "$HOME/.config/nvim"
  ln -s "$REPO_DIR/nvim" "$HOME/.config/nvim"
  say "Linked ~/.config/nvim -> $REPO_DIR/nvim"
}

install_fzf() {
  if [ -d "$HOME/.fzf" ]; then
    say "fzf already installed in ~/.fzf"
    return 0
  fi

  if ! have git; then
    say "git missing; cannot install fzf"
    return 0
  fi

  say "Installing fzf"
  git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
  "$HOME/.fzf/install" --all --no-bash --no-fish
}

install_alacritty_terminfo() {
  if ! have curl || ! have tic; then
    say "curl or tic missing; skipping alacritty terminfo install"
    return 0
  fi

  say "Installing Alacritty terminfo"
  curl -fsSL https://raw.githubusercontent.com/alacritty/alacritty/master/extra/alacritty.info | tic -x -
}

ensure_local_bin_on_path
install_nvim_from_source
link_lazyvim
install_tmux
link_tmux
install_fzf
install_alacritty_terminfo
