# Design notes

Why this config is shaped the way it is: the navigation model it borrows, and
the five things that are non-obvious enough to be worth writing down.

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
out, right onto the next monitor. `SUPER+SHIFT` does the same while dragging
the window along, and the arrow keys are bound to everything `hjkl` is.

---

## Five things worth knowing

### Tapping SUPER is a release-bind, and that is fine

`hl.bind("SUPER + SUPER_L", …, { release = true })` is how the wiki says to
bind a bare modifier, and it is what `~/repos/dots` has been running. The
modmask has to name the mod being pressed — `SUPER + SUPER_L`, not `SUPER_L`.

Hyprland's keybind manager has dedicated arming and sub-chord suppression for
release binds, so this does not simply fire every time you let go of SUPER
after a chord. `lib/supertap.lua` exists as a fallback if it ever does: it
watches `input.keyboard.key`, which is emitted *before* the keybind manager
sees the event and therefore sees every key including ones binds consume, and
requires the tap to be both quick and uninterrupted. Switch it on with
`SUPER_TAP_ENABLED = true` in `conf/options.lua`.

### The bar is event-driven, not timed

Noctalia's panels are layer-shell surfaces, and Hyprland emits `layer.opened` /
`layer.closed` with the surface. `lib/bar.lua` tracks the set of open
`noctalia-panel` / `noctalia-attached-panel` / `noctalia-window-switcher`
surfaces and calls `bar-show` / `bar-hide` as that set becomes non-empty or
empty. No polling, and no guessing how long you will spend in the launcher.

Notifications and OSDs are deliberately excluded — a notification must not drag
the bar on screen with it.

It is also made of the same material as the panels it opens. The bar surface
itself is invisible — no fill, no border, no slab welded to the screen edge — and
what you see are four **capsules** in the *centre* of the screen: navigation,
time, media, status. A summoned HUD should be one thing you look at, not three
things in the far corners of an ultrawide.

Those capsules are Noctalia's own card material, and not by coincidence: sampled
off the running control centre, a popup is `#101010` with `#323232` cards at a
corner radius of 12, and a group capsule is drawn as opaque `surface_variant`
(`#323232`) at whatever radius you ask for. So matching the shell meant setting
one number — the radius — and deleting two that turned out to do nothing.

The window title is given a **fixed** width. Centred content grows in both
directions, so a variable-width title would slide the clock and the status icons
sideways every time you changed window.

Inside them the styling is three rules, and they are what separate a bar that
was *designed* from a bar that merely *works*:

1. **One accent.** `primary` marks the workspace you are on and the button that
   opens the control centre. Nothing else. A bar that colours every widget by
   category has spent the only signal it had for "here".
2. **Two text levels.** `on_surface` at weight 600 for the clock — the one thing
   you look at deliberately — and `on_surface_variant` at 400–500 for the date,
   the window title and the track, which you only glance at.
3. **No word that an icon already says.** The network widget was printing
   `enp4s0`, the battery a percentage; both are icons now, with the detail in the
   panel behind them. Notifications appear only when something is unread.

Media has a capsule of its own because its width follows the track title, and in
a shared capsule that shuffled the whole status row sideways every few minutes.

The blur behind them is the layer rule in `conf/rules.lua`, and
`ignore_alpha = 0.5` is what keeps the transparent part of the bar from being
blurred along with the capsules.

### Why the blur is small

Because a blur large enough to make every window the same shade also makes every
window look opaque, and that turned out to matter more.

With `blur.xray` on, every translucent window samples the wallpaper behind
*itself*, so a small blur preserves the photo's local brightness and two windows
at the same opacity come out as different shades — one over a bright patch, one
over a dark one. Measured on this wallpaper at `size 8 / passes 2`, the backdrops
behind two kitty windows differed by 24–41 of 255, landing as a 4–6 level
difference in what you saw. Both windows measured an own alpha of 1.00; nothing
about them was different.

