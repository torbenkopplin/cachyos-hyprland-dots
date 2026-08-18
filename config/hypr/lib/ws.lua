-- lib/ws.lua -- addressing workspaces inside the focused monitor's band.
--
-- conf/workspaces.lua pins workspace ids to monitors in bands of
-- WORKSPACE_BAND: monitor 0 owns 1..10, monitor 1 owns 11..20, and so on. That
-- makes "workspace 3" ambiguous on its own -- it has to mean "the third
-- workspace of whichever monitor I am looking at", or the number keys would
-- yank you to the other screen.
--
-- Hyprland has selectors that sound like they do this and do not:
--
--   m~3   is not valid syntax in 0.56. The dispatcher accepts it, answers
--         "ok", and does nothing at all -- which is what made SUPER+1..0 look
--         like "workspaces are broken" rather than like a config error.
--   m+1   walks the workspaces that currently EXIST on this monitor. With one
--         workspace per monitor, which is the normal state of a dynamic
--         setup, there is never a next one and J/K at the bottom of a column
--         did nothing either.
--
-- So the band arithmetic is done here instead, from the live monitor, and the
-- dispatchers are given absolute ids. Adopted from ~/repos/dots, where the
-- same thing is a shell script (scripts/wsnav.sh) shelling out to hyprctl for
-- every keypress; in a Lua config it is a table lookup.

local M = {}

--- First id of a monitor's band, minus one: workspace n on that monitor is
--- base + n.
---
--- WSBANDS (from host.lua) is the authority, since that is what the workspace
--- rules were built from -- it keys on connector name, so it stays right even
--- if Hyprland hands out monitor ids in a different order after a replug. The
--- id fallback is for a machine with no host.lua, which has no bands at all.
---@param mon table|nil
---@return integer|nil
local function base_of(mon)
    if not mon then return nil end

    if type(WSBANDS) == "table" then
        for _, band in ipairs(WSBANDS) do
            if band.monitor == mon.name and type(band.base) == "number" then
                return band.base
            end
        end
    end

    return (mon.id or 0) * WORKSPACE_BAND
end

--- base, current workspace id -- or nil when there is nothing sensible to act
--- on (no monitor, or a special workspace, whose ids are negative and belong
--- to no band).
---@return integer|nil base
---@return integer|nil current
local function context()
    local mon = hl.get_active_monitor()
    local base = base_of(mon)
    if not base then return nil, nil end

    local ws = mon.active_workspace
    local id = ws and ws.id
    if type(id) ~= "number" or id < 1 then return base, nil end

    return base, id
end

------------------------------------------------------------------------------
-- Absolute: the number keys
------------------------------------------------------------------------------

--- Focus the n-th workspace of the focused monitor.
---@param n integer  1..WORKSPACE_BAND
function M.switch(n)
    local base = context()
    if not base then return end
    hl.dispatch(hl.dsp.focus({ workspace = base + n }))
end

--- Send the focused window to the n-th workspace of this monitor, and follow.
---@param n integer  1..WORKSPACE_BAND
function M.move_to(n)
    local base = context()
    if not base then return end
    if not hl.get_active_window() then return end
    hl.dispatch(hl.dsp.window.move({ workspace = base + n, follow = true }))
end

------------------------------------------------------------------------------
-- Relative: what J/K fall through to at the end of a column
------------------------------------------------------------------------------

--- The workspace one step up/down inside this monitor's band, or nil at the
--- band's edge. Stopping there is deliberate: the band IS the monitor, so
--- wrapping or spilling over would land you on another screen's workspaces
--- while looking at this one.
---@param dir "u"|"d"
---@return integer|nil
local function neighbour(dir)
    local base, current = context()
    if not base or not current then return nil end

    local target = (dir == "u") and current - 1 or current + 1
    if target < base + 1 or target > base + WORKSPACE_BAND then return nil end
    return target
end

--- Focus the previous/next workspace on this monitor.
---@param dir "u"|"d"
function M.step_focus(dir)
    local target = neighbour(dir)
    if target then hl.dispatch(hl.dsp.focus({ workspace = target })) end
end

--- Move the focused window to the previous/next workspace on this monitor,
--- and follow it there.
---@param dir "u"|"d"
function M.step_move(dir)
    local target = neighbour(dir)
    if target then
        hl.dispatch(hl.dsp.window.move({ workspace = target, follow = true }))
    end
end

return M
