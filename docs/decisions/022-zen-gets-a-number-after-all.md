# 022 — Zen gets a number after all, and it is the mod's own

**Settled 2026-09-07** by measurement. Status: in force.
Does not supersede [013](013-zen-is-translucent-unmatched.md) — see below.

`browsers/zen/user.js` sets two prefs the transparent-zen mod declares:

```js
user_pref("mod.sameerasw.zen_bg_color_enabled", true);
user_pref("mod.sameerasw.zen_transparency_color", "rgba(18, 18, 18, 0.90)");
```

## Why this came up

[021](021-the-colourscheme-is-a-submodule.md) made the terminal level adaptive,
which on a bright wallpaper takes it from 0.55 to about 0.90. Zen did not move.

Measured 2026-09-07, both windows on DP-3 over the same wallpaper:

| | R / G / B | luma | local backdrop | effective opacity |
|---|---|---|---|---|
| Zen page | 89 / 79 / 62 | **89** | 124 | **≈ 0.32** |
| kitty | 23 / 23 / 19 | **22** | 82 | **0.93** (configured 0.90) |

Warm brown against near-black. The method is sound in both directions: derived
from pixels, kitty comes out at 0.93 against a configured 0.90.

**The old match was a coincidence.** At the fixed `terminal = 0.55` the two sat
about 14 levels apart and nobody noticed. Adaptive opacity took that to 36 and
made it obvious.

Note also that a luma match alone would not have done it. Zen was showing 68% of
a photograph and the terminal 7% of the same one, so one was warm and the other
neutral. **Only equal opacity matches them**, which is why this is a number and
not a colour.

## Why this is not 013 coming back

013 gave up a `browser` level in `glass.conf` that was divided by the window
opacity and rendered into a generated `chrome/userChrome.css` in every Zen
profile. It cost a specificity fight with somebody else's stylesheet, four
moving parts that had to stay aligned, and it only showed on pages that painted
nothing themselves.

Three of those four objections do not apply here:

- **No CSS is generated and nothing is overridden.** This sets a pref the mod
  publishes in its own `preferences.json` and reads in its own stylesheet:
  `@media -moz-pref("mod.sameerasw.zen_bg_color_enabled")`. With the checkbox
  off it falls through to `#00000000`, and that fall-through is the whole
  measurement above.
- **One moving part, not four.** `user.js` already sets the two prefs that let
  the mod work at all; these two sit beside them in the same file.
- **The focus step is gone.** `inactive_opacity` went to 1.0 with the rest of
  the compositor level, so there is no 0.06 budget left to run out of.

The fourth stands and is worth stating: this only reaches pages the mod and the
extension actually make transparent. On a page that paints its own opaque
background it does nothing, exactly as 013 said.

What 013 settled against — a level in `glass.conf`, a division by the window
opacity, a generated stylesheet — stays settled. **There is still no number in
`glass.conf` for a browser and there is still no CSS written into a profile.**

## Why 0.90

Zen's setting is a fixed number and the terminal's is not. Across the 41
ultrawide wallpapers the terminal lands between 0.66 and 0.91, so the question
is which single value tracks it best:

| wallpaper | terminal | Zen 0.75 | Zen 0.85 | **Zen 0.90** |
|---|---|---|---|---|
| darkest | 36 | 23 (+13) | 21 (+15) | 20 (+16) |
| median | 36 | 51 (+15) | 38 (+2) | 31 (+5) |
| brightest | 36 | 68 (+32) | 48 (+12) | 38 (+2) |

Background byte, and the gap to the terminal in brackets. 0.90 has the smallest
mean gap (7.7 levels against 9.7 for 0.85) and is closest where it matters, on
the bright wallpapers that made the difference visible in the first place.

The colour is `rgba(18, 18, 18, …)` — the palette's own `bg`, so Zen composites
towards the same ground the terminal does rather than towards black.

## The trap

`user.js` re-applies at every startup, so changing this in the mod's settings
panel lasts until the next restart and then silently reverts. That is the same
trap the transparency prefs above it carry, and it is why they are commented.
Change it in `user.js`; delete the two lines to hand the setting back to the
panel, remembering that a deleted line leaves whatever `prefs.js` recorded
rather than restoring a default.

## What it does not fix

Zen still cannot follow the wallpaper. On the darkest wallpapers the terminal
drops to about 0.10 — there is almost nothing behind it to hide — and Zen stays
at 0.90, 16 levels apart. Both are very dark there, so the absolute difference
is small, but the two are only really the same material in the middle of the
range.
