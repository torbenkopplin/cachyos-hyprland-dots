-- lib/nav.lua -- niri / PaperWM directional navigation for the scrolling layout.
--
-- The behaviour we want:
--
--   SUPER+J / K       focus down / up inside the current column.
--                     At the bottom / top of the column, go to the next /
--                     previous workspace on this monitor instead.
--
--   SUPER+H / L       focus left / right along the tape of columns.
--                     Past the last / first column, go to the monitor in
--                     that direction instead.
--
--   SUPER+CTRL+<hjkl> the same, dragging the focused window along.
--
-- How the edge is detected
-- ------------------------
-- Hyprland exposes the scrolling layout's own bookkeeping on every tiled
-- window as `window.layout`:
--
--   { name = "scrolling",
--     index_in_column = <0-based row within the column>,
--     column = { index   = <0-based column position on the tape>,
--                width   = <fraction of the monitor>,
--                windows = { <window>, ... } } }
--
-- Vertical edges are read straight off that. Horizontal edges need the number
-- of columns on the workspace, which we derive by scanning the workspace's
-- tiled windows for the lowest and highest column index.
--
-- We deliberately do NOT rely on a dispatcher returning ok=false at an edge.
-- The scrolling layout reports "no column that way" as a *success* (it just
-- re-centres), so only the row case would be detectable that way. Reading the
-- indices is uniform and does not depend on that asymmetry.

local M = {}

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

--- Scrolling-layout position of a window, or nil if it isn't on a scrolling
--- tape (floating, no workspace, or a different layout on that workspace).
---@param win table|nil
---@return table|nil
local function pos_of(win)
    if not win or win.floating then return nil end

    local l = win.layout
    if type(l) ~= "table" or l.name ~= "scrolling" then return nil end

    local col = l.column
    if type(col) ~= "table" or type(col.index) ~= "number" then return nil end

    return {
        col       = col.index,                                    -- 0-based
        row       = l.index_in_column or 0,                       -- 0-based
        col_count = type(col.windows) == "table" and #col.windows or 1,
    }
end

--- Lowest and highest column index currently on `win`'s workspace.
--- Column indices are 0-based and contiguous, but we scan rather than assume
--- so this stays correct if that ever changes.
---@param win table
---@return integer|nil lo
---@return integer|nil hi
local function column_range(win)
    local ws = win.workspace
    if not ws then return nil, nil end

    local lo, hi
    -- pos_of() already rejects floating windows, so no filter is needed here.
    for _, w in ipairs(hl.get_workspace_windows(ws.id) or {}) do
        local p = pos_of(w)
        if p then
            if not lo or p.col < lo then lo = p.col end
            if not hi or p.col > hi then hi = p.col end
        end
    end

    return lo, hi
end

--- Run a dispatcher and report whether it actually moved focus to a different
--- window. Used for floating windows, where there is no tape to inspect.
---@param dispatcher table
---@return boolean moved
local function focus_moved(dispatcher)
    local before = hl.get_active_window()
    before = before and before.address

    hl.dispatch(dispatcher)

    local after = hl.get_active_window()
    after = after and after.address

    return before ~= after
end

------------------------------------------------------------------------------
-- Focus
------------------------------------------------------------------------------

--- Focus up/down within the column; fall through to the workspace above/below.
---@param dir "u"|"d"
function M.focus_vertical(dir)
    local win = hl.get_active_window()

    if win then
        local p = pos_of(win)
        if p then
            local at_edge = (dir == "u") and p.row <= 0
                or (dir == "d") and p.row >= p.col_count - 1
            if not at_edge then
                hl.dispatch(hl.dsp.layout("focus " .. dir))
                return
            end
        else
            -- Floating (or non-scrolling) window: let the generic directional
            -- focus try first, and only fall through if nothing was there.
            if focus_moved(hl.dsp.focus({ direction = dir })) then return end
        end
    end

    hl.dispatch(hl.dsp.focus({ workspace = (dir == "u") and "m-1" or "m+1" }))
end

--- Focus left/right along the tape; fall through to the monitor in that
--- direction.
---@param dir "l"|"r"
function M.focus_horizontal(dir)
    local win = hl.get_active_window()

    if win then
        local p = pos_of(win)
        if p then
            local lo, hi = column_range(win)
            local at_edge = (dir == "l") and (lo == nil or p.col <= lo)
                or (dir == "r") and (hi == nil or p.col >= hi)
            if not at_edge then
                hl.dispatch(hl.dsp.layout("focus " .. dir))
                return
            end
        else
            if focus_moved(hl.dsp.focus({ direction = dir })) then return end
        end
    end

    -- `monitor` accepts a direction; if there is no monitor that way this is a
    -- no-op, which is what we want -- no wrapping around the desk.
    hl.dispatch(hl.dsp.focus({ monitor = dir }))
end

------------------------------------------------------------------------------
-- Moving the focused window
------------------------------------------------------------------------------

--- Move the window up/down within its column; past the end of the column,
--- send it to the workspace above/below and follow it there.
---@param dir "u"|"d"
function M.move_vertical(dir)
    local win = hl.get_active_window()
    if not win then return end

    local p = pos_of(win)
    if p then
        local at_edge = (dir == "u") and p.row <= 0
            or (dir == "d") and p.row >= p.col_count - 1
        if not at_edge then
            hl.dispatch(hl.dsp.window.move({ direction = dir }))
            return
        end
    end

    hl.dispatch(hl.dsp.window.move({
        workspace = (dir == "u") and "m-1" or "m+1",
        follow    = true,
    }))
end

--- Move the window left/right along the tape.
---
--- This one is handed straight to the layout, because the scrolling algorithm
--- already does exactly the right thing at every step:
---
---   * window has siblings in its column  -> it is expelled into a new column
---     in that direction (PaperWM "expel"),
---   * window is alone in the end column  -> there is genuinely nothing more
---     that way, so `binds.window_direction_monitor_fallback` (set in
---     conf/input.lua) hands it to the next monitor.
---
--- SUPER+CTRL+SHIFT+H/L forces the monitor hop when you want it unconditionally.
---@param dir "l"|"r"
function M.move_horizontal(dir)
    if not hl.get_active_window() then return end
    hl.dispatch(hl.dsp.window.move({ direction = dir }))
end

return M
