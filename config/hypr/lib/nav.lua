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
--   SUPER+SHIFT+<hjkl> the same, dragging the focused window along.
--
--   SUPER+CTRL+SHIFT+<hjkl>  send the window to another monitor, whatever the
--                     monitors are arranged like. See M.monitor_hop.
--
--   SUPER+CTRL+<hjkl> the same shape one level up, on whole COLUMNS.
--                     H/L reorder the column along the tape; at either end of
--                     the tape the whole column crosses to the next MONITOR,
--                     the same handoff focus and windows make. J/K send it to
--                     the workspace above/below.
--
-- The workspace end of that is band arithmetic, not a relative selector --
-- see lib/ws.lua for why "m+1" cannot do it.
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

-- Named for what it provides rather than "ws": column_range() below has its
-- own local `ws`, which is a workspace object and not this.
local bands = require("lib.ws")

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

--- The monitor in `dir` from the active one, or nil if there is none.
---
--- Worked out here rather than handed to Hyprland's directional monitor
--- selector, for two reasons. A selector that resolves to nothing fails INSIDE
--- the dispatcher without raising a Lua error -- pcall around it returns true --
--- so there is no way to ask "is there one that way?" and get an answer. And
--- moving a whole column needs to know the target BEFORE anything moves.
---
--- With exactly two monitors a direction that points at nothing still resolves
--- to the other one: with two screens there is nothing else "over there" could
--- mean, and a key that does nothing is indistinguishable from an unbound one.
--- With three or more the ambiguity is real, so a miss stays a miss.
---@param dir "l"|"r"|"u"|"d"
---@return table|nil
local function monitor_in_direction(dir)
    local here = hl.get_active_monitor()
    if not here then return nil end

    local mons = hl.get_monitors() or {}

    local function centre(m)
        local p = m.position or {}
        return (p.x or 0) + (m.width or 0) / 2, (p.y or 0) + (m.height or 0) / 2
    end

    local hx, hy = centre(here)
    local best, best_d

    for _, m in ipairs(mons) do
        if m.id ~= here.id then
            local mx, my = centre(m)
            local d
            if     dir == "l" and mx < hx then d = hx - mx
            elseif dir == "r" and mx > hx then d = mx - hx
            elseif dir == "u" and my < hy then d = hy - my
            elseif dir == "d" and my > hy then d = my - hy
            end
            if d and (not best_d or d < best_d) then best, best_d = m, d end
        end
    end
    if best then return best end

    if #mons == 2 then
        for _, m in ipairs(mons) do
            if m.id ~= here.id then return m end
        end
    end
    return nil
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

    bands.step_focus(dir)
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

    bands.step_move(dir)
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
--- SUPER+CTRL+SHIFT+<hjkl> forces the monitor hop when you want it
--- unconditionally; see M.monitor_hop.
---@param dir "l"|"r"
function M.move_horizontal(dir)
    if not hl.get_active_window() then return end
    hl.dispatch(hl.dsp.window.move({ direction = dir }))
end

--- Send the focused window to another monitor, unconditionally.
---
--- The direction is tried first, because it is what the key says. But a
--- directional monitor selector only resolves if a monitor actually lies that
--- way: on a two-monitor desk with the second screen on the LEFT, asking for
--- the monitor to the right raises "Invalid monitor / monitor doesn't exist"
--- and the keypress does nothing at all. That is what this used to do, and a
--- bind that silently does nothing is indistinguishable from a broken one.
---
--- So: with exactly two monitors there is no ambiguity about what was meant --
--- "the other one" -- and any of the four directions goes there. With three or
--- more there genuinely is ambiguity, and a direction that points at nothing
--- stays a no-op rather than guessing.
---
--- This is also the answer for monitors stacked vertically: J/K are bound to
--- "u"/"d" alongside H/L, so the pair that matches the arrangement resolves
--- directionally and the other pair still works through the two-monitor case.
---@param dir "l"|"r"|"u"|"d"
function M.monitor_hop(dir)
    if not hl.get_active_window() then return end

    local target = monitor_in_direction(dir)
    if not target then return end

    hl.dispatch(hl.dsp.window.move({ monitor = target.name, follow = true }))
