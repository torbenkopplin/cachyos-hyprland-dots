-- lib/design.lua -- a design's window shape, over the tracked look.
--
-- bin/noct-design writes the active design's [hyprland] table to
-- generated/design.lua as a plain `return { ... }`. hyprland.lua hands it here
-- after generated/colors.lua, so a flat border can use the palette that file
-- defines. A key the design leaves out keeps conf/options.lua's value.

local M = {}

--- "rgba(rrggbbaa)" for a palette role at `alpha` (0..1).
---@param hex string
---@param alpha number
---@return string
local function rgba(hex, alpha)
    return string.format("rgba(%s%02x)", hex, math.floor(alpha * 255 + 0.5))
end

--- Apply a design's [hyprland] table.
---@param d table
function M.apply(d)
    local general, decoration, col = {}, {}, {}

    if d.gaps_in     then general.gaps_in     = d.gaps_in     end
    if d.gaps_out    then general.gaps_out    = d.gaps_out    end
    if d.border_size then general.border_size = d.border_size end
    if d.rounding    then decoration.rounding = d.rounding    end

    -- PALETTE is nil until Noctalia has rendered colors.lua once with the
    -- current template; the gradient from that file then stays.
    local p = PALETTE
    if p then
        if d.border == "flat" then col.active_border = "rgb(" .. p[d.border_color or "primary"] .. ")" end
        if d.inactive_alpha then col.inactive_border = rgba(p.outline_variant, d.inactive_alpha) end
    end
    if next(col) then general.col = col end

    local cfg = {}
    if next(general)    then cfg.general    = general    end
    if next(decoration) then cfg.decoration = decoration end
    if next(cfg) then hl.config(cfg) end
end

return M
