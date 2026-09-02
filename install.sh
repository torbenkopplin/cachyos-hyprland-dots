#!/usr/bin/env bash
# install.sh -- put this repo into place on a fresh CachyOS install.
#
#   ./install.sh                 link configs into ~/.config (default)
#   ./install.sh --packages      install everything the setup needs
#   ./install.sh --nvim          clone the neovim config
#   ./install.sh --browsers      install browser policies (needs sudo)
#   ./install.sh --input         install the keyd remap that turns the MX Keys
#                                screenshot key back into Print (needs sudo)
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
#   ./install.sh --update        pull, relink, and make it live. This is the
#                                one to run on the second machine: it refuses
#                                to pull over local changes rather than
#                                fighting you for them, and it re-applies the
#                                glass and the templates afterwards so the
#                                session shows what was pulled.
#
#   ./install.sh --dry-run       show what any of the above would do
#   ./install.sh --status        show which setup currently owns each path
#   ./install.sh --unlink        remove this script's links and put back
#                                whatever they replaced
#   ./install.sh --check         verify every package name in the manifest
#                                against the repos, the AUR and npm. Installs
#                                nothing. Run it after editing packages.tsv.
#
#   ./install.sh --root DIR      do everything under DIR instead of ~, and skip
#                                the steps that change the machine rather than
#                                a path. This is how the installer is tested --
#                                by tests/install-fakeroot.sh and in CI -- and
#                                it needs no environment variables and no sudo.
#
# --unlink is a full reverse of the linking step, so this setup and the
# copy-based one in ~/repos/dots can be swapped back and forth: run ./install.sh
# to take over the shared paths, --unlink to hand them back.
#
# What goes where is data, not code: install/manifest/*.tsv lists the links, the
# packages, the units, the browser files and the keyd remap, each row with the
# reason it is there. install/lib/*.sh is the engine that reads them. Adding a
# config file to the deployment is a line in links.tsv; adding a package is a
# line in packages.tsv.

set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
INSTALL_LIB=$REPO/install/lib
STAMP=$(date +%Y%m%d-%H%M%S)

DRY_RUN=0 UNLINK=0 STATUS=0 CHECK=0
DO_LINK=0 DO_PACKAGES=0 DO_BROWSERS=0 DO_NVIM=0 DO_WALLPAPERS=0 DO_LOGIN=0
DO_INPUT=0 DO_UPDATE=0
ROOT_ARG=""

# Kept because --update re-execs this script after pulling, and has to hand on
# the same arguments it was given. "$@" inside a function is that function's
# arguments, not the script's.
ARGV=("$@")

while (( $# )); do
    case "$1" in
        --dry-run)  DRY_RUN=1 ;;
        --status)   STATUS=1; DO_LINK=1 ;;
        --unlink)   UNLINK=1; DO_LINK=1 ;;
        --check)    CHECK=1 ;;
        --packages) DO_PACKAGES=1 ;;
        --browsers) DO_BROWSERS=1 ;;
        --input)    DO_INPUT=1 ;;
        --nvim)     DO_NVIM=1 ;;
        --wallpapers) DO_WALLPAPERS=1 ;;
        # Implies linking: a pull that adds a config file has not landed until
        # something links it.
        --update)   DO_UPDATE=1; DO_LINK=1 ;;
        # Deliberately not part of --all: everything else here is reversible by
        # rerunning something, this one decides whether you get a login screen.
        --login)    DO_LOGIN=1 ;;
        --all)      DO_LINK=1; DO_PACKAGES=1; DO_BROWSERS=1; DO_INPUT=1; DO_NVIM=1; DO_WALLPAPERS=1 ;;
        --root)     shift; [[ $# ]] || { echo "--root needs a directory" >&2; exit 2; }; ROOT_ARG=$1 ;;
        --root=*)   ROOT_ARG=${1#--root=} ;;
        # The whole header comment, found by shape rather than by line number,
        # so editing the block above cannot silently truncate --help.
        -h|--help)  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "$0"; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done
# No action flags at all -> just link, which is the common case.
(( DO_PACKAGES || DO_BROWSERS || DO_INPUT || DO_NVIM || DO_WALLPAPERS || DO_LOGIN || DO_LINK || CHECK )) || DO_LINK=1

# --status and --unlink report on or undo the deployment; pulling first would
# change what they are reporting on or undoing.
(( DO_UPDATE && (STATUS || UNLINK) )) && { echo "--update cannot be combined with --status or --unlink" >&2; exit 2; }

# shellcheck source=install/lib/common.sh
source "$INSTALL_LIB/common.sh"
# shellcheck source=install/lib/link.sh
source "$INSTALL_LIB/link.sh"
# shellcheck source=install/lib/packages.sh
source "$INSTALL_LIB/packages.sh"
# shellcheck source=install/lib/session.sh
source "$INSTALL_LIB/session.sh"
# shellcheck source=install/lib/browsers.sh
source "$INSTALL_LIB/browsers.sh"
# shellcheck source=install/lib/input.sh
source "$INSTALL_LIB/input.sh"
# shellcheck source=install/lib/wallpapers.sh
source "$INSTALL_LIB/wallpapers.sh"
# shellcheck source=install/lib/login.sh
source "$INSTALL_LIB/login.sh"
# shellcheck source=install/lib/update.sh
source "$INSTALL_LIB/update.sh"

init_roots "$ROOT_ARG"

# ---------------------------------------------------------------------------

printf '%shyprland + noctalia dotfiles%s\n' "$BOLD" "$RESET"
(( DRY_RUN )) && note "dry run -- nothing will be changed"
sandboxed && note "root: $ROOT -- nothing outside it is touched"

if (( CHECK )); then
    do_check
    report_warnings
    (( ${#WARNINGS[@]} )) && exit 1
    exit 0
fi

# Before anything else: the point of --update is that everything below runs from
# the version that was pulled, not the one you invoked.
(( DO_UPDATE ))   && do_update

# do_packages returns non-zero when there is no package manager to talk to, and
# the four steps after it are all downstream of one having run.
if (( DO_PACKAGES )) && do_packages; then
    do_npm_globals
    do_claude
    do_fish
    do_services
fi

(( DO_NVIM ))     && do_nvim
(( DO_LINK ))     && do_link
(( DO_BROWSERS ))   && do_browsers
(( DO_INPUT ))      && do_input
(( DO_WALLPAPERS )) && do_wallpapers
(( DO_LOGIN ))      && do_login

# After linking, so it applies the files that were just put in place.
(( DO_UPDATE ))     && do_reapply

if (( STATUS )); then
    do_status
    exit 0
fi

if (( UNLINK )); then
    heading "Done"
    say "Links removed and originals restored where a backup existed."
    note "the copy-based setup in ~/repos/dots owns these paths again;"
    note "nothing there needs to be re-run unless you want it to re-deploy."
    report_warnings
    exit 0
fi

report_warnings

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
