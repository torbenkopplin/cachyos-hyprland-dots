-- ~/.config/hypr/hyprland.lua
--
-- Distraction-free, keyboard-first Hyprland config.
-- Scrolling layout + Noctalia shell, with niri/PaperWM navigation semantics.
--
-- Requires Hyprland >= 0.55 (Lua configs, built-in scrolling layout).
-- Paths in require() are always relative to THIS file's directory.

require("conf.options")   -- must be first: defines the globals everything else reads
require("conf.env")
require("conf.look")
require("conf.input")
require("conf.layout")
require("conf.rules")
require("conf.workspaces")
require("conf.autostart")
require("conf.binds")

-- Window border colours, rendered from the active Noctalia palette by the
-- user template in config/noctalia/40-templates.toml. Loaded LAST so it
-- overrides the fallback colours in conf/look.lua.
--
-- pcall is not optional here: a bare require() of a missing module throws a
-- real error in the calling file, which would kill the rest of this config.
-- The file legitimately does not exist until Noctalia has rendered a palette
-- once, i.e. on a fresh install.
pcall(require, "generated.colors")

-- Frosted glass level for the active scheme, written by bin/noct-glass from
-- Noctalia's colors_changed hook. Same pcall reasoning: absent until the first
-- render, and a bare require() of a missing module would kill this file.
pcall(require, "generated.glass")
