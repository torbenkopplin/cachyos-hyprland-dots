-- conf/autostart.lua
--
-- If you launch Hyprland through uwsm, prefer XDG autostart (~/.config/autostart)
-- for ordinary background apps -- they then get proper systemd scopes and
-- ordered shutdown. Keep this list to things that must exist before you can
-- use the session at all.

hl.on("hyprland.start", function()
    -- Portals and anything DBus-activated need the session env.
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")

    -- The shell: bar, launcher, control centre, notifications, lock screen.
    hl.exec_cmd("noctalia")
end)
