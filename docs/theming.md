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

On by default, tied to the scheme, and — since 2026-08-19 — the **terminal and
nothing else**. `bin/noct-glass` runs from Noctalia's `colors_changed` hook, so
the level follows whatever `/theme` selects. **`SUPER+SHIFT+G`** cycles the whole
desktop through it as a temporary override. Levels live in
`config/noctalia/glass.conf`, and one machine's own answer in an untracked
`glass.local.conf` beside it.

`noct-check glass-visible` measures whether any of it reaches the screen — see
[design.md](design.md#why-the-blur-is-small) for why that is not a question the
eye can answer.

Two knobs, and **both are stated as what you see**:

| Knob | Means | Applies to |
|---|---|---|
| `window` | how opaque an ordinary window is | Hyprland's `active_opacity` — **every window**. Fades text with the background; the compositor cannot tell one from the other. **Shipped at 1.0**, i.e. it fades nothing |
| `terminal` | how opaque a **terminal** ends up | kitty's own `background_opacity`, which fades only the background and leaves text fully opaque. **Shipped at 0.55**, and the whole of the effect |

A browser is not on that list, deliberately, and there is no third level coming
— but Zen is translucent anyway, by itself and outside these knobs entirely. See
[what was tried with Zen](#what-was-tried-with-zen-and-dropped) below.

### Why the compositor level was given up

`window` was 0.85 for most of 2026-08-19 and is 1.0 now. Nothing was measured
wrong; what changed is what the measurement was worth.

The compositor is the only thing that can frost a GTK or Qt app, because those
draw an opaque background and have no opacity of their own. It is also the only
thing it can do for them: it cannot separate glyphs from background, so their
text fades by exactly the same factor. `noct-check glass-legible` puts a number
on it — at `window = 0.60` the ink measured 78% of the scheme's foreground and
read as washed out at a perfectly legal 5.3:1. At 0.85 it is 85%. At 1.0 it is
100%.

Installed on a work machine, that turned out to be the wrong trade: an editor, a
spreadsheet and a chat window whose text sits at 85% of its colour over a moving
photo is a cost paid all day for an effect you stop noticing in a minute. So
those apps are opaque now, on purpose, and the terminal — where translucency
costs nothing, because kitty fades only its background — keeps all of it.

**What it costs, stated plainly:** "everything matching" is gone. A GTK app is
opaque and a terminal is at 0.55, and they do not read as the same material.
There is no way to make them without fading somebody's text.

Two consequences that are easy to trip over:

- **The focus dim goes with it.** `noct-glass` drops an unfocused window 0.06
  below `window`, and at 1.0 it does not — dimming the unfocused ones would put
  back exactly what the setting removes. The focus cue is the border instead: a
  gradient on the focused window, a hairline on everything else.
- **The blur stays on, for the terminal.** It is switched off only when *both*
  levels are opaque. Deciding that on `window` alone left a translucent kitty
  sitting over a sharp, unblurred wallpaper — transparency without the frost.

`SUPER+SHIFT+G` still cycles `1.00 → 0.75 → 0.60 → 0.50` across the whole
desktop, so the old look is one keypress away when you want it, and gone again on
the next scheme change.

### One machine's own levels

`glass.conf` is tracked, so a level in it is a level on **every** machine that
pulls. The right level is not a property of the setup, though — it is a property
of the screen in front of you. So there is a second file, and it is not in the
repo:

```sh
cp config/noctalia/glass.local.conf.example ~/.config/noctalia/glass.local.conf
```

Absent by default, which means "use the tracked levels". Present, it wins
outright — **both** of its keys before **either** of `glass.conf`'s, so a bare
`window` set locally beats a per-scheme `window` in the tracked file. Without
that ordering, a machine that had said "no compositor transparency here" would
get it back the moment you switched to the one scheme that overrides it.

`noct-glass show` prints `[glass.local.conf]` when it is in play, and
`noct-check glass-config` says so too, so "why do the two machines look
different" has an answer you can read off rather than deduce.

This and `~/.config/hypr/host.lua` are the only two files that are allowed to
differ per machine. Anything else that differs is a difference worth committing —
see [install.md](install.md#two-machines).

They used to compound, and that was the bug behind "one is darker than the
other": kitty applied `terminal`, the compositor then applied `window` on top,
and at 0.85 / 0.90 a terminal landed at 0.77 next to a browser at 0.90 — a
visible step between two windows nominally set to the same glassiness.

So what `noct-glass` writes for an app is never the level, it is `level / window`
— the factor that takes the compositor's level to the one you asked for. At
`terminal` = `window` that factor is `1.0`: kitty adds nothing of its own.

### The focus step is what "the same" has to beat

Only when the compositor is fading anything at all — at the shipped `window =
1.0` there is no step, and this is the reasoning to come back to if you ever lower
it again.

An unfocused window is dimmed by 0.06 (`inactive_opacity`). So an app sitting
0.06 below `window` looks *exactly like a window in the other focus state* — the
symptom is "the browser when focused looks like the terminal when it isn't, but
not the other way around". Anything meant to read as the same material has to sit
well inside that 0.06.

That is the whole reason `terminal` at 0.55 against a `window` of 0.85 was a
deliberate *contrast* rather than a failed match: at 0.30 below it is nowhere
near the focus step, so a terminal reads as its own material rather than as a
mis-focused window. Anything that wants to read as *the same* material has a
much smaller budget than it looks like it has, and that is what the Zen
experiment ran out of.

### Why `terminal` is as low as 0.55

Because the lift — how much brighter a translucent window is than an opaque one —
is `(backdrop − the window's own colour) × (1 − opacity)`, and on a dark palette
over a blurred photo the first bracket is small. Measured here: the window's own
colour is 29 of 255 and the backdrop reaches 72, so there are 43 levels to
divide. At an opacity of 0.90 that is a lift of 4; at 0.80, 9; at 0.60, 17.

Which means the frosted look is far more sensitive to the level than it looks
like it should be, and that the range where it reads as glass at all starts lower
than a number like 0.9 suggests. `blur_brightness` is the other half — it scales
the backdrop directly — but it is capped at what the wallpaper actually is.

### What applies live, and what waits for a restart

Both levels, since 2026-08-19 — and that is what makes the current arrangement
possible at all. kitty read `background_opacity` once at startup and ignored it
forever after, which is why `terminal` used to be pinned equal to `window`: any
difference left you with two shades of terminal until the last old window closed.
`dynamic_background_opacity yes` in `kitty.conf` lifts that, and `noct-check
kitty-live` measures a probe window actually following a change on `SIGUSR1`
rather than taking it on trust.

That check is also the one to distrust when the screen is locked. It photographs
a white probe, and a lock screen photographs as something else entirely: locked,
it measured 138.9 before and after and reported that kitty ignores `SIGUSR1`
(it does not — unlocked, the same run measured 157.5 → 255.0). Both pixel checks
now notice that a window they forced to full white opacity did not come back near
255, and skip instead of concluding.

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

So `browser` is gone, `write_zen` is gone, and the generated stylesheet is gone.
Nothing here has a level for a browser or writes a line of CSS into a profile,
and that half is not coming back.

### Zen's own transparency is back on, unmatched

Later the same day the two prefs went back to **`true`**. Dropping the *match*
was right; switching Zen's own transparency off along with it was a second
decision riding on the first, and it cost the browser an effect that works
perfectly well on its own terms. The mod was never the problem — the attempt to
put a number on it was.

`browsers/zen/user.js` sets `browser.tabs.allow_transparent_browser` and
`zen.widget.linux.transparency` to `true`, and states them rather than leaving
them out, which matters in this direction as much as the other: a `user.js` only
ever *sets* prefs, so a deleted line leaves whatever `prefs.js` already recorded
instead of restoring a default.

**Those two prefs are the thing to check when the mod looks broken.** They decide
whether the window has an alpha channel at all. The mod and the extension are
CSS, and an `rgba()` background needs something behind it to show through — so
with the prefs false the mod paints against Zen's own opaque backdrop and looks
like it was never installed. Reinstalling it does not help, because `user.js`
re-applies its values at every startup and each restart undoes the reinstall.
That is the whole loop of the symptom, and it is worth recognising rather than
debugging twice. `about:config` is the definitive read; `prefs.js` will not show
either pref while it sits at its default.

**What you get, stated plainly:** whatever the mod and the extension paint. Not a
level, not a number in `glass.conf`, not anything matched to kitty's 0.55 or to
`window`. Zen is the one window on this desktop whose translucency is decided by
software this repo does not own, and it will read as its own material next to
everything else. That is the price of having the effect at all, and it is the
same price the `browser` level was invented to avoid paying.

**One consequence in the suite.** `noct-check browser-glass` used to fail when the
four browsers were more than 0.06 apart — the compositor's own focus step. A Zen
that is translucent by itself is exactly the spread that assertion was written to
catch, so it would have failed on the intended state forever. **The assertion is
retired, and the spread is gone with it** rather than demoted to a warning: with
one browser deliberately translucent and three deliberately not, a number for how
far apart they are measures the intended difference and nothing else. The 0.06 had
stopped meaning anything in any case — `inactive_opacity` went to 1.0 with the
rest of the compositor level, so there is no focus dim left to compare against.

It is not a baseline metric either, for the same reason. A metric is compared
against a recorded value within a tolerance, which is the same gate wearing a
different hat: it would turn every `--compare` on a machine with the mod installed
into a drift report about a decision made on purpose.

What the check still does is measure each browser on its own and fail on three
things, all still true:

- a browser measuring *more* opaque than the compositor makes it — impossible, so
  the measurement is wrong
- **any browser other than Zen** measuring well under it, because nothing here
  arranges that and nothing should
- page text under 4.5:1

That middle one is the standing invariant, and it is the only thing enforcing it:
Zen is the one browser allowed an effect of its own, from its own mod, and the
other three get exactly what every opaque app gets, which at `window = 1.0` is
nothing at all.

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

`window = 1.0` — the shipped value — is app-translucency only: nothing fades
except surfaces an app draws translucent itself, which in practice means kitty.
`terminal = 1.0` on top of it is a desktop with no translucency anywhere at all,
and is the one line to put in `glass.local.conf` on a machine where none of this
is wanted.

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

See also: [install](install.md) for which packages the theming depends on,
[design notes](design.md) for the rest of the config's shape, and
[decisions 010–013](decisions/README.md) for the short form of everything here
that was settled against something else.
