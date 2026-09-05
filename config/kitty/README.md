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
now its own repository, vendored at `vendor/noirblaze` and linked into
`~/.config/noctalia/palettes/`, where it drives the whole desktop instead of just
the terminal and where `/theme` can select it. See
[decision 021](../../docs/decisions/021-the-colourscheme-is-a-submodule.md).

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

Neovim inherits it, because `init.lua` in the nvim repo sets `bg = "none"` on
`Normal`, `NormalNC` and eighteen other groups right after loading the
colourscheme. So the editor composites against the wallpaper exactly as the
shell does.

That is the case noirblaze is solved for. Every foreground clears its contrast
floor against the **composited** background rather than against `#121212` — which
matters, because kitty makes a cell translucent only when its background matches
the default background, so a group with `bg = c.bg` composites and a group with
`bg = c.bg3` (a popup, the status line) does not, and the two need different
foregrounds to reach the same ratio.

Worth knowing: with a transparent editor background, `CursorLine` and `Visual`
are the only things separating text from the wallpaper, and unfocused splits
stop being visually distinct. Both of those still paint an explicit background,
so both survive the transparency.
