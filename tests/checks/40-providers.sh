# providers.sh -- the launcher's dmenu providers, run the way the launcher runs
# them: through `sh -lc`, under the SESSION's PATH, not a terminal's. That
# difference is the entire bug these check for.

noct_register provider-resolve pure check_provider_resolve \
    "every provider binary resolves under the session PATH"
noct_register provider-run     pure check_provider_run \
    "every provider answers, in time, without leaking a payload"

launcher_toml() { printf '%s' "$CONFIG_HOME/noctalia/20-launcher.toml"; }

# Every `command = "..."` in the launcher config, one per line.
provider_commands() {
    local toml; toml=$(launcher_toml)
    [[ -f $toml ]] || return 1
    sed -n 's/^[[:space:]]*command[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\1/p' "$toml"
}

# Both `command` and `exec`, reduced to the binary each one invokes.
provider_binaries() {
    local toml; toml=$(launcher_toml)
    [[ -f $toml ]] || return 1
    sed -n 's/^[[:space:]]*\(command\|exec\)[[:space:]]*=[[:space:]]*"\(.*\)"[[:space:]]*$/\2/p' "$toml" \
        | awk '{print $1}' | sort -u
}

# The PATH the providers are tried under. NOCT_CHECK_PATH overrides it, which
# is how you confirm the providers themselves are healthy while the session is
# still running the old environment -- run
#
#   NOCT_CHECK_PATH=$PATH noct-check provider-resolve provider-run
#
# from a terminal that has ~/.local/bin, and a pass there plus a session-path
# failure localises the problem to the session environment and nothing else.
provider_path() {
    [[ -n ${NOCT_CHECK_PATH-} ]] && { printf '%s' "$NOCT_CHECK_PATH"; return 0; }
    session_path
}

check_provider_resolve() {
    local path bins missing=() b
    path=$(provider_path) || path=$PATH
    bins=$(provider_binaries) || { skip provider-resolve "no 20-launcher.toml"; return; }

    while IFS= read -r b; do
        [[ -n $b ]] || continue
        env -i HOME="$HOME" PATH="$path" sh -lc "command -v $b" >/dev/null 2>&1 || missing+=("$b")
    done <<<"$bins"

    if (( ${#missing[@]} == 0 )); then
        pass provider-resolve "every provider binary resolves under the session PATH"
    else
        fail provider-resolve "not found by the launcher: ${missing[*]}"
        info "the launcher runs these through 'sh -lc'; /etc/profile does not add $BIN_HOME"
    fi
}

check_provider_run() {
    local path cmds problems=()
    path=$(provider_path) || path=$PATH
    cmds=$(provider_commands) || { skip provider-run "no 20-launcher.toml"; return; }

    local cmd out lines start elapsed status slowest=0
    while IFS= read -r cmd; do
        [[ -n $cmd ]] || continue
        start=$(date +%s%N)
        out=$(timeout 3 env -i HOME="$HOME" PATH="$path" \
                  XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" \
                  sh -lc "$cmd" 2>/dev/null)
        status=$?
        elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
        (( elapsed > slowest )) && slowest=$elapsed
        lines=$(printf '%s' "$out" | grep -c . || true)

        if (( status != 0 )); then
            problems+=("\`$cmd\` exited $status$( ((status == 127)) && printf ' (not found on the session PATH)')")
            continue
        fi
        if (( lines == 0 )); then
            problems+=("\`$cmd\` printed nothing -- the launcher shows this as \"No results found\"")
            continue
        fi
        # A payload reaching the visible line is the bug bin/noct-common.sh's
        # side map exists to prevent: MAC addresses and base64 blobs are what
        # it would leak if the map were bypassed.
        if printf '%s' "$out" | grep -qE '([0-9A-Fa-f]{2}[:_]){5}[0-9A-Fa-f]{2}|[A-Za-z0-9+/]{24,}={0,2}'; then
            problems+=("\`$cmd\` leaks a device id or base64 payload into the visible line")
            continue
        fi
        if (( elapsed > 2000 )); then
            problems+=("\`$cmd\` took ${elapsed}ms -- the launcher feels broken above ~2s")
            continue
        fi
        info "$(printf '%-28s %3d lines  %4dms' "$cmd" "$lines" "$elapsed")"
    done <<<"$cmds"

    # Recorded, because provider latency is the other thing that differs
    # between two machines that both "work": Noctalia SIGTERMs a provider at
    # about two seconds, so a machine sitting at 1800ms is one slow boot away
    # from a launcher that shows nothing, and nothing about it looks wrong yet.
    metric providers.slowest_ms "$slowest" 600

    if (( ${#problems[@]} == 0 )); then
        pass provider-run "every provider answers under the session PATH (slowest ${slowest}ms)"
    else
        fail provider-run "${#problems[@]} provider(s) unusable from the launcher"
        local p; for p in "${problems[@]}"; do info "$p"; done
    fi
}
