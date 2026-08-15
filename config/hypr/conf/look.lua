-- conf/look.lua -- appearance. Quiet by default: the point is to notice the
-- focused window and nothing else.

hl.config({
    general = {
        gaps_in     = GAPS_IN,
        gaps_out    = GAPS_OUT,
        border_size = BORDER,

        col = {
            -- Fallbacks only. Noctalia ships no Hyprland template, so borders
            -- are themed by our own user template instead: it renders
            -- hypr/generated/colors.lua from the palette, which hyprland.lua
            -- requires last and which therefore overrides these two lines.
            -- See config/noctalia/40-templates.toml.
            active_border   = "rgba(7f9cc4ff)",
            inactive_border = "rgba(2a2e36aa)",
        },

        resize_on_border = true,
        allow_tearing    = false,

        layout = "scrolling",

        -- Focus must not silently slide to some unrelated window when there is
        -- nothing in the direction you asked for. conf/binds.lua depends on
        -- this to decide when to hand off to a workspace or monitor instead.
        no_focus_fallback = true,
    },

    decoration = {
        rounding       = ROUNDING,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = INACTIVE_OPACITY,

        shadow = {
            enabled = false, -- shadows on a scrolling tape are just noise
        },

        blur = {
            enabled  = true,
            size     = 4,
            passes   = 2,
            vibrancy = 0.1696,
            -- Blur is here for Noctalia's panels, not for your terminals.
            popups   = true,
        },
    },

    animations = {
        enabled = true,
    },
})

------------------------------------------------------------------------------
-- Animations: short, linear-ish, no bounce. Motion should tell you where the
-- tape went, then get out of the way.
------------------------------------------------------------------------------

hl.curve("snap",   { type = "bezier", points = { { 0.2, 1.0 }, { 0.3, 1.0 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 4,   bezier = "snap" })
hl.animation({ leaf = "windows",       enabled = true, speed = 3.5, bezier = "snap" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 3,   bezier = "snap",   style = "popin 92%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 2.5, bezier = "linear", style = "popin 92%" })
hl.animation({ leaf = "border",        enabled = true, speed = 6,   bezier = "linear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3,   bezier = "linear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 3,   bezier = "snap",   style = "slidevert" })
hl.animation({ leaf = "layers",        enabled = true, speed = 4,   bezier = "snap" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,   bezier = "snap",   style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 3,   bezier = "linear", style = "fade" })
