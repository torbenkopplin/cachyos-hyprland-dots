#!/usr/bin/env bash
# install.sh -- put this repo into place on a fresh CachyOS install.
#
#   ./install.sh                 link configs into ~/.config (default)
#   ./install.sh --packages      install everything the setup needs
#   ./install.sh --nvim          clone the neovim config
#   ./install.sh --browsers      install browser policies (needs sudo)
#   ./install.sh --wallpapers    download wallpapers into ~/Pictures/Wallpapers
#   ./install.sh --all           all of the above, in the right order. This
#                                includes the wallpaper download, which is a few
#                                hundred megabytes over the network -- use
#                                --dry-run first if that matters.
#
#   ./install.sh --login         replace the display manager with greetd +
#                                noctalia-greeter (needs sudo). NOT in --all:
#                                it changes what happens at boot, so it is one
#                                command you run deliberately. Reverse it with
#                                'sudo systemctl disable --now greetd &&
#                                sudo systemctl enable --now plasmalogin'.
#
#   ./install.sh --dry-run       show what any of the above would do
#   ./install.sh --status        show which setup currently owns each path
#   ./install.sh --unlink        remove this script's links and put back
#                                whatever they replaced
#
# --unlink is a full reverse of the linking step, so this setup and the
# copy-based one in ~/repos/dots can be swapped back and forth: run ./install.sh
# to take over the shared paths, --unlink to hand them back.
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

DRY_RUN=0 UNLINK=0 STATUS=0
DO_LINK=0 DO_PACKAGES=0 DO_BROWSERS=0 DO_NVIM=0 DO_WALLPAPERS=0 DO_LOGIN=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN=1 ;;
        --status)   STATUS=1; DO_LINK=1 ;;
        --unlink)   UNLINK=1; DO_LINK=1 ;;
        --packages) DO_PACKAGES=1 ;;
        --browsers) DO_BROWSERS=1 ;;
        --nvim)     DO_NVIM=1 ;;
        --wallpapers) DO_WALLPAPERS=1 ;;
        # Deliberately not part of --all: everything else here is reversible by
        # rerunning something, this one decides whether you get a login screen.
        --login)    DO_LOGIN=1 ;;
        --all)      DO_LINK=1; DO_PACKAGES=1; DO_BROWSERS=1; DO_NVIM=1; DO_WALLPAPERS=1 ;;
        # The whole header comment, found by shape rather than by line number,
        # so editing the block above cannot silently truncate --help.
        -h|--help)  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done
# No action flags at all -> just link, which is the common case.
(( DO_PACKAGES || DO_BROWSERS || DO_NVIM || DO_WALLPAPERS || DO_LOGIN || DO_LINK )) || DO_LINK=1

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

