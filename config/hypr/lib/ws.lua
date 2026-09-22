-- lib/ws.lua -- turning a number key into a workspace id.
--
-- Two models, and which one is in force depends on whether host.lua set
-- WSBANDS. Without it -- the default, and what a laptop that docks to a
-- different screen each week wants -- there are no bands: workspaces
-- 1..WORKSPACE_BAND are shared by every monitor and SUPER+3 is workspace 3.
-- With it, conf/workspaces.lua pins ids to monitors in bands of WORKSPACE_BAND,
-- so "workspace 3" has to mean "the third workspace of whichever monitor I am
-- looking at" or the number keys would yank you to the other screen.
--
-- Either way the answer is arithmetic done here rather than a selector, and
-- that is the part that does not vary. Decision 003 for why, 025 for why bands
-- are opt-in.
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
-- So the arithmetic is done here instead, from the live monitor, and the
-- dispatchers are given absolute ids. In a Lua config that is a table lookup,
-- where a hyprland.conf has to shell out to hyprctl on every keypress.

local M = {}

--- First id of a monitor's band, minus one: workspace n on that monitor is
--- base + n.
---
--- WSBANDS (from host.lua) is the authority, since that is what the workspace
--- rules were built from -- it keys on connector NAME, so it stays right even if
--- Hyprland hands out monitor ids in a different order after a replug.
---
--- No WSBANDS means no bands, and the base is 0 on every monitor: workspaces
--- 1..WORKSPACE_BAND are shared, and SUPER+3 means workspace 3 wherever you are
--- looking. That is what a laptop that meets a different screen every week
--- wants. Unplug the external and Hyprland walks its workspaces over to the
--- panel that is left; the numbers do not change, so there is nothing to move
--- by hand and nothing stranded behind a number key that now means something
--- else. See decision 025.
---
--- This used to fall back to `mon.id * WORKSPACE_BAND`, which banded by
--- Hyprland's monitor id -- assignment order, not identity -- while claiming in
--- this very comment to have no bands at all. Ids are not stable across a
--- replug: with the lid shut, eDP-1 held id 0 while DISABLED and the one live
--- screen was id 1, so the number keys addressed 11-20. Boot with only that
--- screen and it becomes id 0, SUPER+1 means workspace 1, and the windows left
--- on 11-13 are still on screen with no key that reaches them.
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

    return 0
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
    hl.dispatch(hl.dsp.window.move({ workspace = base + n, follow = false }))
end

------------------------------------------------------------------------------
-- Relative: what J/K fall through to at the end of a column
------------------------------------------------------------------------------

--- The workspace one step up/down, or nil at the edge of the range. Stopping
--- there is deliberate: under bands the band IS the monitor, so spilling over
--- would land you on another screen's workspaces while looking at this one.
--- Bandless the range is 1..WORKSPACE_BAND, and stopping at 10 rather than
--- wrapping to 1 keeps J and K a walk along a line rather than a loop.
---
--- Public because lib/nav.lua needs the same clamped arithmetic for the column
--- moves on SUPER+CTRL, which are not a focus or a window step and so cannot go
--- through step_focus / step_move below.
---@param dir "u"|"d"
---@return integer|nil
function M.neighbour(dir)
    local base, current = context()
    if not base or not current then return nil end

    local target = (dir == "u") and current - 1 or current + 1
    if target < base + 1 or target > base + WORKSPACE_BAND then return nil end
    return target
end

--- Focus the previous/next workspace on this monitor.
---@param dir "u"|"d"
function M.step_focus(dir)
    local target = M.neighbour(dir)
    if target then hl.dispatch(hl.dsp.focus({ workspace = target })) end
end

--- Move the focused window to the previous/next workspace on this monitor,
--- and follow it there.
---@param dir "u"|"d"
function M.step_move(dir)
    local target = M.neighbour(dir)
    if target then
        hl.dispatch(hl.dsp.window.move({ workspace = target, follow = true }))
    end
end

return M
