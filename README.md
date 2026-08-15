# cachyos-hyprland-dots

A keyboard-first, distraction-free Hyprland setup for CachyOS, based on
[CachyOS/cachyos-hypr-noctalia](https://github.com/CachyOS/cachyos-hypr-noctalia).

- **Hyprland 0.55+ Lua config** — `hyprland.lua` + `conf/` + `lib/`.
- **Built-in scrolling layout** — no plugins, no `hyprpm`.
- **niri / PaperWM navigation** — `hjkl` moves focus, and running out of windows
  continues into the next workspace (vertically) or the next monitor
  (horizontally) instead of stopping dead.
- **A bar you summon** — hidden while you work, revealed when a shell panel opens.
- **System control from the launcher** — audio devices, Bluetooth, networks and
  power profiles, all without a mouse.

---

## Layout model

Borrowed wholesale from niri, because it is the model that makes `hjkl`
navigation total — every direction always means something:

```
                    monitor 1                     monitor 2
              ┌───────────────────────┐     ┌──────────────────────┐
   ws 1       │  col0   col1   col2 ▸ │     │  col0   col1  ▸      │
              ├───────────────────────┤     ├──────────────────────┤
   ws 2       │  col0   col1 ▸        │     │  col0 ▸              │
              ├───────────────────────┤     ├──────────────────────┤
   ws 3       │  ...                  │     │  ...                 │
              └───────────────────────┘     └──────────────────────┘
                        │                             │
             K/J walk workspaces          H/L crosses to the next monitor
```

- A **workspace** is an infinite horizontal tape of **columns**.
- A **column** holds one or more windows stacked vertically.
- **Workspaces stack vertically**, per monitor. **Monitors sit side by side.**

So `J` means "down": down the column, and when the column runs out, down to the
next workspace. `L` means "right": right along the tape, and when the tape runs
out, right onto the next monitor. `SUPER+CTRL` does the same while dragging the
window along.

---

## Keymap

`SUPER` throughout, written `M`.

### Navigation

| Key | Action |
|---|---|
| `M + H` / `L` | Focus left / right along the tape → next **monitor** at the edge |
| `M + J` / `K` | Focus down / up within the column → next **workspace** at the edge |
| `M + CTRL + H/J/K/L` | Move the focused window, with the same handoff |
| `M + CTRL + SHIFT + H/L` | Send window to the monitor left / right, unconditionally |
| `M + arrows` | Same as `hjkl` |
| `M + Tab` | Window switcher |

### Arranging the tape

| Key | Action |
|---|---|
| `M + SHIFT + H` / `L` | Swap this column with its neighbour |
| `M + ,` | Consume — pull the next window into this column |
| `M + .` | Expel — push this window out into its own column |
| `M + SHIFT + .` | Promote to a new column |
| `M + [` / `]` | Scroll the tape without moving focus |
| `M + Z` | Bring the focused column back into view |
| `M + SHIFT + Z` | Scroll lock — focus moves, the tape stays put |

### Sizing

| Key | Action |
|---|---|
| `M + W` / `SHIFT + W` | Cycle column width presets (⅓, ½, ⅔, full) |
| `M + -` / `=` | Narrow / widen by 5% |
| `M + SHIFT + F` | Expand into whatever free space is left |
| `M + SHIFT + E` | Even out the visible columns |
| `M + R` | **Resize mode**: `hl` width, `jk` height, `Esc`/`Enter` to leave |

### Windows and workspaces

| Key | Action |
|---|---|
| `M + Q` / `SHIFT + Q` | Close / kill |
| `M + F` / `M` | Fullscreen / maximize |
| `M + V` | Toggle floating |
| `M + P` | Pin above workspaces |
| `M + G` | Toggle tab group |
| `M + 1…5` | Workspace *n* **on this monitor** |
| `M + SHIFT + 1…5` | Send window to workspace *n* on this monitor |
| `` M + ` `` | Previous workspace |
| `M + S` / `SHIFT + S` | Scratchpad: toggle / send to |

### Shell

| Key | Action |
|---|---|
| **tap `SUPER`** | **Launcher** |
| `M + Space` | Launcher (fallback, in case the tap detector misbehaves) |
| `M + A` | Control centre |
| `M + N` | Notifications |
| `M + X` | Clipboard history |
| `M + O` | Shell settings |
| `M + B` | Pin / unpin the bar |
| `M + CTRL + Escape` | Lock |
| `M + SHIFT + Escape` | Session menu |

### System control — straight into the launcher

| Key | Prefix | What you get |
|---|---|---|
| `M + CTRL + O` | `/aout` | Audio **o**utput device — switches default *and* moves live streams |
| `M + CTRL + I` | `/ain` | Audio **i**nput device |
| `M + CTRL + B` | `/bt` | Bluetooth — connect, disconnect, scan, radio |
| `M + CTRL + N` | `/net` | Networks — connect, disconnect, Wi-Fi in range, radio |
| `M + CTRL + P` | `/power` | Power profile, night light, caffeine |

Inside the launcher, `Ctrl+J` / `Ctrl+K` move the selection (plain `j`/`k` go
into the search box, since you are typing).

### Apps

| Key | Action |
|---|---|
| `M + Return` | kitty |
| `M + SHIFT + Return` | Floating kitty |
| `M + E` | File manager |
| `M + SHIFT + B` | Browser |
| `Print` / `M + Print` | Screenshot region / screen |
| `M + C` | Colour picker |

---

## Three things worth knowing

### Tapping SUPER is not a release-bind

The obvious way to bind a bare modifier is
`hl.bind("SUPER + SUPER_L", …, { release = true })`. That does not work when
`SUPER` is also your main modifier: Hyprland registers the release callback when
`SUPER_L` goes down and fires it unconditionally when it comes back up, with no
check for whether another key was pressed in between. Every `SUPER+J` would also
pop the launcher.

`lib/supertap.lua` instead watches `input.keyboard.key`, which Hyprland emits
*before* the keybind manager sees the event — so it observes every key, even
ones binds consume. Arm on `SUPER` down, disarm on any other key down, fire on
`SUPER` up if it was quick enough. `SUPER_TAP_MS` in `conf/options.lua` sets
"quick enough"; `SUPER_TAP_ENABLED = false` turns it off.

### The bar is event-driven, not timed

Noctalia's panels are layer-shell surfaces, and Hyprland emits `layer.opened` /
`layer.closed` with the surface. `lib/bar.lua` tracks the set of open
`noctalia-panel` / `noctalia-attached-panel` / `noctalia-window-switcher`
surfaces and calls `bar-show` / `bar-hide` as that set becomes non-empty or
empty. No polling, and no guessing how long you will spend in the launcher.

Notifications and OSDs are deliberately excluded — a notification must not drag
the bar on screen with it.

### Edges are read, not inferred from a failed dispatch

It is tempting to dispatch a focus move and check whether it returned
`ok = false`. That is unreliable here: the scrolling layout reports "no column
that way" as a *success* (it just re-centres), while "no row that way" is a
genuine `NOT_FOUND`. Only the vertical case would be detectable.

So `lib/nav.lua` reads the layout's own bookkeeping off `window.layout` instead
— `column.index`, `index_in_column`, `#column.windows` — and compares against
the column range on the workspace. Uniform, and it does not depend on that
asymmetry. This is why `scrolling.wrap_focus` and `wrap_swapcol` must stay
`false` and `general.no_focus_fallback` must stay `true`.

---

## Colours

One palette drives everything. Noctalia resolves it, then renders it into each
app's own config format through templates, and pokes the app to reload.

```
   wallpaper ──► Noctalia palette ──► templates ──► app configs ──► reload
                 (48 Material roles
                  + 22 terminal roles)
```

Set in `30-theme.toml`. `source = "wallpaper"` regenerates the palette from the
current wallpaper every time it changes; switch to `source = "builtin"` with
`builtin = "Gruvbox"` (or Nord, Kanagawa, Tokyo-Night…) if you would rather your
colours held still.

**What follows the palette, and how:**

| Target | Route | Live? |
|---|---|---|
| Bar, launcher, panels, lock screen | Noctalia itself | yes |
| **Terminal — already-open windows** | `terminal_live` user template → OSC sequences | yes |
| **Shell prompt, `ls`, `git`, vim, btop** | inherited from the 16 ANSI slots above | yes |
| kitty config (new windows) | `kitty` built-in | on restart |
| GTK 3 / GTK 4 apps | `gtk3` / `gtk4` built-ins | on restart |
| Qt apps (dolphin, ark) | `qt` built-in + `kcolorscheme` | on restart |
| btop | `btop` built-in | on restart |
| **Hyprland window borders** | `hyprland` user template → `hyprctl reload` | yes |

Two of those are ours rather than Noctalia's, and both are worth knowing about:

**Hyprland borders.** Noctalia ships no Hyprland template — window borders would
otherwise stay whatever `conf/look.lua` hardcodes. So
`templates/hyprland-colors.lua` renders a small Lua file to
`~/.config/hypr/generated/colors.lua`, which `hyprland.lua` `require`s *last*
(under `pcall`, since it does not exist until the first render) so it overrides
the fallbacks. The focused border becomes `primary`; unfocused becomes
`outline_variant` at 50%.

**Live terminal repaint.** The built-in `kitty` template rewrites kitty's
config, which only affects terminals started afterwards — change your wallpaper
and every terminal you already had open keeps the old colours. So
`templates/terminal-colors.sh` renders a script that pushes OSC colour
sequences into every pty you own. That is emulator-agnostic (works for foot,
ghostty, wezterm, alacritty too) and it is also how your *shell* gets themed:
prompts, `ls`, `git`, vim and btop all paint with those 16 ANSI slots, so
nothing needs per-tool configuration.

Drop the `terminal_live` entry from `40-templates.toml` if you would rather
terminals only changed on restart.

Useful commands:

```sh
noctalia theme --list-templates      # every template id available to you
noctalia msg templates-apply         # re-render without changing the theme
noctalia msg theme-mode-toggle       # dark <-> light
noctalia msg color-scheme-set builtin Gruvbox
```

---

## Install

```sh
git clone <this repo> ~/repos/cachyos-hyprland-dots
cd ~/repos/cachyos-hyprland-dots
./install.sh --dry-run   # look first
./install.sh
```

Files are symlinked, so edits in the repo are live immediately and `git diff`
shows your real config. Anything already in the way is moved to
`*.bak-<timestamp>` rather than deleted. `./install.sh --unlink` removes only
the links it created.

Symlinking is safe for both programs: Hyprland only ever reads its config, and
Noctalia only ever reads `~/.config/noctalia` — it writes GUI changes to
`~/.local/state/noctalia/settings.toml`, a different tree. That state file
loads *after* your config, so **a setting changed in the Noctalia GUI silently
wins over the same setting in these files.** If something here appears to be
ignored, look there first.

### Prerequisites

```sh
# core
sudo pacman -S hyprland noctalia kitty

# what the launcher providers shell out to
sudo pacman -S libpulse networkmanager bluez bluez-utils power-profiles-daemon

# nice to have
sudo pacman -S hyprpicker hyprlock hypridle satty
```

`~/.local/bin` must be on `PATH` — the launcher runs provider commands through
`sh -lc`.

Requires **Hyprland ≥ 0.55** for the Lua config and the built-in scrolling
layout. On 0.54 and earlier none of this loads.

---

## Layout of the repo

```
config/hypr/
  hyprland.lua        requires everything below, in order
  conf/
    options.lua       ← start here: apps, modifiers, workspace count, toggles
    env.lua           session environment
    look.lua          colours, gaps, animations
    input.lua         keyboard, touchpad, focus behaviour, gestures
    layout.lua        the scrolling layout
    rules.lua         window + layer rules
    workspaces.lua    persistent workspace stack, per monitor
    autostart.lua
    binds.lua         every keybind
  lib/
    nav.lua           niri/PaperWM directional focus and window movement
    supertap.lua      tap-SUPER launcher
    bar.lua           bar visibility driven by panel layer events
config/noctalia/
  00-shell.toml       shell behaviour, launcher, vim keys in shell surfaces
  10-bar.toml         the bar
  20-launcher.toml    the /aout /ain /bt /net /power providers
  30-theme.toml       palette source (wallpaper-derived by default)
  40-templates.toml   which apps the palette is rendered into
  templates/
    hyprland-colors.lua   window borders -> hypr/generated/colors.lua
    terminal-colors.sh    OSC repaint of already-open terminals
bin/
  noct-common.sh      shared helpers for the providers
  noct-audio          PipeWire sink/source switching
  noct-bluetooth      bluetoothctl
  noct-network        NetworkManager
  noct-power          power profiles, night light, caffeine
install.sh
TESTING.md            post-install checklist — start here on first boot
```

To change almost anything, start in `config/hypr/conf/options.lua`.

### Editor support

Hyprland ships Lua stubs at `/usr/share/hypr/stubs`; `config/hypr/.luarc.json`
already points lua-ls at them, so `hl.*` autocompletes and typos get flagged.
Until Hyprland is installed, expect `undefined global hl` warnings.
