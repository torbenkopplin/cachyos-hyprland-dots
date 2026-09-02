-- conf/binds.lua -- every keybind in the session.
--
-- Layout of the keymap:
--
--   SUPER              + hjkl   move focus       (niri/PaperWM edge handoff)
--   SUPER + SHIFT      + hjkl   move the window, same handoff
--   SUPER + CTRL       + hjkl   move the whole column: H/L reorder it along the
--                               tape and hand it to the next monitor at the
--                               end, J/K send it to the workspace above/below
--   SUPER + CTRL+SHIFT + hjkl   force the window onto another monitor
--
--   SUPER + <n>                 workspace n on THIS monitor
--   SUPER + SHIFT + <n>         send window to workspace n on this monitor
--
--   tap SUPER                   launcher
--   SUPER + CTRL + <letter>     system control, straight into the launcher
--
-- SHIFT means "bring the window with you" everywhere: with a direction, with a
-- number key, with the scratchpad. It used to mean that only on the number
-- keys, with CTRL doing it for directions -- the two are swapped now.
--
-- Every directional bind is on hjkl AND on the arrow keys. They are the same
-- bind twice, so nothing has to be remembered twice; the arrows are what you
-- reach for when one hand is on the mouse, or before hjkl is muscle memory.
-- The one exception is the SUPER+CTRL+<letter> system-control block, which is
-- a mnemonic list rather than a direction.

local nav      = require("lib.nav")
local bands    = require("lib.ws")
local bar      = require("lib.bar")
local supertap = require("lib.supertap")

local mod = MOD
local run = LAUNCH_PREFIX

-- Must run before the SUPER+B bind below, which calls into what it installs.
if BAR_FOLLOWS_PANELS then
    bar.setup(NOCT)
end

------------------------------------------------------------------------------
-- Launcher
------------------------------------------------------------------------------

-- Tap SUPER on its own to open the launcher.
--
-- The modmask has to name the mod being pressed ("SUPER + SUPER_L", not just
-- "SUPER_L"), which is what the wiki means by "the TARGET modmask". Carried
-- over from ~/repos/dots, where it has been in use -- with `release` as a
-- boolean rather than the string "true"; a string is truthy in Lua so both
-- work, but the boolean is what the API documents.
--
-- lib/supertap.lua is the fallback if this ever fires after ordinary SUPER
-- chords; flip SUPER_TAP_ENABLED in conf/options.lua.
if SUPER_TAP_ENABLED then
    supertap.setup(NOCT .. "panel-toggle launcher", SUPER_TAP_MS)
else
    hl.bind(mod .. " + SUPER_L", hl.dsp.exec_cmd(NOCT .. "panel-toggle launcher"),
        { release = true, description = "Launcher (tap SUPER)" })
end

-- Kept as a fallback: if the tap detector ever misbehaves you are not locked
-- out of your own launcher.
hl.bind(mod .. " + Space", hl.dsp.exec_cmd(NOCT .. "panel-toggle launcher"),
    { description = "Launcher" })

------------------------------------------------------------------------------
-- Focus -- niri / PaperWM semantics
--
-- J/K walk the current column, then continue into the workspace below/above.
-- H/L walk the tape of columns, then continue onto the next monitor.
------------------------------------------------------------------------------

-- bind_dir <chord prefix> <table of h/j/k/l -> action> <table of descriptions>
--
-- Binds a directional set twice, once on hjkl and once on the arrows, from one
-- description. Writing them out separately is how the two drift apart -- the
-- arrows had no window-moving half at all before this.
local ARROW = { h = "left", l = "right", k = "up", j = "down" }

local function bind_dir(prefix, actions, descriptions)
    for key, action in pairs(actions) do
        local opts = { repeating = true, description = descriptions[key] }
        hl.bind(prefix .. " + " .. key:upper(), action, opts)
        hl.bind(prefix .. " + " .. ARROW[key], action, { repeating = true })
    end
end

