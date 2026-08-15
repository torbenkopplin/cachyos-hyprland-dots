# Auto start Hyprland on tty1 -- carried over from ~/dotfiles.
#
# CHANGED: `exec start-hyprland` became a uwsm launch. The rest of this repo
# assumes uwsm (conf/options.lua sets LAUNCH_PREFIX = "uwsm app -- ", so every
# app gets its own systemd scope and a crashing app cannot take the session
# down). Starting the compositor outside uwsm while launching apps through it
# gives you the worst of both: scopes with no session to attach to.
#
# The original command is kept as the fallback, so this still works if uwsm is
# not installed.
#
# NOTE: this file is NOT sourced automatically. fish only auto-loads conf.d/,
# and it sat at the top level of your fish config -- so unless something
# sourced it explicitly, it was inert. Move it to conf.d/ if you want it to
# actually run, and read the warning below first.
#
# Think before enabling: `exec` replaces the login shell. If Hyprland fails to
# start you are logged straight back out, with only ~/.cache/hyprland.log to
# say why. A display manager is the recoverable version of this.

if test -z "$DISPLAY" ;and test "$XDG_VTNR" -eq 1
    mkdir -p ~/.cache

    if type -q uwsm; and uwsm check may-start >/dev/null 2>&1
        exec uwsm start -S -F hyprland.desktop > ~/.cache/hyprland.log 2>&1
    else if type -q start-hyprland
        exec start-hyprland > ~/.cache/hyprland.log 2>&1
    else if type -q Hyprland
        exec Hyprland > ~/.cache/hyprland.log 2>&1
    end
end
