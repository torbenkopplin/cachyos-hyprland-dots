-- lib/nav.lua -- niri / PaperWM directional navigation for the scrolling layout.
--
-- One rule, and it holds on every monitor:
--
--   H / L   walk whatever lies left/right, then hand off to the MONITOR.
--   J / K   walk whatever lies up/down,    then hand off to the WORKSPACE.
--
--   SUPER+<hjkl>             focus
--   SUPER+SHIFT+<hjkl>       the same, dragging the focused window along
--   SUPER+CTRL+<hjkl>        the same shape one level up, on whole COLUMNS
--   SUPER+CTRL+SHIFT+<hjkl>  send the window to another monitor, unconditionally
--
-- "Whatever lies that way" is deliberately vague, because it depends on the
-- band. A workspace is a tape of columns and a column is a stack of windows, but
-- WHICH WAY THE TAPE RUNS is per-band: conf/workspaces.lua gives each band a
-- `direction`, so a portrait monitor scrolls down while a landscape one scrolls
-- right. On a horizontal band J/K walk the column and H/L walk the tape; on a
-- vertical band it is the other way round.
--
-- This file used to assume the horizontal case everywhere, and on a vertical
-- band that put both axes on the wrong structure: J reported "end of column" on
-- the first press, because each column holds one window, and jumped a workspace
-- while the next column sat visibly below. L asked for an in-column neighbour
-- that a vertical band does not have, and did nothing at all.
--
-- How the edge is detected now
-- ---------------------------
-- By asking, not by predicting. `layout("focus <dir>")` takes SCREEN directions
-- and already walks whichever structure runs that way, and at an edge it is a
-- complete no-op. Measured on both bands: focus unchanged, and not one window
-- moved -- so there is no re-centring to undo, and the only thing worth
-- inspecting is whether focus ended up somewhere else.
--
-- That is why nothing here reads WSBANDS to find the axis. A band is keyed on
-- connector name, which a laptop plugged into a monitor it has never seen cannot
-- know in advance; the compositor's own answer is true whatever the screen is
-- called. (`window.layout` carries no direction field to read either -- checked:
-- both `layout.direction` and `layout.column.direction` are nil.)
--
-- Where the axis genuinely cannot be avoided -- `swapcol`, which is
-- tape-relative rather than screen-absolute -- it is derived from the geometry
-- of the windows on the tape. See tape_forward().
--
-- The workspace end of the handoff is band arithmetic, not a relative selector;
-- see lib/ws.lua for why "m+1" cannot do it.

-- Named for what it provides rather than "ws": it is the band arithmetic.
local bands = require("lib.ws")

local M = {}

------------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------------

--- Scrolling-layout position of a window, or nil if it isn't on a scrolling
--- tape (floating, no workspace, or a different layout on that workspace).
---
--- `column_size` is the number of windows in the column, not a count of
--- columns -- it is how many neighbours the window has stacked with it.
---@param win table|nil
---@return table|nil
local function pos_of(win)
    if not win or win.floating then return nil end

    local l = win.layout
    if type(l) ~= "table" or l.name ~= "scrolling" then return nil end

    local col = l.column
    if type(col) ~= "table" or type(col.index) ~= "number" then return nil end

    return {
        col         = col.index,                                    -- 0-based
        row         = l.index_in_column or 0,                       -- 0-based
        column_size = type(col.windows) == "table" and #col.windows or 1,
    }
end

--- Which screen direction "one step further along the tape" points in: "r" on a
--- horizontal band, "d" on a vertical one. Nil when there is only one column,
--- in which case there is no tape to walk and no reorder to make.
---
--- Worked out from the windows themselves, because nothing will say it outright.
--- Column indices ascend along the tape, so the axis the index tracks IS the
--- tape. Measured on this desk:
---
---   horizontal band   col 0..3 at x -1175, -43, 1096, 2235   (y all equal)
---   vertical band     col 0..1 at y 12, 966                  (x all equal)
---
--- Geometric on purpose rather than read out of WSBANDS -- see the file header.
---@param win table
---@return "r"|"d"|nil
local function tape_forward(win)
    local ws = win.workspace
    if not ws then return nil end

    local lo, hi, lo_at, hi_at
    -- pos_of() already rejects floating windows, so no filter is needed here.
    for _, w in ipairs(hl.get_workspace_windows(ws.id) or {}) do
        local p = pos_of(w)
        if p and w.at then
            if not lo or p.col < lo then lo, lo_at = p.col, w.at end
            if not hi or p.col > hi then hi, hi_at = p.col, w.at end
        end
    end
    if not lo or not hi or lo == hi then return nil end
    if not lo_at or not hi_at then return nil end

    local dx = math.abs((hi_at.x or 0) - (lo_at.x or 0))
    local dy = math.abs((hi_at.y or 0) - (lo_at.y or 0))
    return (dy > dx) and "d" or "r"
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
--- window. The address is the signal rather than the dispatcher's return value:
--- the scrolling layout reports "nothing that way" as a SUCCESS, so ok=false
--- never arrives, but the focused window genuinely does not change.
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

--- Run a dispatcher and report whether the focused window's PLACE changed --
--- its workspace, its column, or its row within that column.
---
--- The moves need this instead of focus_moved: focus follows the window, so the
--- focused address is identical either way and says nothing.
---@param dispatcher table
---@return boolean moved
local function window_moved(dispatcher)
    local function place()
        local w = hl.get_active_window()
        if not w then return "gone" end
        local p = pos_of(w)
        if not p then return "floating" end
        return string.format("%s/%d/%d",
            tostring(w.workspace and w.workspace.id), p.col, p.row)
    end

    local before = place()
    hl.dispatch(dispatcher)
    return before ~= place()
