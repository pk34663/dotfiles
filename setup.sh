#!/usr/bin/env bash
# Idempotent dotfiles installer: symlinks repo files into $HOME and
# installs starship if missing. Safe to re-run any time.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

status() {
    local level="$1" msg="$2"
    case "$level" in
        running) printf "  ${YELLOW}RUNNING${RESET}  %s\n" "$msg" ;;
        done)    printf "  ${GREEN}DONE${RESET}     %s\n" "$msg" ;;
        skip)    printf "  ${BLUE}SKIP${RESET}     %s\n" "$msg" ;;
        fail)    printf "  ${RED}FAIL${RESET}     %s\n" "$msg" ;;
    esac
}

link_file() {
    local src="$DOTFILES_DIR/$1" dst="$HOME/$2"

    status running "$2"

    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        status skip "$2 already linked"
        return
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        local backup="$dst.bak.$(date +%Y%m%d%H%M%S)"
        mv "$dst" "$backup"
        status skip "backed up existing $2 -> $(basename "$backup")"
    fi

    ln -s "$src" "$dst"
    status done "$2 -> $src"
}

ensure_starship() {
    status running "starship"

    if command -v starship >/dev/null 2>&1; then
        status skip "starship already installed ($(starship --version | head -n1))"
        return
    fi

    curl -sS https://starship.rs/install.sh | sh -s -- -y >/dev/null
    status done "starship installed"
}

main() {
    echo "Setting up dotfiles from $DOTFILES_DIR"
    echo

    link_file bash_profile .bash_profile
    link_file bashrc .bashrc
    link_file vimrc .vimrc
    ensure_starship

    echo
    echo "Done. Start a new shell (or 'exec bash -l') to pick up changes."
}

main "$@"
