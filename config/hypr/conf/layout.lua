-- conf/layout.lua -- Hyprland's built-in scrolling layout.
--
-- Mental model (same as niri / PaperWM):
--
--   * A workspace is an infinite horizontal tape of COLUMNS.
--   * A column holds one or more windows stacked vertically.
--   * H / L walk the tape.  J / K walk within a column.
--   * Workspaces stack vertically per monitor; monitors sit side by side.
--
-- So "off the top/bottom of a column" means the next workspace, and "off the
-- left/right end of the tape" means the next monitor. conf/binds.lua wires
-- that up; this file just sets the layout's own behaviour.

hl.config({
    scrolling = {
        -- Off, as in ~/repos/dots: with column_width 0.333 you want a lone
        -- window to keep its third, not snap to the whole screen every time
        -- you close its neighbours.
        fullscreen_on_one_column = false,

        -- Default width of a new column. This is the only place the scrolling
        -- layout reads it from -- a workspace rule's layout_opts carries
        -- `direction` but not this -- so lib/colwidth.lua rewrites it as focus
        -- moves between monitors to give the bands a width of their own. See the
        -- header of that file.
        column_width = COLUMN_WIDTH,

        -- 1 = fit the focused column into view rather than always centring it.
        -- Centring on every focus change makes wide monitors feel seasick.
        focus_fit_method = 1,

        follow_focus       = true,
        follow_min_visible = 0.4,

        -- Cycled by SUPER+PLUS / SUPER+MINUS. Six steps, from ~/repos/dots.
        explicit_column_widths = "0.25, 0.333, 0.5, 0.667, 0.75, 1.0",

        -- Both must stay false. Wrapping would make the tape loop around
        -- instead of reporting an edge, and the edge is exactly the signal
        -- conf/binds.lua uses to hand off to the next monitor or workspace.
        wrap_focus   = false,
        wrap_swapcol = false,

        -- New windows appear to the right and the tape scrolls rightwards.
        direction = "right",
    },
})
