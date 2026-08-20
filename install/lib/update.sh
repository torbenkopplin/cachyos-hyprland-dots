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

# Make what was just linked show up in the session that is already running.
#
# Without this an update is only true of the next login: Hyprland reloads its own
# config on change but reaches generated/glass.lua through a require(), Noctalia
# renders its templates on a colour change and not on a config change, and kitty
# reads its colours on SIGUSR1. noct-glass does all three.
do_reapply() {
    heading "Applying"

    if (( DRY_RUN )); then
        say "would: noct-glass apply, then noctalia msg templates-apply"
        return 0
    fi

    needs_machine "applying" || return 0

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
    fi
}
