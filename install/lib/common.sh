# common.sh -- roots, output helpers, and the one refusal.
#
# Sourced by install.sh before anything else. Everything here is shared by more
# than one step; anything used by exactly one step lives in that step's file.

# ---------------------------------------------------------------------------
# Roots
#
# Four of them, and they are the reason this file exists. Every path any step
# writes to is built from one of these, so a single --root makes the whole
# installer land somewhere harmless -- which is what makes it testable, and what
# makes the accident described below impossible rather than merely refused.
#
#   CONFIG_HOME  ~/.config          the configs
#   BIN_HOME     ~/.local/bin       the scripts
#   HOME_DIR     ~                  browser profiles, and ~-expansion
#   SYS          /                  /etc, and only ever through as_root
# ---------------------------------------------------------------------------

# init_roots <root> -- with an empty <root>, the real thing.
init_roots() {
    local root=$1

    if [[ -n $root ]]; then
        # Deliberately not honouring XDG_CONFIG_HOME here: a sandbox that
        # follows an environment variable is not a sandbox.
        mkdir -p "$root"
        ROOT=$(cd -- "$root" && pwd)
        HOME_DIR=$ROOT
        CONFIG_HOME=$ROOT/.config
        BIN_HOME=$ROOT/.local/bin
        SYS=$ROOT
        SUDO_ARGV=()
        return 0
    fi

    ROOT=""
    HOME_DIR=$HOME
    CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
    BIN_HOME=$HOME/.local/bin
    SYS=""
    SUDO_ARGV=(sudo)

    # CONFIG_HOME comes from XDG_CONFIG_HOME and BIN_HOME comes from HOME. Those
    # are two different roots, which means overriding HOME does NOT sandbox this
    # script: it goes on linking into whatever XDG_CONFIG_HOME says, and on a
    # normal session that is the real ~/.config.
    #
    # That is not hypothetical. On 2026-08-19 a test run of --update against a
    # throwaway HOME relinked a live desktop's entire ~/.config to a temporary
    # checkout under /tmp, which was then deleted -- 42 dangling symlinks, no
    # hyprland.lua, and a session that could not start. The repair was easy (the
    # displaced links were all still there as *.bak-*) and finding the cause was
    # not.
    #
    # So: if HOME has been overridden and XDG_CONFIG_HOME did not follow it, that
    # is an accident every time, and this refuses rather than acting on half of
    # it. A deliberate XDG_CONFIG_HOME outside HOME is left alone -- what is
    # caught is the mismatch, not the value.
    #
    # --root is the answer to what that test run was trying to do, and it needs
    # no environment at all. This refusal stays for the runs that do not use it.
    local real_home
    real_home=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)
    if [[ -n ${XDG_CONFIG_HOME:-} && -n $real_home && $HOME != "$real_home" \
          && $XDG_CONFIG_HOME != "$HOME"/* ]]; then
        cat >&2 <<REFUSAL

  !! refusing to run: HOME and XDG_CONFIG_HOME disagree

     HOME             $HOME
     (real home)      $real_home
     XDG_CONFIG_HOME  $XDG_CONFIG_HOME

     HOME has been overridden but XDG_CONFIG_HOME has not, so this would link
     into $XDG_CONFIG_HOME -- somebody else's config -- while treating
     $HOME as yours. To sandbox a test run, use --root, which
     needs no environment variables at all:

       ./install.sh --root /tmp/sandbox

REFUSAL
        exit 2
    fi
}

# ---------------------------------------------------------------------------
# Output
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

report_warnings() {
    (( ${#WARNINGS[@]} )) || return 0
    heading "Warnings (${#WARNINGS[@]})"
    printf '  - %s\n' "${WARNINGS[@]}"
}

# disp <path> -- a path as it should be printed. Under --root the home being
# abbreviated is the sandbox, which is what the banner says it is.
disp() { printf '%s' "${1/#$HOME_DIR/\~}"; }

# ---------------------------------------------------------------------------
# The sandbox
#
# Under --root every path is redirected, but a package manager, a systemd unit
# and a git clone are not paths: they are the machine. Those steps say so and
# skip, which is what leaves --root safe to point anywhere and useful in CI.
# ---------------------------------------------------------------------------

sandboxed() { [[ -n $ROOT ]]; }

# as_root <command...> -- with sudo, unless --root has already redirected the
# target somewhere that needs no privilege. SUDO_ARGV is an array rather than a
# string so it can be genuinely empty, and so `run "${SUDO_ARGV[@]}" ...` prints
# the command it is about to run rather than a mangled version of it.
as_root() { "${SUDO_ARGV[@]}" "$@"; }

# needs_machine <label> -- true when this step may touch the machine.
needs_machine() {
    sandboxed || return 0
    note "$1: skipped under --root -- this one changes the machine, not a path"
    return 1
}

# ---------------------------------------------------------------------------
# Manifests
# ---------------------------------------------------------------------------

# manifest <name> -- the rows of install/manifest/<name>.tsv, comments and blank
# lines removed. Split on tabs by the caller with IFS=$'\t'.
manifest() {
    local file=$INSTALL_LIB/../manifest/$1.tsv
    [[ -f $file ]] || { warn "missing manifest: install/manifest/$1.tsv"; return 1; }
    grep -v '^[[:space:]]*#' "$file" | grep -v '^[[:space:]]*$'
}

# expand_home <path> -- a leading ~ becomes the effective home, and an absolute
# path is prefixed by the system root. Both are identity when no --root is given.
expand_home() {
    case $1 in
        '~'/*) printf '%s' "$HOME_DIR/${1#'~'/}" ;;
        /*)    printf '%s' "$SYS$1" ;;
        *)     printf '%s' "$1" ;;
    esac
}
