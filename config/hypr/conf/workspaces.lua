-- conf/workspaces.lua -- one workspace band per monitor.
--
-- Adopted from ~/repos/dots, because the band model does something the naive
-- "N persistent workspaces per monitor" version cannot: it carries a scrolling
-- *direction* and column width per band. A portrait monitor can scroll down
-- while a landscape one scrolls right, at the same time.
--
-- Only the direction is a workspace rule, though. See lib/colwidth.lua for why
-- the width has to be applied from an event instead.
--
-- Monitor id N owns workspaces N*BAND+1 .. N*BAND+BAND, so the ids alone say
-- which monitor a workspace belongs to and a workspace never migrates.
--
-- The band table is machine-specific (monitor names and ids), so it comes from
-- host.lua as the global WSBANDS -- see the note in hyprland.lua. The fallback
-- below is what a host with no host.lua gets: one band on whichever monitor
-- Hyprland picks.

local bands = WSBANDS or {
    { base = 0, direction = "right", column_width = COLUMN_WIDTH },
}

for _, band in ipairs(bands) do
    for n = 1, WORKSPACE_BAND do
        hl.workspace_rule({
            workspace = tostring(band.base + n),
            monitor   = band.monitor,

            -- The first workspace of each band is that monitor's home, so a
            -- fresh login lands somewhere predictable on every screen.
            default   = (n == 1),

            -- Per-band scroll axis: this is the whole reason for the band model,
            -- and the one layout option the scrolling layout does read from a
            -- workspace rule. `column_width` belongs here too and is silently
            -- ignored -- lib/colwidth.lua supplies it instead.
            layout_opts = {
                direction = band.direction,
            },
        })
    end
end

-- The other half of a band: its default column width, which no workspace rule
-- can express. Set up after the rules so the two are read from the same table.
require("lib.colwidth").setup()
