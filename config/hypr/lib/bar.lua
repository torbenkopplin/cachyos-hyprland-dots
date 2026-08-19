-- lib/bar.lua -- the bar is not part of your desktop; it is a thing you summon.
--
-- Three ways to summon it, and this file owns all three:
--
--   a panel opens   launcher, control centre, clipboard, session menu, window
--                   switcher -- the bar comes with it and leaves with it.
--   SUPER+B         pins it visible for a deliberate glance.
--   the pointer      pushing the mouse at the top edge reveals it, and it
--                   retracts when the pointer leaves. Added 2026-08-19 as the
--                   mouse backup to a keyboard-first setup.
--
-- Visibility is absolute -- bar-show / bar-hide -- and 10-bar.toml keeps
-- `auto_hide = false` so nothing else is deciding at the same time. That matters:
-- two systems with an opinion about the same surface is how you get a bar that
-- retracts the instant you reveal it.
--
-- Why the hot edge is ours and not Noctalia's
-- ------------------------------------------
-- Noctalia has `auto_hide`, and it was the obvious way to do this. It does not
-- do it. Measured on 5.0.0-beta.8 with auto_hide confirmed true in
-- `config export merged`: the bar collapses to a strip at the screen edge and
-- stays collapsed with the pointer parked inside that strip, at the top row and
-- a few pixels down, on `top` and on `overlay`, with and without reserved space.
-- Whatever `auto_hide` gates, it is not pointer proximity.
--
-- (Caveat worth knowing before trusting that: the pointer was placed by warping
-- it and then nudging it with real relative motion events, not by a hand on a
-- mouse. If a hand-moved pointer does reveal it, this whole poll can be deleted
-- in favour of one config key.)
--
-- So the edge is polled here instead. hl.get_cursor_pos() is an in-process read
-- and the tick does nothing but compare two numbers until the answer changes, so
-- the cost is a comparison every HOT_EDGE_POLL_MS and an IPC call only on a
-- transition. Set BAR_HOT_EDGE = false in conf/options.lua to be rid of it.
--
-- Noctalia's panels are layer-shell surfaces and Hyprland emits layer.opened /
-- layer.closed with the surface, so the panel half needs no polling at all.
--
-- Why it used to get stuck, and what stops it now
-- ---------------------------------------------
-- Two independent mechanisms, both addressed:
--
--   1. `open` was only ever written by events. A layer.closed that never arrived
--      stranded an address in it for the rest of the session -- and the bar is
--      wanted while ANYTHING is in that set, so it stayed up. SUPER+B could not
--      rescue it either, because unpinning recomputes from the same stale set. A
--      set rather than a counter defends against double counting, which was never
--      the problem. So `open` is now reconciled against hl.get_layers() before
--      every decision: a surface that is not on screen is not open, whatever we
--      were told about it.
--
--   2. `held` records what was last ASSERTED, not what happened, so a command
--      that got lost was never retried -- the "state already matches" guard
--      suppressed the correction for good. The guard is worth keeping, since
--      re-sending bar-show re-runs the slide animation, so instead it is bypassed
--      whenever there is reason to doubt it: after a prune that actually dropped
--      something, when Noctalia reappears, and on SUPER+B -- which makes that key
--      a resync as well as a toggle, and the way out if this is ever wrong again.

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
        -- bad data, so what we think we asserted cannot be trusted either.
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
        hl.timer(edge_poll, { timeout = HOT_EDGE_POLL_MS, type = "repeat" })
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
    --- the pointer. Forced, so it doubles as a resync -- if the bar is ever stuck
    --- in a state this file did not intend, two presses of this key end it.
    function M.toggle_pin()
        pinned = not pinned
        apply(true)
    end
end

return M