bind_dir(mod, {
    h = function() nav.focus_horizontal("l") end,
    l = function() nav.focus_horizontal("r") end,
    k = function() nav.focus_vertical("u") end,
    j = function() nav.focus_vertical("d") end,
}, {
    h = "Focus left / previous monitor",
    l = "Focus right / next monitor",
    k = "Focus up / previous workspace",
    j = "Focus down / next workspace",
})

------------------------------------------------------------------------------
-- Move the focused window, with the same handoff
------------------------------------------------------------------------------

bind_dir(mod .. " + SHIFT", {
    h = function() nav.move_horizontal("l") end,
    l = function() nav.move_horizontal("r") end,
    k = function() nav.move_vertical("u") end,
    j = function() nav.move_vertical("d") end,
}, {
    h = "Move window left / to previous monitor",
    l = "Move window right / to next monitor",
    k = "Move window up / to previous workspace",
    j = "Move window down / to next workspace",
})

-- Unconditional monitor hop, for when you don't want to think about edges.
--
-- All four directions, not just left/right: monitors are not always side by
-- side, and a bind that only exists on one axis is a bind that does nothing on
-- a vertically stacked desk. nav.monitor_hop tries the direction first and
-- falls back to "the other monitor" when there are exactly two, so every one of
-- these keys does something on a two-monitor setup however it is arranged.
bind_dir(mod .. " + CTRL + SHIFT", {
    h = function() nav.monitor_hop("l") end,
    l = function() nav.monitor_hop("r") end,
    k = function() nav.monitor_hop("u") end,
    j = function() nav.monitor_hop("d") end,
}, {
    h = "Send window to the monitor on the left",
    l = "Send window to the monitor on the right",
    k = "Send window to the monitor above",
    j = "Send window to the monitor below",
})

------------------------------------------------------------------------------
-- Arranging the tape
------------------------------------------------------------------------------

-- Whole columns, on the same four keys, and on the same axes as everything
-- else: H/L reorder the column along the tape and, once it is at either end,
-- hand the whole column to the next monitor -- the same handoff focus and a
-- single window make. J/K are the workspace axis. Focus goes with the column,
-- so this is "take this stack of windows somewhere else"; SHIFT is the same
-- gesture for one window.
bind_dir(mod .. " + CTRL", {
    h = function() nav.column_horizontal("l") end,
    l = function() nav.column_horizontal("r") end,
    k = function() nav.column_vertical("u") end,
    j = function() nav.column_vertical("d") end,
}, {
    h = "Swap column left / to the monitor on the left",
    l = "Swap column right / to the monitor on the right",
    k = "Send column to previous workspace",
    j = "Send column to next workspace",
})

-- Stack / unstack windows within a column. This is PaperWM's core gesture:
-- pull the neighbouring window into my column, or push mine back out.
-- O/I from ~/repos/dots.
hl.bind(mod .. " + O", hl.dsp.layout("consume"), { description = "Pull window into this column" })
hl.bind(mod .. " + I", hl.dsp.layout("expel"),   { description = "Push window out to its own column" })
hl.bind(mod .. " + SHIFT + period", hl.dsp.layout("promote"),
    { description = "Promote window to a new column" })

-- Scroll the viewport without moving focus.
hl.bind(mod .. " + bracketleft",  hl.dsp.layout("move -col"), { repeating = true, description = "Scroll tape left" })
hl.bind(mod .. " + bracketright", hl.dsp.layout("move +col"), { repeating = true, description = "Scroll tape right" })
hl.bind(mod .. " + Z", hl.dsp.layout("fit_into_view"), { description = "Bring focused column into view" })

-- Freeze the viewport: focus still moves, the tape stays put. Useful when you
-- are copying between two columns and don't want the world sliding around.
hl.bind(mod .. " + SHIFT + Z", hl.dsp.layout("inhibit_scroll"),
    { description = "Toggle tape scroll lock" })

------------------------------------------------------------------------------
-- Sizing
------------------------------------------------------------------------------

