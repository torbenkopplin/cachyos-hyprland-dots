-- TEMPLATE -- rendered by Noctalia into ~/.config/hypr/generated/colors.lua
-- whenever the palette changes. Do not edit the rendered copy; edit this one.
--
-- Noctalia's built-in `hyprland` id emits hyprland.conf syntax and this config
-- is Lua, so this template is how window borders get to follow the wallpaper
-- palette instead. hyprland.lua dofiles the rendered file last, so these values
-- win over the fallbacks in conf/look.lua.
--
-- {{ ... }} is Noctalia's template syntax. Available colour roles and formats
-- are listed at https://docs.noctalia.dev/noctalia/theming/templates/

hl.config({
    general = {
        col = {
            -- The focused window is the only thing on screen that should draw
            -- the eye, so it gets the palette's strongest accent -- as a
            -- gradient across the diagonal rather than a flat fill. Two roles
            -- that are already guaranteed to contrast with each other and with
            -- the surface, so this stays legible on any palette: primary is the
            -- accent, tertiary is the one chosen to sit against it.
            --
            -- The table form is Lua's. A single "rgb(a) rgb(b) 45deg" string is
            -- hyprland.conf syntax and is not parsed by a Lua config.
            --
            -- For a flat border instead, make this one string:
            --   active_border = "rgb({{ colors.primary.default.hex_stripped }})",
            active_border = {
                colors = {
                    "rgb({{ colors.primary.default.hex_stripped }})",
                    "rgb({{ colors.tertiary.default.hex_stripped }})",
                },
                angle = 45,
            },

            -- Unfocused borders are a hairline: present enough to delimit a
            -- column, quiet enough to ignore. The trailing 26 is ~15% alpha --
            -- deliberately far below the focused border, since telling the two
            -- apart at a glance is the border's entire job.
            inactive_border = "rgba({{ colors.outline_variant.default.hex_stripped }}26)",
        },
    },
})
