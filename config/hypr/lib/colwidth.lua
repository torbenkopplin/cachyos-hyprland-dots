-- lib/colwidth.lua -- keep the focused monitor's band column width in force.
--
-- WSBANDS gives every band a `column_width`, and putting it in the workspace
-- rule's layout_opts -- which is where it belongs and where `direction` works
-- from -- does nothing at all. Hyprland 0.56.2's scrolling layout reads
-- `direction` out of a workspace rule but takes the width only from the global
-- `scrolling:column_width`, so every band got the one value in conf/layout.lua:
-- a third, on a portrait screen that wanted halves. (Measured 2026-08-18 on the
-- HDMI band, whose `column_width = 0.5` produced a 0.333 column.)
--
-- There is no per-monitor form of that option, so this supplies one: the value
-- is only ever consulted when a new column is created, and a new column appears
-- on the monitor you are looking at -- so setting the global as focus moves
-- between monitors is indistinguishable from the option being per-band, without
-- a poll or a timer anywhere.
--
-- What it deliberately does NOT do is touch columns that already exist. This
-- runs on every monitor focus change, and re-deriving widths there would undo
-- the resizing you did by hand (SUPER+PLUS, SUPER+R) every time you glanced at
-- the other screen.

local M = {}

--- The column width band for `mon`, or nil to leave the default alone.
---
--- `mon` is not a plain table -- monitors arrive as userdata with an __index --
--- so this reads fields off it rather than type-checking it.
---@param mon table|userdata|nil
---@return number|nil
local function width_of(mon)
    if not mon or type(WSBANDS) ~= "table" then return nil end

    local name = mon.name
    for _, band in ipairs(WSBANDS) do
        if band.monitor == name and type(band.column_width) == "number" then
            return band.column_width
        end
    end

    return nil
end

--- Apply a monitor's band width, falling back to the configured default for a
--- monitor that has no band or no width of its own.
---
--- The monitor has to be passed in. `monitor.focused` fires *before* the switch
--- is recorded, so hl.get_active_monitor() inside the handler still answers with
--- the monitor you just left -- which put every width exactly one focus change
--- behind. The event's own argument is the monitor being focused; only the
--- startup call has to ask.
---@param mon table|userdata|nil
function M.apply(mon)
    local width = width_of(mon or hl.get_active_monitor()) or COLUMN_WIDTH
    if type(width) ~= "number" then return end

    hl.config({ scrolling = { column_width = width } })
end

function M.setup()
    -- Nothing to follow on a machine with no bands: conf/layout.lua's value is
    -- already the whole story, and the fallback would just rewrite it.
    if type(WSBANDS) ~= "table" then return end

    hl.on("monitor.focused", function(mon) M.apply(mon) end)

    -- The compositor may not have monitors yet when this file is first read, so
    -- the initial value comes from whichever of these arrives: a reload runs
    -- with monitors up and applies immediately, a cold start does it here.
    hl.on("hyprland.start", function() M.apply() end)
    pcall(M.apply)
end

return M
