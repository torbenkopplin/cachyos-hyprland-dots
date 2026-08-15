#!/usr/bin/env bash
# bootstrap.sh -- one-command install from a fresh CachyOS system.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/torbenkopplin/cachyos-hyprland-dots/master/bootstrap.sh)
#
# Clones the repo (or updates it if already there) and hands over to
# install.sh. Any arguments are passed straight through:
#
#   bash <(curl -fsSL .../bootstrap.sh) --all --dry-run
#
# This file is deliberately self-contained -- it is fetched on its own, before
# the repo exists, so it cannot rely on anything else in it.

set -euo pipefail

REPO_URL_HTTPS="https://github.com/torbenkopplin/cachyos-hyprland-dots.git"
REPO_URL_SSH="git@github.com:torbenkopplin/cachyos-hyprland-dots.git"
BRANCH="${DOTS_BRANCH:-master}"
DEST="${DOTS_DEST:-$HOME/repos/cachyos-hyprland-dots}"

BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
[[ -t 1 ]] || { BOLD=""; DIM=""; RESET=""; }
say()  { printf '  %s\n' "$*"; }
note() { printf '  %s%s%s\n' "$DIM" "$*" "$RESET"; }
die()  { printf '\n  !! %s\n' "$*" >&2; exit 1; }

printf '%shyprland + noctalia dotfiles -- bootstrap%s\n\n' "$BOLD" "$RESET"

# A dotfiles install writes all over $HOME. Running it as root would put a
# root-owned ~/.config in place and lock the real user out of their own config.
[[ $EUID -eq 0 ]] && die "don't run this as root -- it installs into \$HOME, and sudo is asked for only where it is needed"

command -v pacman >/dev/null 2>&1 || die "this targets CachyOS/Arch (no pacman found)"

if ! command -v git >/dev/null 2>&1; then
    say "installing git"
    sudo pacman -S --needed --noconfirm git
fi

if [[ -d $DEST/.git ]]; then
    say "updating ${DEST/#$HOME/\~}"
    git -C "$DEST" pull --ff-only || note "pull failed (local changes?) -- continuing with what is on disk"
else
    [[ -e $DEST ]] && die "$DEST exists and is not a git checkout; move it aside first"
    say "cloning into ${DEST/#$HOME/\~}"
    mkdir -p "$(dirname "$DEST")"
    git clone --branch "$BRANCH" --quiet "$REPO_URL_HTTPS" "$DEST"

    # Cloned over HTTPS so this works before any SSH key exists; the remote is
    # switched to SSH afterwards to match how you actually push.
    git -C "$DEST" remote set-url origin "$REPO_URL_SSH"
    note "origin set to SSH -- needs your key to push"
fi

printf '\n'
say "handing over to install.sh ${*:-(no arguments -- linking only)}"
printf '\n'

cd "$DEST"
exec ./install.sh "$@"
