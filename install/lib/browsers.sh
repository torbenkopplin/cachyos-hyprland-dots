# browsers.sh -- declarative browser configuration, from
# install/manifest/browsers.tsv.
#
# Profiles -- cookies, saved logins, history -- are never touched: see
# browsers/README.md. What this writes is a managed policy in /etc, which is the
# one place a setting cannot be un-set from inside the browser, and a user.js in
# each profile, which is read exactly once at startup.

install_policy() {  # <source> <destination>
    local src=$1 dst=$2
    [[ -f $src ]] || return 0

    if (( DRY_RUN )); then
        say "would: ${SUDO_ARGV[*]} install -Dm644 $src $dst"
        return 0
    fi

    if as_root install -Dm644 "$src" "$dst" 2>/dev/null; then
        say "policy $dst"
    else
        warn "could not write $dst"
    fi
}

# install_user_js <source user.js> <label> <profiles root>...
#
# Firefox-family profiles have generated directory names, so they are discovered
# rather than assumed. They do not exist until the browser has been launched
# once, which is why "no profiles found" is a note and not a warning.
install_user_js() {
    local src=$1 label=$2
    shift 2
    [[ -f $src ]] || return 0

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

do_browsers() {
    local kind src rest
    local -a roots

    heading "Browser policies"
    note "declarative settings only -- no profile data is copied or tracked"
    while IFS=$'\t' read -r kind src rest; do
        [[ $kind == policy ]] || continue
        install_policy "$REPO/$src" "$(expand_home "$rest")"
    done < <(manifest browsers)

    heading "Browser preferences"
    local label
    while IFS=$'\t' read -r kind src label rest; do
        [[ $kind == userjs ]] || continue
        roots=()
        local r
        # printf with the newline, not without: `read` returns non-zero on a
        # final line that has none, and the loop condition then throws that line
        # away -- which silently dropped the last profile root of every row.
        while IFS= read -r r; do roots+=("$(expand_home "$r")"); done \
            < <(printf '%s\n' "$rest" | tr '\t' '\n')
        install_user_js "$REPO/$src" "$label" "${roots[@]}"
    done < <(manifest browsers)
}