end

--- One focus step in screen direction `dir`, staying on this workspace.
---@param win table
---@param dir "l"|"r"|"u"|"d"
---@return boolean moved
local function focus_step(win, dir)
    if pos_of(win) then
        -- Screen-absolute, and it knows the band better than we do.
        return focus_moved(hl.dsp.layout("focus " .. dir))
    end
    -- Floating (or non-scrolling): no tape, so the generic geometric focus is
    -- the only thing that can find a neighbour.
    return focus_moved(hl.dsp.focus({ direction = dir }))
end

--- Reorder the focused column one step in screen direction `dir`, when the tape
--- runs that way. Returns whether the column actually moved.
---
--- This is the one place the tape's orientation cannot be avoided, because
--- `swapcol` is tape-relative where `focus` is screen-absolute. Measured:
--- `swapcol u` and `swapcol d` are rejected outright ("no target (invalid
--- direction?)"), and `swapcol r` on a vertical band moves the column DOWN the
--- screen. So the screen direction has to be translated into tape terms, which
--- is what tape_forward() is for.
---@param win table  known to be on a scrolling tape
---@param dir "l"|"r"|"u"|"d"
---@return boolean moved
local function swap_column(win, dir)
    local fwd = tape_forward(win)
    if not fwd then return false end
    local back = (fwd == "r") and "l" or "u"

    local msg
    if     dir == fwd  then msg = "swapcol r"
    elseif dir == back then msg = "swapcol l"
    else   return false end   -- across the tape: there is no column that way

    local before = pos_of(win)
    if not before then return false end

    hl.dispatch(hl.dsp.layout(msg))

    local after = pos_of(hl.get_active_window())
    if not after then return false end
    return before.col ~= after.col
end

------------------------------------------------------------------------------
-- Focus
------------------------------------------------------------------------------

--- Focus up/down; past the last window that way, the workspace above/below.
---@param dir "u"|"d"
function M.focus_vertical(dir)
    local win = hl.get_active_window()
    if win and focus_step(win, dir) then return end

    bands.step_focus(dir)
end

--- Focus left/right; past the last window that way, the monitor in that
--- direction.
---@param dir "l"|"r"
function M.focus_horizontal(dir)
    local win = hl.get_active_window()
    if win and focus_step(win, dir) then return end

    -- monitor_in_direction rather than a bare `{ monitor = dir }`: the
    -- directional selector fails inside the dispatcher without raising, which
    -- is what made this key do nothing at the end of a tape and nothing at all
    -- on an empty workspace. The rest of this file already routes through the
    -- helper; this was the call that never got converted.
    local target = monitor_in_direction(dir)
    if target then hl.dispatch(hl.dsp.focus({ monitor = target.name })) end
end

------------------------------------------------------------------------------
-- Moving the focused window
------------------------------------------------------------------------------

--- Move the window up/down; past the end of whatever it is in, send it to the
--- workspace above/below and follow it there.
---@param dir "u"|"d"
function M.move_vertical(dir)
    local win = hl.get_active_window()
    if not win then return end

    -- A floating window has no place on the tape to move within, so it goes
    -- straight to the next workspace.
    if pos_of(win) and window_moved(hl.dsp.window.move({ direction = dir })) then
        return
    end

    bands.step_move(dir)
end

--- Move the window left/right.
---
--- Handed straight to the layout, because between them the layout and
--- `binds.window_direction_monitor_fallback` (conf/input.lua) already do the
--- right thing at every step, on either band:
---
---   * something lies that way  -> the window goes there; if it had siblings in
---     its column it is expelled into a column of its own (PaperWM "expel"),
---   * nothing does             -> the layout declines, and the fallback hands
---     the window to the monitor in that direction.
---
--- Which is the H/L rule exactly: walk what is there, then cross to the screen
--- that way. SUPER+CTRL+SHIFT+<hjkl> forces the monitor hop unconditionally.
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

--- Reorder the column left/right along the tape; where nothing lies that way,
--- send the whole column to the monitor in that direction.
---
--- The handoff is deliberately to a MONITOR and never to a workspace: H/L is the
--- horizontal axis everywhere in this keymap and J/K is the workspace axis, and
--- a column doing something different from the window inside it on the same two
--- keys is what made this feel arbitrary. Sending a column to another workspace
--- is SUPER+CTRL+J/K.
---
--- On a vertical band there is no column to the left or right, so this crosses
--- to the next monitor on the first press -- which is the same thing H/L does
--- for focus and for a window there, and is the point of the rule.
---@param dir "l"|"r"
function M.column_horizontal(dir)
    local win = hl.get_active_window()
    if not win then return end

    -- A floating window is not on the tape, so it has no column to reorder and
    -- nothing to spill: leave it alone rather than surprising you with a move.
    if not pos_of(win) then return end

    if swap_column(win, dir) then return end

    local mon = monitor_in_direction(dir)
    if not mon then return end

    local ws = mon.active_workspace
    if ws and ws.id then move_column(win, ws.id) end
end

--- Reorder the column up/down along the tape; where nothing lies that way, send
--- the whole column to the workspace above/below, clamped at the band edge
--- exactly as a focus or window step is.
---
--- On a horizontal band nothing lies up or down, so this is the workspace move
--- on the first press, as it always was. On a vertical band it walks the tape
--- first, which is J/K's rule: exhaust the local structure, then the workspace.
---@param dir "u"|"d"
function M.column_vertical(dir)
    local win = hl.get_active_window()
    if not win then return end

    if pos_of(win) and swap_column(win, dir) then return end

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
