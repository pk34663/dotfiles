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

SIDEBAR_REPO="https://github.com/hiroppy/tmux-agent-sidebar"
SIDEBAR_DIR="$HOME/.tmux/plugins/tmux-agent-sidebar"

# Clone tmux-agent-sidebar at its latest release tag and fetch the matching
# prebuilt binary (its tmux entry point refuses to load on a version mismatch).
ensure_agent_sidebar() {
    status running "tmux-agent-sidebar"

    if [ ! -d "$SIDEBAR_DIR/.git" ]; then
        local tag
        tag="$(git ls-remote --tags --refs --sort=-v:refname "$SIDEBAR_REPO" 'v*' \
               | head -n1 | sed 's|.*refs/tags/||')"
        if [ -z "$tag" ]; then
            status fail "tmux-agent-sidebar: could not find a release tag"
            return
        fi
        mkdir -p "$(dirname "$SIDEBAR_DIR")"
        git -c advice.detachedHead=false clone -q --depth 1 --branch "$tag" \
            "$SIDEBAR_REPO" "$SIDEBAR_DIR"
        status done "tmux-agent-sidebar $tag cloned"
    fi

    local bin="$SIDEBAR_DIR/bin/tmux-agent-sidebar" want have
    want="$(sed -n 's/^version *= *"\(.*\)"/\1/p' "$SIDEBAR_DIR/Cargo.toml")"
    have="$("$bin" version 2>/dev/null || true)"
    if [ -n "$want" ] && [ "$have" = "$want" ]; then
        status skip "tmux-agent-sidebar binary already at $want"
        return
    fi

    local os arch
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    case "$(uname -m)" in
        x86_64|amd64)  arch=x86_64 ;;
        arm64|aarch64) arch=aarch64 ;;
        *) status fail "tmux-agent-sidebar: unsupported arch $(uname -m)"; return ;;
    esac

    local url="$SIDEBAR_REPO/releases/download/v$want/tmux-agent-sidebar-$os-$arch"
    mkdir -p "$SIDEBAR_DIR/bin"
    if curl -fsSL "$url" -o "$bin.tmp"; then
        chmod +x "$bin.tmp" && mv "$bin.tmp" "$bin"
        pkill -f "$bin" 2>/dev/null || true   # running sidebars restart on toggle
        status done "tmux-agent-sidebar binary $want"
    else
        rm -f "$bin.tmp"
        status fail "tmux-agent-sidebar: download failed ($url)"
    fi
}

# Register the sidebar's hooks with Claude Code (skipped if claude is absent).
ensure_sidebar_claude_plugin() {
    status running "tmux-agent-sidebar Claude Code plugin"

    if ! command -v claude >/dev/null 2>&1; then
        status skip "claude not installed; re-run setup.sh after installing it"
        return
    fi
    if [ ! -d "$SIDEBAR_DIR" ]; then
        status skip "tmux-agent-sidebar not installed"
        return
    fi
    if claude plugin list 2>/dev/null | grep -q 'tmux-agent-sidebar'; then
        status skip "Claude Code plugin already installed"
        return
    fi

    if ! claude plugin marketplace list 2>/dev/null | grep -q 'hiroppy'; then
        claude plugin marketplace add "$SIDEBAR_DIR" >/dev/null
    fi
    if claude plugin install tmux-agent-sidebar@hiroppy >/dev/null; then
        status done "Claude Code plugin installed"
    else
        status fail "claude plugin install tmux-agent-sidebar@hiroppy"
    fi
}

main() {
    echo "Setting up dotfiles from $DOTFILES_DIR"
    echo

    link_file bash_profile .bash_profile
    link_file bashrc .bashrc
    link_file vimrc .vimrc
    link_file tmux.conf .tmux.conf
    ensure_starship
    ensure_agent_sidebar
    ensure_sidebar_claude_plugin

    echo
    echo "Done. Start a new shell (or 'exec bash -l') to pick up changes."
}

main "$@"
