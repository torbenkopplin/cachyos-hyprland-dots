# 011 — The blur is small, so the wallpaper stays visible through a terminal

**Settled 2026-08-19** by measurement. Status: in force, and it is the one dial
worth revisiting.

`size 8 / passes 2`, `brightness 1.0`, `vibrancy 0.15`, with `terminal = 0.60`.

## The trade-off, stated plainly because there is no value that does both

With `blur.xray` on, every translucent window samples the wallpaper behind
*itself*. So:

- **A small blur preserves the photo's local brightness.** Two windows at the
  same opacity come out as different shades — one over a bright patch, one over a
  dark one. Measured at `size 8 / passes 2`: the backdrops behind two kitty
  windows differed by 24–41 of 255, landing as a 4–6 level difference in what you
  saw, at an identical measured own-alpha of 1.00. Nothing about the windows was
  different.
- **A large blur averages the wallpaper away entirely.** `size 32 / passes 4`,
  dimmed to `brightness 0.65` and desaturated to `vibrancy 0.05`, brings that
  spread to 5 — and at `window = 0.90` was worth a **lift of 3 levels of 255**,
  with a backdrop varying by 2. Uniform, and uniformly grey. Nothing on the screen
  said the glass was on.

The setting now measures a lift of **17** and structure of **8**. You can make
out what the wallpaper is through a terminal, which is the point of having one
behind the windows at all. The price is that two terminals over different parts
of the image read as slightly different shades.

## How any of these numbers get settled

`noct-check glass-visible`. It drives a window to fully opaque, then to almost
fully transparent, and reads both ends off a screenshot. Eyes are not reliable at
3 levels of 255, and neither is a config file that looks correct.

`glass.conf` states what you *see*, not what each layer multiplies by, because a
translucent window composites as `seen = own × opacity + backdrop × (1 − opacity)`
and the effect is worth `lift = (backdrop − own) × (1 − opacity)` — both halves
have to be right, and this was got wrong once in each direction.

`blur_brightness` is the dial between "one uniform shade" and "you can see the
wallpaper's shape through a window". It is at 1.00.

Narrative: [design.md](../design.md#why-the-blur-is-small).
