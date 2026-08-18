# cachyos-hyprland-dots

A keyboard-first, distraction-free Hyprland setup for CachyOS, based on
[CachyOS/cachyos-hypr-noctalia](https://github.com/CachyOS/cachyos-hypr-noctalia).

- **Hyprland Lua config** — `hyprland.lua` + `conf/` + `lib/`, no plugins.
- **Built-in scrolling layout** with **niri / PaperWM navigation**: `hjkl` moves
  focus, and running out of windows continues into the next workspace
  (vertically) or the next monitor (horizontally) instead of stopping dead.
- **A bar you summon** — hidden while you work, revealed when a shell panel
  opens.
- **One palette, everywhere** — wallpaper-derived, rendered into the terminal,
  GTK, Qt and the window borders, live.
- **System control from the launcher** — audio devices, Bluetooth, networks,
  power profiles and colour schemes, all without a mouse.

```sh
# fresh machine, one command
bash <(curl -fsSL https://raw.githubusercontent.com/torbenkopplin/cachyos-hyprland-dots/master/bootstrap.sh) --all

# already cloned
./install.sh --all          # or just ./install.sh to link configs only
./install.sh --dry-run      # see it first
```

Then copy `config/hypr/host.lua.example` to `~/.config/hypr/host.lua` and put
your monitors in it — that file is the only machine-specific one, and it is
never tracked.

---

## The keys that matter first

`SUPER` throughout, written `M`. **Arrows work anywhere `hjkl` does.**

| Key | Action |
|---|---|
| **tap `SUPER`** | Launcher |
| `M + H J K L` | Move focus — off the end of the tape goes to the next monitor, off the end of a column to the next workspace |
| `M + SHIFT + H J K L` | The same, dragging the window along |
| `M + 1…9`, `0` | Workspace *n* **on the monitor you are looking at** |
| `M + SHIFT + 1…9` | Send the window there |
| `M + T` / `Return` | Terminal |
| `M + BackSpace` / `Q` | Close window |
| `M + O` / `I` | Pull the next window into this column / push it back out |
| `M + +` / `-` | Cycle column width |
| `M + CTRL + T` | `/theme` — switch colour scheme |
| `M + W` | Wallpaper picker |
| `M + Escape` | Session menu |

`SHIFT` always means "bring the window with you". `CTRL` reorders columns
(`M + CTRL + H/L`) and, with a letter, opens the launcher already filtered to
one system-control provider: `O`utput, `I`nput, `B`luetooth, `N`etwork,
`P`ower, `T`heme.

**[→ the full keymap](docs/keymap.md)**

---

## How it fits together

```
                    monitor 1                     monitor 2
              ┌───────────────────────┐     ┌──────────────────────┐
   ws 1       │  col0   col1   col2 ▸ │     │  col0   col1  ▸      │
              ├───────────────────────┤     ├──────────────────────┤
   ws 2       │  col0   col1 ▸        │     │  col0 ▸              │
              └───────────────────────┘     └──────────────────────┘
                        │                             │
             K/J walk workspaces          H/L crosses to the next monitor
```

A workspace is an infinite horizontal tape of columns; a column is a vertical
stack of windows; workspaces stack vertically per monitor. Every direction
always means something, which is what makes `hjkl` navigation total.

Each monitor owns a band of ten workspace ids (1–10, 11–20, …), so a number key
always means "the *n*-th workspace of the screen I am looking at". Workspaces
stay dynamic — one exists while something is on it.

Colours come from the wallpaper:

```
   wallpaper ──► Noctalia palette ──► templates ──► app configs ──► reload
```

`/theme` (`M + CTRL + T`) switches between that, ten built-in palettes, and
your own — **noirblaze** ships here, ported from the neovim colourscheme.
Frosted glass follows the scheme, and both terminals and browsers end up
showing exactly the same amount of wallpaper.

Idle has one owner (Noctalia): lock at 10 minutes, screen off at 15, suspend at
30, and anything playing video holds all three off.

**[→ design notes](docs/design.md)** — the navigation model, and the five
non-obvious things (why tapping `SUPER` is safe, how the bar knows when to
appear, how edges are detected, why workspace numbers are arithmetic, and why
only one thing may own idle).

**[→ colours, wallpapers and glass](docs/theming.md)**

---

## What is where

```
config/hypr/       hyprland.lua, conf/ (options, look, input, rules, binds …),
                   lib/ (nav, ws, bar, supertap)
config/noctalia/   00-shell … 70-idle, palettes/, templates/
config/kitty/      kitty.conf and two kittens
config/fish/       config.fish, plugins, frozen theme colours
bin/noct-*         the launcher providers, the glass level, the wallpaper fetcher
browsers/          policies and user.js for Brave, Chromium, Firefox, Zen
install.sh         linking, packages, browsers, wallpapers, login screen
docs/              keymap, design notes, theming, install
TESTING.md         post-install checklist — start here on first boot
```

To change almost anything, start in **`config/hypr/conf/options.lua`**.

**[→ install, packages and switching between setups](docs/install.md)**

---

## Requirements

Hyprland **≥ 0.55** for the Lua config and the built-in scrolling layout
(developed against 0.56), Noctalia **5.x** — not `noctalia-shell` 4.x — and
neovim 0.12+ if you use the companion config. `~/.local/bin` must be on `PATH`,
since the launcher runs its providers through `sh -lc`.
