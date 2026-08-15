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
| `M + SHIFT + G` | Cycle frosted glass level |
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
| `M + CTRL + T` | `/theme` | Colour scheme — wallpaper, built-in, or your own |

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

### Switching scheme

`/theme` in the launcher (**`SUPER+CTRL+T`**) lists everything and marks the
active one with `●`:

- **your own palettes** — anything in `~/.config/noctalia/palettes/`.
  **noirblaze** ships there, ported from `~/.config/nvim/colors/noirblaze.lua`
  so the desktop matches the editor. Dark only, like the original.
- **built-ins** — Ayu, Catppuccin, Dracula, Eldritch, Gruvbox, Kanagawa,
  Noctalia, Nord, Rosé Pine, Tokyo-Night.
- **wallpaper-derived** — under any of nine generators (Tonal Spot, Content,
  Monochrome, Vibrant, Muted…).
- dark/light toggle, and a re-apply for when you have edited a template.

Drop another palette JSON into that folder and it appears in the list with no
edit to any script. The starting point is set in `30-theme.toml`; picking from
the launcher persists it.

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

### Frosted glass

On by default, and tied to the scheme. `bin/noct-glass` runs from Noctalia's
`colors_changed` hook, so the level follows whatever you pick in `/theme` —
levels live in `config/noctalia/glass.conf`, keyed by scheme. **`SUPER+SHIFT+G`**
cycles opaque → light → default → heavy as a temporary override.

The effect is not "make windows transparent". Compositor opacity fades a
window's *text* along with its background, which is unreadable for work. Real
frosted glass is the app drawing a translucent background while the compositor
blurs what is behind it:

| Surface | Frosted? | How |
|---|---|---|
| kitty | yes | `background_opacity` + Hyprland blur behind it |
| Noctalia bar and panels | yes | `background_opacity` + the layer blur rule |
| GTK / Qt apps | **no** | they paint an opaque background and offer no way not to |

That last row is why "every app possible" is a genuinely short list. If you
want it anyway for a specific app, add its class to `GLASS_WINDOWS` in
`conf/rules.lua` — it is left empty rather than populated, because the trade is
translucent body text.

Two consequences worth knowing:

- **Colour changes apply live; glass changes need a new terminal.** kitty reads
  `background_opacity` at startup, whereas colours arrive over OSC sequences.
- **Neovim will look opaque inside a transparent kitty.** Your `noirblaze.lua`
  paints `Normal` with `bg = #121212`. Making it `bg = "none"` fixes that — but
  it is a change in *your nvim repo*, not this one, so it has not been made.
  `config/kitty/README.md` has the snippet and the trade-off.

Useful commands:

```sh
noctalia theme --list-templates      # every template id available to you
noctalia msg templates-apply         # re-render without changing the theme
noctalia msg theme-mode-toggle       # dark <-> light
noctalia msg color-scheme-set builtin Gruvbox
noct-glass show                      # level currently in effect
```

---

## Install

```sh
git clone <this repo> ~/repos/cachyos-hyprland-dots
cd ~/repos/cachyos-hyprland-dots
./install.sh --all --dry-run   # look first, always
./install.sh --all
```

| Flag | Does |
|---|---|
| *(none)* | Link configs into `~/.config` and scripts into `~/.local/bin` |
| `--packages` | Install everything below via pacman, an AUR helper, and npm |
| `--nvim` | Clone `torbenkopplin/nvimrc` to `~/.config/nvim` |
| `--browsers` | Install browser policies and `user.js` (needs sudo) |
| `--all` | All of the above, in dependency order |
| `--dry-run` | Print what any of the above would do |
| `--unlink` | Remove only the links this script created |

Run `--browsers` again after launching Firefox and Zen once — their profile
directories have generated names and do not exist until first launch, so
`user.js` cannot be placed before then. The script tells you when this applies.

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

### What `--packages` installs

