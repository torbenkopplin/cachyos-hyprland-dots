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

-- After a resume, how long every external connector has to read "connected"
-- without a break before the externals are enabled again, how often to look,
-- and when to stop waiting and restore them anyway (an undocked laptop's
-- connector never comes back, and its rules still have to). All in ms.
local RESUME_STABLE_MS  = 3000
local RESUME_POLL_MS    = 250
local RESUME_GIVE_UP_MS = 20000

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

--- The external monitors' specs, as handed to M.external(), in the order they
--- were declared: when two rules match one screen (a connector rule and a
--- `desc:` rule), the one registered last wins, so after_resume() has to put
--- them back in that order. Measured 2026-10-26, when a hash walk restored the
--- ultrawide's "preferred" rule after its "@60" one, the ultrawide came back
--- at 72 Hz, and the link dropped and retrained in a loop.
---@type table[]
local externals = {}

--- Where each output's spec sits in `externals`, so a reload that registers
--- it again replaces it rather than adding a second one.
---@type table<string, integer>
local external_index = {}

--- True between before_sleep() disabling the externals and after_resume()
--- giving them back. The one thing here that IS remembered: what is being
--- remembered is a promise to undo, not the state of an output.
---@type boolean
local parked = false

--- The post-resume poll, held for the same reason as settle_timer.
---@type userdata|nil
local resume_timer

--- Where each workspace on an external lived when it was parked, in the order
--- to move them back: each monitor's visible workspace last, so it is the one
--- left showing. Hyprland only returns a workspace to the monitor it was last
--- on, and parking makes that the panel -- measured 2026-10-06, when the
--- ultrawide came back to an empty workspace and the windows stayed under the
--- lid. So the homes are taken down here and put back by hand.
---@type { id: integer, monitor: string }[]
local homes = {}

--- The one-shot that puts the workspaces back, held like the others.
---@type userdata|nil
local homes_timer

-- How long after the externals are enabled to move their workspaces back, in
-- ms: long enough for Hyprland to have the monitor set up to receive them.
local HOMES_DELAY_MS = 500

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

--- Turn the panel to transform `t` -- lib/rotate.lua's rotation. Kept in the spec
--- itself, because this module re-applies that spec on every lid change and a
--- copy without the transform would put the panel upright again. Applied now
--- only if the panel is lit and meant to stay lit; otherwise it comes with the
--- panel when it does. The second half matters at parse time: setup() has just
--- declared the panel OFF if the lid is shut and docked, and lib/rotate.lua
--- calls this straight after it -- a panel still lit inside OFF_HOLD_MS would
--- otherwise be declared ON again by the reload.
---
--- Returns false when `output` is not the panel this module was set up with, so
--- the caller knows to apply its own rule.
---@param output string
---@param t integer
---@return boolean
function M.transform(output, t)
    if not panel or panel.output ~= output then return false end

    panel.transform = t
    if monitor_enabled(panel.output) and not want_off() then apply(panel) end
    return true
end

--- Declare an external monitor, and let sleep park it. Use this instead of
--- hl.monitor() for every rule that can match an external display -- `desc:`
--- rules included -- so before_sleep() can disable all of them and
--- after_resume() can put back exactly what was declared.
---@param spec table
function M.external(spec)
    if type(spec) ~= "table" or type(spec.output) ~= "string" then return end

    local copy = {}
    for k, v in pairs(spec) do copy[k] = v end
    copy.disabled = false -- present and false; see M.setup()

    local i = external_index[copy.output] or #externals + 1
    externals[i] = copy
    external_index[copy.output] = i
    if not parked then hl.monitor(copy) end
end

---@param name string a connector name, e.g. "DP-1"
---@return string|nil "connected", "disconnected", or nil if no such connector
local function connector_status(name)
    for card = 0, 3 do
        local status = slurp("/sys/class/drm/card" .. card .. "-" .. name .. "/status")
        if status then return status:match("^%s*(.-)%s*$") end
    end

    return nil
end

