#!/usr/bin/env bash
# Bootstrap a fresh Rocky Linux (WSL) box: base packages -> dotfiles -> Claude Code.
# Safe to re-run.
#
# Usage (inside Rocky, as your normal user):
#   curl -fsSL https://raw.githubusercontent.com/<you>/dotfiles/main/bootstrap.sh | bash
set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-https://github.com/<you>/dotfiles.git}"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/.dotfiles}"

log() { printf '\n==> %s\n' "$*"; }

# --- 1. Packages -------------------------------------------------------------
log "Enabling EPEL + CRB"
sudo dnf -y install epel-release
sudo crb enable            # helper shipped by epel-release

log "Installing base packages"
BASE_PKGS=(git vim-enhanced tmux curl wget unzip tar which procps-ng iproute
           bash-completion man-db)
sudo dnf -y install "${BASE_PKGS[@]}"

# --- 2. Dotfiles -------------------------------------------------------------
if [[ -d "$DOTFILES_DIR/.git" ]]; then
  log "Updating dotfiles"
  git -C "$DOTFILES_DIR" pull --ff-only
else
  log "Cloning dotfiles"
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

# Optional extra packages listed in the repo, one per line (# comments allowed)
if [[ -f "$DOTFILES_DIR/packages-rocky.txt" ]]; then
  log "Installing packages from packages-rocky.txt"
  mapfile -t EXTRA < <(grep -vE '^\s*(#|$)' "$DOTFILES_DIR/packages-rocky.txt")
  (( ${#EXTRA[@]} )) && sudo dnf -y install "${EXTRA[@]}"
fi

# Hand over to the repo's own installer (symlinks etc.) if it has one
if [[ -x "$DOTFILES_DIR/install.sh" ]]; then
  log "Running dotfiles install.sh"
  "$DOTFILES_DIR/install.sh"
fi

# --- 3. Claude Code ----------------------------------------------------------
if ! command -v claude >/dev/null 2>&1; then
  log "Installing Claude Code"
  curl -fsSL https://claude.ai/install.sh | bash
fi

log "Done. Open a new shell (or: exec bash -l)."
