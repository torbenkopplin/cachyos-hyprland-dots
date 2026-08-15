#!/usr/bin/env bash
# install.sh -- put this repo into place on a fresh CachyOS install.
#
#   ./install.sh                 link configs into ~/.config (default)
#   ./install.sh --packages      install everything the setup needs
#   ./install.sh --nvim          clone the neovim config
#   ./install.sh --browsers      install browser policies (needs sudo)
#   ./install.sh --all           all of the above, in the right order
#
#   ./install.sh --dry-run       show what any of the above would do
#   ./install.sh --unlink        remove only the links this script created
#
# Symlinks are safe for everything here:
#
#   ~/.config/hypr/*      Hyprland only ever reads its config.
#   ~/.config/noctalia/*  Noctalia only ever reads ~/.config/noctalia. It saves
#                         GUI changes to ~/.local/state/noctalia/settings.toml,
#                         a different tree -- so the app can never clobber a
#                         tracked file or replace a link.
#   ~/.config/yazi/*      read-only as far as yazi is concerned.
#   ~/.local/bin/noct-*   plain scripts.
#
# Individual files are linked rather than whole directories, so either program
# can still create its own files alongside yours without fighting the repo.

set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
BIN_HOME=$HOME/.local/bin
STAMP=$(date +%Y%m%d-%H%M%S)

DRY_RUN=0 UNLINK=0
DO_LINK=0 DO_PACKAGES=0 DO_BROWSERS=0 DO_NVIM=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN=1 ;;
        --unlink)   UNLINK=1; DO_LINK=1 ;;
        --packages) DO_PACKAGES=1 ;;
        --browsers) DO_BROWSERS=1 ;;
        --nvim)     DO_NVIM=1 ;;
        --all)      DO_LINK=1; DO_PACKAGES=1; DO_BROWSERS=1; DO_NVIM=1 ;;
        -h|--help)  sed -n '2,18p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done
# No action flags at all -> just link, which is the common case.
(( DO_PACKAGES || DO_BROWSERS || DO_NVIM || DO_LINK )) || DO_LINK=1

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

BOLD=$'\033[1m'; DIM=$'\033[2m'; RESET=$'\033[0m'
[[ -t 1 ]] || { BOLD=""; DIM=""; RESET=""; }

heading() { printf '\n%s%s%s\n' "$BOLD" "$1" "$RESET"; }
say()     { printf '  %s\n' "$*"; }
note()    { printf '  %s%s%s\n' "$DIM" "$*" "$RESET"; }
run()     { if (( DRY_RUN )); then say "would: $*"; else "$@"; fi; }

# Collected and reported at the end rather than scrolling past mid-run.
WARNINGS=()
warn() { WARNINGS+=("$1"); printf '  !! %s\n' "$1"; }

# ---------------------------------------------------------------------------
# Linking
# ---------------------------------------------------------------------------

link() {
    local src=$1 dst=$2 dir
    dir=$(dirname "$dst")

    if (( UNLINK )); then
        if [[ -L $dst && $(readlink -f "$dst") == "$src" ]]; then
            say "unlink $dst"
            run rm -f "$dst"
        fi
        return 0
    fi

    run mkdir -p "$dir"

    # Already correct? Say nothing, so reruns are quiet.
    [[ -L $dst && $(readlink -f "$dst") == "$src" ]] && return 0

    # Anything else in the way is moved aside, never deleted.
    if [[ -e $dst || -L $dst ]]; then
        say "backup $dst -> $dst.bak-$STAMP"
        run mv "$dst" "$dst.bak-$STAMP"
    fi

    say "link   ${dst/#$HOME/\~}"
    run ln -s "$src" "$dst"
}