# restore_backup <path> -- move the most recent <path>.bak-* back into place.
#
# This is what makes --unlink a real reverse of the install rather than just a
# delink: whatever was at the path before (typically the copy-based ~/repos/dots
# deployment) is put back, so switching between the two setups is one command in
# each direction and leaves no residue to accumulate.
restore_backup() {
    local dst=$1 dir base bak
    dir=$(dirname "$dst"); base=$(basename "$dst")

    local -a baks=()
    while IFS= read -r -d '' bak; do baks+=("$bak"); done \
        < <(find "$dir" -maxdepth 1 -name "$base.bak-*" -print0 2>/dev/null | sort -z)
    (( ${#baks[@]} )) || return 0

    # Stamps are fixed-width, so lexical order is chronological.
    bak=${baks[-1]}

    # In a dry run the link was never actually removed, so the destination still
    # being occupied says nothing.
    if (( ! DRY_RUN )) && [[ -e $dst || -L $dst ]]; then
        warn "not restoring ${bak##*/} -- something is already at ${dst/#$HOME/\~}"
        return 0
    fi

    say "restore ${dst/#$HOME/\~}  (from ${bak##*/})"
    run mv "$bak" "$dst"
    (( ${#baks[@]} > 1 )) && note "$(( ${#baks[@]} - 1 )) older backup(s) of this file left alone"
    return 0
}

# --status buckets: which setup owns each managed path right now.
STAT_LINKED=() STAT_FOREIGN=() STAT_ABSENT=()

link() {
    local src=$1 dst=$2 dir
    dir=$(dirname "$dst")

    if (( STATUS )); then
        if [[ -L $dst && $(readlink -f "$dst") == "$src" ]]; then
            STAT_LINKED+=("$dst")
        elif [[ -e $dst || -L $dst ]]; then
            STAT_FOREIGN+=("$dst")
        else
            STAT_ABSENT+=("$dst")
        fi
        return 0
    fi

    if (( UNLINK )); then
        if [[ -L $dst && $(readlink -f "$dst") == "$src" ]]; then
            say "unlink ${dst/#$HOME/\~}"
            run rm -f "$dst"
        fi
        # Attempted even when there was no link of ours to remove, so a
        # half-finished switch still gets its originals back.
        restore_backup "$dst"
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
        # Documentation belongs in the repo, not scattered through ~/.config.
        [[ $(basename "$rel") == README.md ]] && continue
        link "$file" "$dst_root/$rel"
    done < <(find "$src_root" -type f -print0 | sort -z)
}

do_link() {
    heading "Configs"
    link_tree "$REPO/config/hypr"     "$CONFIG_HOME/hypr"
    link_tree "$REPO/config/noctalia" "$CONFIG_HOME/noctalia"
    link_tree "$REPO/config/yazi"     "$CONFIG_HOME/yazi"
    link_tree "$REPO/config/kitty"    "$CONFIG_HOME/kitty"
    link_tree "$REPO/config/fish"     "$CONFIG_HOME/fish"
    link      "$REPO/config/starship/starship.toml" "$CONFIG_HOME/starship.toml"

    # Read by uwsm before the compositor starts, and the only place the session
    # gets ~/.local/bin on PATH -- which is what the launcher providers and the
    # noct-glass binds are found through. See config/uwsm/env.
    link_tree "$REPO/config/uwsm"     "$CONFIG_HOME/uwsm"

    # The same PATH, through the systemd user manager instead, for the case
    # where the session was started without uwsm. See config/environment.d.
    link_tree "$REPO/config/environment.d" "$CONFIG_HOME/environment.d"

    heading "Scripts"
    local script
    for script in "$REPO"/bin/*; do
        [[ -f $script ]] || continue
        (( UNLINK || STATUS )) || run chmod +x "$script"
        link "$script" "$BIN_HOME/$(basename "$script")"
    done
}

# Reported instead of the link/backup lines when --status is given.
do_status() {
    heading "Status"
    say "linked to this repo:  ${#STAT_LINKED[@]}"
    say "owned by something else: ${#STAT_FOREIGN[@]}"
    say "not present:          ${#STAT_ABSENT[@]}"

    if (( ${#STAT_FOREIGN[@]} )); then
        heading "Paths another setup owns (${#STAT_FOREIGN[@]})"
        note "./install.sh would back these up before linking over them"
        local f
        for f in "${STAT_FOREIGN[@]}"; do say "${f/#$HOME/\~}"; done
    fi

    # Backups mean a previous run took these over; --unlink puts them back.
    local -a baks=()
    local b
    while IFS= read -r -d '' b; do baks+=("$b"); done \
        < <(find "$CONFIG_HOME" "$BIN_HOME" -name '*.bak-*' -print0 2>/dev/null)
    if (( ${#baks[@]} )); then
        heading "Restorable backups (${#baks[@]})"
        note "--unlink moves the newest of these back for each path"
        for b in "${baks[@]}"; do say "${b/#$HOME/\~}"; done
    fi

    heading "Verdict"
    if (( ${#STAT_LINKED[@]} == 0 )); then
        say "this setup is NOT deployed"
    elif (( ${#STAT_FOREIGN[@]} == 0 )); then
        say "this setup is deployed"
    else
        say "partially deployed -- ${#STAT_LINKED[@]} linked, ${#STAT_FOREIGN[@]} still owned elsewhere"
    fi
}

# ---------------------------------------------------------------------------
# Packages
#
# pacman first, always. CachyOS rebuilds its repos with architecture-specific
# optimisations (x86-64-v3/v4, LTO, BOLT), so a package that exists in the
# repos is meaningfully better than the same package built locally from the
# AUR. Everything below is therefore attempted with pacman regardless of where
# it "usually" lives, and only what pacman cannot resolve falls through to an
# AUR helper.
#
# Package names are not verified against the CachyOS repos from here, so
# installs are permissive: a name that resolves nowhere is reported in the
# summary instead of aborting the run. Check that summary before assuming the
# setup is complete.
# ---------------------------------------------------------------------------

# Compositor, shell, and the pieces the config actually calls out to.
#
# uwsm, nautilus, libnotify and hyprpolkitagent are here because conf/ names
# them directly -- see the comment on each. They are easy to miss precisely
# because a CachyOS Hyprland install usually pulls them in already, so the gap
# only shows up on a machine that started from a different base.
PKGS_DESKTOP=(
    hyprland xdg-desktop-portal-hyprland xdg-desktop-portal-gtk
    kitty qt6ct
    hyprpicker hyprlock
    wl-clipboard brightnessctl playerctl

    # grim is what bin/noct-check measures the frosted glass with -- the only
    # way to tell a 3-level effect from a 17-level one is to photograph the
    # screen and do the arithmetic. imagemagick, which does that arithmetic,
    # comes in with PKGS_YAZI.
    grim

    # Fonts, all three named because something reads each of them:
    #   ttf-jetbrains-mono-nerd  kitty's font_family, and the glyphs starship
    #                            and eza draw their icons from
    #   adwaita-fonts            Adwaita Sans, the shell's UI face
    #                            (00-shell.toml). Usually present as a GNOME
    #                            dependency, which is not a thing to rely on
    #   noto-*                   everything else, emoji included
    noto-fonts noto-fonts-emoji ttf-jetbrains-mono-nerd adwaita-fonts

    # options.lua sets LAUNCH_PREFIX = "uwsm app -- ", so without uwsm every
    # single app bind fails. Clear LAUNCH_PREFIX instead if you do not want it.
    uwsm

    # options.lua FILE_MANAGER.
    nautilus

    # polkit is only the library; an agent is what actually shows the password
    # prompt, so GUI privilege escalation is silently dead without one.
    polkit hyprpolkitagent

    # notify-send, which every bin/noct-* script uses to report what it did.
    libnotify

    # hypridle is deliberately NOT here. Noctalia has its own idle service and
    # this repo configures it (config/noctalia/70-idle.toml); running hypridle
    # as well means two countdowns to the same lock screen, each unaware of the
    # other. That is not hypothetical -- it is what a machine upgraded from
    # ~/repos/dots ends up with, and do_services() below turns the leftover
    # unit off. Nothing else here needs it: hyprlock stays, since it is a
    # perfectly good fallback lock you can call by hand.
)

# Applications that are part of the setup rather than of the desktop.
PKGS_APPS=(
    # TODO asked for it by name, and it is the one messenger with no web
    # client worth using.
    signal-desktop

    # Mail. The brief was keyboard-driven, vim-style, TUI, and able to send
    # attachments -- which is aerc almost exactly: modal keybinds, :commands,
    # `:attach` for files, and it opens the message in $EDITOR (nvim, per
    # conf/env.lua). neomutt is the other candidate and is more configurable;
    # aerc wins on arriving usable, understanding maildir and IMAP out of the
    # box, and having a first-run account wizard rather than a .muttrc.
    #
    # No account config is tracked here: an accounts.conf holds mail addresses
    # and server names, and its password entries would either be secrets in git
    # or a keyring reference that only works on one machine. Run `aerc` once
    # and answer the wizard.
    aerc
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
#
# tree-sitter-cli is the one to be careful about, and it is the reason
# tests/deps.tsv exists at all. nvim-treesitter shells out to `tree-sitter` to
# build a parser from a grammar, but the neovim config is its own repository --
# cloned by --nvim, not vendored here -- so NOTHING in this repo names the
# dependency. It was missing from this list for as long as this list has
# existed, on a machine that happened to have it installed by hand, and the
# only symptom on a fresh one is a treesitter error that talks about the
# grammar. `noct-check deps-manifest` is what makes that impossible to repeat.
PKGS_DEV=(
    neovim git base-devel
    nodejs npm
    tree-sitter-cli
    ripgrep fd fzf bat
    curl wget unzip
)

# Referenced directly by the carried-over fish config: starship builds the
# prompt, eza backs `ls`/`lt`, bat backs `cat`.
#
# rustup is deliberately NOT here, though conf.d/rustup.fish is named after it.
# It declares `Conflicts With: rust cargo`, and pacman runs with --noconfirm
# below, which answers the "remove them?" prompt rather than aborting -- so on
# any machine that already has the repo toolchain this would swap a working
# rust/cargo for a rustup that ships no toolchain at all until
# `rustup default stable` is run by hand. Nothing here needs rustup: cargo from
# the repos lands on PATH at /usr/bin/cargo, and CachyOS builds it with the same
# architecture optimisations that are the whole reason this script prefers repo
# packages. Install rustup yourself if you want per-project toolchain pinning;
# conf.d/rustup.fish works either way.
PKGS_PROMPT=( starship eza )

# The shell, and the plugin manager used to get a fish-native nvm.
PKGS_SHELL=( fish fisher fastfetch )

# yazi and its preview pipeline.
PKGS_YAZI=(
    yazi ffmpeg 7zip jq poppler imagemagick chafa
)

PKGS_BROWSERS=( chromium firefox brave-bin zen-browser-bin )

# Usually AUR-only -- but still attempted with pacman first, because CachyOS
# ships some of these in its own repos and a repo build beats a local one.
#
PKGS_LIKELY_AUR=( noctalia satty claude-code )

# cursor_packages -- the cursor theme named by CURSOR_THEME in
# conf/options.lua, unless some Bibata build already provides it.
#
# No Bibata package exists in the repos, so this is AUR-only, and the AUR
# variants (bibata-cursor-theme, -bin, -git, and the illogical-impulse build
# that ~/repos/dots pulls in) all ship /usr/share/icons/Bibata-*. pacman aborts
# an entire transaction on a file conflict, so asking for one on a machine that
# already has another would take the rest of the package step down with it.
#
# Nothing breaks if this ends up not installed either: an XCURSOR_THEME that
# names a missing theme means the pointer stays the compositor default.
cursor_packages() {
    compgen -G '/usr/share/icons/Bibata-*' >/dev/null 2>&1 && return 0
    printf '%s\n' bibata-cursor-theme-bin
}

# Installed by --login only. greetd is the daemon; noctalia-greeter is the
# greeter that runs inside it, and it brings its own small wlroots compositor
# so it does not need Hyprland to be up first.
PKGS_LOGIN=( greetd noctalia-greeter )

# Installed with npm rather than pacman. LSP servers are deliberately absent:
# your neovim config installs those through mason (tsgo, eslint, vimls,
# lua_ls, lemminx), and a second copy on PATH would only cause confusion.
NPM_GLOBALS=( eslint @mermaid-js/mermaid-cli )

# Package frontends
# -----------------
# shelly is CachyOS's own manager (`shelly` in the cachyos repo) and it is
# preferred wherever it exists, for one reason that matters here: it installs
# repository packages AND AUR packages through one tool, so a fresh CachyOS
# machine needs no separate AUR helper for this script to finish. It
# authenticates through polkit rather than sudo, which means a graphical
# password prompt in a session -- and nothing at all in a bare TTY, where it
# simply fails and the pacman path below picks the list up.
#
# pacman + paru/yay stays as the fallback, unchanged, so this script still
# works on plain Arch.

detect_aur_helper() {
    local helper
    for helper in paru yay; do
        command -v "$helper" >/dev/null 2>&1 && { printf '%s' "$helper"; return 0; }
    done
    return 1
}

have_shelly() { command -v shelly >/dev/null 2>&1; }

# pkg_installed <name> -- true when the name is already satisfied.
#
# `pacman -T` rather than `-Q`: it resolves *provides* too, so a package
# installed under a different name than the one asked for (very common with
# -bin and -git variants) does not get reinstalled on every run. This is what
# makes every frontend below idempotent, including the ones with no --needed.
pkg_installed() { pacman -T -- "$1" >/dev/null 2>&1; }

# Names that could not be resolved from the repositories, for the AUR pass.
UNRESOLVED=()

# pacman_install <packages...>
#
# Named for what it means -- "get these from the repositories" -- rather than
# for which binary does it. Already-installed names are dropped first, then the
# whole list goes in one transaction, which is fast and resolves dependencies
# together. If that fails it retries one at a time, so a single unknown name
# cannot block the other twenty; anything still missing afterwards goes to
# UNRESOLVED for the AUR pass rather than being reported as an error here.
pacman_install() {
    local -a want=("$@") pkgs=()
    local pkg
    for pkg in "${want[@]}"; do
        pkg_installed "$pkg" || pkgs+=("$pkg")
    done

    if (( ! ${#pkgs[@]} )); then
        (( ${#want[@]} )) && note "already installed: ${#want[@]} package(s)"
        return 0
    fi

    if (( DRY_RUN )); then
        if have_shelly; then
            say "would: shelly install standard ${pkgs[*]}"
        else
            say "would: pacman -S --needed ${pkgs[*]}"
        fi
        return 0
    fi

    if have_shelly && shelly install standard --no-confirm "${pkgs[@]}" >/dev/null 2>&1; then
        say "shelly: ${pkgs[*]}"
    elif sudo pacman -S --needed --noconfirm "${pkgs[@]}" >/dev/null 2>&1; then
        say "pacman: ${pkgs[*]}"
    else
        note "batch failed, resolving individually"
        for pkg in "${pkgs[@]}"; do
            if sudo pacman -S --needed --noconfirm "$pkg" >/dev/null 2>&1; then
                say "pacman: $pkg"
            fi
        done
    fi

    # One truth at the end, whichever frontend ran: what is still not there.
    for pkg in "${pkgs[@]}"; do
        pkg_installed "$pkg" || UNRESOLVED+=("$pkg")
    done
}

# Only reached for what the repositories could not provide.
aur_install() {
    local -a want=("$@") pkgs=()
    local pkg
    for pkg in "${want[@]}"; do
        pkg_installed "$pkg" || pkgs+=("$pkg")
    done
    (( ${#pkgs[@]} )) || return 0

    if (( DRY_RUN )); then
        if have_shelly; then
            say "would: shelly install aur ${pkgs[*]}"
        else
            say "would: $(detect_aur_helper || echo '<no AUR helper>') -S --needed ${pkgs[*]}"
        fi
        return 0
    fi

    # shelly builds AUR packages itself, so this is the branch that runs on
    # CachyOS whether or not paru is installed.
    if have_shelly; then
        shelly install aur --no-confirm "${pkgs[@]}" >/dev/null 2>&1 || true
        local -a left=()
        for pkg in "${pkgs[@]}"; do
            if pkg_installed "$pkg"; then say "shelly: $pkg"; else left+=("$pkg"); fi
        done
        pkgs=("${left[@]}")
        (( ${#pkgs[@]} )) || return 0
    fi

    local helper
    if ! helper=$(detect_aur_helper); then
        warn "not installed, and no AUR helper to try: ${pkgs[*]}"
        note "install shelly or paru, then rerun with --packages"
        return 0
    fi

    for pkg in "${pkgs[@]}"; do
        if "$helper" -S --needed --noconfirm "$pkg" >/dev/null 2>&1; then
            say "$helper: $pkg"
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

    # Everything goes at pacman first, including the names that are usually
    # AUR-only: CachyOS builds its repos with architecture-specific
    # optimisations, so a repo package is worth preferring wherever one exists.
    say "repositories"
    pacman_install \
        "${PKGS_DESKTOP[@]}" "${PKGS_SYSTEM[@]}" "${PKGS_DEV[@]}" \
        "${PKGS_SHELL[@]}" "${PKGS_PROMPT[@]}" \
        "${PKGS_YAZI[@]}" "${PKGS_BROWSERS[@]}" "${PKGS_APPS[@]}" \
        "${PKGS_LIKELY_AUR[@]}" $(cursor_packages)

    if (( ${#UNRESOLVED[@]} )); then
        heading "AUR fallback"
        note "not in any enabled repo: ${UNRESOLVED[*]}"
        aur_install "${UNRESOLVED[@]}"
    fi

    do_npm_globals
    do_claude
    do_fish
    do_services
}

# npm_install <packages...>
#
# Same shape as pacman_install: one batch first, then one at a time so a single
# bad name cannot block the rest. Nothing falls through to another source, so
# failures are warned about here rather than collected.
npm_install() {
    local -a pkgs=("$@")
    (( ${#pkgs[@]} )) || return 0

    if (( DRY_RUN )); then
        say "would: npm install -g ${pkgs[*]}"
        return 0
    fi

    if npm install -g "${pkgs[@]}" >/dev/null 2>&1; then
        say "npm: ${pkgs[*]}"
        return 0
    fi

    note "batch failed, resolving individually"
    local pkg
    for pkg in "${pkgs[@]}"; do
        if npm install -g "$pkg" >/dev/null 2>&1; then
            say "npm: $pkg"
        else
            warn "could not install: $pkg"
        fi
    done
}

do_npm_globals() {
    command -v npm >/dev/null 2>&1 || { warn "npm missing, skipped: ${NPM_GLOBALS[*]}"; return 0; }

    # Global installs go under ~/.local so they never need root and land on the
    # PATH this script already asks you to have. Without this npm would try to
    # write to /usr/lib/node_modules.
    say "npm globals (prefix ~/.local)"
    run npm config set prefix "$HOME/.local"
    npm_install "${NPM_GLOBALS[@]}"
}

# ---------------------------------------------------------------------------
# Fish
#
# Two things: make it the login shell, and restore its plugins.
#
# Plugins are not vendored -- config/fish/fish_plugins is the source of truth
# and `fisher update` installs everything listed in it. That is the whole point
# of a plugin manager, and it is how nvm gets into fish: the list names
# jorgebucaran/nvm.fish, a native reimplementation.
#
# Why that is needed at all: `nvm` proper is a bash/zsh *shell function*, not a
# program. `nvm use 20` has to mutate the environment of the calling shell, so
# there is no binary to put on PATH and no way to make the bash version work
# under fish.
# ---------------------------------------------------------------------------

do_fish() {
    command -v fish >/dev/null 2>&1 || { warn "fish not installed, skipping shell setup"; return 0; }

    heading "Fish"

    # --- default shell -------------------------------------------------------
    local fish_path current
    fish_path=$(command -v fish)
    current=$(getent passwd "$USER" | cut -d: -f7)

    if [[ $current == "$fish_path" ]]; then
        say "already the default shell"
    elif (( DRY_RUN )); then
        say "would: chsh -s $fish_path"
    else
        # chsh refuses a shell that is not listed in /etc/shells.
        if ! grep -qxF "$fish_path" /etc/shells 2>/dev/null; then
            say "adding $fish_path to /etc/shells"
            printf '%s\n' "$fish_path" | sudo tee -a /etc/shells >/dev/null
        fi
        if chsh -s "$fish_path"; then
            say "default shell -> fish (takes effect on next login)"
        else
            warn "chsh failed -- run 'chsh -s $fish_path' yourself"
        fi
    fi

    # --- plugins from fish_plugins ------------------------------------------
    if (( DRY_RUN )); then
        say "would: fisher update  (installs everything in fish_plugins)"
        return 0
    fi

    if ! fish -c 'type -q fisher' >/dev/null 2>&1; then
        # fisher is a single function file; bootstrapping it by hand is its
        # own documented install path, and cheaper than failing here.
        say "bootstrapping fisher"
        if ! fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher' >/dev/null 2>&1; then
            warn "could not bootstrap fisher -- fish plugins (incl. nvm) unavailable"
            note "install fisher, then run: fisher update"
            return 0
        fi
    fi

    if fish -c 'fisher update' >/dev/null 2>&1; then
        say "fisher: installed plugins from fish_plugins"
    else
        warn "fisher update failed -- check 'fisher list' in a fish shell"
    fi
}

# ---------------------------------------------------------------------------
# Claude Code
#
# Tried as a package first like everything else; npm is the documented fallback
# and the one that works when no AUR build exists.
# ---------------------------------------------------------------------------

do_claude() {
    command -v claude >/dev/null 2>&1 && { say "claude-code already installed"; return 0; }

    if (( DRY_RUN )); then
        say "would: npm install -g @anthropic-ai/claude-code  (if no package)"
        return 0
    fi

    command -v npm >/dev/null 2>&1 || { warn "claude-code not installed (no package, no npm)"; return 0; }

    say "claude-code via npm"
    if npm install -g @anthropic-ai/claude-code >/dev/null 2>&1; then
        say "installed: @anthropic-ai/claude-code"
    else
        warn "could not install claude-code"
    fi
}

do_services() {
    say "services"
    local svc
    for svc in NetworkManager bluetooth power-profiles-daemon; do
        if systemctl list-unit-files "$svc.service" >/dev/null 2>&1; then
            run sudo systemctl enable --now "$svc.service"
        fi
    done

    stop_stray_idle_daemon
}

# Noctalia's idle service is what this repo configures (70-idle.toml). hypridle
# does the same job from a config directory the repo does not manage, and on a
# machine that ran ~/repos/dots it is still enabled as a user unit -- so the
# screen locks on whichever of the two counts down first, with two different
# sets of timeouts and only one of them written down here.
#
# A user unit, so no sudo, and disabling it is a one-word undo if you would
# rather keep hypridle: `systemctl --user enable --now hypridle`, and then set
# every behaviour in 70-idle.toml to enabled = false so only one of them acts.
stop_stray_idle_daemon() {
    systemctl --user list-unit-files hypridle.service >/dev/null 2>&1 || return 0
    systemctl --user is-enabled hypridle.service >/dev/null 2>&1 ||
        systemctl --user is-active hypridle.service >/dev/null 2>&1 || return 0

    say "hypridle is running as well as Noctalia's idle service -- disabling it"
    note "two idle daemons means two countdowns to the lock screen"
    run systemctl --user disable --now hypridle.service
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
install_user_js() {  # <source user.js> <label> <profiles root>...
    local src=$1 label=$2
    shift 2
    [[ -f $src ]] || return 0

    # More than one root because a browser's profile directory is not a stable
    # thing: Zen moved from ~/.zen to ~/.config/zen, and a file written to the
    # root the browser is not using is invisible rather than an error.
    local found=0 root profile
    for root in "$@"; do
        [[ -d $root ]] || continue
        while IFS= read -r -d '' profile; do
            found=1
            link "$src" "$profile/user.js"
        done < <(find "$root" -maxdepth 1 -type d -name '*.*' -print0 2>/dev/null)
    done

    (( found )) || note "$label: no profiles found -- launch it once, then rerun"
}

# ---------------------------------------------------------------------------
# Wallpapers
#
# Part of --all, and last in it: the palette is wallpaper-derived, so the
# desktop is not finished until this has run once and leaving it out of the
# one-command setup just means a fresh machine looks half-configured.
#
# It does pull a few hundred megabytes of images over the network, which is the
# one step here with a real cost attached -- hence the note in --all's help and
# the advice to try --dry-run on a metered connection.
# ---------------------------------------------------------------------------

# check_wallpaper_monitors -- warn when 60-wallpaper.toml names monitors this
# machine does not have.
#
# This is the one part of the setup that cannot be made host-agnostic: Noctalia
# keys per-monitor wallpaper directories on connector names, and it has no
# per-host mechanism the way hypr/host.lua does. An unmatched
# [wallpaper.monitor.X] section is not an error -- Noctalia just ignores it and
# falls back to the global `directory`, so the failure mode on a machine with
# different connectors is every screen quietly showing the same 16:9 set. That
# is invisible unless something says so, which is what this does.
check_wallpaper_monitors() {
    local toml=$REPO/config/noctalia/60-wallpaper.toml
    [[ -f $toml ]] || return 0

    local -a configured=()
    while IFS= read -r name; do configured+=("$name"); done \
        < <(sed -n 's/^\[wallpaper\.monitor\.\([^]]*\)\].*/\1/p' "$toml")
    (( ${#configured[@]} )) || return 0

    # Only answerable from inside a running session, which an install run from a
    # TTY is not. Say so rather than pretending the names are fine.
    if ! command -v hyprctl >/dev/null 2>&1 || ! hyprctl monitors >/dev/null 2>&1; then
        note "per-monitor sections: ${configured[*]}"
        note "not verifiable outside a Hyprland session -- recheck in one with"
        note "'hyprctl monitors' if the wrong wallpapers show up per screen"
        return 0
    fi

    local -a live=()
    while IFS= read -r name; do live+=("$name"); done \
        < <(hyprctl monitors | awk '/^Monitor /{print $2}')

    local cfg mon found
    local -a unmatched=()
    for cfg in "${configured[@]}"; do
        found=0
        for mon in "${live[@]}"; do [[ $cfg == "$mon" ]] && { found=1; break; }; done
        (( found )) || unmatched+=("$cfg")
    done

    if (( ${#unmatched[@]} )); then
        warn "60-wallpaper.toml targets monitors this machine does not have: ${unmatched[*]}"
        note "connected: ${live[*]}"
        note "rename the [wallpaper.monitor.X] sections to match, or those"
        note "screens silently fall back to the global directory"
    else
        say "per-monitor sections match the connected monitors (${live[*]})"
    fi
}

do_wallpapers() {
    heading "Wallpapers"

    # Called by absolute path rather than through PATH: the linking step puts
    # this in ~/.local/bin, but that directory is only on PATH once a new login
    # shell has picked it up -- so on a fresh machine `--all --wallpapers` in one
    # go would otherwise fail here having just installed the very script it
    # cannot find.
    local wallfetch=$BIN_HOME/noct-wallfetch
    if [[ ! -x $wallfetch ]]; then
        wallfetch=$REPO/bin/noct-wallfetch
        [[ -x $wallfetch ]] || { warn "noct-wallfetch not found -- run the linking step first"; return 0; }
        note "not linked yet; running it from the repo"
    fi

    if (( DRY_RUN )); then
        # Actually run it rather than printing "would: ...". noct-wallfetch
        # --dry-run only queries the API and prints what it would fetch, so it
        # writes nothing -- and now that --wallpapers is part of --all,
        # `--all --dry-run` is how you see the size of the download before
        # committing to it. Printing the command name would defeat the point.
        "$wallfetch" --dry-run || warn "wallpaper dry run reported problems"
        check_wallpaper_monitors
        return 0
    fi

    "$wallfetch" || warn "wallpaper fetch reported problems"
    check_wallpaper_monitors
}

# ---------------------------------------------------------------------------
# Login manager
#
# A CachyOS install boots into plasmalogin (SDDM under Plasma 6.5's new name),
# which is a Qt/Plasma login screen in front of a session that has nothing else
# Plasma in it -- different fonts, different accent colour, different cursor,
# and a session list where the Hyprland entry is one of three.
#
# greetd + noctalia-greeter replaces it with the same shell you are logging
# into: noctalia-greeter brings its own small wlroots compositor, so it runs
# before Hyprland exists, and it reads the palette and wallpaper Noctalia
# already resolved.
#
# This is the one step here that changes what happens at boot, which is why it
# is not in --all and why it prints how to undo itself. If the greeter ever
# fails to come up you are not locked out: switch to a TTY with
# ctrl+alt+F2, log in, and run the revert line below.
# ---------------------------------------------------------------------------

GREETD_CONF=/etc/greetd/config.toml

# The display manager currently enabled, by unit name -- plasmalogin.service,
# sddm.service, gdm.service, ... Read from the symlink systemd itself uses, so
# it is right regardless of which of them the distro shipped.
current_display_manager() {
    local target
    target=$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null) || return 1
    [[ -n $target ]] || return 1
    basename "$target"
}

do_login() {
    heading "Login manager"

    if ! command -v pacman >/dev/null 2>&1; then
        warn "pacman not found -- this step only works on CachyOS/Arch"
        return 0
    fi

    say "packages"
    UNRESOLVED=()
    pacman_install "${PKGS_LOGIN[@]}"
    if (( ${#UNRESOLVED[@]} )); then
        note "not in any enabled repo: ${UNRESOLVED[*]}"
        aur_install "${UNRESOLVED[@]}"
    fi

    # The session entry point, not the greeter binary: it starts the bundled
    # compositor and runs the greeter inside it. Resolved rather than
    # hardcoded, since a repo build lands in /usr/bin and a manual one in
    # /usr/local/bin.
    local session
    session=$(command -v noctalia-greeter-session 2>/dev/null || true)
    if [[ -z $session ]]; then
        if (( DRY_RUN )); then
            session=/usr/bin/noctalia-greeter-session
            note "noctalia-greeter is not installed yet; assuming $session"
        else
            warn "noctalia-greeter-session not found -- greeter not configured"
            note "install noctalia-greeter and rerun ./install.sh --login"
            return 0
        fi
    fi

    # --- greetd config -------------------------------------------------------
    #
    # greetd itself only knows how to run one command as one user; everything
    # about how the login screen looks, and which session it starts afterwards,
    # belongs to the greeter.
    local tmp
    tmp=$(mktemp)
    cat >"$tmp" <<EOF
# Written by cachyos-hyprland-dots (install.sh --login).
#
# greetd runs one command as the unprivileged 'greeter' user. That command is
# noctalia-greeter-session, which starts a small wlroots compositor, shows the
# greeter inside it, and hands over to whichever session you pick from
# /usr/share/wayland-sessions -- hyprland-uwsm.desktop being the one this repo
# is built around.
#
# Appearance comes from Noctalia: open its settings (SUPER+comma) ->
# Security -> Noctalia Greeter -> Sync Now to push the current palette and
# wallpaper to the login screen.

[terminal]
vt = 1

[default_session]
command = "$session"
user = "greeter"
EOF

    if [[ -f $GREETD_CONF ]] && ! diff -q "$tmp" "$GREETD_CONF" >/dev/null 2>&1; then
        say "back up $GREETD_CONF"
        run sudo cp -a "$GREETD_CONF" "$GREETD_CONF.bak-$STAMP"
    fi
    say "write $GREETD_CONF"
    run sudo install -Dm644 "$tmp" "$GREETD_CONF"
    rm -f "$tmp"

    # --- switch over ---------------------------------------------------------
    local current
    current=$(current_display_manager || true)

    if [[ $current == greetd.service ]]; then
        say "greetd is already the display manager"
    else
        if [[ -n $current ]]; then
            say "disable $current"
            run sudo systemctl disable "$current"
        fi
        say "enable greetd"
        # Not --now: restarting the display manager from inside a session it
        # started would kill that session, i.e. this one. It takes effect at
        # the next boot, or the next `systemctl isolate graphical.target` from
        # a TTY.
        run sudo systemctl enable greetd.service
    fi

    note "takes effect at the next boot; this session is not touched"
    note "sync its look: SUPER+comma -> Security -> Noctalia Greeter -> Sync Now"
    if [[ -n ${current:-} && $current != greetd.service ]]; then
        note "undo: sudo systemctl disable greetd && sudo systemctl enable $current"
    fi
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
    install_user_js "$REPO/browsers/firefox/user.js" Firefox "$HOME/.mozilla/firefox"

    # ~/.config/zen is where zen-browser-bin 1.21 keeps profiles -- confirmed on
    # this machine, where the ~/.zen this used to write to does not exist at all,
    # so the Zen half of --browsers had never actually landed. ~/.zen is kept as
    # a second candidate for older builds and the flatpak.
    install_user_js "$REPO/browsers/zen/user.js" Zen "$HOME/.config/zen" "$HOME/.zen"
}

# ---------------------------------------------------------------------------

printf '%shyprland + noctalia dotfiles%s\n' "$BOLD" "$RESET"
(( DRY_RUN )) && note "dry run -- nothing will be changed"

(( DO_PACKAGES )) && do_packages
(( DO_NVIM ))     && do_nvim
(( DO_LINK ))     && do_link
(( DO_BROWSERS ))   && do_browsers
(( DO_WALLPAPERS )) && do_wallpapers
(( DO_LOGIN ))      && do_login

if (( STATUS )); then
    do_status
    exit 0
fi

if (( UNLINK )); then
    heading "Done"
    say "Links removed and originals restored where a backup existed."
    note "the copy-based setup in ~/repos/dots owns these paths again;"
    note "nothing there needs to be re-run unless you want it to re-deploy."
    if (( ${#WARNINGS[@]} )); then
        heading "Warnings (${#WARNINGS[@]})"
        printf '  - %s\n' "${WARNINGS[@]}"
    fi
    exit 0
fi

if (( ${#WARNINGS[@]} )); then
    heading "Warnings (${#WARNINGS[@]})"
    printf '  - %s\n' "${WARNINGS[@]}"
fi

heading "Next"
if [[ ":$PATH:" != *":$BIN_HOME:"* ]]; then
    say "Put $BIN_HOME on your PATH for this shell -- the noct-* commands are"
    say "there. The Hyprland session gets it from ~/.config/uwsm/env, which"
    say "this script just linked, and which is read at login: until you log in"
    say "again the launcher's /aout /ain /bt /net /power /theme entries answer"
    say "\"No results found\" and SUPER+SHIFT+G does nothing."
fi
cat <<'EOF'
  1. Log into the Hyprland session.
  2. Run 'noct-check'. It is the part of TESTING.md that does not need you:
     one command, and it fails loudly for each thing that otherwise fails
     silently -- providers the launcher cannot find, a session running
     something other than what is on disk, frosted glass that is present in
     the config and invisible on the screen. 'noct-check --all' adds the
     measurement that flickers the display for a few seconds.
  3. Work through TESTING.md -- the checklist for everything left that
     could not be verified without a live session.
  4. Sign into browser sync for bookmarks and extensions; nothing in this
     repo carries them.
  5. Pick a wallpaper per monitor from the shell's picker. The colour palette
     is derived from the active one, so this is what finishes the theming.
EOF

if (( ! DO_LOGIN )) && [[ $(current_display_manager 2>/dev/null || echo none) != greetd.service ]]; then
cat <<'EOF'
  5. ./install.sh --login  -- replaces the Plasma login screen with greetd +
     noctalia-greeter, which looks like the shell you are logging into.
     Separate from --all because it changes what happens at boot.
EOF
fi