--- Is every external connector there is to read reading "connected"? `desc:`
--- rules have no connector to read and do not count either way.
---@return boolean
local function externals_connected()
    for _, spec in ipairs(externals) do
        local status = connector_status(spec.output)
        if status and status ~= "connected" then return false end
    end

    return true
end

--- Write down which workspace lives on which external, visible ones last.
local function take_homes()
    homes = {}
    local visible = {}

    for _, ws in ipairs(hl.get_workspaces()) do
        local mon = ws.monitor and ws.monitor.name
        if mon and mon ~= panel.output and not ws.special then
            local home = { id = ws.id, monitor = mon }
            if ws.visible then
                visible[#visible + 1] = home
            else
                homes[#homes + 1] = home
            end
        end
    end

    for _, home in ipairs(visible) do homes[#homes + 1] = home end
end

--- Move every recorded workspace back to its monitor, if that monitor is back.
local function restore_homes()
    homes_timer = nil -- fired: nothing pending for before_sleep() to keep
    for _, home in ipairs(homes) do
        if monitor_enabled(home.monitor) then
            pcall(hl.dispatch, hl.dsp.workspace.move({ workspace = home.id, monitor = home.monitor }))
        end
    end
    homes = {}
end

local function stop_resume_timer()
    if resume_timer then pcall(resume_timer.set_enabled, resume_timer, false) end
    resume_timer = nil
end

--- Called by bin/hypr-sleepwatch, through `hyprctl eval`, while logind holds the
--- suspend for it. Light the panel, then disable every external, so the link
--- retraining on resume happens to outputs Hyprland has no wl_output for --
--- nothing for a client to bind, so nothing to race. Decision 023, "Park the
--- externals across sleep".
function M.before_sleep()
    stop_resume_timer()
    if parked or not panel or next(externals) == nil then return end
    if not external_enabled() then return end

    -- A suspend inside HOMES_DELAY_MS of a resume finds the restore still
    -- pending: the workspaces are still on the panel, so what take_homes()
    -- would read now is wrong, and the list already held is the right one.
    -- Cancel the restore -- left to fire while parked it would clear that list
    -- -- and keep the list for the next resume.
    if homes_timer then
        pcall(homes_timer.set_enabled, homes_timer, false)
        homes_timer = nil
    else
        take_homes()
    end

    off_generation = off_generation + 1
    if not monitor_enabled(panel.output) then apply(panel) end

    parked = true
    for _, spec in ipairs(externals) do
        apply({ output = spec.output, disabled = true })
    end
end

--- The other half: once every external connector has read "connected" for
--- RESUME_STABLE_MS straight, or RESUME_GIVE_UP_MS has passed, put back the
--- specs M.external() was given. The panel goes off afterwards the ordinary
--- way, through reconcile and OFF_HOLD_MS.
function M.after_resume()
    stop_resume_timer()
    if not parked then return end

    local stable, waited = 0, 0
    resume_timer = hl.timer(function()
        waited = waited + RESUME_POLL_MS
        stable = externals_connected() and stable + RESUME_POLL_MS or 0
        if stable < RESUME_STABLE_MS and waited < RESUME_GIVE_UP_MS then return end

        stop_resume_timer()
        parked = false
        for _, spec in ipairs(externals) do apply(spec) end

        homes_timer = hl.timer(restore_homes, { timeout = HOMES_DELAY_MS, type = "oneshot" })

        -- The guard swallowed the monitor events those calls fired.
        M.reconcile()
    end, { timeout = RESUME_POLL_MS, type = "repeat" })
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
    hl.on("hyprland.start", function()
        M.reconcile()

        -- What calls before_sleep() and after_resume(). Started here rather
        -- than enabled against a target because it is part of this mechanism:
        -- a machine that never calls setup() has nothing for it to do.
        hl.exec_cmd("systemctl --user start hypr-sleepwatch.service")
    end)

    settle_timer = hl.timer(function() M.reconcile() end,
        { timeout = SETTLE_MS, type = "oneshot" })

    apply(want_off() and { output = panel.output, disabled = true } or panel)
end

return M
