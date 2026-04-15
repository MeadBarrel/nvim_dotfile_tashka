#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
say() { printf '[dotfiles] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

MIN_NVIM_VERSION="${MIN_NVIM_VERSION:-0.12.1}"

ensure_local_bin_on_path() {
  mkdir -p "$HOME/.local/bin"

  if ! grep -q 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$HOME/.bashrc"
  fi

  export PATH="$HOME/.local/bin:$PATH"
}

detect_pkg_manager() {
  if have apt-get; then
    echo apt
    return 0
  fi
  if have dnf; then
    echo dnf
    return 0
  fi
  if have yum; then
    echo yum
    return 0
  fi
  if have apk; then
    echo apk
    return 0
  fi
  if have pacman; then
    echo pacman
    return 0
  fi

  return 1
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

pkg_update() {
  local pm
  pm="$(detect_pkg_manager)" || {
    say "No supported package manager found"
    return 1
  }

  case "$pm" in
    apt)
      disable_broken_yarn_repo
      sudo apt-get update
      ;;
    dnf)
      sudo dnf makecache
      ;;
    yum)
      sudo yum makecache
      ;;
    apk)
      sudo apk update
      ;;
    pacman)
      sudo pacman -Sy
      ;;
  esac
}

pkg_install() {
  local pm
  pm="$(detect_pkg_manager)" || {
    say "No supported package manager found"
    return 1
  }

  case "$pm" in
    apt)
      sudo apt-get install -y "$@"
      ;;
    dnf)
      sudo dnf install -y "$@"
      ;;
    yum)
      sudo yum install -y "$@"
      ;;
    apk)
      sudo apk add --no-cache "$@"
      ;;
    pacman)
      sudo pacman -S --noconfirm "$@"
      ;;
  esac
}

ensure_curl() {
  if have curl; then
    return 0
  fi

  local pm
  pm="$(detect_pkg_manager)" || {
    say "No supported package manager found for curl"
    return 1
  }

  case "$pm" in
    dnf|yum)
      pkg_install curl-minimal || pkg_install curl
      ;;
    *)
      pkg_install curl
      ;;
  esac
}

install_nvim_build_deps() {
  local pm
  pm="$(detect_pkg_manager)" || {
    say "No supported package manager found for Neovim build dependencies"
    return 1
  }

  say "Installing Neovim build dependencies via $pm"
  pkg_update
  ensure_curl

  case "$pm" in
    apt)
      pkg_install \
        ninja-build \
        gettext \
        cmake \
        unzip \
        build-essential \
        git
      ;;
    dnf|yum)
      pkg_install \
        gcc \
        gcc-c++ \
        make \
        ninja-build \
        gettext \
        cmake \
        unzip \
        tar \
        git
      ;;
    apk)
      pkg_install \
        build-base \
        ninja \
        gettext \
        cmake \
        unzip \
        git \
        tar
      ;;
    pacman)
      pkg_install \
        base-devel \
        ninja \
        gettext \
        cmake \
        unzip \
        git \
        tar
      ;;
  esac
}

get_installed_nvim_version() {
  if ! have nvim; then
    return 1
  fi

  nvim --version | head -n 1 | sed -E 's/^NVIM v([0-9]+\.[0-9]+\.[0-9]+).*$/\1/'
}

version_ge() {
  [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | tail -n 1)" = "$1" ]
}

need_nvim_build() {
  local installed
  if ! installed="$(get_installed_nvim_version)"; then
    say "nvim not found; build required"
    return 0
  fi

  if version_ge "$installed" "$MIN_NVIM_VERSION"; then
    say "nvim $installed already satisfies minimum $MIN_NVIM_VERSION"
    return 1
  fi

  say "nvim $installed is older than required $MIN_NVIM_VERSION; build required"
  return 0
}

install_nvim_from_source() {
  if ! need_nvim_build; then
    return 0
  fi

  install_nvim_build_deps

  local tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  say "Cloning Neovim v${MIN_NVIM_VERSION}"
  git clone --depth 1 --branch "v${MIN_NVIM_VERSION}" https://github.com/neovim/neovim.git "$tmp/neovim"

  say "Building Neovim v${MIN_NVIM_VERSION} from source"
  (
    cd "$tmp/neovim"
    make CMAKE_BUILD_TYPE=Release CMAKE_INSTALL_PREFIX="$HOME/.local"
    say "Installing Neovim v${MIN_NVIM_VERSION} into $HOME/.local"
    make install
  )

  ensure_local_bin_on_path
  hash -r

  say "Installed: $(nvim --version | head -n 1)"
}

install_tmux() {
  if have tmux; then
    say "tmux already installed: $(tmux -V)"
    return 0
  fi

  local pm
  pm="$(detect_pkg_manager)" || {
    say "No supported package manager found; skipping tmux install."
    return 0
  }

  say "Installing tmux via $pm"
  pkg_update
  pkg_install tmux
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
  if ! have tic; then
    say "tic missing; skipping alacritty terminfo install"
    return 0
  fi

  ensure_curl

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
