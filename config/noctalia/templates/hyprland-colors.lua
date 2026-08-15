-- TEMPLATE -- rendered by Noctalia into ~/.config/hypr/generated/colors.lua
-- whenever the palette changes. Do not edit the rendered copy; edit this one.
--
-- Noctalia has no built-in Hyprland template, so this is how window borders
-- get to follow the wallpaper palette. hyprland.lua requires the rendered file
-- last, so these values win over the fallbacks in conf/look.lua.
--
-- {{ ... }} is Noctalia's template syntax. Available colour roles and formats
-- are listed at https://docs.noctalia.dev/noctalia/theming/templates/

hl.config({
    general = {
        col = {
            -- The focused window is the only thing on screen that should draw
            -- the eye, so it gets the palette's strongest accent.
            active_border   = "rgb({{ colors.primary.default.hex_stripped }})",

            -- Unfocused borders sit just above the background: present enough
            -- to delimit a column, quiet enough to ignore. The trailing 80 is
            -- ~50% alpha.
            inactive_border = "rgba({{ colors.outline_variant.default.hex_stripped }}80)",
        },
    },
})
