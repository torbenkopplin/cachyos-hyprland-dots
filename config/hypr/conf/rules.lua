-- conf/rules.lua -- window and layer rules.
--
-- Rules here exist for exactly two reasons: keep dialogs from being shoved
-- onto the tape as full columns, and keep anything from interrupting you.

------------------------------------------------------------------------------
-- Don't let apps rearrange your layout
------------------------------------------------------------------------------

-- A scrolling tape is unforgiving about focus theft: a window that grabs focus
-- also scrolls the viewport away from whatever you were reading. Together with
-- misc.focus_on_activate = false in conf/input.lua, nothing gets to interrupt.
hl.window_rule({
    name  = "suppress-layout-grabs",
    match = { class = ".*" },
    suppress_event = "maximize activate activatefocus",
})

hl.window_rule({
    -- Known XWayland drag-and-drop fix; harmless otherwise.
    name  = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true,
              fullscreen = false, pin = false },
    no_focus = true,
})

------------------------------------------------------------------------------
-- Transient windows float instead of claiming a column
------------------------------------------------------------------------------

hl.window_rule({
    name  = "float-dialogs",
    match = { class = "^(org.kde.polkit-kde-authentication-agent-1|xdg-desktop-portal-gtk|nm-connection-editor|blueman-manager|pavucontrol|org.pulseaudio.pavucontrol)$" },
    float  = true,
    center = true,
})

hl.window_rule({
    name  = "float-modals",
    match = { title = "^(Open File|Open Folder|Save File|Save As|Choose Files|Select a File|Confirm)" },
    float  = true,
    center = true,
})

-- SUPER+SHIFT+Return launches the terminal under this class precisely so it
-- can be caught here. See TERMINAL_FLOAT in conf/options.lua.
hl.window_rule({
    name  = "float-scratch-terminal",
    match = { class = "^" .. TERMINAL_FLOAT_CLASS .. "$" },
    float  = true,
    size   = { 1000, 640 },
    center = true,
})

------------------------------------------------------------------------------
-- Floating windows stack the effect instead of sampling past it
------------------------------------------------------------------------------
--
-- There is no rule here, and that is the point of the comment.
--
-- `xray` decides whether a window's blur samples the WALLPAPER or whatever is
-- actually beneath it, and the obvious implementation was a window rule turning
-- it off for `float = true`. Hyprland 0.56 accepts that rule, reports no config
-- error, and ignores it: `xray` is a LAYER rule (HL.LayerRuleSpec in
-- /usr/share/hypr/stubs/hl.meta.lua lists it; HL.WindowRuleSpec does not).
-- Measured 2026-08-19, two probe windows with and without the rule saw
-- backdrops of 87.0 and 86.2 -- the same wallpaper, twice.
--
-- So it is off globally instead, in glass.conf's `blur_xray`. Nothing is lost
-- by that: tiled windows do not overlap, so what is beneath one of them IS the
-- wallpaper, and only floating windows see a difference. `noct-check
-- blur-stacks` measures that a floating window samples the window under it, and
-- `noct-check glass-visible` measures that a tiled one still samples the
-- wallpaper.

-- bin/noct-check spawns throwaway windows to measure things that only exist on
-- a real window: whether kitty picks up a new background_opacity on SIGUSR1,
-- whether Zen's generated stylesheet is actually winning against the
-- transparency mod. Floating and centred so running a check never rearranges
-- the tape you were working in. Matched on class only: a title rule was tried
-- first and never fired, because kitty sets its title after the window is
-- mapped and the rule is evaluated at map time. Anything that needs to be
-- caught here has to be launched under this class.
hl.window_rule({
    name  = "float-noct-probe",
    match = { class = "^noct-probe$" },
    float  = true,
    size   = { 900, 600 },
    center = true,
})

hl.window_rule({
    name  = "float-noctalia-settings",
    match = { class = "^dev\\.noctalia\\.Noctalia$" },
    float = true,
    size  = { 1080, 920 },
    center = true,
})

------------------------------------------------------------------------------
-- Column widths for specific apps
--
-- `scrolling_width` sets the column width a window claims when it first lands
-- on the tape, as a fraction of the monitor.
------------------------------------------------------------------------------

hl.window_rule({
    name  = "wide-browser",
    match = { class = "^(firefox|zen|chromium|google-chrome|brave-browser)$" },
    scrolling_width = 0.667,
})

hl.window_rule({
    name  = "narrow-terminal",
    match = { class = "^(kitty|foot|Alacritty|com\\.mitchellh\\.ghostty)$" },
    scrolling_width = 0.5,
})

------------------------------------------------------------------------------
-- Opting out of frosted glass
--
-- bin/noct-glass sets active_opacity for every window, so the frosted look is
-- universal by default -- including GTK and Qt apps, which have no
-- transparency of their own.
--
-- These are the windows where that is wrong. Anything whose job is to show you
-- accurate pixels should not have the wallpaper mixed into them: you cannot
-- judge a photo, grade a video or pick a colour through 10% of your desktop.
------------------------------------------------------------------------------

local OPAQUE_WINDOWS = {
    "^(mpv|vlc|imv|org%.gnome%.Loupe|qimgv)$",
    "^(gimp|krita|inkscape|darktable)$",
    "^(obs|com%.obsproject%.Studio)$",
    "^hyprpicker$",
}

for i, class in ipairs(OPAQUE_WINDOWS) do
    hl.window_rule({
        name    = "opaque-" .. i,
        match   = { class = class },
        opacity = "1.0 1.0", -- active, inactive; a table is rejected at parse time
    })
end

------------------------------------------------------------------------------
-- Don't idle-lock during meetings or playback
--
-- Three layers, because no single one of them covers the whole case:
--
--   1. Apps that ask. mpv, VLC and the browsers hold a Wayland idle inhibitor
--      while something is actually playing, and Hyprland stops sending idle
--      notifications for as long as one is held -- so whatever is counting
--      down (Noctalia, here; see config/noctalia/70-idle.toml) never gets to
--      the timeout. This is the layer that handles video in a browser tab,
--      and it needs no rule at all.
--   2. Anything fullscreen. A fullscreen window is being watched or presented
--      almost by definition, and "fullscreen" mode costs nothing the rest of
--      the time.
--   3. A focused media player, even windowed. A player that is paused and
--      focused will hold the screen awake under this rule, which is the
--      trade worth making: the alternative is the screen locking while you
--      are looking straight at it.
--
-- If something still locks under you, SUPER+CTRL+P -> Caffeine is the manual
-- override, and it is also the thing to reach for when what is playing is
-- audio in a terminal.
------------------------------------------------------------------------------

hl.window_rule({
    name  = "inhibit-idle-when-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})

-- Matched after the rule above, so for these classes it is what applies.
hl.window_rule({
    name  = "inhibit-idle-media-players",
    match = { class = "^(mpv|vlc|io\\.github\\.celluloid\\.Celluloid|org\\.kde\\.haruna)$" },
    idle_inhibit = "focus",
})

------------------------------------------------------------------------------
-- Noctalia layer rules
--
-- Blur its surfaces, and disable Hyprland's own layer animations for them so
-- they don't fight Noctalia's slide animation -- which matters here because
-- the bar is animated in and out constantly by lib/bar.lua.
------------------------------------------------------------------------------

hl.layer_rule({
    name  = "noctalia-surfaces",
    match = { namespace = "^noctalia-(bar-.+|notification|dock|panel|attached-panel|osd|window-switcher)$" },
    no_anim      = true,
    blur         = true,
    blur_popups  = true,
    ignore_alpha = 0.5,
})
