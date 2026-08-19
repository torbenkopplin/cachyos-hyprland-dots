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

**`generated-colors.conf`** — the palette for new terminal windows, rendered from
the active Noctalia scheme by the user template in
`config/noctalia/templates/kitty-colors.conf`. That is how `/theme` reaches the
terminal, so the file belongs to the template engine; the copy in git would be
stale the moment you changed scheme.

Your old static noirblaze theme lived in a file like this. It is not lost — it is
now `config/noctalia/palettes/noirblaze.json`, where it drives the whole desktop
instead of just the terminal, and where `/theme` can select it.

> **Do not enable Noctalia's built-in `kitty` template.** It writes
> `themes/noctalia.conf` *and rewrites `kitty.conf`* to include it, replacing
> whatever theme include it finds. `install.sh` symlinks `kitty.conf` into this
> repo, so the built-in edits a tracked file — the checkout goes dirty on every
> palette change, `./install.sh --update` on the other machine then refuses to
> pull over the edit, and `git pull` by hand conflicts over generated output. That
> is why the colours come from a user template with an output path of our own
> choosing.
>
> **It is not off just because `builtin_ids` omits it.** Observed 2026-08-19: it
> ran anyway, eleven seconds before Noctalia saved `settings.toml`, whose copy of
> `builtin_ids` loads after `40-templates.toml` and wins. `noctalia msg
> templates-apply` does not reproduce it, so the config file being right proves
> nothing. `noct-check kitty-untouched` is the check; if it fires, turn the
> template off in the GUI (`SUPER+,`), then:
>
> ```sh
> git checkout -- config/kitty/kitty.conf
> rm -rf ~/.config/kitty/themes
> ```
>
> No colours are lost — `generated-colors.conf` carries the same palette.

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
