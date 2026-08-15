-- conf/input.lua

hl.config({
    input = {
        kb_layout  = KB_LAYOUT,
        kb_variant = KB_VARIANT,
        kb_options = KB_OPTIONS,

        -- 2 = cursor focus is detached from keyboard focus; only a *click*
        -- moves keyboard focus. This is the setting that makes keyboard
        -- navigation stick: the tape scrolls under a stationary pointer
        -- constantly, and at the default (1) every scroll would silently
        -- reassign focus to whatever slid beneath the cursor.
        follow_mouse = 2,

        -- Don't jump focus around when a window is floated or re-tiled.
        float_switch_override_focus = 0,

        sensitivity = 0,

        repeat_rate  = 40,
        repeat_delay = 250,

        touchpad = {
            natural_scroll    = false,   -- as in ~/repos/dots
            disable_while_typing = true,
            clickfinger_behavior = true,
            scroll_factor     = 0.6,
        },
    },

    cursor = {
        -- Park the pointer instead of letting it hover over whatever the tape
        -- scrolled underneath it.
        hide_on_key_press = true,
        no_warps          = false,
        inactive_timeout  = 5,
    },

    binds = {
        -- Moving a window past the edge of a monitor hands it to the next one.
        -- conf/binds.lua relies on this for SUPER+CTRL+H/L.
        window_direction_monitor_fallback = true,

        workspace_back_and_forth = false,
        allow_workspace_cycles   = false,

        scroll_event_delay = 0,
        drag_threshold     = 10,
    },

    misc = {
        disable_hyprland_logo      = true,
        disable_splash_rendering   = true,
        force_default_wallpaper    = 0,
        -- Nothing may steal focus while you are typing. This is the single
        -- most important "distraction free" setting in the file.
        focus_on_activate          = false,
        -- Leaving a fullscreen window keeps its fullscreen state, so tabbing
        -- away and back doesn't reshuffle the tape.
        exit_window_retains_fullscreen = true,
        -- Don't let a stray pointer nudge steal the active monitor away from
        -- where SUPER+H/L just put it.
        mouse_move_focuses_monitor = false,
    },
})

------------------------------------------------------------------------------
-- Touchpad gestures.
--
-- Three fingers sideways scrolls the tape (the layout's own axis), four
-- fingers vertically walks the workspace stack -- the same mental model as
-- SUPER+H/L versus SUPER+J/K.
------------------------------------------------------------------------------

hl.gesture({ fingers = 3, direction = "horizontal", action = "scroll_move" })
hl.gesture({ fingers = 4, direction = "vertical",   action = "workspace" })
