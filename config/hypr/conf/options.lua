-- conf/options.lua -- everything you are likely to want to change lives here.
--
-- These are globals on purpose: Hyprland gives each require()d file its own
-- error boundary but they share one global table, so later files can read them.

------------------------------------------------------------------------------
-- Programs
------------------------------------------------------------------------------

-- `-1` makes kitty a single instance: new windows attach to the running
-- process instead of starting another. Carried over from ~/repos/dots.
TERMINAL     = "kitty -1"
FILE_MANAGER = "nautilus"
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

KB_LAYOUT  = "se"
KB_VARIANT = ""
-- Caps as an additional Ctrl, carried over from ~/repos/dots. ("caps:escape"
-- is the other common vim choice; you picked Ctrl, so Ctrl it is.)
KB_OPTIONS = "caps:ctrl_modifier"

------------------------------------------------------------------------------
-- Workspaces
------------------------------------------------------------------------------

-- Workspaces are organised in per-monitor bands: monitor id N owns workspaces
-- N*WORKSPACE_BAND+1 .. N*WORKSPACE_BAND+WORKSPACE_BAND. Ten per monitor, so
-- the number keys map one-to-one (1..9 then 0).
--
-- The per-machine band table (which monitor, which scroll direction, which
-- column width) is the WSBANDS global from host.lua -- see
-- config/hypr/host.lua.example. conf/workspaces.lua builds the rules from it.
WORKSPACE_BAND = 10

------------------------------------------------------------------------------
-- Behaviour toggles
------------------------------------------------------------------------------

-- Tap SUPER on its own to open the launcher.
--
-- false = use the plain release bind in conf/binds.lua, which is what the
-- wiki documents for binding a bare modifier and what ~/repos/dots has been
-- running. Leave it here.
--
-- true  = use lib/supertap.lua instead, which watches raw key events and
-- requires the tap to be quick and uninterrupted. Only worth switching on if
-- the release bind turns out to also fire after ordinary SUPER chords (open
-- the launcher, press SUPER+J, release SUPER -- see TESTING.md section 3).
SUPER_TAP_ENABLED = false
SUPER_TAP_MS      = 250 -- max press-to-release time still counted as a "tap"

-- Reveal the bar while a Noctalia panel is open, hide it again on close.
BAR_FOLLOWS_PANELS = true

------------------------------------------------------------------------------
-- Look
------------------------------------------------------------------------------

-- Carried over from ~/repos/dots. The generous outer gap earns its keep here:
-- it is what you see the blurred wallpaper through.
GAPS_IN  = 5
GAPS_OUT = 20
BORDER   = 2
ROUNDING = 10

-- Animations are off in ~/repos/dots. Kept off: it is the most consistent
-- choice for a setup whose whole point is not pulling your eye around. Set to
-- true for the short, non-bouncy set defined in conf/look.lua.
ANIMATIONS = false
