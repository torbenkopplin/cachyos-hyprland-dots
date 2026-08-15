-- conf/binds.lua -- every keybind in the session.
--
-- Layout of the keymap:
--
--   SUPER              + hjkl   move focus       (niri/PaperWM edge handoff)
--   SUPER + CTRL       + hjkl   move the window, same handoff
--   SUPER + SHIFT      + hl     reorder columns on the tape
--   SUPER + CTRL+SHIFT + hl     force the window onto the next monitor
--
--   SUPER + <n>                 workspace n on THIS monitor
--   SUPER + SHIFT + <n>         send window to workspace n on this monitor
--
--   tap SUPER                   launcher
--   SUPER + CTRL + <letter>     system control, straight into the launcher
--
-- Everything reachable without leaving the home row where it plausibly can be.

local nav      = require("lib.nav")
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

-- Tap SUPER on its own. See lib/supertap.lua for why this isn't a release bind.
if SUPER_TAP_ENABLED then
    supertap.setup(NOCT .. "panel-toggle launcher", SUPER_TAP_MS)
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

hl.bind(mod .. " + H", function() nav.focus_horizontal("l") end,
    { repeating = true, description = "Focus left / previous monitor" })
hl.bind(mod .. " + L", function() nav.focus_horizontal("r") end,
    { repeating = true, description = "Focus right / next monitor" })
hl.bind(mod .. " + K", function() nav.focus_vertical("u") end,
    { repeating = true, description = "Focus up / previous workspace" })
hl.bind(mod .. " + J", function() nav.focus_vertical("d") end,
    { repeating = true, description = "Focus down / next workspace" })

-- Arrows do the same thing, for the times your hand is already on the mouse.
hl.bind(mod .. " + left",  function() nav.focus_horizontal("l") end, { repeating = true })
hl.bind(mod .. " + right", function() nav.focus_horizontal("r") end, { repeating = true })
hl.bind(mod .. " + up",    function() nav.focus_vertical("u") end,   { repeating = true })
hl.bind(mod .. " + down",  function() nav.focus_vertical("d") end,   { repeating = true })

------------------------------------------------------------------------------
-- Move the focused window, with the same handoff
------------------------------------------------------------------------------

hl.bind(mod .. " + CTRL + H", function() nav.move_horizontal("l") end,
    { repeating = true, description = "Move window left / to previous monitor" })
hl.bind(mod .. " + CTRL + L", function() nav.move_horizontal("r") end,
    { repeating = true, description = "Move window right / to next monitor" })
hl.bind(mod .. " + CTRL + K", function() nav.move_vertical("u") end,
    { repeating = true, description = "Move window up / to previous workspace" })
hl.bind(mod .. " + CTRL + J", function() nav.move_vertical("d") end,
    { repeating = true, description = "Move window down / to next workspace" })

-- Unconditional monitor hop, for when you don't want to think about edges.
hl.bind(mod .. " + CTRL + SHIFT + H", hl.dsp.window.move({ monitor = "l", follow = true }),
    { description = "Send window to the monitor on the left" })
hl.bind(mod .. " + CTRL + SHIFT + L", hl.dsp.window.move({ monitor = "r", follow = true }),
    { description = "Send window to the monitor on the right" })

------------------------------------------------------------------------------
-- Arranging the tape
------------------------------------------------------------------------------

-- Reorder whole columns without changing which window is focused.
hl.bind(mod .. " + SHIFT + H", hl.dsp.layout("swapcol l"), { description = "Swap column left" })
hl.bind(mod .. " + SHIFT + L", hl.dsp.layout("swapcol r"), { description = "Swap column right" })

-- Stack / unstack windows within a column. This is PaperWM's core gesture:
-- pull the neighbouring window into my column, or push mine back out.
hl.bind(mod .. " + comma",  hl.dsp.layout("consume"), { description = "Pull window into this column" })
hl.bind(mod .. " + period", hl.dsp.layout("expel"),   { description = "Push window out to its own column" })
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

