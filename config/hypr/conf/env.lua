-- conf/env.lua -- environment variables set for the Hyprland session.
--
-- NOTE: this file sets variables for apps Hyprland spawns, which covers the
-- normal case. It cannot set anything Hyprland itself needs at startup, and it
-- is invisible to systemd user units. This session boots via uwsm, so those go
-- in config/uwsm/env instead -- PATH in particular, which is what the launcher
-- providers and the noct-glass binds are found through.

-- Cursor. XCURSOR_* is what GTK, Qt and XWayland read; HYPRCURSOR_* is
-- Hyprland's own vector cursor format, which falls back to the XCursor theme
-- of the same name when there is no hyprcursor build of it -- which is the
-- case for Bibata, so both names point at the same theme on purpose.
--
-- Environment alone is not enough: Hyprland caches the cursor it started with,
-- so conf/autostart.lua also issues `hyprctl setcursor` once the session is up.
hl.env("XCURSOR_THEME",    CURSOR_THEME)
hl.env("HYPRCURSOR_THEME", CURSOR_THEME)
hl.env("XCURSOR_SIZE",    tostring(CURSOR_SIZE))
hl.env("HYPRCURSOR_SIZE", tostring(CURSOR_SIZE))

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

-- The launcher providers open one of these when something has to be typed that
-- Noctalia cannot prompt for -- a Wi-Fi passphrase (bin/noct-common.sh's
-- in_terminal). It is exported so that prompt arrives as the floating, centred
-- scratch window conf/rules.lua already describes, rather than as a new column
-- shoved onto the tape. Note that both of these are command *lines* and not
-- binary names: anything reading them has to split on whitespace first.
hl.env("TERMINAL_FLOAT", TERMINAL_FLOAT)

-- yazi, git and anything else that shells out to an editor read these.
hl.env("EDITOR", "nvim")
hl.env("VISUAL", "nvim")

-- Carried over from ~/repos/dots.
hl.env("MANPAGER", "bat -plman")