| Group | Why |
|---|---|
| hyprland, portals, kitty, qt6ct, hypr{picker,lock,idle}, fonts | the session itself |
| noctalia, satty | the shell and its screenshot editor |
| libpulse, networkmanager, bluez, power-profiles-daemon | the backends `/aout` `/ain` `/bt` `/net` `/power` shell out to — without these those providers just say "not installed" |
| neovim, git, base-devel, nodejs, npm | editor, and what mason needs to build its servers |
| fish, fisher, fastfetch | the login shell and its plugin manager |
| starship, eza, rustup | what your fish config calls: the prompt, `ls`/`lt`, and the cargo env `conf.d/rustup.fish` sources |
| claude-code | tried as a package, npm as fallback |
| ripgrep, fd, fzf, bat | what the neovim config calls out to (fzf-lua and its previewer) |
| yazi, ffmpeg, p7zip, jq, poppler, imagemagick, chafa | file manager and its preview pipeline |
| brave-bin, zen-browser-bin, chromium, firefox | browsers |
| eslint, mermaid-cli (npm, into `~/.local`) | used directly by the neovim config |

**LSP servers are not installed.** Your neovim config already installs `tsgo`,
`eslint`, `vimls`, `lua_ls` and `lemminx` through mason on first launch, and a
second copy on `PATH` would only cause confusion. That is also why `nodejs` is
in the list — mason needs it.

**nvm comes from `fish_plugins`, not from a package.** `nvm` proper is a bash
shell function — `nvm use` mutates the calling shell, so there is no binary to
put on `PATH` and it cannot work under fish. Your config already uses
`jorgebucaran/nvm.fish`, the native reimplementation; the installer runs
`fisher update` to restore it. System `nodejs` is installed alongside it
because mason needs a `node` on `PATH` when neovim is launched from the app
launcher, where nothing has sourced a version manager.

Package names could not be verified against the CachyOS repos from here, so
a failed batch retries package-by-package and anything unresolved is listed in
a warning summary at the end. **Read that summary** rather than assuming a
clean run.

`~/.local/bin` must be on `PATH` — the launcher runs provider commands through
`sh -lc`.

Requires **Hyprland ≥ 0.55** for the Lua config and the built-in scrolling
layout. On 0.54 and earlier none of this loads. Neovim must be recent enough
for `vim.pack` (0.12+), which your config uses.

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
  palettes/
    noirblaze.json        your neovim colourscheme, as a desktop palette
  templates/
    hyprland-colors.lua   window borders -> hypr/generated/colors.lua
    terminal-colors.sh    OSC repaint of already-open terminals
config/kitty/
  kitty.conf          carried over; theme + glass come from generated includes
  search.py           third-party kitten (GPLv3), scroll_mark.py
  README.md           what is not tracked here, and why
config/fish/
  config.fish         carried over from ~/dotfiles, CHANGED lines marked
  auto-Hypr.fish      tty1 autostart, adapted for uwsm
  fish_plugins        fisher restores the plugins from this
  conf.d/             frozen theme colours, rustup env
  README.md           what changed, what is not tracked, and why
config/starship/
  starship.toml       carried over
config/yazi/
  yazi.toml           carried over from the Ubuntu setup
browsers/
  README.md           what is versioned here, and what deliberately is not
  brave|chromium|firefox/policies.json
  firefox|zen/user.js
bin/
  noct-common.sh      shared helpers: the title -> payload map, sanitising
  noct-audio          PipeWire sink/source switching
  noct-bluetooth      bluetoothctl
  noct-network        NetworkManager
  noct-power          power profiles, night light, caffeine
  noct-theme          colour scheme picker
  noct-glass          frosted glass level, per scheme
install.sh
TESTING.md            post-install checklist — start here on first boot
```

To change almost anything, start in `config/hypr/conf/options.lua`.

### Editor support

Hyprland ships Lua stubs at `/usr/share/hypr/stubs`; `config/hypr/.luarc.json`
already points lua-ls at them, so `hl.*` autocompletes and typos get flagged.
Until Hyprland is installed, expect `undefined global hl` warnings.