-- Cycle the six preset widths from scrolling.explicit_column_widths.
-- PLUS/MINUS as in ~/repos/dots.
hl.bind(mod .. " + plus",  hl.dsp.layout("colresize +conf"), { description = "Next column width" })
hl.bind(mod .. " + minus", hl.dsp.layout("colresize -conf"), { description = "Previous column width" })

-- Fine adjustment.
hl.bind(mod .. " + equal",         hl.dsp.layout("colresize +0.05"), { repeating = true, description = "Widen column" })
hl.bind(mod .. " + SHIFT + minus", hl.dsp.layout("colresize -0.05"), { repeating = true, description = "Narrow column" })

-- Take all the free space on the monitor / share it out evenly.
hl.bind(mod .. " + SHIFT + F", hl.dsp.layout("fit expand"),  { description = "Expand into free space" })
hl.bind(mod .. " + SHIFT + E", hl.dsp.layout("fit visible"), { description = "Even out visible columns" })

-- A resize mode, so you can adjust with hjkl instead of holding a chord.
hl.bind(mod .. " + R", hl.dsp.submap("resize"), { description = "Resize mode" })
hl.define_submap("resize", function()
    -- Arrows alongside hjkl here too, so the submap is not the one place where
    -- the habit stops working.
    local narrower = hl.dsp.layout("colresize -0.02")
    local wider    = hl.dsp.layout("colresize +0.02")
    local shorter  = hl.dsp.window.resize({ x = 0, y = -40, relative = true })
    local taller   = hl.dsp.window.resize({ x = 0, y =  40, relative = true })

    hl.bind("h", narrower, { repeating = true })
    hl.bind("l", wider,    { repeating = true })
    hl.bind("k", shorter,  { repeating = true })
    hl.bind("j", taller,   { repeating = true })

    hl.bind("left",  narrower, { repeating = true })
    hl.bind("right", wider,    { repeating = true })
    hl.bind("up",    shorter,  { repeating = true })
    hl.bind("down",  taller,   { repeating = true })

    hl.bind("w", hl.dsp.layout("colresize +conf"))

    -- Always leave yourself a way out of a submap.
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)

------------------------------------------------------------------------------
-- Window state
------------------------------------------------------------------------------

-- BACKSPACE from ~/repos/dots; Q kept as an alias.
hl.bind(mod .. " + BackSpace", hl.dsp.window.close(), { description = "Close window" })
hl.bind(mod .. " + Q",         hl.dsp.window.close(), { description = "Close window" })
hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.kill(),  { description = "Kill window" })

hl.bind(mod .. " + F", hl.dsp.window.fullscreen(), { description = "Fullscreen" })
hl.bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = "maximized" }), { description = "Maximize" })
hl.bind(mod .. " + V", hl.dsp.window.float({ action = "toggle" }), { description = "Toggle floating" })
hl.bind(mod .. " + P", hl.dsp.window.pin(), { description = "Pin above workspaces" })
hl.bind(mod .. " + G", hl.dsp.group.toggle(), { description = "Toggle tab group" })
hl.bind(mod .. " + Tab", hl.dsp.exec_cmd(NOCT .. "window-switcher"), { description = "Window switcher" })

------------------------------------------------------------------------------
-- Workspaces
--
-- Each key means "the n-th workspace of the monitor I am looking at", which is
-- lib/ws.lua's job: the ids themselves are per-monitor bands (1-10, 11-20, ...)
-- and there is no workspace selector that expresses this correctly.
------------------------------------------------------------------------------

-- One key per workspace in the band: 1..9 then 0 for the tenth.
for n = 1, WORKSPACE_BAND do
    local key = n % 10
    hl.bind(mod .. " + " .. key, function() bands.switch(n) end,
        { description = "Workspace " .. n })
    hl.bind(mod .. " + SHIFT + " .. key, function() bands.move_to(n) end,
        { description = "Send window to workspace " .. n })
end

hl.bind(mod .. " + grave", hl.dsp.focus({ workspace = "previous_per_monitor" }),
    { description = "Last workspace" })

