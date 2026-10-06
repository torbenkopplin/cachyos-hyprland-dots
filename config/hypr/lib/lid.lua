-- lib/lid.lua -- the built-in panel is never the last output.
--
--     The panel is off only while the lid is shut AND something else is
--     actually driving a screen.
--
-- Re-decided on every monitor event, not on lid transitions alone: the case
-- that cost a reboot -- a resume with the lid already shut, the external
-- display gone for a moment, and Hyprland left with zero enabled outputs --
-- produces no lid event by definition.
--
-- The asymmetry is deliberate. A lit panel under a closed lid is a thing you fix
-- by opening the lid. A session with no outputs is a thing you can only reboot.
--
-- docs/decisions/023-the-panel-is-never-the-last-output.md is the decision: the
-- journal that settled it, every upstream fact this module leans on, and why the
-- obvious simpler forms are all wrong. Read it before changing anything here.

local M = {}

-- How long after a config reload to re-decide, in ms. Long enough for Hyprland
-- to have applied the monitor rules the reload just parsed, short enough that a
-- panel left lit under a shut lid is not something you have time to notice.
local SETTLE_MS = 500

-- How long the external display has to stay up, with no monitor event at all,
-- before the panel is turned off, in ms. Turning it ON never waits. A DP link
-- coming back from s2idle can drop and return dozens of times in a few seconds,
-- and switching the panel on every swing doubled the output churn every client
-- has to swallow. Decision 023, "Off waits; on never does".
local OFF_HOLD_MS = 3000

-- Which ACPI lid button to read. Only one of these exists on any given machine
-- (LID0 here), and a machine with none is a machine with no lid.
local LID_BUTTONS = { "LID0", "LID", "LID1" }

--- The panel's own monitor spec, as handed to M.setup().
---@type table|nil
local panel

--- Set while an hl.monitor() call is in flight. Enabling or disabling an output
--- fires the very events that call back into reconcile(), which would recurse
--- until Hyprland's dispatch-depth limit of 32 stops it.
---
--- A guard, and NOT a record of what was applied -- the panel's state is read
--- back from Hyprland every time. Decision 023, "The state is read, never
--- remembered".
---@type boolean
local applying = false

--- The deferred reconcile's timer. Held at module level because an hl.timer()
--- handle that nothing holds is collected and never fires at all.
---@type userdata|nil
local settle_timer

--- The pending turn-off's timer, held for the same reason as settle_timer.
---@type userdata|nil
local off_timer

