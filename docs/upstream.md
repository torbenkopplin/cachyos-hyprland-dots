# Upstream facts

What Hyprland, Noctalia, kitty and the browsers actually do, as opposed to what
their documentation says — with the version it was established against, and the
check that holds it.

Most of this repo was written against the Hyprland Lua API source, the
scrolling-layout docs and the Noctalia v5 config reference rather than against a
running system. This is where the difference is recorded.

**Read this before debugging anything that "looks correct and does nothing."**
Almost every real bug in this repo has been of that shape: a dispatcher that
answers `ok` and does nothing, a config key that validates and is ignored, a
provider killed at a deadline with no error shown.

Versions these were established against: **Hyprland 0.56.2**, **Noctalia
5.0.0-beta.8**, **kitty 0.42**, **zen-browser-bin 1.21.14b**.

---

## Hyprland

| Fact | Established | Held by |
|---|---|---|
| `m~n` is **not valid syntax**. The dispatcher answers `ok` and no workspace changes — which is why every number key was dead | Disproven 2026-08-18 | [003](decisions/003-workspace-numbers-are-arithmetic.md), `lib/ws.lua` |
| `m+1` / `m-1` walk only the workspaces that currently *exist* on the monitor — usually one | Disproven 2026-08-18 | [003](decisions/003-workspace-numbers-are-arithmetic.md) |
| `hyprctl keyword` is a **silent no-op under the Lua parser**: "keyword can't work with non-legacy parsers. Use eval." So an A/B test written with it measures nothing and reports success | Disproven 2026-08-18 | `noct-check keyword-inert` |
| `hyprctl eval` prints `ok` or an error, **never the value you return**. Every `return ...` check was reading its own hope. Assert instead, or write to a file with `io` (the sandbox does provide it) | Disproven 2026-08-18 | TESTING.md diagnostics |
| A dispatcher's `window` selector does **not** take a bare address. `window = "0x…"` answers "window not found"; the hyprctl form `"address:0x…"` is what matches | Disproven 2026-08-18 | `lib/nav.lua` |
| `column.index` and `index_in_column` are **0-based**, and `window.layout` is populated for every tiled window on a scrolling workspace | Verified 2026-08-18 | `lib/nav.lua` |
| `hl.get_workspace_windows(<id>)` accepts a numeric id | Verified 2026-08-18 | `lib/nav.lua` |
| Moving a column's windows to another workspace does **not** keep them in one column — each arriving window starts a column of its own. `move_column()` moves them with `follow = false` and re-consumes them, which also restores row order | Disproven 2026-08-18 | `noct-check column-hop` |
| A workspace rule's `layout_opts` carries `direction` but **not** `column_width`: the layout takes the width only from the global `scrolling:column_width`. Measured: a new window on the 0.5 band came out at 0.333 | Disproven 2026-08-18 | [005](decisions/005-per-monitor-column-width.md), `lib/colwidth.lua` |
| `monitor.focused` fires **before** the switch is recorded — inside the handler `hl.get_active_monitor()` still answers with the monitor you left. Use the event's own argument | Disproven 2026-08-18 | `lib/colwidth.lua` |
| The scrolling layout reports "no column that way" as a **success** and "no row that way" as `NOT_FOUND`, so edge detection cannot be built on the return value | 2026-08-18 | [004](decisions/004-edges-are-read-not-inferred.md) |
| A dispatcher can fail **without raising**, so a `pcall` around it returns true. `SUPER+CTRL+SHIFT+hjkl` silently did nothing, and so did the obvious fix | Disproven 2026-08-18 | `noct-check monitor-hop` |
| A border gradient cannot be one string in a Lua config. `"rgb(a) rgb(b) 45deg"` is hyprland.conf syntax; Lua wants `{ colors = {...}, angle = 45 }`. The string form loads silently and draws a flat border | Disproven 2026-08-18 | `templates/hyprland-colors.lua`, `conf/look.lua` |
| `xray` is a **layer** rule, not a window rule. It is accepted as a window rule and ignored | Disproven 2026-08-18 | `noct-check blur-stacks` |
| With `blur.xray`, each window samples the wallpaper behind **itself**, so two windows at an identical opacity read 4–6 levels apart over different parts of the photo | Measured 2026-08-18 | [011](decisions/011-the-blur-is-small.md) |
| Hyprland pauses idle notifications for as long as a client holds a Wayland idle inhibitor | Protocol behaviour, assumed | [006](decisions/006-idle-has-one-owner.md) |
| Gesture action `scroll_move` | Documented, **untested** | `conf/input.lua` |
| `hyprctl reload` picks up a newly created `generated/colors.lua` | Unconfirmed — Hyprland reloads on config change, but whether it watches `require`d files is not known, hence the explicit reload | `40-templates.toml` |

