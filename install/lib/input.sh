# input.sh -- input remapping, from install/manifest/input.tsv.
#
# Written, not linked, and as root: keyd reads /etc/keyd at boot, before any home
# directory is guaranteed to be there. Same shape as a browser policy in
# browsers.sh, and for the same reason -- the file has to survive without the
# home it came from.
#
# The step is separate from --browsers because the failure it has is different:
# a policy that is not written leaves a browser with its own defaults, while a
# keyd conf that is not written -- or is written and not loaded -- leaves a
# keyboard sending a chord that three binds answer at once. So this step says
# which of the two happened.

install_keyd_conf() {  # <source> <destination>
    local src=$1 dst=$2
    [[ -f $src ]] || { warn "missing keyd config: $src"; return 1; }

    # A conf keyd cannot parse is a conf keyd SKIPS: the file sits in /etc, the
    # reason is in the journal, and the keyboard goes on sending the chord as
    # though nothing had been installed. `keyd check` is the same parser, so ask
    # it before the file is anywhere it can be ignored from. Only when the binary
    # is here -- the package step may not have run yet, and a missing validator
    # is not a reason to refuse to write the file it would have validated.
    local out
    if command -v keyd >/dev/null 2>&1 && ! out=$(keyd check "$src" 2>&1); then
        warn "keyd rejected $(basename "$src"): $(printf '%s' "$out" | tail -1)"
        return 1
    fi

    if (( DRY_RUN )); then
        say "would: ${SUDO_ARGV[*]} install -Dm644 $src $dst"
        return 0
    fi

    if as_root install -Dm644 "$src" "$dst" 2>/dev/null; then
        say "keyd $dst"
        return 0
    fi

    warn "could not write $dst"
    return 1
}

do_input() {
    local kind src rest wrote=0

    heading "Input remapping"
    note "one chord, caught below the compositor -- see input/README.md"
    while IFS=$'\t' read -r kind src rest; do
        [[ $kind == keyd ]] || continue
        install_keyd_conf "$REPO/$src" "$(expand_home "$rest")" && wrote=1
    done < <(manifest input)

    (( wrote )) || return 0
    sandboxed && return 0

    # A conf in /etc/keyd that the daemon has not read is a file, not a remap:
    # keyd loads the directory once at startup and on `keyd reload`. Nothing here
    # starts the unit -- services.tsv does that, and packages.tsv installs it --
    # so this reports the gap instead of papering over it.
    if ! systemctl is-active --quiet keyd.service 2>/dev/null; then
        note "keyd is not running: ./install.sh --packages installs it and turns it on"
        return 0
    fi
    run "${SUDO_ARGV[@]}" keyd reload
}
