-- conf/env.lua -- environment variables set for the Hyprland session.
--
-- NOTE: if you boot via uwsm, prefer ~/.config/uwsm/env for anything that also
-- needs to be visible to systemd user units. Variables set here are inherited
-- by apps Hyprland spawns, which covers the normal case.

hl.env("XCURSOR_SIZE",    "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Qt/GTK look consistent with the rest of the shell.
hl.env("QT_QPA_PLATFORM",                       "wayland;xcb")
hl.env("QT_QPA_PLATFORMTHEME",                  "qt6ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION",   "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR",           "1")

-- Prefer native Wayland where the toolkit supports it.
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Terminal apps launched from the Noctalia launcher (.desktop Terminal=true)
-- use $TERMINAL. Do NOT append -e here; Noctalia adds the exec flag itself.
hl.env("TERMINAL", TERMINAL)

-- yazi, git and anything else that shells out to an editor read these.
hl.env("EDITOR", "nvim")
hl.env("VISUAL", "nvim")

-- Carried over from ~/repos/dots.
hl.env("MANPAGER", "bat -plman")