## Noctalia

| Fact | Established | Held by |
|---|---|---|
| A dmenu provider gets **~2 seconds** before SIGTERM (exit 143), and the launcher then shows "No results found" with no partial list and no visible error. Undocumented | Measured 2026-08-18 | [018](decisions/018-providers-get-two-seconds.md), `noct-check provider-run` |
| A provider's whole result line is **displayed**, both sides of the tab — so there is nowhere in it to hide a payload | 2026-08-18 | `bin/noct-common.sh` |
| `noctalia config validate` **does** check widget keys: it names an unknown setting and rejects a value outside a key's allowed set. This is the fastest way to discover a widget's real schema, and how the one in this repo was derived | Disproven-then-verified 2026-08-18 | `10-bar.toml` |
| A bar capsule group is named with `id`, not `name`. `name` validates as an unknown setting and `group:<id>` then matches nothing | Disproven 2026-08-18 | `10-bar.toml` |
| `capsule_fill` and `capsule_opacity` are accepted, appear in `config export merged`, and are **ignored** for group capsules, which draw as opaque `surface_variant`. Verified by setting the fill to `#ff0000` and watching nothing turn red. Radius, padding and thickness do apply | Disproven 2026-08-18 | [009](decisions/009-the-bar-is-three-capsules.md) |
| `capsule_border` colours nothing on its own. The only width available is `border_width`, which outlines the *bar* — and with an invisible bar that draws a full-width line above and below the capsules | Disproven 2026-08-18 | `10-bar.toml` |
| `margin_ends` is the only width lever for the bar, in absolute pixels, shared across monitors. `"25%"` is not a percentage (flat 88px). `monitor = "DP-3"` validates and is ignored | Disproven 2026-08-20 | [009](decisions/009-the-bar-is-three-capsules.md) |
| The workspace widget draws the workspaces that **exist**; there is no key for a fixed row | 2026-08-18 | [017](decisions/017-workspaces-stay-dynamic.md) |
| The **built-in kitty template writes `themes/noctalia.conf` and rewrites `kitty.conf`** to include it, clobbering the tracked symlink | Disproven 2026-08-18 | `noct-check kitty-untouched` |
| Excluding `kitty` from `builtin_ids` is **not** enough to stop it. It ran anyway, eleven seconds before Noctalia saved `settings.toml` — the GUI's copy of `builtin_ids` loads last and wins. `noctalia msg templates-apply` does not reproduce it, so a correct config file is no evidence the built-in is off | Disproven 2026-08-19 | [010](decisions/010-glass-is-the-terminal-only.md) |
| A user template may share a name with a built-in id (`kitty`, `hyprland`) without colliding — both render while the id is absent from `builtin_ids`. Read alongside the row above | Verified 2026-08-18 | `40-templates.toml` |
| `colors.tertiary` is available to a user template and renders to real hex (`#ffffff` on noirblaze), so the border gradient has a second role to use | Verified 2026-08-18 | `templates/hyprland-colors.lua` |
| The colour roles `kitty-colors.conf` uses (`terminal_*`, `primary`, `outline_variant`) all render to real hex, no leftover placeholders | Verified 2026-08-18 | `templates/kitty-colors.conf` |
| `noctalia msg greeter-sync` **does not exist**; appearance sync to the greeter is a GUI action | 2026-08-19 | [016](decisions/016-greetd-instead-of-plasmalogin.md) |
| Panel layer namespaces (`noctalia-panel`, `-attached-panel`, `-window-switcher`) | Taken from Noctalia's own blur layer rule, not documented | `lib/bar.lua` |
| `[keybinds]` chord names (`ctrl+k`, `iso_left_tab`) | Format documented, these exact names **not confirmed** | `00-shell.toml` |
| dmenu `prefix` is a bare word (`"ssh"` → `/ssh`) | Docs contradict themselves — one example page shows `"/cmd"` | `20-launcher.toml` |
| `control-center` is hyphenated while other widget ids are snake_case | Matches upstream doc titles, which are genuinely inconsistent | `10-bar.toml` |
| Built-in template ids (`qt`, `kcolorscheme`, …) | Taken from CachyOS's shipped config; verify with `noctalia theme --list-templates` | `40-templates.toml` |
| A `post_hook` is run through a shell, so `${VAR:-default}` expands | Docs say hooks are rendered then executed; shell semantics **assumed** | `40-templates.toml` |
| `colors_changed` fires on a scheme change and not only a wallpaper change | Documented as "after the theme palette is resolved". If it turns out to be wallpaper-only, call `noct-glass apply` from `noct-theme act` instead | `50-glass.toml` |
| Custom palettes are read from `~/.config/noctalia/palettes/<name>.json` | Documented; the exact key set came from the docs example | `palettes/noirblaze.json` |
| `[plugins].enabled` activates the wallhaven plugin declaratively | Documented, but the plugin system is beta; `noctalia msg plugins enable noctalia/wallhaven` is the fallback | `60-wallpaper.toml` |

