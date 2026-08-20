# 010 — Frosted glass is the terminal and nothing else

**Settled against compositor-wide glass on 2026-08-19**, after installing it on
a work machine. Status: in force.

`window = 1.0`, so the compositor fades no window at all, and `terminal = 0.55`
reaches kitty undivided.

## What was given up, and why

Compositor-wide glass was built, measured and correct. `window = 0.85` frosted
GTK and Qt apps, which is the only way those can be frosted at all, and
`noct-check glass-visible` confirmed the wallpaper reading through.

What it could not do is separate a window's **text** from its background. The
compositor composites the whole surface, so every step of glass is a step of
contrast off every glyph in every app: at 0.60, ink at 78% of the foreground and
a washed-out 5.3:1; at 0.85, 85% of its colour.

An effect you stop noticing in a minute, paid for all day.

kitty is the one window that fades its background and leaves its text alone, so
that is where the glass went, and there it costs nothing.

`SUPER+SHIFT+G` still cycles the whole desktop through it if you want the old
look for a while. **If it comes back permanently**, it comes back per machine in
`glass.local.conf` ([014](014-two-machine-local-files.md)) — the level is a
property of the screen, not of the setup.

## Three things that came with it

- **No focus dim.** `inactive_opacity = 1.0`: dimming unfocused windows would put
  back exactly what the setting removes.
- **The blur stays on**, because it is now what a *terminal* looks through.
  Switching it off on `window` alone left kitty over a sharp wallpaper.
- **`SUPER+SHIFT+G` first press works**, which it did not: the cycle compared
  `"1.00"` against `"1.0"` as strings.

## The two facts underneath it

- **kitty applies `background_opacity` only at startup** — with
  `generated-glass.conf` at 0.94 and a fresh `SIGUSR1`, running kitties still
  composited at 1.00; colours reloaded, opacity did not. `dynamic_background_opacity yes`
  in `kitty.conf` is what lifts that, verified by `noct-check kitty-live`
  (157.5 → 255.0). Without it a terminal-specific level quietly gives you two
  shades of terminal until every window is restarted.
- **Noctalia's built-in kitty template rewrites `kitty.conf`.** It writes
  `themes/noctalia.conf` and edits `kitty.conf` to include it, clobbering the
  tracked symlink — and excluding `kitty` from `builtin_ids` is *not* enough to
  stop it: it ran anyway at 12:04:25 on 2026-08-19, eleven seconds before
  Noctalia saved `settings.toml`, because the GUI's copy of `builtin_ids` loads
  last and wins. `noctalia msg templates-apply` does not reproduce it, so the
  config being right is no evidence the built-in is off.
  `noct-check kitty-untouched` is the check, and it matters more now that
  `--update` refuses to pull over exactly that kind of edit.

Full reasoning: [theming.md](../theming.md#why-the-compositor-level-was-given-up).
