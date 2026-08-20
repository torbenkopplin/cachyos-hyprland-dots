# login.sh -- replacing the display manager with greetd + noctalia-greeter.
#
# A CachyOS install boots into plasmalogin (SDDM under Plasma 6.5's new name),
# which is a Qt/Plasma login screen in front of a session that has nothing else
# Plasma in it -- different fonts, different accent colour, different cursor, and
# a session list where the Hyprland entry is one of three.
#
# greetd + noctalia-greeter replaces it with the same shell you are logging into:
# noctalia-greeter brings its own small wlroots compositor, so it runs before
# Hyprland exists, and it reads the palette and wallpaper Noctalia already
# resolved.
#
# This is the one step here that changes what happens at boot, which is why it is
# not in --all and why it prints how to undo itself. If the greeter ever fails to
# come up you are not locked out: switch to a TTY with ctrl+alt+F2, log in, and
# run the revert line below.

# The display manager currently enabled, by unit name -- plasmalogin.service,
# sddm.service, gdm.service, ... Read from the symlink systemd itself uses, so it
# is right regardless of which of them the distro shipped.
current_display_manager() {
    local target
    target=$(readlink -f "$SYS/etc/systemd/system/display-manager.service" 2>/dev/null) || return 1
    [[ -n $target ]] || return 1
    basename "$target"
}

do_login() {
    heading "Login manager"

    local greetd_conf=$SYS/etc/greetd/config.toml

    if ! sandboxed; then
        # Only the package half needs a package manager. Under --root there is
        # no package half, and the config this writes is the part worth testing.
        if ! command -v pacman >/dev/null 2>&1; then
            warn "pacman not found -- this step only works on CachyOS/Arch"
            return 0
        fi
        say "packages"
        UNRESOLVED=()
        local -a login_pkgs=()
        local p
        while IFS= read -r p; do login_pkgs+=("$p"); done < <(pkg_group login)
        pacman_install "${login_pkgs[@]}"
        if (( ${#UNRESOLVED[@]} )); then
            note "not in any enabled repo: ${UNRESOLVED[*]}"
            aur_install "${UNRESOLVED[@]}"
        fi
    else
        note "packages: skipped under --root"
    fi

    # The session entry point, not the greeter binary: it starts the bundled
    # compositor and runs the greeter inside it. Resolved rather than hardcoded,
    # since a repo build lands in /usr/bin and a manual one in /usr/local/bin.
    local session
    session=$(command -v noctalia-greeter-session 2>/dev/null || true)
    if [[ -z $session ]]; then
        if (( DRY_RUN )) || sandboxed; then
            session=/usr/bin/noctalia-greeter-session
            note "noctalia-greeter is not installed yet; assuming $session"
        else
            warn "noctalia-greeter-session not found -- greeter not configured"
            note "install noctalia-greeter and rerun ./install.sh --login"
            return 0
        fi
    fi

    # --- greetd config -------------------------------------------------------
    #
    # greetd itself only knows how to run one command as one user; everything
    # about how the login screen looks, and which session it starts afterwards,
    # belongs to the greeter.
    local tmp
    tmp=$(mktemp)
    cat >"$tmp" <<GREETD
# Written by cachyos-hyprland-dots (install.sh --login).
#
# greetd runs one command as the unprivileged 'greeter' user. That command is
# noctalia-greeter-session, which starts a small wlroots compositor, shows the
# greeter inside it, and hands over to whichever session you pick from
# /usr/share/wayland-sessions -- hyprland-uwsm.desktop being the one this repo
# is built around.
#
# Appearance comes from Noctalia: open its settings (SUPER+comma) ->
# Security -> Noctalia Greeter -> Sync Now to push the current palette and
# wallpaper to the login screen.

[terminal]
vt = 1

[default_session]
command = "$session"
user = "greeter"
GREETD

    if [[ -f $greetd_conf ]] && ! diff -q "$tmp" "$greetd_conf" >/dev/null 2>&1; then
        say "back up $greetd_conf"
        run "${SUDO_ARGV[@]}" cp -a "$greetd_conf" "$greetd_conf.bak-$STAMP"
    fi
    say "write $greetd_conf"
    run "${SUDO_ARGV[@]}" install -Dm644 "$tmp" "$greetd_conf"
    rm -f "$tmp"

    # --- switch over ---------------------------------------------------------
    if sandboxed; then
        note "display manager: not switched under --root"
        return 0
    fi

    local current
    current=$(current_display_manager || true)

    if [[ $current == greetd.service ]]; then
        say "greetd is already the display manager"
    else
        if [[ -n $current ]]; then
            say "disable $current"
            run "${SUDO_ARGV[@]}" systemctl disable "$current"
        fi
        say "enable greetd"
        # Not --now: restarting the display manager from inside a session it
        # started would kill that session, i.e. this one. It takes effect at the
        # next boot, or the next `systemctl isolate graphical.target` from a TTY.
        run "${SUDO_ARGV[@]}" systemctl enable greetd.service
    fi

    note "takes effect at the next boot; this session is not touched"
    note "sync its look: SUPER+comma -> Security -> Noctalia Greeter -> Sync Now"
    if [[ -n ${current:-} && $current != greetd.service ]]; then
        note "undo: sudo systemctl disable greetd && sudo systemctl enable $current"
    fi
}