end

------------------------------------------------------------------------------
-- Moving whole columns
--
-- SUPER+SHIFT moves a window; SUPER+CTRL moves the column it lives in. Keeping
-- them on separate chords is what stops the two from feeling identical: with a
-- single-window column, "drag the window right" and "reorder the column right"
-- are the same gesture, and there was no way to say which you meant.
--
-- There is no "move column to workspace" dispatcher. The layout only ever moves
-- one window, and a window arriving on another workspace starts a column of its
-- own -- so moving a two-window column naively arrives as two columns. Hence
-- move_column() below: move them all silently, then consume the followers back
-- into the first one's column, which also restores the order they were in.
------------------------------------------------------------------------------

--- Move every window of `win`'s column to workspace `target`, rebuild the
--- column there, and follow it, landing on the window that was focused.
---@param win table    the focused window, known to be on a scrolling tape
---@param target integer  absolute workspace id
local function move_column(win, target)
    local addrs = {}
    for _, w in ipairs(win.layout.column.windows or {}) do
        if w.address then table.insert(addrs, w.address) end
    end
    if #addrs == 0 then return end

    -- follow = false on every move: without it the view chases each window in
    -- turn and a three-window column flickers through three workspace switches.
    for _, address in ipairs(addrs) do
        hl.dispatch(hl.dsp.window.move({
            workspace = target,
            window    = "address:" .. address,
            follow    = false,
        }))
    end

    hl.dispatch(hl.dsp.focus({ workspace = target }))

    -- Re-stack. `consume` pulls the next column into the focused one, so
    -- calling it from the first window as many times as there are followers
    -- puts the column back together in its original order.
    if #addrs > 1 then
        hl.dispatch(hl.dsp.focus({ window = "address:" .. addrs[1] }))
        for _ = 2, #addrs do
            hl.dispatch(hl.dsp.layout("consume"))
        end
    end

    -- Selectors need the hyprctl form: a bare "0x..." is not matched.
    hl.dispatch(hl.dsp.focus({ window = "address:" .. win.address }))
end

--- Reorder the column along the tape; at either end of the tape, send the whole
--- column to the previous/next workspace instead.
---
--- The tape end deliberately hands off to a *workspace* and never to another
--- monitor: SUPER+CTRL+SHIFT+H/L is the monitor hop, and a chord that could do
--- either depending on how full the tape is would be unpredictable.
---@param dir "l"|"r"
function M.column_horizontal(dir)
    local win = hl.get_active_window()
    if not win then return end

    -- A floating window is not on the tape, so it has no column to reorder and
    -- nothing to spill: leave it alone rather than surprising you with a move.
    local p = pos_of(win)
    if not p then return end

    local lo, hi = column_range(win)
    local at_edge = (dir == "l") and (lo == nil or p.col <= lo)
        or (dir == "r") and (hi == nil or p.col >= hi)

    if not at_edge then
        hl.dispatch(hl.dsp.layout("swapcol " .. dir))
        return
    end

    -- Off the end of the tape is the next MONITOR, not the next workspace.
    --
    -- h/l is the horizontal axis everywhere else in this keymap -- focus and
    -- window both run out of columns and hand off to the screen that way -- and
    -- j/k is the workspace axis. A column doing something different from the
    -- window inside it on the same two keys is the thing that made this feel
    -- arbitrary. Sending a column to another workspace is SUPER+CTRL+J/K, which
    -- is where the band arithmetic still lives.
    local mon = monitor_in_direction(dir)
    if not mon then return end

    local ws = mon.active_workspace
    if ws and ws.id then move_column(win, ws.id) end
end

--- Send the whole column to the workspace above/below, clamped at the band edge
--- exactly as a focus or window step is.
---@param dir "u"|"d"
function M.column_vertical(dir)
    local win = hl.get_active_window()
    if not win then return end

    local target = bands.neighbour(dir)
    if not target then return end

    if pos_of(win) then
        move_column(win, target)
    else
        -- Floating: there is no column, so the window itself is the whole of it.
        hl.dispatch(hl.dsp.window.move({ workspace = target, follow = true }))
    end
end

return M
