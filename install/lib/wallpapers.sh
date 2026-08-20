# wallpapers.sh -- fetching the images the palette is derived from.
#
# Part of --all, and last in it: the palette is wallpaper-derived, so the desktop
# is not finished until this has run once, and leaving it out of the one-command
# setup just means a fresh machine looks half-configured.
#
# It does pull a few hundred megabytes of images over the network, which is the
# one step here with a real cost attached -- hence the note in --all's help and
# the advice to try --dry-run on a metered connection.

# check_wallpaper_monitors -- warn when 60-wallpaper.toml names monitors this
# machine does not have.
#
# This is the one part of the setup that cannot be made host-agnostic: Noctalia
# keys per-monitor wallpaper directories on connector names, and it has no
# per-host mechanism the way hypr/host.lua does. An unmatched
# [wallpaper.monitor.X] section is not an error -- Noctalia just ignores it and
# falls back to the global `directory`, so the failure mode on a machine with
# different connectors is every screen quietly showing the same 16:9 set. That is
# invisible unless something says so, which is what this does.
check_wallpaper_monitors() {
    local toml=$REPO/config/noctalia/60-wallpaper.toml
    [[ -f $toml ]] || return 0

    local -a configured=()
    local name
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

    needs_machine "wallpapers" || return 0

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
