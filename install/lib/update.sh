# update.sh -- pull, relink, and make it live.
#
# This is the one to run on the second machine. It refuses to pull over local
# changes rather than fighting you for them, and it re-applies the glass and the
# templates afterwards so the session shows what was pulled.

# Pull, and nothing else, then hand over to the version that was just pulled.
#
# Two phases on purpose. bash reads a script from disk as it executes it, so a
# pull that rewrites install.sh under a running install.sh can resume at a byte
# offset that now means something else -- and this script is exactly the kind of
# thing an update changes. So this function pulls, re-execs, and the second run
# does the linking with the code that was actually pulled. DOTS_UPDATED marks
# that second run so it cannot loop.
#
# Splitting the installer into install/lib/*.sh does not change that reasoning,
# it widens it: the libraries are sourced at startup, so a pull can now also
# rewrite a file this process has already read.
do_update() {
    heading "Update"

    if [[ -n ${DOTS_UPDATED:-} ]]; then
        note "pulled ${DOTS_UPDATED:0:7} -- continuing with the version that came with it"
        return 0
    fi

    needs_machine "update" || return 0

    [[ -d $REPO/.git ]] || { warn "$REPO is not a git checkout -- nothing to pull"; return 0; }
    command -v git >/dev/null 2>&1 || { warn "git is not installed -- nothing to pull"; return 0; }

    # Refused rather than stashed. Every config here is a symlink into this
    # checkout, so uncommitted changes are the config you are running: stashing
    # them would change the desktop out from under you, and merging them is a
    # decision only you can make. The one thing to do is say exactly what is in
    # the way.
    local dirty
    dirty=$(git -C "$REPO" status --porcelain 2>/dev/null)
    if [[ -n $dirty ]]; then
        warn "not pulling -- this checkout has local changes"
        note "the configs are symlinks into here, so these ARE your live config:"
        printf '%s\n' "$dirty" | sed 's/^/      /'
        note "commit them, or 'git stash', or 'git checkout --' them, then rerun --update"
        # A submodule shows up here as " M vendor/<name>" whenever its checkout
        # is not at the commit this repo records -- which happens the moment you
        # edit the theme in place, and it is NOT something 'git stash' or
        # 'git checkout --' in this repo will resolve. Say so, because the advice
        # above is otherwise wrong for that one line.
        if printf '%s\n' "$dirty" | grep -q '^.[[:space:]]*M[[:space:]]*vendor/'; then
            note "a 'vendor/...' line means a SUBMODULE has moved, not a file here:"
            note "commit and push inside it, then 'git add' it here -- or"
            note "'git submodule update --recursive' to throw those changes away"
        fi
        return 0
    fi

    local before after
    before=$(git -C "$REPO" rev-parse HEAD 2>/dev/null) || { warn "cannot read HEAD"; return 0; }

    if (( DRY_RUN )); then
        say "would: git -C $(disp "$REPO") pull --ff-only"
        note "then relink, then re-apply the glass and the templates"
        return 0
    fi

    # --ff-only: a fast-forward is the only kind of update that needs no
    # decision. Anything else means the two machines have diverged, which is a
    # merge, which is not something an installer should do behind your back.
    if ! git -C "$REPO" pull --ff-only; then
        warn "pull failed -- continuing with what is already on disk"
        note "diverged? 'git log --oneline --graph HEAD @{u}' shows how, and the"
        note "merge or rebase is yours to make"
        return 0
    fi

    # Submodules are pulled as part of the pull, not left for the next command
    # to discover. vendor/noirblaze carries the colourscheme, and links.tsv
    # points a row straight at a file inside it: a submodule left uninitialised
    # deploys a DANGLING SYMLINK into ~/.config/noctalia/palettes, which is the
    # exact failure tests/lint.sh manifest-sources exists to catch and which
    # this end of it can prevent outright.
    #
    # --init so a first pull after the submodule was added works without a
    # separate command, --recursive because a submodule may have its own.
    git -C "$REPO" submodule update --init --recursive || \
        warn "submodule update failed -- vendor/ may be stale or missing"

    after=$(git -C "$REPO" rev-parse HEAD)
    if [[ $before == "$after" ]]; then
        say "already up to date (${after:0:7})"
        return 0
    fi

    say "updated ${before:0:7} -> ${after:0:7}"
    git -C "$REPO" --no-pager log --oneline --no-decorate "$before..$after" | sed 's/^/      /'
    printf '\n'
    say "re-running with the version just pulled"
    DOTS_UPDATED=$after exec "$REPO/install.sh" "${ARGV[@]}"
}