-- Scratchpad.
--
-- SUPER+ALT+S is the same bind as SUPER+SHIFT+S, and it is here because of one
-- keyboard: the MX Keys screenshot key sends SUPER+SHIFT+S in firmware, and
-- input/keyd/mx-keys.conf turns that chord into Print for that keyboard only.
-- So on the MX Keys the SHIFT form is a screenshot and this is how a window
-- reaches the scratchpad; on the laptop's own keyboard both work. See
-- docs/decisions/020-the-print-key-is-remapped-below-hyprland.md.
hl.bind(mod .. " + S",         hl.dsp.workspace.toggle_special("magic"), { description = "Scratchpad" })
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }),
    { description = "Send to scratchpad" })
hl.bind(mod .. " + ALT + S",   hl.dsp.window.move({ workspace = "special:magic" }),
    { description = "Send to scratchpad" })

------------------------------------------------------------------------------
-- Applications
------------------------------------------------------------------------------

-- SUPER+T is the one from ~/repos/dots; Return is kept as an alias so both
-- habits work.
hl.bind(mod .. " + T",      hl.dsp.exec_cmd(run .. TERMINAL), { description = "Terminal" })
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(run .. TERMINAL), { description = "Terminal" })
-- Floats and sizes itself via the scratchterm window rule in conf/rules.lua.
hl.bind(mod .. " + SHIFT + Return", hl.dsp.exec_cmd(run .. TERMINAL_FLOAT),
    { description = "Floating terminal" })
hl.bind(mod .. " + E",         hl.dsp.exec_cmd(run .. FILE_MANAGER), { description = "File manager" })
hl.bind(mod .. " + SHIFT + B", hl.dsp.exec_cmd(run .. BROWSER),      { description = "Browser" })

------------------------------------------------------------------------------
-- Shell surfaces
------------------------------------------------------------------------------

hl.bind(mod .. " + A", hl.dsp.exec_cmd(NOCT .. "panel-toggle control-center"), { description = "Control centre" })
hl.bind(mod .. " + N", hl.dsp.exec_cmd(NOCT .. "panel-toggle control-center notifications"), { description = "Notifications" })
hl.bind(mod .. " + X", hl.dsp.exec_cmd(NOCT .. "panel-toggle clipboard"), { description = "Clipboard history" })
-- SUPER+W was wallpaper in ~/repos/dots (a script); here it is Noctalia's panel.
hl.bind(mod .. " + W", hl.dsp.exec_cmd(NOCT .. "panel-toggle wallpaper"), { description = "Wallpaper" })
-- Browse Wallhaven without leaving the shell, for when the local folders have
-- nothing you want. Needs the noctalia/wallhaven plugin (60-wallpaper.toml).
hl.bind(mod .. " + SHIFT + W", hl.dsp.exec_cmd(NOCT .. "panel-toggle noctalia/wallhaven:browser"),
    { description = "Browse Wallhaven" })
-- Moved off O, which is consume now. comma is also what Noctalia's own docs use.
hl.bind(mod .. " + comma", hl.dsp.exec_cmd(NOCT .. "settings-toggle"), { description = "Shell settings" })

-- Step the frosted-glass level: opaque -> light -> default -> heavy. Overrides
-- the per-scheme level until you next change scheme. Applies to new terminal
-- windows; see bin/noct-glass.
hl.bind(mod .. " + SHIFT + G", hl.dsp.exec_cmd("noct-glass cycle"),
    { description = "Cycle frosted glass" })

-- Pin the bar on screen instead of letting it follow panels. See lib/bar.lua.
-- With BAR_FOLLOWS_PANELS off, lib/bar.lua is never set up, so fall back to a
-- plain toggle rather than leaving the key dead.
hl.bind(mod .. " + B", function()
    if bar.toggle_pin then
        bar.toggle_pin()
    else
        hl.exec_cmd(NOCT .. "bar-toggle")
    end
end, { description = "Pin / unpin the bar" })

