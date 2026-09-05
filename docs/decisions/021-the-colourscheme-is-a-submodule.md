# 021 — The colourscheme is a submodule, and its opacity is measured

**Settled 2026-09-05.** Status: in force.

`config/noctalia/palettes/noirblaze.json` is gone. The palette comes from
`vendor/noirblaze`, a submodule of
[torbenkopplin/noirblaze](https://github.com/torbenkopplin/noirblaze), and
`links.tsv` points a row straight at `dist/noirblaze.json` inside it.

## Why it left this repo

The same theme was in two places: here as a Noctalia palette, and in the neovim
config as `colors/noirblaze.lua`. Two hand-edited copies of fifteen colours, and
the only thing keeping them in step was remembering.

That is the same argument as [001](001-links-not-copies.md), one level up. A
symlink stops `~/.config` drifting from the repo; a submodule stops the repo
drifting from the other repo.

## What it fixed, measured

The theme's dim band was below WCAG AA **on its own background**: on `#121212`,
4.5:1 needs byte 124, and `dim1` through `dim4` are 83, 115, 120 and 122. At
`terminal = 0.55` over a bright wallpaper `Comment` reached **1.02:1** — the
composited background passes the text's own luminance and the two swap places.

`bright.black` was the one that bit hardest in practice, at **3.95:1** before any
transparency: the fish prompt, `git diff` context lines, `ls`, `fzf`, `bat` line
numbers, `delta`. It is `#8b8b8b` now, 4.56:1.

Measured on this session, before and after, with `noct-check glass-legible`:

| | before | after |
|---|---|---|
| terminal text contrast | 5.16:1 | **11.10:1** |
| composited background | 84 | 32 |
| lift | 53.7 | 12.6 |
| structure | 30.9 | 5.9 |

## Why the level is adaptive, and why that is not "less glass"

`lift = (backdrop − own colour) × (1 − opacity)`, so a fixed `terminal` is not a
fixed amount of glass. Across the 41 ultrawide wallpapers in
`~/Pictures/Wallpapers`, at the shipped 0.55:

| backdrop (brightest window-sized tile) | 38 | 101 | 153 | 212 | 238 |
|---|---|---|---|---|---|
| lift | **9.0** | 37.4 | 60.8 | 87.3 | **99.0** |

Ten to one — and the bottom of that range is below the `LIFT_MIN = 12` that
`tests/checks/50-glass.sh` enforces. On the darkest wallpapers in the folder the
frosted glass was not visible at all.

[011](011-the-blur-is-small.md) tuned the blur against a lift of 17, on a
wallpaper of mean luma 99 whose backdrop reached 72. That was a correct
measurement of one image.

So `noct-glass` measures the wallpaper and solves for the level. **It does not
make the desktop less glassy; it makes it the same every time.** The price is
that the number moves — about 0.66 over a dark wallpaper and 0.90 over a bright
one, against a fixed 0.55 before.

## Three things this cost, all of them stated

- **The level is driven by the BRIGHTEST window-sized tile**, not the mean,
  because `blur.xray` is false and a window samples what is behind itself — a
  window can be anywhere, so the level has to serve the worst place you can put
  one. Measured, the brightest tile runs about 50 levels above the whole-image
  mean (median 153 against 101). The consequence is that over the *darker* parts
  of a mixed wallpaper the lift sits near the floor: measured 12.6 against a
  `LIFT_MIN` of 12. Legibility everywhere, minimum glass in the dark corners.
- **`templates-apply` does not re-read a palette file.** It re-renders against
  the palette Noctalia already has in memory, so an update that changes
  `dist/noirblaze.json` renders the old colours and reports success. Measured:
  with `bright.black` changed to `#8b8b8b`, `templates-apply` wrote `#737373`.
  Re-issuing `color-scheme-set` with the scheme already selected is what makes
  it re-read the file. `install/lib/update.sh` does both now.
- **A submodule makes this checkout dirty when it moves.** `git status` reports
  ` M vendor/noirblaze` whenever the submodule is not at the recorded commit,
  and `--update` refuses to pull over local changes. That refusal is correct —
  the theme is your live config — but the advice it printed ("commit them, or
  `git stash`") does not apply to a submodule, so it now says so.

## Settled against

**Keeping the palette here and the Lua there, kept in step by hand.** It is what
was happening, and the fifteen colours had already diverged in one place: the
palette's `_comment` credited the upstream kitty theme for `#00ff77`, which
upstream does not have — upstream paints ANSI 2 pink. Nobody noticed for months
because there was nothing that could.
