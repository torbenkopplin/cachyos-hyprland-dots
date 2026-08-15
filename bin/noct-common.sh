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