--- Bumped by every reconcile, so only the newest scheduled turn-off acts. Any
--- event in the hold window -- the link swinging again -- makes the timer
--- already armed a no-op, without relying on cancelling it.
---@type integer
local off_generation = 0

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
--- answers with enabled monitors only, so membership of that list IS the
--- enabled state.
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
--- Asked of Hyprland, not of /sys/class/drm/*/status: the kernel counts a
--- connector that is merely *connected*, which is exactly what the external
--- display is in the moment after a resume when it has no mode and shows
--- nothing.
---@return boolean
local function external_enabled()
    for _, mon in ipairs(hl.get_monitors()) do
        if mon.name ~= panel.output then return true end
    end

    return false
end

--- Apply a monitor spec under the re-entrancy guard.
---
--- pcall so a failing hl.monitor() cannot leave the guard stuck true, which
--- would wedge every later reconcile for the rest of the session.
---@param spec table
local function apply(spec)
    applying = true
    pcall(hl.monitor, spec)
    applying = false
end

--- Should the panel be off right now? Asked fresh every time.
---@return boolean
local function want_off()
    return lid_shut() and external_enabled()
end

--- Re-decide whether the panel should be on, and act only if that is not
--- already what Hyprland is doing.
---
--- The two directions are deliberately not symmetric in time. On is applied
--- immediately, because a session with no outputs is the failure this module
--- exists for. Off is only scheduled, and lands once OFF_HOLD_MS passes with no
--- further monitor event -- re-decided from scratch when it does.
function M.reconcile()
    if not panel or applying then return end

    off_generation = off_generation + 1

    local off_now = not monitor_enabled(panel.output)

    if not want_off() then
        if off_now then apply(panel) end
        return
    end

    if off_now then return end

    local generation = off_generation
    off_timer = hl.timer(function()
        if generation ~= off_generation or applying then return end
        if want_off() and monitor_enabled(panel.output) then
            apply({ output = panel.output, disabled = true })
        end
    end, { timeout = OFF_HOLD_MS, type = "oneshot" })
end

--- Force the panel back on, whatever the lid is doing. The escape hatch.
---
--- This does not pin the panel on: the next monitor event reconciles as usual.
--- Deliberate rather than unfinished -- the state this exists for is "nothing to
--- look at", and in that state reconcile already agrees.
function M.panel_on()
    if not panel then return end

    -- Also void any turn-off still pending, or the hatch is undone seconds later.
    off_generation = off_generation + 1
    apply(panel)
end

--- `spec` is the panel's ordinary monitor spec -- output, mode, position, scale.
---
--- Give it an explicit position rather than "auto": with auto, an output that
--- comes back after being disabled is placed after the one that stayed, so
--- opening the lid put the laptop panel to the RIGHT of the ultrawide.
---@param spec table
function M.setup(spec)
    if type(spec) ~= "table" or type(spec.output) ~= "string" then return end

    panel = {}
    for k, v in pairs(spec) do panel[k] = v end

    -- Not optional: re-applying a spec that merely omits `disabled` does NOT
    -- clear an earlier disable. The key has to be present and false.
    panel.disabled = false

    -- Every one of these is a moment where the set of screens you can actually
    -- see changed, and any of them can be the one that would otherwise leave
    -- nothing enabled. layout_changed catches a geometry change with no add and
    -- no remove -- an output returning from a resume with a different mode, or
    -- none.
    hl.on("monitor.added", function() M.reconcile() end)
    hl.on("monitor.removed", function() M.reconcile() end)
    hl.on("monitor.layout_changed", function() M.reconcile() end)

    -- locked = true is what `bindl` means in hyprland.conf syntax: the bind has
    -- to fire with the lockscreen up, which is exactly when the lid is shut.
    --
    -- Both directions run the same reconcile. There is deliberately no "the lid
    -- closed, so turn the panel off" case -- see the rule at the top.
    hl.bind("switch:on:Lid Switch", function() M.reconcile() end,
        { locked = true, description = "Lid shut: reconcile the built-in panel" })
    hl.bind("switch:off:Lid Switch", function() M.reconcile() end,
        { locked = true, description = "Lid open: reconcile the built-in panel" })

    -- The escape hatch. locked, so it works with the lock screen up, and it
    -- needs no screen to press -- which is the whole point of having it.
    hl.bind(MOD .. " + CTRL + D", function() M.panel_on() end,
        { locked = true, description = "Force the built-in panel back on" })

    -- Three reconciles, each covering what the others miss. A switch bind fires
    -- on a transition only, so something has to cover logging in -- or
    -- reloading -- with the lid already shut:
    --
    --   * now, at parse time -- not a reconcile but the panel's monitor rule
    --     itself, declared in the state it should already be in. On a cold
    --     start no outputs are enumerated yet, so it comes up ON: the safe
    --     direction, corrected by the first event. On a reload with the lid
    --     shut it declares OFF, so the reload never lights the panel just to
    --     put it out again. setup() is the panel's only monitor rule; host.lua
    --     must not declare one too;
    --   * hyprland.start, once the compositor has its outputs;
    --   * a one-shot timer, the only one of the three that covers a RELOAD.
    --
    -- The reload hole is not obvious and cost a second session: `hyprctl reload`
    -- destroys and recreates every event subscription *and* re-applies the
    -- monitor rules, so an output returning as part of the reload fires
    -- monitor.added with nothing subscribed to hear it. Decision 023, "The
    -- reload is its own hole".
    hl.on("hyprland.start", function() M.reconcile() end)

    settle_timer = hl.timer(function() M.reconcile() end,
        { timeout = SETTLE_MS, type = "oneshot" })

    apply(want_off() and { output = panel.output, disabled = true } or panel)
end

return M
