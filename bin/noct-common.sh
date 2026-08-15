#!/usr/bin/env bash
# noct-common.sh -- shared helpers for the noct-* launcher providers.
#
# The contract with Noctalia's dmenu providers:
#
#   command  is run through `sh -lc`; every stdout line becomes a result.
#            A tab splits the line into "title <TAB> description".
#   exec     is run on activation with {selection} replaced by the *whole*
#            selected line, tab included.
#
# So each candidate carries its own payload in the half after the tab, and we
# base64 it: that keeps arbitrary SSIDs, device names and descriptions from
# ever reaching the shell as syntax. The title half is only cosmetic, so we
# strip the characters that would break out of the double quotes in `exec`.

# Base64 with no line wrapping, so a payload is always a single token.
enc() { printf '%s' "$1" | base64 -w0; }
dec() { printf '%s' "$1" | base64 -d 2>/dev/null; }

# Titles are interpolated into exec="... \"{selection}\"", so remove anything
# that has meaning inside double quotes.
safe() { printf '%s' "$1" | tr -d '"$`\\' | tr -d '\t\n'; }

# Print one launcher candidate: visible title, then the payload.
emit() { printf '%s\t%s\n' "$(safe "$1")" "$2"; }

# Everything after the last tab of a selected line, i.e. the payload.
token() { printf '%s' "${1##*$'\t'}"; }

# Guard against a missing backend rather than emitting a wall of shell errors
# into the launcher.
need() {
    if ! command -v "$1" >/dev/null 2>&1; then
        emit "$1 is not installed" "$(enc "")"
        return 1
    fi
    return 0
}

# Run an interactive command in a terminal window. Used for the few operations
# that must prompt (a Wi-Fi passphrase), because Noctalia runs `exec` detached
# with no tty attached.
in_terminal() {
    local term=${TERMINAL:-kitty}
    command -v "$term" >/dev/null 2>&1 || term=xterm
    setsid "$term" -e "$@" >/dev/null 2>&1 &
}