## kitty

| Fact | Established | Held by |
|---|---|---|
| `background_opacity` is applied **at startup only** — with a fresh `SIGUSR1`, running kitties reloaded colours and not opacity. `dynamic_background_opacity yes` is what lifts that (157.5 → 255.0) | Disproven 2026-08-18, fixed 2026-08-19 | [010](decisions/010-glass-is-the-terminal-only.md), `noct-check kitty-live` |
| kitty accepts `-e` as a compatibility alias, undocumented in `--help`. foot, alacritty, ghostty, konsole and xterm take it too, so `in_terminal` can use one form for all of them | Disproven 2026-08-18 | `bin/noct-common.sh` |
| kitty is the one window that fades its background and leaves its **text** alone | 2026-08-19 | [010](decisions/010-glass-is-the-terminal-only.md) |

## Browsers

| Fact | Established | Held by |
|---|---|---|
| Zen's profile root is `~/.config/zen`, not `~/.zen` — which does not exist. The Zen half of `--browsers` had never landed a file | Disproven 2026-08-18 | `install/manifest/browsers.tsv` |
| A Firefox-family browser reads `user.js` exactly **once**, at startup | 2026-08-18 | `tests/lib/probe.sh` |
| A page tinted to match a window is invisible on the pages you actually visit: all four browsers composited at 0.85, 0.00 apart, on an ordinary page. A tint under the page area only shows where the page paints nothing itself | Measured 2026-08-19 | [013](decisions/013-zen-is-translucent-unmatched.md) |
| Brave-specific policy names (`BraveRewardsDisabled`, `BraveAIChatEnabled`, …) are less stable than Chromium's | `brave://policy` is the check | `browsers/brave/policies.json` |

## Packaging and the session