# The active scheme as color-scheme-set wants it: "<source> <name>". Read from
# Noctalia's own state files rather than over IPC, the same way bin/noct-common.sh
# does -- this runs from the installer, not from inside the shell, but the reader
# is the one that cannot deadlock and it is already written.
noct_scheme_for_reapply() {
    local common="$REPO/bin/noct-common.sh"
    [[ -f $common ]] || return 1
    # shellcheck source=/dev/null
    . "$common" 2>/dev/null || return 1
    noct_scheme 2>/dev/null
}

# Make what was just linked show up in the session that is already running.
#
# Without this an update is only true of the next login: Hyprland reloads its own
# config on change but reaches generated/glass.lua through a require(), Noctalia
# renders its templates on a colour change and not on a config change, and kitty
# reads its colours on SIGUSR1. noct-glass does all three.
do_reapply() {
    heading "Applying"

    if (( DRY_RUN )); then
        say "would: systemctl --user daemon-reload, try-restart the helpers,"
        say "       noct-glass apply, then noctalia msg templates-apply"
        return 0
    fi

    needs_machine "applying" || return 0

    # The user units in config/systemd, and the daemons two of them run. systemd
    # reads a unit file when it loads it, so a changed one is only true after a
    # daemon-reload; a running Python helper keeps executing the code it started
    # with until it is restarted. try-restart touches only what is already
    # running, so a machine that never calls lid.setup() or rotate.setup() is
    # not handed a daemon it has no use for. noctalia.service is reloaded and
    # NOT restarted: that would blank the bar and the lock screen mid-install.
    if systemctl --user show-environment >/dev/null 2>&1; then
        systemctl --user daemon-reload \
            && say "user units reloaded" \
            || note "systemctl --user daemon-reload failed"
        systemctl --user try-restart hypr-sleepwatch.service hypr-autorotate.service \
            && say "sleep and rotation helpers restarted (where running)" \
            || note "could not restart hypr-sleepwatch / hypr-autorotate"
    fi

    if [[ -z ${HYPRLAND_INSTANCE_SIGNATURE:-} ]]; then
        note "no Hyprland session here -- this lands at the next login"
        return 0
    fi

    if [[ -x $BIN_HOME/noct-glass ]]; then
        "$BIN_HOME/noct-glass" apply
        say "glass re-applied ($("$BIN_HOME/noct-glass" show 2>/dev/null))"
    else
        note "noct-glass is not on $BIN_HOME yet -- skipping"
    fi

    # Re-renders every template against the palette already in force, which is
    # what picks up a template this update changed.
    if command -v noctalia >/dev/null 2>&1; then
        noctalia msg templates-apply >/dev/null 2>&1 \
            && say "templates re-rendered" \
            || note "noctalia would not re-render (shell not running?)"

        # ...but templates-apply re-renders against the palette Noctalia ALREADY
        # HAS IN MEMORY. It does not re-read the palette file, so an update that
        # changed config/noctalia/palettes/*.json -- or moved the colourscheme
        # into vendor/noirblaze, which is exactly what happened -- renders the
        # old colours and reports success.
        #
        # Measured 2026-09-05: with the palette relinked to the submodule and
        # bright.black changed from #737373 to #8b8b8b, templates-apply wrote
        # #737373. Re-issuing color-scheme-set with the scheme already selected
        # is what makes it re-read the file, and it wrote #8b8b8b.
        local scheme
        if scheme=$(noct_scheme_for_reapply); then
            # shellcheck disable=SC2086
            noctalia msg color-scheme-set $scheme >/dev/null 2>&1 \
                && say "palette re-read ($scheme)" \
                || note "noctalia would not re-read the palette"
        fi
    fi
}
