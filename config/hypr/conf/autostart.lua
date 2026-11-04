-- conf/autostart.lua
--
-- If you launch Hyprland through uwsm, prefer XDG autostart (~/.config/autostart)
-- for ordinary background apps -- they then get proper systemd scopes and
-- ordered shutdown. Keep this list to things that must exist before you can
-- use the session at all.

hl.on("hyprland.start", function()
    -- Portals and anything DBus-activated need the session env. So does the
    -- shell, which is why it is started in the same command, after the import
    -- has finished: two separate exec_cmds race. `;` and not `&&`: an import
    -- that fails on one variable is a degraded session, no shell is a dead one.
    --
    -- The shell: bar, launcher, control centre, notifications, lock screen. It
    -- runs as a user unit so a crash restarts it -- see
    -- config/systemd/user/noctalia.service.
    hl.exec_cmd("dbus-update-activation-environment --systemd --all; systemctl --user start noctalia.service")

    -- The cursor theme. conf/env.lua exports XCURSOR_THEME for the apps, but
    -- Hyprland resolves its own cursor at startup from the environment it was
    -- launched with -- which is the display manager's, not this file's. One
    -- setcursor call fixes the pointer you see over the desktop and over any
    -- window that does not draw its own.
    --
    -- GTK apps read neither: they take the theme from gsettings, which keeps
    -- whatever the last desktop set there until something sets it again.
    if CURSOR_THEME ~= "" then
        hl.exec_cmd(("hyprctl setcursor '%s' %d"):format(CURSOR_THEME, CURSOR_SIZE))
        hl.exec_cmd(("gsettings set org.gnome.desktop.interface cursor-theme '%s'; gsettings set org.gnome.desktop.interface cursor-size %d")
            :format(CURSOR_THEME, CURSOR_SIZE))
    end
end)