-- SUPER+L is focus-right, so locking moves out of the way.
hl.bind(mod .. " + CTRL + Escape", hl.dsp.exec_cmd(NOCT .. "session lock"), { description = "Lock" })
hl.bind(mod .. " + Escape", hl.dsp.exec_cmd(NOCT .. "panel-toggle session"), { description = "Session menu" })

------------------------------------------------------------------------------
-- System control, from the keyboard, through the launcher
--
-- Each of these opens the launcher already filtered to one provider, so you
-- land in a list and pick with j/k + Enter. See config/noctalia/20-launcher.toml
-- and the bin/noct-* scripts behind them.
------------------------------------------------------------------------------

local function provider(prefix)
    return hl.dsp.exec_cmd(NOCT .. 'panel-toggle launcher "' .. prefix .. ' "')
end

hl.bind(mod .. " + CTRL + O", provider("/aout"),  { description = "Audio output device" })
hl.bind(mod .. " + CTRL + I", provider("/ain"),   { description = "Audio input device" })
hl.bind(mod .. " + CTRL + B", provider("/bt"),    { description = "Bluetooth devices" })
hl.bind(mod .. " + CTRL + N", provider("/net"),   { description = "Networks" })
hl.bind(mod .. " + CTRL + P", provider("/power"), { description = "Power profile" })
hl.bind(mod .. " + CTRL + T", provider("/theme"), { description = "Colour scheme" })

------------------------------------------------------------------------------
-- Hardware keys
------------------------------------------------------------------------------

hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd(NOCT .. "volume-up"),       { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd(NOCT .. "volume-down"),     { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd(NOCT .. "volume-mute"),     { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd(NOCT .. "mic-mute"),        { locked = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd(NOCT .. "brightness-up"),   { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(NOCT .. "brightness-down"), { locked = true, repeating = true })

hl.bind("XF86AudioPlay",  hl.dsp.exec_cmd(NOCT .. "media toggle"),   { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd(NOCT .. "media toggle"),   { locked = true })
hl.bind("XF86AudioNext",  hl.dsp.exec_cmd(NOCT .. "media next"),     { locked = true })
hl.bind("XF86AudioPrev",  hl.dsp.exec_cmd(NOCT .. "media previous"), { locked = true })

------------------------------------------------------------------------------
-- Screenshots
------------------------------------------------------------------------------

-- CTRL+Print is the same bind as SUPER+Print, and it is here for the MX Keys.
-- That keyboard's screenshot key sends SUPER+SHIFT+S in firmware, so SUPER is
-- one of the keycodes the key itself presses: input/keyd/mx-keys.conf strips it
-- along with SHIFT and there is no way to hold a *second* SUPER on top. CTRL is
-- not part of that layer and survives it -- measured -- so CTRL is how the
-- fullscreen half of the pair is reachable from this keyboard at all.
hl.bind("Print",           hl.dsp.exec_cmd(NOCT .. "screenshot-region"),     { description = "Screenshot region" })
hl.bind(mod .. " + Print", hl.dsp.exec_cmd(NOCT .. "screenshot-fullscreen"), { description = "Screenshot screen" })
hl.bind("CTRL + Print",    hl.dsp.exec_cmd(NOCT .. "screenshot-fullscreen"), { description = "Screenshot screen" })
hl.bind(mod .. " + C",     hl.dsp.exec_cmd("hyprpicker -a -n"),              { description = "Pick a colour" })

------------------------------------------------------------------------------
-- Mouse
------------------------------------------------------------------------------

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Scroll the tape with SUPER+wheel, walk workspaces with SUPER+SHIFT+wheel.
hl.bind(mod .. " + mouse_down", hl.dsp.layout("move +col"))
hl.bind(mod .. " + mouse_up",   hl.dsp.layout("move -col"))
hl.bind(mod .. " + SHIFT + mouse_down", function() bands.step_focus("d") end)
hl.bind(mod .. " + SHIFT + mouse_up",   function() bands.step_focus("u") end)
