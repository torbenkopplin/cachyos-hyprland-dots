# 009 — The bar is three centred capsules of Noctalia's own card material

**Settled 2026-08-20**, after building and looking at every alternative.
Status: in force.

The bar surface itself is invisible — no fill, no border, no slab welded to the
screen edge. What you see are capsules in the **centre** of the screen:
navigation, time, media, status. A summoned HUD should be one thing you look at,
not three things in the far corners of an ultrawide.

## The material is not a coincidence

Sampled off the running control centre: a Noctalia popup is `#101010` with
`#323232` cards at corner radius 12, and a group capsule is drawn as opaque
`surface_variant` (`#323232`) at whatever radius you ask for. Matching the shell
meant setting one number — the radius — and deleting two that turned out to do
nothing.

`capsule_radius = 12` stays at 12 while `ROUNDING` is 2, because a capsule is
shell furniture rather than a window. What was actually wrong with the bar was
redundancy, not radius: the media capsule restated the window title verbatim.

## Three styling rules, which are what separate designed from working

1. **One accent.** `primary` marks the workspace you are on and the button that
   opens the control centre. Nothing else. A bar that colours every widget by
   category has spent the only signal it had for "here".
2. **Two text levels.** `on_surface` at weight 600 for the clock — the one thing
   you look at deliberately — and `on_surface_variant` at 400–500 for the date,
   the window title and the track, which you only glance at.
3. **No word that an icon already says.** The network widget was printing
   `enp4s0` and the battery a percentage; both are icons now, with the detail in
   the panel behind them. Notifications appear only when something is unread.

The window title has a **fixed** width. Centred content grows in both directions,
so a variable-width title slides the clock and the status icons sideways every
time you change window. Media has a capsule of its own for the same reason: its
width follows the track title.

## Settled against: a small glass island

The capsules do **not** match the panels' glass, and that is a measured dead end
rather than a gap.

- A capsule is drawn opaque whatever `capsule_fill` / `capsule_opacity` say. Both
  are accepted, both appear in `config export merged`, and both are ignored —
  verified by setting the fill to `#ff0000` and watching nothing turn red.
- The only surface that takes an opacity is the bar itself, which has no width key
  and always spans the monitor.
- `margin_ends` is the only width lever, it is absolute pixels, and it is shared:
  1200 gives a nice 1064px island on the 3440px screen and collapses the 1080px
  one to nothing. `"25%"` is not a percentage (flat 88px). `monitor = "DP-3"`
  validates and is ignored.
- A second `[bar.<name>]` block does work and can carry its own margins, but it
  inherits nothing and would hard-code a pixel width to one screen — the same trap
  `WSBANDS` exists to avoid for a laptop.

**If the capsules should ever be glass**, the only routes left are Noctalia
honouring `capsule_opacity` or a theme-level surface alpha. Worth a look when
Noctalia moves past 5.0.0-beta.8. The capsule form has no resolution in it at
all, which is why it is the one that shipped.
