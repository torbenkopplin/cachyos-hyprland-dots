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
-- Frosted glass for apps that cannot do it themselves
--
-- kitty draws its own translucent background, so the compositor blurs behind
-- it and the text stays fully opaque. That is the good version of this effect
-- and it needs no rule.
--
-- GTK and Qt apps paint an opaque background with no way to ask them not to.
-- The only lever left is compositor opacity, which fades the *whole surface* --
-- text included. That is why this list is empty by default rather than
-- "every app": on a work machine, slightly translucent body text is a bad
-- trade for a nicer-looking window.
--
-- Add classes here if you want it anyway. Good candidates are windows you
-- look at rather than read: a music player, an image viewer, a calculator.
------------------------------------------------------------------------------

local GLASS_WINDOWS = {
    -- "^org%.gnome%.Calculator$",
    -- "^imv$",
}

for _, class in ipairs(GLASS_WINDOWS) do
    hl.window_rule({
        name    = "glass-" .. class,
        match   = { class = class },
        opacity = { 0.90, 0.82 }, -- active, inactive
    })
end

------------------------------------------------------------------------------
-- Don't idle-lock during meetings or playback
------------------------------------------------------------------------------

-- "fullscreen" mode inhibits idle only while the window is actually
-- fullscreen, so this is safe to apply everywhere: video calls and playback
-- hold the screen awake, ordinary windows don't.
hl.window_rule({
    name  = "inhibit-idle-when-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
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
