# Colours, wallpapers and glass

One palette drives the desktop, the terminal, GTK and Qt apps and the window
borders. This is how it gets there, and what to change when you want it to look
different.

One palette drives everything. Noctalia resolves it, then renders it into each
app's own config format through templates, and pokes the app to reload.

```
   wallpaper ──► Noctalia palette ──► templates ──► app configs ──► reload
                 (48 Material roles
                  + 22 terminal roles)
```

## Switching scheme

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
| **kitty config (new windows)** | `kitty` user template → `generated-colors.conf` | on restart |
| GTK 3 / GTK 4 apps | `gtk3` / `gtk4` built-ins | on restart |
| Qt apps (dolphin, ark) | `qt` built-in + `kcolorscheme` | on restart |
| btop | `btop` built-in | on restart |
| **Hyprland window borders** | `hyprland` user template → `hyprctl reload` | yes |

Three of those are ours rather than Noctalia's, and all three are worth knowing
about:

**Hyprland borders.** Noctalia v5 does ship an `hyprland` built-in, but it emits
`hyprland.conf` syntax and this config is Lua, so window borders would otherwise
stay whatever `conf/look.lua` hardcodes. `templates/hyprland-colors.lua` renders
a small Lua file to `~/.config/hypr/generated/colors.lua`, which `hyprland.lua`
`dofile`s *last* (under `pcall`, since it does not exist until the first render)
so it overrides the fallbacks.

The focused border is a **gradient** — `primary` to `tertiary` across the
diagonal — and the unfocused one is `outline_variant` at 15%, a hairline. The
split is deliberate: the focused window is the only thing on screen that should
draw the eye, so it gets the palette's two most contrasting accents, and every
other window gets just enough edge to say where a column ends. Corners are nearly
square (`ROUNDING = 2`), which is the other half of that look: a wide radius
spends most of a gradient's length in the corners.

Note the syntax. A gradient in a Lua config is a **table** —
`{ colors = { "rgb(a)", "rgb(b)" }, angle = 45 }`. The single-string form
`"rgb(a) rgb(b) 45deg"` is `hyprland.conf` syntax and is not parsed here; it
loads without complaint and you get a flat border. To go flat on purpose, make
`active_border` one string — the template says where.

**kitty colours.** The built-in `kitty` template is deliberately *not* enabled.
It does not just write a colour file — it rewrites `kitty.conf` itself to include
a path of its own choosing (`themes/noctalia.conf`), and `install.sh` deploys
`kitty.conf` as a symlink into this repo. So the built-in edits a tracked file:
the checkout goes dirty on every palette change, and pulling on another machine
lands you in a merge conflict over generated output. `templates/kitty-colors.conf`
renders to `~/.config/kitty/generated-colors.conf` instead — a path we picked,
which `kitty.conf` includes once and Noctalia never touches. Same arrangement
`generated-glass.conf` already uses.

That rule generalises: **a built-in is only safe to enable if its output path is
not a file this repo tracks.** Check `starship` and the community `yazi` template
twice before enabling either — this repo tracks `starship.toml` and `yazi.toml`.

**Live terminal repaint.** A kitty colour file only affects terminals started
afterwards — change your wallpaper and every terminal you already had open keeps
the old colours. So
`templates/terminal-colors.sh` renders a script that pushes OSC colour
sequences into every pty you own. That is emulator-agnostic (works for foot,
ghostty, wezterm, alacritty too) and it is also how your *shell* gets themed:
prompts, `ls`, `git`, vim and btop all paint with those 16 ANSI slots, so
nothing needs per-tool configuration.

Drop the `terminal_live` entry from `40-templates.toml` if you would rather
terminals only changed on restart.

## Wallpapers

The palette is derived from the wallpaper, so this is not decoration — it is
where every colour in the desktop comes from.

