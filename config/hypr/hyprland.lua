-- ~/.config/hypr/hyprland.lua
--
-- Distraction-free, keyboard-first Hyprland config.
-- Scrolling layout + Noctalia shell, with niri/PaperWM navigation semantics.
--
-- Requires Hyprland >= 0.55 (Lua configs, built-in scrolling layout).
-- Paths in require() are always relative to THIS file's directory.

require("conf.options")   -- must be first: defines the globals everything else reads

-- Where the untracked, machine-local files live.
--
-- This has to be an absolute path, and it has to be resolved from the
-- environment rather than from this file's location. Hyprland resolves
-- require() against the *realpath* of the config, which is the repo checkout
-- when installed as a symlink -- so nothing written next to the symlink is
-- reachable through require(). XDG_CONFIG_HOME is honoured because that is what
-- Noctalia expands when it renders into this directory (40-templates.toml).
local CONFIG_HOME = os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")

-- Machine-specific settings: monitors, GPU/host environment, and the WSBANDS
-- table conf/workspaces.lua builds workspaces from. Pattern adopted from
-- ~/repos/dots, where hosts/<hostname>/ supplies the file.
--
-- dofile rather than require so `hyprctl reload` always re-reads it, and pcall
-- so a machine without one still gets a working session (Hyprland then
-- auto-configures monitors and workspaces.lua falls back to a single band).
pcall(dofile, CONFIG_HOME .. "/hypr/host.lua")
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
-- dofile with an absolute path, not require("generated.colors"): these files are
-- written into the real config directory, which is not where require() looks
-- when this config is a symlink into the repo (see CONFIG_HOME above). pcall is
-- not optional either -- the file legitimately does not exist until Noctalia has
-- rendered a palette once, i.e. on a fresh install, and an uncaught error here
-- would kill the rest of this config.
pcall(dofile, CONFIG_HOME .. "/hypr/generated/colors.lua")

-- Frosted glass level for the active scheme, written by bin/noct-glass from
-- Noctalia's colors_changed hook. Same reasoning as above: absolute path so it
-- is found at all, pcall because it is absent until the first render.
pcall(dofile, CONFIG_HOME .. "/hypr/generated/glass.lua")
