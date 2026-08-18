#!/usr/bin/env bash
# noct-common.sh -- shared helpers for the noct-* launcher providers.
#
# The contract with Noctalia's dmenu providers:
#
#   command  is run through `sh -lc`; every stdout line becomes a result.
#            A tab splits the line into "title <TAB> description", and BOTH
#            halves are shown to you.
#   exec     runs on activation with {selection} replaced by the whole
#            selected line, tab included.
#
# That leaves nowhere in the line to hide a machine-readable payload: anything
# we put there is displayed. Stuffing a device id or a base64 blob into the
# description would fill the launcher with noise.
#
# So the line carries only what you should read, and the payload goes into a
# side map in $XDG_RUNTIME_DIR, keyed by the title:
#
#   list:  item "Sony WH-1000XM4" "connected · 87%"  "disconnect:AA:BB:..."
#            -> shows   "Sony WH-1000XM4   connected · 87%"
#            -> records "Sony WH-1000XM4 <TAB> disconnect:AA:BB:..."
#   act:   payload "$selected_line"   -> "disconnect:AA:BB:..."
#
# This also settles the quoting question. Titles are sanitised of characters
# that would break out of the double quotes in `exec`, and a network name or
# device id never reaches a shell at all -- it is only ever read back out of
# the map file.
#
# The two-second rule
# -------------------
# Noctalia runs `command` synchronously on its render thread and SIGTERMs it
# after ~2 seconds. A provider that overruns produces no output at all, and the
# launcher shows "No results found" -- there is no partial list and no error
# you would see without turning the log level up. Measured on v5.0.0-beta.8;
# the docs do not mention a limit. Two rules follow from it:
#
#   1. `list` must not call `noctalia msg`. The shell is blocked waiting for us
#      while we would be waiting for it, so the IPC call never returns and the
#      whole provider is killed at the deadline. Read the state files instead --
#      noct_setting() below -- which is where Noctalia persists this anyway.
#   2. `list` must not run anything that can block on the network or on
#      hardware (a Wi-Fi scan, a Bluetooth discovery, an HTTP request). Ask for
#      cached results, and offer the slow thing as an *entry* the user can pick
#      -- `exec` is run detached and has no deadline.

set -o pipefail

# ---------------------------------------------------------------------------
# Provider identity. Each script sets this before calling anything else.
# ---------------------------------------------------------------------------

noct_provider=""

_map_file() {
    printf '%s/noct-%s.map' "${XDG_RUNTIME_DIR:-/tmp}" "$noct_provider"
}

# ---------------------------------------------------------------------------
# Emitting candidates
# ---------------------------------------------------------------------------

# Strip characters that have meaning inside the double quotes of `exec`, plus
# the tab and newline that would corrupt the field structure.
_safe() { printf '%s' "$1" | tr -d '"$`\\' | tr -d '\t\n'; }

# provider <id> -- name the map this script reads or writes. Both `list` and
# `act` must pass the same id, which is why providers that serve more than one
# list (audio sinks vs sources) take the kind as an argument in both modes.
provider() { noct_provider=$1; }

# begin_list -- truncate the map. Only `list` calls this; `act` must not, or it
# would erase the very entry it was asked to resolve.
begin_list() { : >"$(_map_file)"; }

# item <title> <description> <payload>
#
# Titles are the map key, so they must be unique. Rather than silently
# shadowing an earlier entry, a repeat gets a counter suffix -- two identical
# USB headsets stay individually selectable.
item() {
    local title desc payload map n candidate
    title=$(_safe "$1")
    desc=$(_safe "${2:-}")
    payload=$3
    map=$(_map_file)

    candidate=$title
    n=1
    while cut -f1 <"$map" | grep -qxF "$candidate"; do
        n=$((n + 1))
        candidate="$title ($n)"
    done

    printf '%s\t%s\n' "$candidate" "$payload" >>"$map"

    if [[ -n $desc ]]; then
        printf '%s\t%s\n' "$candidate" "$desc"
    else
        printf '%s\n' "$candidate"
    fi
}

