-- conf/autostart.lua
--
-- If you launch Hyprland through uwsm, prefer XDG autostart (~/.config/autostart)
-- for ordinary background apps -- they then get proper systemd scopes and
-- ordered shutdown. Keep this list to things that must exist before you can
-- use the session at all.

hl.on("hyprland.start", function()
    -- Portals and anything DBus-activated need the session env.
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")

    -- The cursor theme. conf/env.lua exports XCURSOR_THEME for the apps, but
    -- Hyprland resolves its own cursor at startup from the environment it was
    -- launched with -- which is the display manager's, not this file's. One
    -- setcursor call fixes the pointer you see over the desktop and over any
    -- window that does not draw its own.
    if CURSOR_THEME ~= "" then
        hl.exec_cmd(("hyprctl setcursor '%s' %d"):format(CURSOR_THEME, CURSOR_SIZE))
    end

    -- The shell: bar, launcher, control centre, notifications, lock screen.
    hl.exec_cmd("noctalia")
end)
