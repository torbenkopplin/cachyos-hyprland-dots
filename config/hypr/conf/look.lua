-- conf/look.lua -- appearance. Quiet by default: the point is to notice the
-- focused window and nothing else.

hl.config({
    general = {
        gaps_in     = GAPS_IN,
        gaps_out    = GAPS_OUT,
        border_size = BORDER,

        col = {
            -- Fallbacks only. Noctalia's built-in hyprland template emits
            -- hyprland.conf syntax, which is no use to a Lua config, so
            -- borders are themed by our own user template instead: it renders
            -- hypr/generated/colors.lua from the palette, which hyprland.lua
            -- dofiles last and which therefore overrides these two lines.
            -- See config/noctalia/40-templates.toml.
            --
            -- The focused border is a two-colour gradient across the diagonal.
            -- A flat accent tells you where focus is; a gradient tells you the
            -- same thing while looking like something built rather than
            -- defaulted, and it costs nothing -- the border is one quad the
            -- compositor draws either way. The table form is the Lua one;
            -- "rgb(a) rgb(b) 45deg" in a single string is hyprland.conf syntax
            -- and is not parsed here.
            active_border = { colors = { "rgba(7f9cc4ff)", "rgba(c4a37fff)" }, angle = 45 },

            -- Unfocused borders are a hairline: enough to say where a column
            -- ends, not enough to compete. 0x26 is ~15% alpha -- the old 0xaa
            -- (67%) drew a visible frame around every window on screen, which
            -- is exactly the noise the gradient is supposed to stand out from.
            inactive_border = "rgba(2a2e3626)",
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

        -- Opacity and blur are fallbacks only. bin/noct-glass overwrites both
        -- from generated/glass.lua, which hyprland.lua loads last, using the
        -- frosted-glass level configured per colour scheme in
        -- ~/.config/noctalia/glass.conf.
        --
        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled = false, -- shadows on a scrolling tape are just noise
        },

        blur = {
            enabled        = true,
            size           = 8,
            passes         = 2,
            xray           = true,
            ignore_opacity = true,
            vibrancy       = 0.1696,
            popups         = true,
        },
    },

    animations = {
        enabled = ANIMATIONS,
    },
})

------------------------------------------------------------------------------
-- Animations: short, no bounce. Motion tells you where the tape went, then
-- gets out of the way.
--
-- Hyprland's speed is a DURATION in deciseconds -- speed = 3 is 300ms -- so
-- bigger is slower. The set below runs 100-250ms, which is roughly the range
-- where movement reads as continuous without being something you wait for.
-- The old values were 350-600ms: fine as decoration, too slow for a layout you
-- drive at typing speed, and long enough that two quick keypresses queue up.
--
-- Cost is negligible against the blur that is already on. These animate the
-- position and alpha of surfaces the compositor composites either way; nothing
-- here adds a render pass.
------------------------------------------------------------------------------

-- No overshoot in either curve: a window that springs past its target and
-- comes back is exactly the kind of motion this config exists to avoid.
hl.curve("snap",   { type = "bezier", points = { { 0.2, 1.0 }, { 0.3, 1.0 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 2.5, bezier = "snap" })
hl.animation({ leaf = "windows",       enabled = true, speed = 2.5, bezier = "snap" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 2,   bezier = "snap",   style = "popin 92%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.8, bezier = "linear", style = "popin 92%" })

-- The border is the focus indicator, so it is the one thing that should feel
-- instant: 100ms is enough to avoid a hard flicker and not enough to lag
-- behind hjkl held down.
hl.animation({ leaf = "border",        enabled = true, speed = 1,   bezier = "linear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 1.5, bezier = "linear" })

-- Workspaces slide vertically because that is the direction they are stacked
-- in (J/K walks them); a horizontal slide would fight the tape, which is what
-- H/L moves along.
hl.animation({ leaf = "workspaces",    enabled = true, speed = 2.5, bezier = "snap",   style = "slidevert" })

hl.animation({ leaf = "layers",        enabled = true, speed = 2,   bezier = "snap" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 2,   bezier = "snap",   style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5, bezier = "linear", style = "fade" })
