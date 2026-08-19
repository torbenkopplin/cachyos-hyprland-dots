-- conf/layout.lua -- Hyprland's built-in scrolling layout.
--
-- Mental model (same as niri / PaperWM):
--
--   * A workspace is an infinite tape of COLUMNS.
--   * A column holds one or more windows, stacked across the tape's axis.
--   * H / L walk whatever lies sideways, then hand off to the next MONITOR.
--   * J / K walk whatever lies up/down, then hand off to the next WORKSPACE.
--
-- Note "an infinite tape" and not "an infinite horizontal tape". `direction`
-- below is the default, and a workspace rule overrides it per band -- so a
-- portrait monitor scrolls DOWN while a landscape one scrolls right, and on that
-- monitor it is J/K that walk the tape and H/L that walk the column. See
-- conf/workspaces.lua, and host.lua for the bands themselves.
--
-- lib/nav.lua is what makes the two keys mean the same thing on both, and it
-- works this out from the compositor rather than from the band table -- it has to
-- hold on a laptop plugged into a monitor no config has ever named. conf/binds.lua
-- wires the keys up; this file just sets the layout's own behaviour.

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

        -- Default only: which way a new column goes, and therefore which way
        -- the tape runs. Per-band overrides live in the workspace rules
        -- (conf/workspaces.lua), which is the one layout option they can carry.
        direction = "right",
    },
})
