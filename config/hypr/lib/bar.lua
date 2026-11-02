-- lib/bar.lua -- the bar is not part of your desktop; it is a thing you summon.
--
-- Three ways to summon it, and this file owns all three:
--
--   a panel opens   launcher, control centre, clipboard, session menu, window
--                   switcher -- the bar comes with it and leaves with it.
--   SUPER+B         pins it visible for a deliberate glance.
--   the pointer     pushing the mouse at the top edge reveals it, and it
--                   retracts when the pointer leaves.
--
-- Visibility is absolute -- bar-show / bar-hide -- and 10-bar.toml keeps
-- `auto_hide = false` so nothing else is deciding at the same time. Two systems
-- with an opinion about the same surface is how you get a bar that retracts the
-- instant you reveal it.
--
-- Two rules earn their complexity, and decision 008 is why:
--
--   * the open set is RECONCILED against hl.get_layers() before every decision,
--     never maintained from events alone. A missed layer.closed would otherwise
--     strand an address and pin the bar up for the rest of the session.
--   * `held` is what was last ASSERTED, so it can be wrong. The guard against
--     re-sending is bypassed whenever there is reason to doubt it -- after a
--     prune that dropped something, when Noctalia reappears, and on SUPER+B,
--     which makes that key a resync as well as a toggle.
--
-- The hot edge is polled rather than subscribed because Noctalia's own
-- `auto_hide` is not a proximity reveal -- measured, see docs/upstream.md -- and
-- there is no "pointer entered a region" event for a surface that is not mapped
-- there yet. hl.get_cursor_pos() is an in-process read and the tick compares two
-- numbers until the answer changes, so the cost is a comparison every
-- HOT_EDGE_POLL_MS and an IPC call only on a transition. BAR_HOT_EDGE = false in
-- conf/options.lua is rid of it.
--
-- docs/decisions/008-the-bar-is-event-driven.md is the decision;
-- 009 is what the bar is made of.

local M = {}

-- Surfaces that count as "a panel is open".
--
-- Notifications, OSDs and the dock are deliberately absent: a notification
-- popping up must not drag the bar on screen with it.
local PANEL_NAMESPACES = {
    ["noctalia-panel"]           = true,
    ["noctalia-attached-panel"]  = true,
    ["noctalia-window-switcher"] = true,
}

-- The bar's own surfaces, used only to detect that Noctalia is up.
local BAR_NAMESPACE_PATTERN = "^noctalia%-bar%-"

-- How close to the top of a monitor counts as asking for the bar.
local HOT_EDGE_REVEAL_PX = 6

-- ...and how far the pointer may then travel before it counts as leaving. This
-- has to clear the bar itself or the bar would retract as you reached for it:
-- 10-bar.toml puts it at `margin_edge` 10 with `thickness` 30, so it occupies
-- 10..40 below the monitor's top edge, and this is that plus slack. Raise it if
-- either of those numbers grows.
local HOT_EDGE_KEEP_PX = 48

local HOT_EDGE_POLL_MS = 250

--- The hot-edge poll, held at module level like lib/lid.lua's timers. On 0.57
--- a discarded handle measurably keeps firing, but on 0.56.2 one was collected
--- and never fired at all -- docs/upstream.md has both -- and holding it costs
--- nothing under either.
---@type userdata|nil
local edge_timer

function M.setup(noct)
    -- Addresses of the panel surfaces currently open.
    local open   = {}
    local pinned = false -- SUPER+B override
    local hot    = false -- pointer is at the top edge
    local held   = nil   -- last state asserted; nil = nothing asserted yet

    --- Drop anything from `open` that is no longer a live layer.
    ---@return boolean dropped  whether the set was actually wrong
    local function prune()
        local live = {}
        for _, layer in ipairs(hl.get_layers() or {}) do
            if layer.address then live[layer.address] = true end
        end

        local dropped = false
        for address in pairs(open) do
            if not live[address] then
                open[address] = nil
                dropped = true
            end
        end
        return dropped
    end

    --- Assert the state the bar should be in.
    --- `force` sends even when nothing appears to have changed.
    local function apply(force)
        -- A prune that found something means the previous decision was made on
        -- bad data, so `held` cannot be trusted either.
        if prune() then force = true end

        local want = pinned or hot or next(open) ~= nil
        if want == held and not force then return end
        held = want

        hl.exec_cmd(noct .. (want and "bar-show" or "bar-hide"))
    end

    --- Is the pointer asking for the bar? Hysteresis: it takes a few pixels to
    --- summon and the whole depth of the bar to dismiss, so the bar does not
    --- vanish from under a pointer on its way to click something on it.
    local function edge_poll()
        local c = hl.get_cursor_pos()
        if not c then return end

        local mon = hl.get_monitor_at_cursor()
        if not mon then return end

        -- Only `position` is needed, not the size -- so this sidesteps the fact
        -- that a monitor reports its UNTRANSFORMED width and height (a rotated
        -- screen answers 1920x1080 while occupying 1080x1920).
        local top   = (mon.position and mon.position.y) or 0
        local depth = c.y - top
        local limit = hot and HOT_EDGE_KEEP_PX or HOT_EDGE_REVEAL_PX

        local near = depth >= 0 and depth <= limit
        if near ~= hot then
            hot = near
            apply()
        end
    end

    if BAR_HOT_EDGE then
        edge_timer = hl.timer(edge_poll, { timeout = HOT_EDGE_POLL_MS, type = "repeat" })
    end

    hl.on("layer.opened", function(layer)
        if not layer then return end

        if PANEL_NAMESPACES[layer.namespace] then
            open[layer.address] = true
            apply()
            return
        end

        -- Noctalia has (re)started and drawn its bar. Anything sent before this
        -- point went nowhere, so assert the state we actually want now. This is
        -- also what hides the bar at login.
        if layer.namespace:match(BAR_NAMESPACE_PATTERN) then
            apply(true)
        end
    end)

    hl.on("layer.closed", function(layer)
        if layer and open[layer.address] then
            open[layer.address] = nil
        end
        -- Unconditionally, and not only for surfaces we were tracking: any layer
        -- going away is a chance for prune() to notice one whose close we missed.
        apply()
    end)

    --- SUPER+B: pin the bar on screen, or let it go back to following panels and
    --- the pointer. Forced, so it doubles as a resync.
    function M.toggle_pin()
        pinned = not pinned
        apply(true)
    end
end

return M
