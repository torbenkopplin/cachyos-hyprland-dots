# 029 — A design bundles palette, shape and material, and is swapped whole

**Settled 2026-11-25** on Noctalia 5.6.0 and Hyprland 0.57. Status: in force.
Makes [010](010-glass-is-the-terminal-only.md),
[011](011-the-blur-is-small.md) and [028](028-the-bar-is-one-pill.md) the
**Glass** design rather than the only look. Each still holds inside that design.

`/theme` already swapped colours everywhere. Shape and material did not swap:
rounding, the gradient border, the glass pill and the terminal's translucency
are spread over six files, and changing the palette left all of them alone. So
the noirblaze look could change colour but could not stop being rounded glass.

A design is one TOML file in `config/noct-design/`. `noct-design` (`/design`,
`SUPER+CTRL+A`) renders it into three generated files that load after the
tracked config, plus a palette switch:

| Table | Becomes | Loaded by |
|---|---|---|
| `[noctalia]`, `[pill]` | `~/.config/noctalia/90-design.toml` | Noctalia, after `00`–`70` |
| `[hyprland]` | `~/.config/hypr/generated/design.lua` | `lib/design.lua`, after `colors.lua` |
| `[glass]` | `~/.local/state/noctalia/design-glass.conf` | `noct-glass`, before `glass.local.conf` |
| `palette` | `noctalia msg color-scheme-set` | — |

The tracked config stays the Glass design: `glass.toml` names its palette and
its one font, which it also applies to GTK and Qt. A table a design leaves out
writes no file.

## Three things that shaped it

- **Noctalia replaces arrays, it does not merge them.** Measured 2026-11-25: a
  later `.toml` with one `[[bar.default.capsule_group]]` holding `id` and
  `radius` replaced the whole list, and the pill came up with no members. So
  `[pill]` names only the keys that change, and `noct-design` writes the full
  group from `10-bar.toml` with them merged in. The members stay in one place.
- **The Settings UI layer wins over every `.toml`.** `settings.toml` in the state
  directory already held `transparency_mode` and `font_family` from the GUI, so
  a generated file alone could not change them. For a key that layer holds,
  `noct-design` saves the value and calls `noctalia msg config-set` with the
  design's, and the next switch sets the saved value back. GTK and Qt fonts are
  saved and restored the same way. Restoring the tracked value instead was the
  first version; a review found it would overwrite choices made in the Settings
  UI before any design was picked.
- **The designs are not in `~/.config/noctalia`.** They are TOML, and a `.toml`
  there is Noctalia config.

## Settled against

| What | Why not |
|---|---|
| A design as a set of edits to the tracked files | Switching would dirty the checkout, which is the live config ([001](001-links-not-copies.md)) |
| Restoring the tracked value on switching back | It overwrites a Settings UI or font choice the user made before any design was picked |
| Writing every key through `config-set` | It puts `[bar.*]` tables in `settings.toml`, which is exactly the override `noct-check bar-pill-config` reports |