| Fact | Established | Held by |
|---|---|---|
| Every package name in the manifest resolves on CachyOS, and the AUR fallback was never reached | Verified 2026-08-18 | `./install.sh --check` |
| `shelly install standard/aur --no-confirm` authenticates through **polkit**, so it needs an agent: in a bare TTY it fails and the pacman path takes over | 2026-08-18 | [015](decisions/015-pacman-first.md) |
| `noctalia-greeter-session` is the greetd entry point | From upstream's README; the path is resolved with `command -v` rather than hardcoded | [016](decisions/016-greetd-instead-of-plasmalogin.md) |
| `fisher` exists as a package | If not, the installer warns rather than failing; install it by its documented one-liner and rerun | `install/manifest/packages.tsv` |
| `uwsm start -S -F hyprland.desktop` is the right invocation | Adapted from `start-hyprland`; the original is kept as a fallback in the same file | `config/fish/auto-Hypr.fish` |
| yazi's `%s` opener placeholder is still current | Carried over verbatim from a working config rather than modernised | `config/yazi/yazi.toml` |
| Wallhaven result counts hold over time | Measured 2026-08-15; the 21:9 Dragon Ball supply was 4 and can only grow | `wallpapers.conf` |

## Measurement itself

Two ways a reading can be **meaningless rather than wrong**. Both are handled by
skipping, never by concluding.

| Fact | Established | Held by |
|---|---|---|
| A locked screen invalidates every pixel measurement. `grim` photographs the lock screen without complaint: locked, `kitty-live` read 138.9 before and after and reported that kitty ignores `SIGUSR1`; unlocked, the same run measured 157.5 → 255.0. The pixel checks now notice that a window forced to full white did not come back near 255 | Measured 2026-08-19 | `tests/checks/50-glass.sh`, `60-kitty.sh` |
| A tiled probe can land somewhere unmeasurable. On a 3440x1440 + 1920x1080 pair the tape probe opened as the second row of a column on the short monitor, 942px of window starting at y=966 of 1080 — 114px against a 150px floor. Every pixel check skipped, and the message blamed motion. It now reports where the probe actually is | Disproven 2026-08-19 | `tests/lib/probe.sh` |
| **A rotated monitor is still misjudged.** `noct_window_geom` clips the patch against the monitor's `width`/`height` as `hyprctl monitors` reports them (1920x1080 for `HDMI-A-1`), while window coordinates are in *logical* space — 1080x1920 under `transform = 3`. Anything past y=1080 on that screen reads as off the edge, so `glass-visible`, `glass-legible`, `blur-stacks`, `browser-glass` and `column-hop` all skip. Fix is to swap width and height when `transform` is odd | **Open**, 2026-08-20 | [TODO.md](../TODO.md) |

## Facts that stopped mattering

Kept because they are the reasoning behind a gap, and a gap invites a rebuild.

| Fact | Why it no longer matters |
|---|---|
| `zen_transparency_color` tints Zen (measured: a 0.75 pref composited as 0.82 on reddit), and defines the background variable on an element below `:root` so a stylesheet cannot override it from above | Superseded by a generated stylesheet 2026-08-18, then moot 2026-08-19 — nothing tints Zen at all. [013](decisions/013-zen-is-translucent-unmatched.md) |
| `:root .browserStack > browser` loses a specificity fight with the transparency mod (0-2-1 against the mod's `!important` 0-3-1); beatable with `#main-window …` plus a tripled `:root` | Moot 2026-08-19. Having to win that fight silently, every time the mod changes its selector, is one of the reasons the approach went. [013](decisions/013-zen-is-translucent-unmatched.md) |
| Whether setting `mod.sameerasw.*` from `user.js` reaches the Zen mod | Never resolved, and no longer asked. If you ever go back to driving a mod from a pref, this is still unconfirmed |
| Firefox may resolve a symlinked `userChrome.css` before relative `@import`s, so an import next to a repo-linked sheet would look in the repo and fail silently | Avoided rather than confirmed, and moot since nothing generates a stylesheet. Worth remembering before ever linking one out of this repo |

## Adding to this

A fact belongs here when it is about somebody else's software, it was surprising,
and something in this repo depends on it. Give it the date and the version, and
name the check that holds it — a row with no check is a fact that will rot.

If there is no check and one is possible, the check is the better contribution.