link_tree() {
    local src_root=$1 dst_root=$2 rel
    [[ -d $src_root ]] || return 0
    while IFS= read -r -d '' file; do
        rel=${file#"$src_root"/}
        link "$file" "$dst_root/$rel"
    done < <(find "$src_root" -type f -print0 | sort -z)
}

do_link() {
    heading "Configs"
    link_tree "$REPO/config/hypr"     "$CONFIG_HOME/hypr"
    link_tree "$REPO/config/noctalia" "$CONFIG_HOME/noctalia"
    link_tree "$REPO/config/yazi"     "$CONFIG_HOME/yazi"

    heading "Scripts"
    local script
    for script in "$REPO"/bin/*; do
        [[ -f $script ]] || continue
        (( UNLINK )) || run chmod +x "$script"
        link "$script" "$BIN_HOME/$(basename "$script")"
    done
}

# ---------------------------------------------------------------------------
# Packages
#
# Package names are not verified against the CachyOS repos from here, so each
# list is installed permissively: a name that does not resolve is reported at
# the end instead of aborting the run. Check the summary before assuming the
# setup is complete.
# ---------------------------------------------------------------------------

# Compositor, shell, and the pieces the config actually calls out to.
PKGS_DESKTOP=(
    hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    kitty qt6ct polkit
    hyprpicker hyprlock hypridle
    wl-clipboard brightnessctl playerctl
    noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd
)

# Backends behind the launcher's /aout /ain /bt /net /power providers.
# Without these the providers list "not installed" and do nothing.
PKGS_SYSTEM=(
    libpulse networkmanager bluez bluez-utils power-profiles-daemon
)

# Editor, and the tools the neovim config shells out to:
#   fzf + bat  -> fzf-lua and its previewer
#   ripgrep    -> grep backend
#   nodejs/npm -> mason needs it for tsgo, eslint and lemminx
PKGS_DEV=(
    neovim git base-devel
    nodejs npm
    ripgrep fd fzf bat
    curl wget unzip
)

# yazi and its preview pipeline.
PKGS_YAZI=(
    yazi ffmpeg p7zip jq poppler imagemagick chafa
)

PKGS_BROWSERS_REPO=( chromium firefox )

# Not in the standard repos. noctalia and satty are listed here but tried in
# the repos first, since CachyOS may ship them.
PKGS_AUR=( noctalia brave-bin zen-browser-bin satty nvm )

# Installed with npm rather than pacman. LSP servers are deliberately absent:
# your neovim config installs those through mason (tsgo, eslint, vimls,
# lua_ls, lemminx), and a second copy on PATH would only cause confusion.
NPM_GLOBALS=( eslint @mermaid-js/mermaid-cli )

detect_aur_helper() {
    local helper
    for helper in paru yay; do
        command -v "$helper" >/dev/null 2>&1 && { printf '%s' "$helper"; return 0; }
    done
    return 1
}

# install_with <command...> -- <packages...>
#
# Tries the whole list in one transaction, which is fast and resolves
# dependencies together. If that fails, retries one at a time so a single
# unknown name cannot block the other twenty.
install_with() {
    local -a cmd=()
    while [[ $1 != "--" ]]; do cmd+=("$1"); shift; done
    shift
    local -a pkgs=("$@")
    (( ${#pkgs[@]} )) || return 0

    if (( DRY_RUN )); then
        say "would: ${cmd[*]} ${pkgs[*]}"
        return 0
    fi

    if "${cmd[@]}" "${pkgs[@]}" >/dev/null 2>&1; then
        say "installed: ${pkgs[*]}"
        return 0
    fi

    note "batch install failed, retrying individually"
    local pkg
    for pkg in "${pkgs[@]}"; do
        if "${cmd[@]}" "$pkg" >/dev/null 2>&1; then
            say "installed: $pkg"
        else
            warn "could not install: $pkg"
        fi
    done
}

do_packages() {
    heading "Packages"

    if ! command -v pacman >/dev/null 2>&1; then
        warn "pacman not found -- this step only works on CachyOS/Arch"
        return 0
    fi

    local -a PACMAN=(sudo pacman -S --needed --noconfirm)

    say "repositories"
    install_with "${PACMAN[@]}" -- \
        "${PKGS_DESKTOP[@]}" "${PKGS_SYSTEM[@]}" "${PKGS_DEV[@]}" \
        "${PKGS_YAZI[@]}" "${PKGS_BROWSERS_REPO[@]}"

    local helper
    if helper=$(detect_aur_helper); then
        say "AUR (via $helper)"
        install_with "$helper" -S --needed --noconfirm -- "${PKGS_AUR[@]}"
    else
        warn "no AUR helper (paru/yay) found -- skipped: ${PKGS_AUR[*]}"
        note "install paru first, then rerun with --packages"
    fi

    do_npm_globals
    do_services
}

do_npm_globals() {
    command -v npm >/dev/null 2>&1 || { warn "npm missing, skipped: ${NPM_GLOBALS[*]}"; return 0; }

    # Global installs go under ~/.local so they never need root and land on the
    # PATH this script already asks you to have. Without this npm would try to
    # write to /usr/lib/node_modules.
    say "npm globals (prefix ~/.local)"
    run npm config set prefix "$HOME/.local"
    install_with npm install -g -- "${NPM_GLOBALS[@]}"
}

do_services() {
    say "services"
    local svc
    for svc in NetworkManager bluetooth power-profiles-daemon; do
        if systemctl list-unit-files "$svc.service" >/dev/null 2>&1; then
            run sudo systemctl enable --now "$svc.service"
        fi
    done
}

# ---------------------------------------------------------------------------
# Neovim config
#
# Your neovim config is its own repository, so it is cloned rather than
# vendored here -- that keeps one source of truth and lets you keep pushing to
# it independently of these dotfiles.
# ---------------------------------------------------------------------------

NVIM_HTTPS=https://github.com/torbenkopplin/nvimrc.git
NVIM_SSH=git@github.com:torbenkopplin/nvimrc.git

do_nvim() {
    heading "Neovim config"

    local dest=$CONFIG_HOME/nvim

    if [[ -d $dest/.git ]]; then
        say "already a git checkout: ${dest/#$HOME/\~}"
        note "leaving it alone; pull it yourself if you want the latest"
        return 0
    fi

    if [[ -e $dest ]]; then
        say "backup ${dest/#$HOME/\~} -> ${dest/#$HOME/\~}.bak-$STAMP"
        run mv "$dest" "$dest.bak-$STAMP"
    fi

    # Cloned over HTTPS so this works before any SSH key is on the machine,
    # then the remote is switched to SSH to match how you actually push.
    if (( DRY_RUN )); then
        say "would: git clone $NVIM_HTTPS $dest"
        say "would: git -C $dest remote set-url origin $NVIM_SSH"
    elif git clone --quiet "$NVIM_HTTPS" "$dest"; then
        say "cloned ${dest/#$HOME/\~}"
        git -C "$dest" remote set-url origin "$NVIM_SSH"
        note "origin set to SSH ($NVIM_SSH) -- needs your key to push"
    else
        warn "could not clone $NVIM_HTTPS"
    fi

    note "LSP servers install themselves on first launch, via mason"
}

# ---------------------------------------------------------------------------
# Browsers
#
# Declarative configuration only. Profiles -- cookies, saved logins, history --
# are never touched: see browsers/README.md.
# ---------------------------------------------------------------------------

install_policy() {  # <source> <destination dir> <destination name>
    local src=$1 dir=$2 name=$3
    [[ -f $src ]] || return 0

    if (( DRY_RUN )); then
        say "would: sudo install -Dm644 $src $dir/$name"
        return 0
    fi

    if sudo install -Dm644 "$src" "$dir/$name" 2>/dev/null; then
        say "policy $dir/$name"
    else
        warn "could not write $dir/$name"
    fi
}

# Firefox-family profiles have generated directory names, so they are
# discovered rather than assumed. They do not exist until the browser has been
# launched once.
install_user_js() {  # <source user.js> <profiles root> <label>
    local src=$1 root=$2 label=$3
    [[ -f $src ]] || return 0

    if [[ ! -d $root ]]; then
        note "$label: no profile directory yet -- launch it once, then rerun"
        return 0
    fi

    local found=0 profile
    while IFS= read -r -d '' profile; do
        found=1
        link "$src" "$profile/user.js"
    done < <(find "$root" -maxdepth 1 -type d -name '*.*' -print0 2>/dev/null)

    (( found )) || note "$label: no profiles found under ${root/#$HOME/\~}"
}

do_browsers() {
    heading "Browser policies"
    note "declarative settings only -- no profile data is copied or tracked"

    install_policy "$REPO/browsers/brave/policies.json" \
                   /etc/brave/policies/managed policies.json
    install_policy "$REPO/browsers/chromium/policies.json" \
                   /etc/chromium/policies/managed policies.json
    install_policy "$REPO/browsers/firefox/policies.json" \
                   /etc/firefox/policies policies.json

    heading "Browser preferences"
    install_user_js "$REPO/browsers/firefox/user.js" "$HOME/.mozilla/firefox" Firefox
    install_user_js "$REPO/browsers/zen/user.js"     "$HOME/.zen"             Zen
}

# ---------------------------------------------------------------------------

printf '%shyprland + noctalia dotfiles%s\n' "$BOLD" "$RESET"
(( DRY_RUN )) && note "dry run -- nothing will be changed"

(( DO_PACKAGES )) && do_packages
(( DO_NVIM ))     && do_nvim
(( DO_LINK ))     && do_link
(( DO_BROWSERS )) && do_browsers

if (( UNLINK )); then
    heading "Done"
    say "Unlinked. Backups named *.bak-* were left alone."
    exit 0
fi

if (( ${#WARNINGS[@]} )); then
    heading "Warnings (${#WARNINGS[@]})"
    printf '  - %s\n' "${WARNINGS[@]}"
fi

heading "Next"
if [[ ":$PATH:" != *":$BIN_HOME:"* ]]; then
    say "Put $BIN_HOME on your PATH -- the launcher runs provider commands"
    say "through 'sh -lc' and will not find them otherwise."
fi
cat <<'EOF'
  1. Log into the Hyprland session.
  2. Work through TESTING.md -- the checklist for everything in here that
     could not be verified without a live session.
  3. Sign into browser sync for bookmarks and extensions; nothing in this
     repo carries them.
EOF
