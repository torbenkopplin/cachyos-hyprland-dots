# session.sh -- the environment the compositor handed to everything it spawned.
#
# Not the environment you get in a terminal. fish builds that per terminal,
# long after the compositor started, so a PATH that is right in your shell says
# nothing about the PATH the launcher's providers run under. Read it from the
# process instead of asking a shell.

# shellcheck disable=SC2088  # a description read by a person, not a path
noct_register session-path pure check_session_path \
    "~/.local/bin is on the PATH the session actually runs with"
noct_register session-env  pure check_session_env \
    "both doors onto that PATH are written the way their reader expands them"

session_path() {
    local pid
    pid=$(pgrep -x noctalia | head -1) || return 1
    [[ -n $pid ]] || return 1
    tr '\0' '\n' < "/proc/$pid/environ" 2>/dev/null | sed -n 's/^PATH=//p' | head -1
}

check_session_path() {
    local path
    path=$(session_path) || { skip session-path "noctalia is not running"; return; }

    if [[ ":$path:" == *":$BIN_HOME:"* ]]; then
        pass session-path "$(tilde "$BIN_HOME") is on the shell's PATH"
    else
        fail session-path "$(tilde "$BIN_HOME") is missing from the running shell's PATH"
        info "every /aout /ain /bt /net /power /theme entry will answer \"No results found\""
        info "and SUPER+SHIFT+G will do nothing. Fix: ./install.sh, then log out and in."
        info "got: $(tilde "$path")"
    fi
}

# Both doors onto the session's PATH, because which one is used depends on how
# the session was started and that is a choice made at the login screen:
#
#   ~/.config/uwsm/env             read by uwsm, the intended route
#   ~/.config/environment.d/*.conf read by the systemd user manager, which
#                                  covers any user-unit session however it
#                                  started -- including a plain
#                                  hyprland.desktop picked at the greeter
#
# Each is exercised the way its reader would, and both from a deliberately bare
# environment. That last part is not a detail: the generator EXPANDS $PATH
# against what it inherits, so running it from an ordinary shell hands it a
# PATH that already contains the directory and it passes however the file is
# written. The environment.d file was first written with %h, which is a UNIT
# file specifier that environment.d does not expand -- it parsed fine, prepended
# a literal "%h/.local/bin", and this check said it was fine.
check_session_env() {
    local problems=()

    local f=$CONFIG_HOME/uwsm/env
    if [[ ! -f $f ]]; then
        problems+=("$f does not exist -- run ./install.sh")
    elif ! sh -n "$f" 2>/dev/null; then
        problems+=("$f is not valid POSIX sh (uwsm sources it with /bin/sh, not fish)")
    else
        local got
        got=$(env -i HOME="$HOME" PATH=/usr/bin sh -c ". '$f'; printf '%s' \"\$PATH\"")
        [[ ":$got:" == *":$BIN_HOME:"* ]] || problems+=("sourcing $(tilde "$f") does not add $(tilde "$BIN_HOME") (got: $(tilde "$got"))")
    fi

    # The real generator, not a reimplementation of it. environment.d has its
    # own expansion rules and the whole point of this check is that they are
    # not the ones you would guess -- so anything that guessed them here would
    # be wrong in exactly the way the file was.
    local gen=/usr/lib/systemd/user-environment-generators/30-systemd-environment-d-generator
    if [[ ! -d $CONFIG_HOME/environment.d ]]; then
        problems+=("$CONFIG_HOME/environment.d does not exist -- run ./install.sh")
    elif [[ -x $gen ]]; then
        local envd
        envd=$(env -i HOME="$HOME" PATH=/usr/bin XDG_CONFIG_HOME="$CONFIG_HOME" \
                   "$gen" 2>/dev/null | sed -n 's/^PATH=//p' | head -1)
        if [[ -z $envd ]]; then
            problems+=("environment.d sets no PATH at all")
        elif [[ ":$envd:" != *":$BIN_HOME:"* ]]; then
            problems+=("environment.d expands to a PATH without $(tilde "$BIN_HOME") (got: $(tilde "$envd"))")
        fi
    fi

    if (( ${#problems[@]} == 0 )); then
        pass session-env "both PATH files put $(tilde "$BIN_HOME") on the session's PATH"
    else
        fail session-env "${#problems[@]} problem(s) with the session PATH files"
        local pr; for pr in "${problems[@]}"; do info "$pr"; done
    fi
}
