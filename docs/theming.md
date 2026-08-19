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

`noct-check glass-visible` measures whether any of it reaches the screen — see
[design.md](design.md#why-the-blur-is-small) for why that is not a question the
eye can answer.

Two knobs, and **both are stated as what you see**:

| Knob | Means | Applies to |
|---|---|---|
| `window` | how opaque an ordinary window is | Hyprland's `active_opacity` — **every window**, including GTK and Qt apps with no transparency of their own. Fades text with the background; the compositor cannot tell one from the other |
| `terminal` | how opaque a **terminal** ends up | kitty's own `background_opacity`, which fades only the background and leaves text fully opaque |

A browser is not on that list, deliberately — see
[what was tried with Zen](#what-was-tried-with-zen-and-dropped) below.

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
well inside that 0.06.

That is the whole reason `terminal` at 0.55 against a `window` of 0.85 is a
deliberate *contrast* rather than a failed match: at 0.30 below it is nowhere
near the focus step, so a terminal reads as its own material rather than as a
mis-focused window. Anything that wants to read as *the same* material has a
much smaller budget than it looks like it has, and that is what the Zen
experiment ran out of.

### Why the levels are as low as 0.60

Because the lift — how much brighter a translucent window is than an opaque one —
is `(backdrop − the window's own colour) × (1 − opacity)`, and on a dark palette
over a blurred photo the first bracket is small. Measured here: the window's own
colour is 29 of 255 and the backdrop reaches 72, so there are 43 levels to
divide. At `window = 0.90` that is a lift of 4; at 0.80, 9; at 0.60, 17.

Which means the frosted look is far more sensitive to the level than it looks
like it should be, and that the range where it reads as glass at all starts lower
than a number like 0.9 suggests. `blur_brightness` is the other half — it scales
the backdrop directly — but it is capped at what the wallpaper actually is.

### What applies live, and what waits for a restart

The compositor's `window` level, always — and `terminal` too, since 2026-08-19.
kitty read `background_opacity` once at startup and ignored it forever after,
which is why `terminal` used to be pinned equal to `window`: any difference left
you with two shades of terminal until the last old window closed.
`dynamic_background_opacity yes` in `kitty.conf` lifts that, and `noct-check
kitty-live` measures a probe window actually following a change on `SIGUSR1`
rather than taking it on trust.

That is what lets `terminal` sit far below `window`, which is the point: the
compositor cannot tell glyphs from background and fades both, kitty fades only
the background. Glassiness bought through `terminal` costs no contrast at all.

A browser reads its profile at startup and never again, so anything set in
`browsers/*/user.js` needs the browser restarted. `noct-check browser-glass`
launches each of the four fresh and measures how much of the wallpaper an
ordinary web page lets through, so the four can be compared with each other
rather than described one at a time.

### What was tried with Zen, and dropped

Zen is the one browser that can make its own window and page backgrounds
transparent, with the [transparent zen](https://github.com/sameerasw/transparent-zen)
mod and the "Zen Internet" extension. Between 2026-08-18 and 2026-08-19 this repo
tried to make that match the desktop: a third level, `browser`, in `glass.conf`,
divided by the window opacity and written into a generated
`chrome/userChrome.css` in each Zen profile.

It worked in the sense that the numbers came out right — `browser-glass` measured
all four browsers composing at 0.85, 0.00 apart — and it did not work in the sense
that mattered, which is what it looked like to use. **Dropped 2026-08-19.** What
it cost to keep:

- The match only ever applied where a page painted *nothing itself*. Ordinary
  pages paint an opaque background, so on almost everything you actually visit
  the tint was invisible and the browser was simply at `window` like every other
  app. The tuning applied to a minority of pages.
- It needed a specificity fight with somebody else's stylesheet. The mod paints
  the page area `!important` from a 0-3-1 selector, so the generated sheet had to
  reach 1-1-1 and a tripled `:root` to win — and would have lost silently, with
  nothing to report, the next time the mod changed its selector.
- Four moving parts had to stay aligned for one number to mean anything: the mod,
  the extension, two Zen prefs and a generated file, none of them ours, all read
  once at startup.
- The focus step above left almost no room. A page a tenth under `window` reads as
  a mis-focused window; a page two hundredths under is indistinguishable from one,
  at which point the transparency is buying nothing.

So `browser` is gone, `write_zen` is gone, the generated stylesheet is gone, and
`browsers/zen/user.js` now sets `browser.tabs.allow_transparent_browser` and
`zen.widget.linux.transparency` to **false** rather than leaving them out — a
`user.js` only ever *sets* prefs, so a deleted line would have left the old value
in `prefs.js` and the transparency would have stayed on forever.

**Two things to turn off by hand,** because no file here can: in Zen, disable the
"transparent zen" mod (`about:preferences` → Zen Mods) and remove or disable the
"Zen Internet" extension. Then restart it. `noct-check browser-glass` will tell
you whether anything is still translucent beyond the compositor's level, and any
browser more than 0.06 from the others fails it.

`blur.ignore_opacity` is on. Without it Hyprland scales the blur by the
window's own alpha, so a 0.9 window gets a tenth of the blur and the effect
disappears — this is the setting that makes compositor-driven glass actually
look frosted rather than merely faded.

**The blur is the other half of the effect, and it lives in the same file.**
`blur_size`, `blur_passes`, `blur_brightness`, `blur_contrast` and
`blur_vibrancy` are read from `glass.conf` alongside the levels and rendered into
the same generated Lua, per scheme if you want them to be — so the whole of what
a window looks like is described in one place.

`blur.xray` has every window sample the wallpaper behind itself, so at a small
radius two windows at the same level come out as different shades depending on
what they are sitting over — measured at 4–6 levels of 255 here. A big blur
(`size 32 / passes 4`, `brightness 0.65`) flattens that to 2, and flattens the
wallpaper out of existence with it: lift 3, which is nothing. The setting is
`size 8 / passes 2` at `brightness 1.0`, and it buys back the photo at the cost
of that uniformity. See [design notes](design.md#why-the-blur-is-small).

Set `window = 1.0` for app-translucency only, which is what `~/repos/dots`
does today: nothing fades except surfaces an app draws translucent itself.

`conf/rules.lua` has an **opt-out** list for windows whose job is accurate
pixels — mpv, imv, gimp, obs, hyprpicker. You cannot judge a photo or pick a
colour through 10% of your wallpaper.

One consequence worth knowing:

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