# ---------------------------------------------------------------------------
# Resolving an activation
# ---------------------------------------------------------------------------

# payload <selected line> -- everything the line's title was recorded against.
payload() {
    local key
    key=${1%%$'\t'*}
    awk -F'\t' -v k="$key" '$1 == k { sub(/^[^\t]*\t/, ""); print; exit }' \
        "$(_map_file)" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Reading Noctalia's own state
#
# `noctalia msg color-scheme-get` would answer these, but a provider may not
# call it -- see "The two-second rule" above. Noctalia persists the same values
# as TOML, so read them from disk instead.
#
# Precedence matches Noctalia's own: state settings.toml (what the GUI and IPC
# write) wins over the config directory, and within the config directory the
# alphabetically last file wins, since that is the merge order.
# ---------------------------------------------------------------------------

_noct_config_dir() { printf '%s/noctalia' "${XDG_CONFIG_HOME:-$HOME/.config}"; }
_noct_state_dir()  { printf '%s/noctalia' "${XDG_STATE_HOME:-$HOME/.local/state}"; }

# _toml_get <file> <section> <key> -- one scalar out of one TOML section.
#
# Deliberately not a general TOML parser: it handles the flat "key = value"
# lines under a [section] header, which is the whole shape of the files we read
# here. Sub-tables are indented in Noctalia's output but that changes nothing --
# the header line is matched after leading space is stripped, so
# [lockscreen_widgets.grid] simply is not [theme] and its keys are skipped.
_toml_get() {
    [[ -f $1 ]] || return 1
    awk -v want="$2" -v key="$3" '
        { line = $0; sub(/^[[:space:]]+/, "", line) }
        line ~ /^#/ { next }
        line ~ /^\[/ {
            sect = line
            sub(/^\[+/, "", sect); sub(/\]+.*$/, "", sect)
            in_want = (sect == want)
            next
        }
        in_want {
            eq = index(line, "=")
            if (eq == 0) next
            k = substr(line, 1, eq - 1); v = substr(line, eq + 1)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", k)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", v)
            gsub(/^"|"$/, "", v)
            if (k == key && v != "") { print v; found = 1; exit }
        }
        END { if (!found) exit 1 }
    ' "$1"
}

# noct_setting <section> <key> -- first hit in Noctalia's merge order.
noct_setting() {
    local file
    _toml_get "$(_noct_state_dir)/settings.toml" "$1" "$2" && return 0
    while IFS= read -r file; do
        _toml_get "$file" "$1" "$2" && return 0
    done < <(find "$(_noct_config_dir)" -maxdepth 1 -name '*.toml' 2>/dev/null | sort -r)
    return 1
}

# noct_scheme -- "<source> <name>", the same two tokens `color-scheme-get`
# prints. The name lives under a different key per source.
noct_scheme() {
    local source name
    source=$(noct_setting theme source) || return 1
    case "$source" in
        builtin)   name=$(noct_setting theme builtin) ;;
        wallpaper) name=$(noct_setting theme wallpaper_scheme) ;;
        community) name=$(noct_setting theme community_palette) ;;
        custom)    name=$(noct_setting theme custom_palette) ;;
        *)         return 1 ;;
    esac
    [[ -n ${name:-} ]] || return 1
    printf '%s %s' "$source" "$name"
}

# noct_theme_mode -- dark | light | auto, as `theme-mode-get` would report it.
noct_theme_mode() { noct_setting theme mode; }

# ---------------------------------------------------------------------------
# Misc
# ---------------------------------------------------------------------------

# Report a missing backend as a result rather than dumping shell errors into
# the launcher.
need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        item "$1 is not installed" "required for this provider" ""
        return 1
    fi
    return 0
}

# Run an interactive command in a terminal. Needed for the few operations that
# must prompt (a Wi-Fi passphrase): Noctalia runs `exec` detached, with no tty.
in_terminal() {
    local term=${TERMINAL:-kitty}
    command -v "$term" >/dev/null 2>&1 || term=xterm
    setsid "$term" -e "$@" >/dev/null 2>&1 &
}
