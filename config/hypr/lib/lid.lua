-- lib/lid.lua -- the built-in panel is never the last output.
--
-- On a docked laptop the lid switch reaches nothing. logind counts a second
-- connected display as a dock and HandleLidSwitchDocked defaults to ignore, so
-- shutting the lid leaves the built-in panel lit -- windows and all -- under a
-- closed lid. Disabling that output is the fix. Disabling it is also how you
-- lock yourself out of the session, which is what this module is really about.
--
-- What went wrong, measured 2026-09-10 from the journal of the session that had
-- to be rebooted at 16:41: with the lid shut and the panel disabled, the
-- external display is the ONLY enabled output. Coming back from s2idle its DP
-- link renegotiates and Hyprland loses that output for a moment, so
-- hl.get_monitors() -- which answers with *enabled* monitors only, verified
-- through `hyprctl repl` -- goes to zero. A compositor with no outputs has
-- nowhere to put the lock screen: the session is alive, it holds the keyboard,
-- and it paints nothing. The journal signs it twice, at the instant of the
-- resume: `XWAYLAND: mode -1x-1 is not available` from Hyprland, and
-- `gdk_monitor_set_scale: assertion 'scale > 0.' failed` from a GTK client
-- being handed a monitor with no geometry.
--
-- Nothing recovered it either, because the only two things that reconciled the
-- panel's state were a lid transition and a config reload. Waking on the
-- external keyboard is not a transition, so that wake produced no event at all:
-- every other resume in the journal is followed within seconds by a
-- pam_unix(login:account) line from noctalia's lock screen, and that one is
-- followed by nothing for thirteen minutes, until the dock was unplugged.
--
-- So the rule here is deliberately not "off when the lid is shut". It is
--
--     the panel is off only while the lid is shut AND something else is
--     actually driving a screen
--
-- and it is re-decided on every monitor event rather than on lid transitions
-- alone. Lose the external display -- to a resume, to a pulled cable, to the
-- monitor's own power saving -- and the panel comes back by itself. A lit panel
-- under a closed lid is a thing you fix by opening the lid. A session with no
-- outputs is a thing you can only reboot.
--
-- See docs/decisions/023-the-panel-is-never-the-last-output.md.

local M = {}

-- How long after a config reload to re-decide, in ms. Long enough for Hyprland
-- to have applied the monitor rules the reload just parsed, short enough that a
-- panel left lit under a shut lid is not something you have time to notice.
local SETTLE_MS = 500

-- Which ACPI lid button to read. Only one of these exists on any given machine
-- (LID0 here), and a machine with none is a machine with no lid.
local LID_BUTTONS = { "LID0", "LID", "LID1" }

--- The panel's own monitor spec, as handed to M.setup().
---@type table|nil
local panel

--- Set while an hl.monitor() call is in flight. Enabling or disabling an output
--- fires monitor.added / monitor.removed, which lands straight back here, and a
--- reconcile that re-decides from a half-applied state would call hl.monitor()
--- again -- recursion, until Hyprland's dispatch depth limit of 32 stops it.
---
--- This is a guard and NOT a record of what was applied. The panel's state is
--- read back from Hyprland every time (see monitor_enabled), because a cached
--- one can be wrong: anything that changes an output behind this module's back
--- leaves the cache describing a session that no longer exists, and a reconcile
--- that believes it then does nothing at all. Measured 2026-09-10 -- a probe
--- that enabled the panel directly left the cache saying "off" and the next
--- reconcile agreed with itself and skipped.
---@type boolean
local applying = false

--- The deferred reconcile's timer, kept in a module-level reference on purpose:
--- an hl.timer() handle that nothing holds is collected and never fires at all.
--- Measured 2026-09-11 -- the same call with the result discarded did nothing,
--- and assigning it to anything that outlives the call made it fire.
---@type userdata|nil
local settle_timer

