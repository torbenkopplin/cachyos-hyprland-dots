-- lib/bar.lua -- the bar is not part of your desktop; it is a thing you summon.
--
-- Default state is hidden with no reserved space, so windows get the whole
-- screen and nothing shifts when it appears. It slides in whenever a Noctalia
-- panel opens (launcher, control centre, clipboard, session menu, window
-- switcher) and slides back out when the last one closes. SUPER+B pins it
-- visible for a deliberate glance.
--
-- Noctalia's panels are layer-shell surfaces and Hyprland emits layer.opened /
-- layer.closed with the surface, so this is event-driven: no polling, and no
-- timeout guesswork about how long you will spend in the launcher.
--
-- Visibility is driven entirely from here via bar-show / bar-hide, and
-- 10-bar.toml deliberately sets auto_hide = false so that pointer-proximity
-- logic cannot retract a bar we just asked for. The trade-off is that pushing
-- the mouse into the screen edge no longer reveals it -- which is the right
-- trade for a keyboard-first setup.

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

function M.setup(noct)
    -- Addresses of the panel surfaces currently open. A set rather than a
    -- counter, so a missed or duplicated event cannot leave the bar stuck on.
    local open   = {}
    local pinned = false -- SUPER+B override
    local shown  = nil   -- last state we sent; nil = we have not sent anything

    local function apply(force)
        local want = pinned or next(open) ~= nil
        if want == shown and not force then return end
        shown = want
        hl.exec_cmd(noct .. (want and "bar-show" or "bar-hide"))
    end

    hl.on("layer.opened", function(layer)
        if not layer then return end

        if PANEL_NAMESPACES[layer.namespace] then
            open[layer.address] = true
            apply()
            return
        end

        -- Noctalia has (re)started and drawn its bar. Anything we sent before
        -- this point went nowhere, so assert the state we actually want now.
        -- This is also what hides the bar at login.
        if layer.namespace:match(BAR_NAMESPACE_PATTERN) then
            apply(true)
        end
    end)

    hl.on("layer.closed", function(layer)
        if layer and open[layer.address] then
            open[layer.address] = nil
            apply()
        end
    end)

    --- SUPER+B: pin the bar on screen, or let it go back to following panels.
    function M.toggle_pin()
        pinned = not pinned
        apply()
    end
end

return M