**Per monitor, not per desktop.** `fill_mode = "crop"` scales to cover and
discards the overflow, so a 16:9 image on a 21:9 screen loses about a third of
its height, which is usually where the subject was. `60-wallpaper.toml` sets
`per_monitor_directories = true` and points each output at its own folder:

```
~/Pictures/Wallpapers/
  ultrawide/   21:9 and 32:9
  standard/    16:9, ≥2560×1440
  portrait/    9:16
```

> **This is the one host-specific thing in the repo.** Noctalia keys those
> overrides on connector names (`[wallpaper.monitor.DP-3]`), and unlike
> `hypr/host.lua` it has no per-machine mechanism — the names are committed, so
> they are right on one machine and wrong on the next. An unmatched section is
> not an error: Noctalia ignores it and falls back to the global `directory`, so
> the symptom is every screen quietly showing the same 16:9 set. `install.sh`
> compares the sections against `hyprctl monitors` during `--wallpapers` and
> warns when they disagree; `hyprctl monitors` is the fix. The current names
> match this machine (`DP-3` ultrawide, `HDMI-A-1` portrait via `transform`).

Fill them with `noct-wallfetch`, which pulls from Wallhaven's public API using
the sets in `config/noctalia/wallpapers.conf`:

```sh
noct-wallfetch --list          # sets, and what is already on disk
noct-wallfetch --dry-run       # what it would download
noct-wallfetch                 # all sets
noct-wallfetch db-standard     # just one
```

Re-runs skip what is already there, so it is safe to run repeatedly. Set
`WALLHAVEN_API_KEY` to raise the anonymous 45 req/min rate limit.

**On Dragon Ball specifically — the supply is lopsided.** Measured against the
API rather than guessed:

| Search | Results |
|---|---|
| `dragonball`, any ratio | 1225 |
| `dragonball`, 16:9, ≥2560×1440 | 353 |
| `dragonball`, 9:16 portrait | 42 |
| **`dragonball`, 21:9 or 32:9** | **4** |

Four. True ultrawide Dragon Ball art essentially does not exist. So the
ultrawide folder is filled from three sets rather than one: those four, then
Dragon Ball art at ≥3440px wide that survives a centre crop, then a general
anime-ultrawide pool so rotation has somewhere to go. Adjust the balance by
editing the counts in `wallpapers.conf` — if you would rather have only true
Dragon Ball on the wide screen, drop the `anime-ultrawide` line and accept four
images.

For finding one image now rather than filling a folder, **`SUPER+SHIFT+W`**
opens the Wallhaven browser (the official Noctalia plugin, enabled in
`60-wallpaper.toml`). `SUPER+W` is the local picker.

Images are downloaded, never committed — they are other people's artwork, and a
wallpaper folder would dwarf the rest of the repo. `wallpapers.conf` is the
tracked part; the images are reproducible from it.

**Rotation is off by default.** With `[wallpaper.automation]` enabled the
palette changes on a timer, which means your whole desktop recolours
mid-task. It is a real preference rather than an oversight — turn it on in
`60-wallpaper.toml` if you want it.

## Frosted glass

On by default, tied to the scheme, and done in the compositor.
`bin/noct-glass` runs from Noctalia's `colors_changed` hook, so the level
follows whatever `/theme` selects. **`SUPER+SHIFT+G`** cycles as a temporary
override. Levels live in `config/noctalia/glass.conf`.

Three knobs, and **all are stated as what you see**:

| Knob | Means | Applies to |
|---|---|---|
| `window` | how opaque an ordinary window is | Hyprland's `active_opacity` — **every window**, including GTK and Qt apps with no transparency of their own. Fades text with the background; the compositor cannot tell one from the other |
| `terminal` | how opaque a **terminal** ends up | kitty's own `background_opacity`, which fades only the background and leaves text fully opaque |
| `browser` | how opaque a browser **page** ends up | a stylesheet in the Zen profile, for the page area the transparency mod and the "Zen Internet" extension leave transparent |

