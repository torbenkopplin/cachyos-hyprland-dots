# kitty

Carried over from the Ubuntu setup. Two files here are third-party:

| File | Origin | Licence |
|---|---|---|
| `search.py` | [trygveaa/kitty-kitten-search](https://github.com/trygveaa/kitty-kitten-search) | GPLv3 |
| `scroll_mark.py` | small local kitten | — |

`search.py` is GPLv3, so if this repo is ever published under a different
licence that file needs to be either kept under GPLv3 with attribution (it
carries its own header) or fetched at install time rather than vendored.

## Files this repo deliberately does not track

**`current-theme.conf`** — Noctalia's `kitty` template rewrites it on every
palette change. That is exactly how `/theme` reaches new terminal windows, so
the file has to belong to the template engine. Tracking it would mean fighting
for ownership on every scheme switch, and the copy in git would be stale the
moment you changed anything.

Your old static noirblaze theme lived in this file. It is not lost — it is now
`config/noctalia/palettes/noirblaze.json`, where it drives the whole desktop
instead of just the terminal, and where `/theme` can select it.

**`generated-glass.conf`** — written by `bin/noct-glass` with the frosted-glass
level for the active scheme. Levels are configured in
`config/noctalia/glass.conf`.

Both are `include`d by `kitty.conf` and neither exists until the shell has
rendered a palette once. kitty warns about a missing include and carries on,
so a first launch before Noctalia has started is not fatal.

## Transparency and neovim

kitty's `background_opacity` makes the terminal *background* translucent while
leaving text opaque — that is what the frosted-glass effect is built on.

Neovim will not inherit it. Your `noirblaze.lua` sets `Normal` and `NormalNC`
to `bg = c.bg` (`#121212`), which paints an opaque rectangle over the whole
terminal. If you want the editor to be frosted too, that needs a one-line
change **in the nvim repo, not this one**:

```lua
hi("Normal",   { fg = c.fg2, bg = "none" })
hi("NormalNC", { fg = c.fg2, bg = "none" })
```

Worth knowing before you decide: with a transparent editor background, the
`CursorLine` and `Visual` highlights become the only things separating text
from the wallpaper, and unfocused splits stop being visually distinct.
