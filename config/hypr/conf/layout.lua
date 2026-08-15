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
        -- One window on a workspace fills the screen. Two share it. That is
        -- the whole point of a focused work setup.
        fullscreen_on_one_column = true,

        -- Default column width as a fraction of the monitor.
        column_width = 0.5,

        -- 1 = fit the focused column into view rather than always centring it.
        -- Centring on every focus change makes wide monitors feel seasick.
        focus_fit_method = 1,

        follow_focus       = true,
        follow_min_visible = 0.4,

        -- Cycled by SUPER+W / SUPER+SHIFT+W.
        explicit_column_widths = "0.333, 0.5, 0.667, 1.0",

        -- Both must stay false. Wrapping would make the tape loop around
        -- instead of reporting an edge, and the edge is exactly the signal
        -- conf/binds.lua uses to hand off to the next monitor or workspace.
        wrap_focus   = false,
        wrap_swapcol = false,

        -- New windows appear to the right and the tape scrolls rightwards.
        direction = "right",
    },
})
