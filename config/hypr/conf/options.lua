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

-- Default width of a new column, as a fraction of the monitor. A band in
-- host.lua overrides this for its own monitor -- a portrait screen wants halves
-- or the whole width where an ultrawide wants a third -- and lib/colwidth.lua is
-- what makes that per-monitor value stick. This is the value monitors with no
-- band of their own get.
COLUMN_WIDTH = 0.333

------------------------------------------------------------------------------
-- Pointer
------------------------------------------------------------------------------

-- Two-finger scrolling that moves the *content* rather than the viewport, i.e.
-- the phone/macOS direction. This is a touchpad-only setting -- libinput
-- applies it to touchpad devices, never to a wheel -- so it is safe to leave
-- on for every machine: a desktop simply has no device it applies to, and a
-- laptop gets the direction that matches its trackpad gestures.
TOUCHPAD_NATURAL_SCROLL = true

-- Cursor theme. Bibata is what ~/repos/dots already installs and what is on
-- this machine; anything under /usr/share/icons or ~/.icons with a
-- cursors/ directory works. Set to "" to leave the theme alone and inherit
-- whatever the system default is.
CURSOR_THEME = "Bibata-Modern-Classic"
CURSOR_SIZE  = 24

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

-- Tightened from the 5/20 carried over from ~/repos/dots. The outer gap is
-- what you see the blurred wallpaper through, so it has a job -- but 20px on
-- every edge costs 40px of a column's width and reads as padding rather than
-- as framing. 10 still shows the wallpaper between windows and the screen
-- edge; the inner gap only has to keep two borders from touching.
--
-- Concretely, on the 3440px ultrawide: a third-width column goes from 1107px
-- of usable space to 1127px, and three of them stop looking like a form.
GAPS_IN  = 4
GAPS_OUT = 10
BORDER   = 2

-- Nearly square, down from 8. A rounded card reads as a surface you are meant
-- to admire; a 2px corner reads as a frame around a terminal, which is what
-- these windows mostly are. It also stops fighting the border: the focused
-- window's border is a two-colour gradient (conf/look.lua), and a gradient
-- following a wide radius spends most of its length in the corners.
--
-- Not 0. A hard corner shows every stair-step of the border's diagonal, and at
-- 2 the anti-aliasing has something to work with while the silhouette still
-- reads as square.
ROUNDING = 2

-- The short, non-bouncy set defined in conf/look.lua: nothing longer than
-- ~150ms, no overshoot, and no animation at all on anything that happens while
-- you type. Motion here is telling you where the tape went -- with a scrolling
-- layout, a column that teleports is genuinely harder to follow than one that
-- slides. Blur is already on, so the incremental GPU cost of animating is
-- small; set to false if you want the old instant behaviour back.
ANIMATIONS = true
