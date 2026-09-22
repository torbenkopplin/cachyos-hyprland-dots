-- conf/workspaces.lua -- the workspace rules.
--
-- Two shapes, and WSBANDS in host.lua decides which. It is machine-specific
-- (monitor names and ids), so it cannot be tracked -- see the note in
-- hyprland.lua.
--
-- WITHOUT it, which is the default: one unpinned set of WORKSPACE_BAND
-- workspaces shared by every monitor. Nothing names a monitor, so nothing is
-- tied to one, and pulling a cable moves that screen's workspaces to whatever
-- is left with their numbers intact. That is the point -- work on the external,
-- unplug it, carry on on the built-in panel with the same number keys and
-- nothing to move by hand. Decision 025.
--
-- WITH it, one band per monitor: monitor N owns N*BAND+1 .. N*BAND+BAND, the
-- ids alone say which monitor a workspace belongs to, and a workspace returns
-- to its own screen when that screen comes back. The band model also carries a
-- scrolling *direction* and column width per monitor, which the shared set has
-- no way to express -- a portrait screen can scroll down while a landscape one
-- scrolls right, at the same time. Worth it for a fixed desk; the wrong trade
-- for a laptop that meets a different screen every week.
--
-- Only the direction is a workspace rule, though. See lib/colwidth.lua for why
-- the width has to be applied from an event instead.

-- The fallback is a single band based at 0 with no `monitor`, which is what
-- makes the shared set shared: a rule that names no monitor pins nothing.
-- lib/ws.lua bases its arithmetic at 0 to match.
local bands = WSBANDS or {
    { base = 0, direction = "right", column_width = COLUMN_WIDTH },
}

for _, band in ipairs(bands) do
    for n = 1, WORKSPACE_BAND do
        hl.workspace_rule({
            workspace = tostring(band.base + n),
            monitor   = band.monitor,

            -- The first workspace of each band is that monitor's home, so a
            -- fresh login lands somewhere predictable on every screen. With no
            -- bands there is one such rule and it names no monitor, which is
            -- Hyprland's own default anyway -- harmless, and it keeps the two
            -- shapes building from the same loop.
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