---@param path string
---@return string|nil
local function slurp(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local text = f:read("a")
    f:close()
    return text
end

--- Is the lid shut? Asked of the kernel rather than tracked from the switch
--- binds, because this has to answer on a cold start too -- where the lid may
--- already be closed and no transition is ever coming.
---@return boolean
local function lid_shut()
    for _, button in ipairs(LID_BUTTONS) do
        local state = slurp("/proc/acpi/button/lid/" .. button .. "/state")
        if state then return state:match("closed") ~= nil end
    end

    -- No lid switch to read at all. Answer "open", which keeps the panel on.
    return false
end

--- Is `name` one of the outputs currently driving a screen? hl.get_monitors()
--- answers with enabled monitors only -- a disabled one is absent rather than
--- present with a flag, verified through `hyprctl repl` 2026-09-10 -- so
--- membership of that list IS the enabled state.
---@param name string
---@return boolean
local function monitor_enabled(name)
    for _, mon in ipairs(hl.get_monitors()) do
        if mon.name == name then return true end
    end

    return false
end

--- Is anything other than the panel actually driving a screen?
---
--- Asked of Hyprland, not of /sys/class/drm/*/status. The old form of this read
--- the kernel and so counted a connector that is merely *connected* -- which is
--- exactly the state the external display is in for the moment after a resume
--- when it has no mode set and shows nothing. "Connected" is not "a screen you
--- can see", and it was the wrong question.
---@return boolean
local function external_enabled()
    for _, mon in ipairs(hl.get_monitors()) do
        if mon.name ~= panel.output then return true end
    end

    return false
end

--- Re-decide whether the panel should be on, and act only if that is not
--- already what Hyprland is doing.
---
--- hl.monitor() applies at runtime -- from a bind callback and from an event
--- handler, both measured, the second on 2026-09-10 by arming a handler and
--- firing it with `hyprctl output create headless`. Two contexts where it does
--- not: `hyprctl keyword monitor` is refused outright under a Lua config
--- ("keyword can't work with non-legacy parsers"), and a bare `hyprctl repl`
--- call returns without applying, which is worth knowing before using the repl
--- to test any of this.
function M.reconcile()
    if not panel or applying then return end

    local want_off = lid_shut() and external_enabled()
    local is_off   = not monitor_enabled(panel.output)
    if want_off == is_off then return end

    -- pcall so a failing hl.monitor() cannot leave the guard stuck true, which
    -- would wedge every later reconcile -- the panel would then stay in
    -- whatever state it happened to be in, for the rest of the session.
    applying = true
    pcall(hl.monitor, want_off and { output = panel.output, disabled = true } or panel)
    applying = false
end

--- Force the panel back on, whatever the lid is doing. The escape hatch.
---
--- This does not pin the panel on: the next monitor event reconciles as usual
--- and, with the lid shut and an external display working, turns it off again.
--- That is deliberate rather than unfinished -- the state this exists for is
--- "nothing to look at", and in that state reconcile already agrees.
function M.panel_on()
    if not panel then return end

    applying = true
    pcall(hl.monitor, panel)
    applying = false
end

--- `spec` is the panel's ordinary monitor spec -- output, mode, position, scale.
---
--- Give it an explicit position rather than "auto": with auto, an output that
--- comes back after being disabled is placed after the one that stayed, so
--- opening the lid put the laptop panel to the RIGHT of the ultrawide. Measured
--- 2026-08-26.
---@param spec table
function M.setup(spec)
    if type(spec) ~= "table" or type(spec.output) ~= "string" then return end

    panel = {}
    for k, v in pairs(spec) do panel[k] = v end

    -- Not optional, and not decoration: re-applying a spec that merely omits
    -- `disabled` does NOT clear an earlier disable. The key has to be present
    -- and false. Measured 2026-08-26 -- eDP-1 stayed off until it was.
    panel.disabled = false

    -- The reason this module exists. Every one of these is a moment where the
    -- set of screens you can actually see changed, and any of them can be the
    -- one that would otherwise leave nothing enabled.
    hl.on("monitor.added", function() M.reconcile() end)
    hl.on("monitor.removed", function() M.reconcile() end)
    -- A geometry change with no add and no remove: an output that comes back
    -- from a resume with a different mode, or none, arrives as this.
    hl.on("monitor.layout_changed", function() M.reconcile() end)

    -- locked = true is what `bindl` means in hyprland.conf syntax: the bind has
    -- to fire with the lockscreen up, which is exactly when the lid is shut.
    --
    -- Both switch directions run the same reconcile. There is no such thing as
    -- "the lid closed, so turn the panel off" here -- closing the lid on an
    -- undocked laptop must not disable the only screen there is, and the rule
    -- at the top of this file already says so without a special case.
    hl.bind("switch:on:Lid Switch", function() M.reconcile() end,
        { locked = true, description = "Lid shut: reconcile the built-in panel" })
    hl.bind("switch:off:Lid Switch", function() M.reconcile() end,
        { locked = true, description = "Lid open: reconcile the built-in panel" })

    -- The escape hatch, for the state this module is meant to make impossible.
    -- locked, so it works with the lock screen up, and it needs no screen to
    -- press -- which is the whole point of having it.
    hl.bind(MOD .. " + CTRL + D", function() M.panel_on() end,
        { locked = true, description = "Force the built-in panel back on" })

    -- A switch bind fires on a transition only, so something has to cover
    -- logging in -- or reloading -- with the lid already shut. Three things do,
    -- and each covers a case the others miss:
    --
    --   * now, at parse time. On a cold start Hyprland has not enumerated any
    --     output yet, so external_enabled() is false and the panel comes up on:
    --     the safe direction, corrected a moment later by the first event.
    --   * hyprland.start, once the compositor has its outputs. This is the cold
    --     start's real answer, and it is the hook lib/colwidth.lua uses for the
    --     same reason.
    --   * a one-shot timer, which is the only one that covers a RELOAD.
    --
    -- The reload case is worth spelling out, because it is what a session was
    -- left wedged by on 2026-09-10. `hyprctl reload` destroys and recreates
    -- every event subscription -- by design, so callbacks cannot double up --
    -- and it re-applies the monitor rules at the same time. An output coming
    -- back as part of that reload therefore fires monitor.added while there is
    -- nothing subscribed to hear it, and the parse-time reconcile above has
    -- already run, against the monitor set as it was BEFORE the reload. Neither
    -- end of the reload sees the change. hyprland.start does not fire on a
    -- reload either, so without this timer the panel keeps whatever state it
    -- had -- which, coming back from an external display being re-enabled,
    -- means lit under a shut lid with the lock screen spread across it.
    hl.on("hyprland.start", function() M.reconcile() end)

    settle_timer = hl.timer(function() M.reconcile() end,
        { timeout = SETTLE_MS, type = "oneshot" })

    M.reconcile()
end

return M
