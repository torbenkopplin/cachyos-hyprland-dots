-- conf/workspaces.lua -- one persistent workspace stack per monitor.
--
-- SUPER+J/K walk up and down this stack when they run out of windows, so the
-- stack has to actually exist. Persistent workspaces mean the ends are
-- predictable (you can always go down until you hit the last one) and Noctalia
-- can show the whole stack in its workspace indicator instead of only the
-- workspaces that happen to have windows in them right now.
--
-- Monitors are numbered left to right by physical position, so the leftmost
-- screen owns workspaces 1..N, the next one N+1..2N, and so on. Binds address
-- them with the `m~<n>` selector ("n-th workspace on THIS monitor"), so
-- SUPER+2 always means "second workspace on the screen I'm looking at"
-- regardless of which monitor that is.

local applied = {} -- monitor name -> true, so reruns don't stack duplicate rules

local function apply()
    local monitors = hl.get_monitors()
    if not monitors or #monitors == 0 then return end

    -- Left to right, then top to bottom for stacked displays.
    table.sort(monitors, function(a, b)
        if a.x ~= b.x then return a.x < b.x end
        return a.y < b.y
    end)

    for index, monitor in ipairs(monitors) do
        if not applied[monitor.name] then
            applied[monitor.name] = true

            local base = (index - 1) * WORKSPACES_PER_MONITOR
            for n = 1, WORKSPACES_PER_MONITOR do
                hl.workspace_rule({
                    workspace  = tostring(base + n),
                    monitor    = monitor.name,
                    persistent = true,
                })
            end
        end
    end
end

-- Monitors may not be enumerated yet when the config is first parsed, so cover
-- all three moments: config load (a reload), session start, and hotplug.
apply()
hl.on("hyprland.start", apply)
hl.on("monitor.added", apply)