-- Cycle the preset widths from scrolling.explicit_column_widths.
hl.bind(mod .. " + W",         hl.dsp.layout("colresize +conf"), { description = "Next column width" })
hl.bind(mod .. " + SHIFT + W", hl.dsp.layout("colresize -conf"), { description = "Previous column width" })

-- Fine adjustment.
hl.bind(mod .. " + minus", hl.dsp.layout("colresize -0.05"), { repeating = true, description = "Narrow column" })
hl.bind(mod .. " + equal", hl.dsp.layout("colresize +0.05"), { repeating = true, description = "Widen column" })

-- Take all the free space on the monitor / share it out evenly.
hl.bind(mod .. " + SHIFT + F", hl.dsp.layout("fit expand"),  { description = "Expand into free space" })
hl.bind(mod .. " + SHIFT + E", hl.dsp.layout("fit visible"), { description = "Even out visible columns" })

-- A resize mode, so you can adjust with hjkl instead of holding a chord.
hl.bind(mod .. " + R", hl.dsp.submap("resize"), { description = "Resize mode" })
hl.define_submap("resize", function()
    hl.bind("h", hl.dsp.layout("colresize -0.02"), { repeating = true })
    hl.bind("l", hl.dsp.layout("colresize +0.02"), { repeating = true })
    hl.bind("k", hl.dsp.window.resize({ x = 0, y = -40, relative = true }), { repeating = true })
    hl.bind("j", hl.dsp.window.resize({ x = 0, y =  40, relative = true }), { repeating = true })

    hl.bind("w", hl.dsp.layout("colresize +conf"))

    -- Always leave yourself a way out of a submap.
    hl.bind("escape", hl.dsp.submap("reset"))
    hl.bind("Return", hl.dsp.submap("reset"))
end)

------------------------------------------------------------------------------
-- Window state
------------------------------------------------------------------------------

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
-- `m~n` is "the n-th workspace on the monitor I'm looking at", so these mean
-- the same thing on every screen.
------------------------------------------------------------------------------

for n = 1, WORKSPACES_PER_MONITOR do
    hl.bind(mod .. " + " .. n, hl.dsp.focus({ workspace = "m~" .. n }),
        { description = "Workspace " .. n })
    hl.bind(mod .. " + SHIFT + " .. n, hl.dsp.window.move({ workspace = "m~" .. n, follow = true }),
        { description = "Send window to workspace " .. n })
end

hl.bind(mod .. " + grave", hl.dsp.focus({ workspace = "previous_per_monitor" }),
    { description = "Last workspace" })

-- Scratchpad.
hl.bind(mod .. " + S",         hl.dsp.workspace.toggle_special("scratch"), { description = "Scratchpad" })
hl.bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:scratch" }),
    { description = "Send to scratchpad" })

------------------------------------------------------------------------------
-- Applications
------------------------------------------------------------------------------

hl.bind(mod .. " + Return",         hl.dsp.exec_cmd(run .. TERMINAL), { description = "Terminal" })
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
hl.bind(mod .. " + O", hl.dsp.exec_cmd(NOCT .. "settings-toggle"), { description = "Shell settings" })

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
hl.bind(mod .. " + SHIFT + Escape", hl.dsp.exec_cmd(NOCT .. "panel-toggle session"), { description = "Session menu" })

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

hl.bind("Print",         hl.dsp.exec_cmd(NOCT .. "screenshot-region"),     { description = "Screenshot region" })
hl.bind(mod .. " + Print", hl.dsp.exec_cmd(NOCT .. "screenshot-fullscreen"), { description = "Screenshot screen" })
hl.bind(mod .. " + C",     hl.dsp.exec_cmd("hyprpicker -a -n"),              { description = "Pick a colour" })

------------------------------------------------------------------------------
-- Mouse
------------------------------------------------------------------------------

hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Scroll the tape with SUPER+wheel, walk workspaces with SUPER+SHIFT+wheel.
hl.bind(mod .. " + mouse_down", hl.dsp.layout("move +col"))
hl.bind(mod .. " + mouse_up",   hl.dsp.layout("move -col"))
hl.bind(mod .. " + SHIFT + mouse_down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + SHIFT + mouse_up",   hl.dsp.focus({ workspace = "m-1" }))
