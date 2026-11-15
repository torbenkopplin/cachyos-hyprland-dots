# 028 — The bar is one glass pill, and it is as wide as its content

**Settled 2026-11-15** on Noctalia 5.5.0 and Hyprland 0.57.2. Status: in force.
Supersedes the *form* of [009](009-the-bar-is-three-capsules.md); 009's three
styling rules — one accent, two text levels, no word an icon already says — are
unchanged and still the reason the bar looks designed.

The bar surface spans the monitor and draws nothing. What you see is a single
capsule group in the centre lane: one pill, `surface` at 0.76, a hairline
`outline_variant` border, fully round (radius 17 on a 34px bar). It holds the
workspaces, the clock and date, and the status icons, separated by spacers.

A capsule sizes itself to its content, so the pill grows when a workspace opens
and shrinks when one closes — on every monitor, at every scale. Nothing in the
config names a width. That is the property this decision is about, because the
machine it has to work on is a laptop that meets a 4K screen, a 5K ultrawide or
a monitor it has never seen, and whose workspace row is dynamic
([017](017-workspaces-stay-dynamic.md)).

## What changed upstream

On 5.0.0-beta.8 a group capsule drew opaque `surface_variant` whatever it was
given, which is why 009 settled against a glass island. On 5.5.0 it does not:

- `fill` and `opacity` on a `[[bar.default.capsule_group]]` are honoured.
  Measured with a red fill: `(255,0,0)` at 1.0, `(183,4,8)` at 0.7 over a dark
  backdrop — 0.7 × 255 plus 0.3 of what was behind.
- `border` and `border_width` on a group draw an outline round the capsule, not
  round the bar.
- The surface around the pill stays invisible: with the pill shown, the strip
  either side was pixel-identical to the screen with the bar hidden.

## What the pill is measured to be

`noct-check bar-pill` puts a probe window under the bar, striped and then plain,
and reads the pill off the difference. On eDP-1 at 1920:

| | |
|---|---|
| width | 370px with one workspace and no tray icons |
| centre | 0.0px off the monitor's |
| opacity | 0.76 — the configured value, measured |
| blur | the stripes behind measure sd 91; through the pill, 0.1. Half a percent of what an unblurred pill at that opacity would let through |

The same check fails each broken version it was written against: a pill at 0.40
(stripes through at 100% of their unblurred contrast — below the layer rule's
`ignore_alpha = 0.5` Hyprland does not blur it at all), an opaque pill (a = 1.00),
and a full-width slab (0 to 1919 of a 1920px strip).

## The look, and what was tried for it

Six variants were put on screen and compared:

- **24px pill (the old capsule height), no border.** Over a dark wallpaper the
  `surface` fill all but vanishes and only the glyphs are left.
- **34px, hairline border.** The border is what makes it an object. It is the
  outline the control centre draws round itself, and that panel opens directly
  under the pill with a gap between them, so the two read as one family.
- **The same with `·` dividers between sections.** Barely visible, and only
  added width. The sections already look different from each other.
- **`surface_container` fill.** Reads more strongly over dark backdrops, but it
  is lighter than the panels it opens. Matching the panels won.
- **radius 17 rather than 12.** Half the height: a pill rather than a rounded
  rectangle.
- **Status icons quieted to `on_surface_variant`.** They were as bright as the
  clock, which broke rule 2. Done per widget: the group's `foreground` key
  overrides every member, and took the accent off the control-centre button.

## Settled against

**`margin_ends` as a percentage.** It works on 5.5 — per end, so `"40%"` is a
384px bar on a 1920px screen — but it follows the screen, not the content.
The same setting is 688px of mostly empty glass on a 3440 ultrawide and 216px
on a 1080 portrait panel, which cannot hold the widgets.

**`margin_ends` in pixels, computed per monitor by the compositor.**
`[bar.default.monitor.<name>]` overrides exist on 5.5, inherit everything they
do not set, hot-reload from a new file within a second and a half, and beat
the Settings UI's `settings.toml` — all measured. A Lua module writing one per
connected monitor would have followed any screen. It is still a fixed box:
too many workspaces overflow it and too few leave glass at both ends.
Recomputing it as content changes is not an option either, because every
config reload tears the bar down and builds it again (`[bar] creating #0
"default" on eDP-1` in Noctalia's log on each one).

**Everything in `center` of a narrowed bar** — the Settings UI experiment that
started this — is the percentage case above, with the bar's own background as
the glass.

## The cost

The clock is no longer pinned to one spot. Centred content grows both ways, so
a new workspace moves the clock left by half its width — 17px when the
workspace indicator appeared during testing. The bar is summoned, not watched,
so this is a difference between two appearances rather than motion you see.

The window title cannot come back without a fixed box (`min_length =
max_length`), or the pill changes width with every window you focus.

## Watch for

The Settings UI saves to `~/.local/state/noctalia/settings.toml`, which loads
after `~/.config/noctalia` and wins — whole `capsule_group` lists included. One
visit to the bar's page overrides this file. `noct-check bar-pill-config` fails
when it has.