`size 32 / passes 4`, dimmed to `brightness 0.65` and desaturated to `vibrancy
0.05`, fixes that: the same two backdrops differ by 5. It also averages the
wallpaper away entirely. Measured 2026-08-18 with `noct-check glass-visible`,
that combination at `window = 0.90` was worth a **lift of 3 levels of 255** — the
difference between the window and an opaque one — with a backdrop varying by 2.
Uniform, and uniformly grey. Nothing on the screen said the glass was on.

The setting now is `size 8 / passes 2` at `brightness 1.0`, `vibrancy 0.15`, with
`window = 0.60`: lift **17**, structure **8**. You can make out what the
wallpaper is through a terminal, which is the point of having one behind the
windows at all.

There is no value that does both, and it is worth being plain about which was
chosen. Two windows over different parts of the image now read as slightly
different shades. That is the price of the photo being visible through either of
them.

`noct-check glass-visible` is how any of these numbers get settled — it drives a
window to fully opaque, then to almost fully transparent, and reads both ends off
a screenshot. Eyes are not reliable at 3 levels of 255, and neither is a config
file that looks correct.

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

### Workspace numbers are arithmetic, not a selector

Each monitor owns a band of ten workspace ids — monitor 0 gets 1–10, monitor 1
gets 11–20 — so `SUPER+3` has to mean "the third workspace of the monitor I am
looking at". Hyprland has selectors that look like they say that, and neither
one does:

| Selector | What it actually does |
|---|---|
| `m~3` | **Nothing.** Not valid syntax in 0.56 — the dispatcher answers `ok` and no workspace changes |
| `m+1` / `m-1` | Walks the workspaces that currently *exist* on this monitor. In a dynamic setup that is usually one, so there is never a next one |

That first row is why every number key was dead and why `J` at the bottom of a
column did nothing: both failed silently, in a config that looked correct.
`lib/ws.lua` does the arithmetic instead — read the focused monitor, find its
band in `WSBANDS` by connector name, dispatch the absolute id — and clamps at
the band edges so a workspace step never lands you on another screen's numbers.
`~/repos/dots` solves the same problem with a shell script that shells out to
`hyprctl` on every keypress; in a Lua config it is a table lookup.

Workspaces stay **dynamic**: nothing is persistent, so a workspace exists while
something is on it and the bar shows exactly those. The band only decides what
number a new one gets.

A band's other half is its **column width**, and that is not a workspace rule
either. `layout_opts` carries the scroll `direction` and the scrolling layout
does read it — but the width it takes only from the global
`scrolling:column_width`, so the portrait band that asked for halves quietly got
thirds like everything else. `lib/colwidth.lua` supplies the per-monitor option
Hyprland does not have: it sets that global as focus crosses monitors. The value
is only ever consulted when a new column is created, and a new column appears on
the monitor you are looking at — so the two are indistinguishable, with no poll
and no timer. Existing columns are deliberately left alone, or every glance at
the other screen would undo your `SUPER+PLUS` resizing.

### Idle has exactly one owner

Noctalia's idle service does the locking (`70-idle.toml`: lock at 10 min,
screen off at 15, lock-and-suspend at 30). `hypridle` — which a CachyOS
Hyprland install ships and which `~/repos/dots` enables as a user unit — does
the same job from a config this repo does not manage, and two countdowns to the
same lock screen is how you end up locked out mid-video with no idea which of
them did it. `install.sh` disables the stray unit; `systemctl --user status
hypridle` is the check.

Playback keeps the screen awake in three layers, because no single one of them
covers the whole case:

1. **Apps that ask.** mpv, VLC and the browsers hold a Wayland idle inhibitor
   while something plays, and Hyprland stops issuing idle notifications for as
   long as one is held — so the countdown never starts. This is the layer that
   covers video in a browser tab.
2. **Anything fullscreen** — `idle_inhibit = fullscreen` on every window.
3. **A focused media player**, even windowed — `idle_inhibit = focus` for mpv,
   VLC, Celluloid and Haruna, so a paused film does not lock the screen you are
   looking at.

`SUPER+CTRL+P` → Caffeine is the manual override, and the one to use when what
is playing is audio in a terminal.

---

See also: [the full keymap](keymap.md).
