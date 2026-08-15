-- conf/options.lua -- everything you are likely to want to change lives here.
--
-- These are globals on purpose: Hyprland gives each require()d file its own
-- error boundary but they share one global table, so later files can read them.

------------------------------------------------------------------------------
-- Programs
------------------------------------------------------------------------------

TERMINAL     = "kitty"
FILE_MANAGER = "dolphin"
BROWSER      = "firefox"

-- The floating scratch terminal on SUPER+SHIFT+Return. It is launched under
-- its own class so conf/rules.lua can float, size and centre it; keep the two
-- in sync if you change terminal. (foot uses --app-id, alacritty --class,
-- ghostty --class.)
TERMINAL_FLOAT       = "kitty --class scratchterm"
TERMINAL_FLOAT_CLASS = "scratchterm"

-- uwsm keeps every app in its own systemd scope, so a crashing app can never
-- take the session down with it. Set to "" if you don't boot Hyprland via uwsm.
LAUNCH_PREFIX = "uwsm app -- "

-- Noctalia IPC entrypoint.
NOCT = "noctalia msg "

------------------------------------------------------------------------------
-- Keyboard
------------------------------------------------------------------------------

MOD = "SUPER"

KB_LAYOUT  = "us"
KB_VARIANT = ""
-- Caps Lock as a second Escape is the single highest-value remap for vim work.
-- Use "caps:escape" if you never want it to latch, "" to leave it alone.
KB_OPTIONS = "caps:escape"

------------------------------------------------------------------------------
-- Workspaces
------------------------------------------------------------------------------

-- Workspaces are created per monitor and made persistent, so SUPER+J/K can
-- always walk up and down a known stack instead of falling off into nothing.
-- Keep this small: a distraction-free setup wants few, meaningful workspaces.
WORKSPACES_PER_MONITOR = 5

------------------------------------------------------------------------------
-- Behaviour toggles
------------------------------------------------------------------------------

-- Tap SUPER on its own to open the launcher. Detection is time-bounded and
-- cancelled by any other key, so SUPER+J etc. never trigger it.
SUPER_TAP_ENABLED = true
SUPER_TAP_MS      = 250 -- max press-to-release time still counted as a "tap"

-- Reveal the bar while a Noctalia panel is open, hide it again on close.
BAR_FOLLOWS_PANELS = true

------------------------------------------------------------------------------
-- Look
------------------------------------------------------------------------------

GAPS_IN  = 4
GAPS_OUT = 8
BORDER   = 2
ROUNDING = 8

-- Dimming unfocused windows is the cheapest possible focus aid. 1.0 disables.
INACTIVE_OPACITY = 0.94