They used to compound, and that was the bug behind "one is darker than the
other": kitty applied `terminal`, the compositor then applied `window` on top,
and at 0.85 / 0.90 a terminal landed at 0.77 next to a browser at 0.90 — a
visible step between two windows nominally set to the same glassiness.

So what `noct-glass` writes for an app is never the level, it is `level / window`
— the factor that takes the compositor's level to the one you asked for. At
`terminal` = `window` that factor is `1.0`: kitty adds nothing of its own.

### The focus step is what "the same" has to beat

An unfocused window is dimmed by 0.06 (`inactive_opacity`). So an app sitting
0.06 below `window` looks *exactly like a window in the other focus state* — the
symptom is "the browser when focused looks like the terminal when it isn't, but
not the other way around". Anything meant to read as the same material has to sit
well inside that 0.06, which is why `browser` is 0.88 against a `window` of 0.90.

The consequence is worth saying out loud: a browser page cannot be both
noticeably glassier than a terminal *and* indistinguishable from one. 0.83 buys
the glassy look and puts them a step apart; 0.88 makes them the same material and
leaves the transparency mod contributing a whisper. One number, in `glass.conf`.

### What applies live, and what waits for a restart

Only the compositor's `window` level. Measured on 2026-08-18: **kitty re-reads
colours on `SIGUSR1` but not `background_opacity`** — a running terminal stayed
at 1.00 while its generated config said 0.94 — and Zen reads stylesheets at
startup. That is why `terminal` is kept equal to `window` by default: a
terminal-specific level would otherwise leave you with two shades of terminal
until every window had been restarted. `browser` has the same limitation but only
one window's worth of it.

`blur.ignore_opacity` is on. Without it Hyprland scales the blur by the
window's own alpha, so a 0.9 window gets a tenth of the blur and the effect
disappears — this is the setting that makes compositor-driven glass actually
look frosted rather than merely faded.

**The blur is also what makes the levels above mean anything.** `blur.xray` has
every window sample the wallpaper behind itself, so at a small radius two windows
at the same level come out as different shades depending on what they happen to be
sitting over — measured at 4–6 levels of 255 on this wallpaper, which reads as
"one is grey and one is black". `size 32 / passes 4` at `brightness 0.65` and
`vibrancy 0.05` flattens that to 2 levels. See [design notes](design.md) for the
numbers; the cost is that you see less of the wallpaper's shape through a window.

Set `window = 1.0` for app-translucency only, which is what `~/repos/dots`
does today: nothing fades except surfaces an app draws translucent itself.

`conf/rules.lua` has an **opt-out** list for windows whose job is accurate
pixels — mpv, imv, gimp, obs, hyprpicker. You cannot judge a photo or pick a
colour through 10% of your wallpaper.

Two consequences worth knowing:

- **Zen's level is generated, not tracked.** A profile directory is named
  randomly per install, so no template can render into it and no symlink can be
  planned for it — `noct-glass` finds the profiles that carry a `user.js` and
  writes the whole of `chrome/userChrome.css` there. It writes the whole file
  rather than one that imports a generated half, because Firefox resolves a
  symlinked sheet to its real path before resolving relative `@import`s, and the
  import would then quietly look inside this repo. An existing sheet that is not
  ours is reported and left alone.
- **Neovim inside a transparent kitty.** Your `noirblaze.lua` paints `Normal`
  with `bg = #121212`, so the editor stays opaque against kitty's translucent
  background. `bg = "none"` fixes it — a change in *your nvim repo*, not this
  one. `config/kitty/README.md` has the snippet and the trade-off.

Useful commands:

```sh
noctalia theme --list-templates      # every template id available to you
noctalia msg templates-apply         # re-render without changing the theme
noctalia msg theme-mode-toggle       # dark <-> light
noctalia msg color-scheme-set builtin Gruvbox
noct-glass show                      # level currently in effect
```

---

See also: [install](install.md) for which packages the theming depends on, and
[design notes](design.md) for the rest of the config's shape.
