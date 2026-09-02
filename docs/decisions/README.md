# Decisions

One file per decision, dated, with the measurement that settled it. Append-only:
a decision that turns out wrong gets a new entry that supersedes it rather than an
edit that hides it.

This exists because of the shape of this repo's history. Six of the biggest pieces
of work here were built, measured, and then removed — compositor-wide glass, the
Zen match, the `browser` level, the browser-parity gate, a glass bar island, three
shapes of bar. All of them were correct work. What makes them expensive is not the
building, it is the second person (or the same person in three months) looking at
the gap where the feature should be and starting again.

So the **Settled against** sections are the load-bearing half of this directory.

## What goes where

| | |
|---|---|
| **decisions/** (here) | a choice, when it was made, and the number or measurement that made it |
| [design.md](../design.md) | how the navigation model and the five non-obvious mechanisms actually work |
| [theming.md](../theming.md) | the palette, the glass, and the long form of 010–013 |
| [upstream.md](../upstream.md) | version-stamped facts about Hyprland, Noctalia, kitty and the browsers, each with the check that holds it |
| [../../TESTING.md](../../TESTING.md) | what a person has to judge on a live session |
| [../../tests/README.md](../../tests/README.md) | how the measurement suite is built, and the two rules that shape it |

## The log

| # | Decision | Settled |
|---|---|---|
| 001 | [Deploy by symlink, one file at a time, and be reversible](001-links-not-copies.md) | 2026-08-15 |
| 002 | [The Hyprland config is Lua, split into options, conf and lib](002-hyprland-config-is-lua.md) | 2026-08-15 |
| 003 | [Workspace numbers are arithmetic, not a selector](003-workspace-numbers-are-arithmetic.md) | 2026-08-18 |
| 004 | [Edges are read from the layout, not inferred from a failed dispatch](004-edges-are-read-not-inferred.md) | 2026-08-18 |
| 005 | [Per-monitor column width, applied as focus crosses monitors](005-per-monitor-column-width.md) | 2026-08-18 |
| 006 | [Idle has exactly one owner](006-idle-has-one-owner.md) | 2026-08-18 |
| 007 | [Tapping SUPER is a release bind, with a fallback kept in the drawer](007-tap-super-is-a-release-bind.md) | 2026-08-15 |
| 008 | [The bar is event-driven, reconciled, and answers the pointer](008-the-bar-is-event-driven.md) | 2026-08-18 |
| 009 | [The bar is three centred capsules of Noctalia's own card material](009-the-bar-is-three-capsules.md) | 2026-08-20 |
| 010 | [Frosted glass is the terminal and nothing else](010-glass-is-the-terminal-only.md) | 2026-08-19 |
| 011 | [The blur is small, so the wallpaper stays visible through a terminal](011-the-blur-is-small.md) | 2026-08-19 |
| 012 | [The installer is a manifest plus an engine, and it has a `--root`](012-installer-is-data-plus-an-engine.md) | 2026-08-20 |
| 013 | [Zen is translucent, and nothing here tries to make it match](013-zen-is-translucent-unmatched.md) | 2026-08-19 |
| 014 | [Exactly two files may differ per machine](014-two-machine-local-files.md) | 2026-08-19 |
| 015 | [pacman first, shelly preferred, the AUR as a fallback](015-pacman-first.md) | 2026-08-18 |
| 016 | [greetd + noctalia-greeter, and it is opt-in](016-greetd-instead-of-plasmalogin.md) | 2026-08-19 |
| 017 | [Workspaces stay dynamic](017-workspaces-stay-dynamic.md) | 2026-08-18 |
| 018 | [A launcher provider gets two seconds, so it may not ask anything slow](018-providers-get-two-seconds.md) | 2026-08-18 |
| 019 | [Mail credentials live in `pass`, and `accounts.conf` holds only the lookup](019-mail-credentials-live-in-pass.md) | 2026-08-22 |
| 020 | [The MX Keys print key is remapped below Hyprland, not bound inside it](020-the-print-key-is-remapped-below-hyprland.md) | 2026-08-26 |

## Settled against, in one place

The dead ends, and where the reasoning is. Read these before rebuilding one.

| Not doing | Because | Where |
|---|---|---|
| Frosted glass on every window | The compositor cannot tell a glyph from its background, so the price is a permanent discount on every letter in every app | [010](010-glass-is-the-terminal-only.md) |
| Making Zen's translucency match the desktop's | It only showed on pages that paint no background, it needed a silent specificity fight with someone else's extension, and there was no room between the two focus states | [013](013-zen-is-translucent-unmatched.md) |
| A browser-parity gate in the suite | A deliberately translucent Zen *is* a spread, so the gate could only fire on the intended state. Retired, not exempted — and not kept as a metric either, because a baseline tolerance is the same gate under another name | [013](013-zen-is-translucent-unmatched.md) |
| A small glass island instead of a bar | A capsule draws opaque whatever you ask; the only surface that takes an opacity spans the monitor; the only width lever is absolute pixels and shared between screens | [009](009-the-bar-is-three-capsules.md) |
| A large blur, for one uniform shade | It averages the wallpaper away: measured a lift of 3 levels of 255, i.e. nothing on screen saying the glass was on | [011](011-the-blur-is-small.md) |
| A Hyprland bind on the MX Keys screenshot chord | A bind cannot subtract the modifiers, so the key never becomes a Print key — and one press of it fired `SUPER+SHIFT+S` *and* `SUPER+S`, so the scratchpad answers underneath whatever the chord is pointed at | [020](020-the-print-key-is-remapped-below-hyprland.md) |
| Moving the scratchpad off `S` to free the chord | The `S` / `SHIFT+S` pair is the toggle-and-send shape the rest of the keymap is built from | [020](020-the-print-key-is-remapped-below-hyprland.md) |
| A keyring for the mail password | `secret-tool` is on PATH but nothing owns `org.freedesktop.secrets`; the only activatable name fails to launch. It needs gnome-keyring plus PAM unlock wiring under greetd, on both machines, for what one GPG key already buys | [019](019-mail-credentials-live-in-pass.md) |
| The mail password inline in `accounts.conf` | A readable secret on disk, when `source-cred-cmd` costs one line. Kept documented as the fallback for a machine with no GPG key | [019](019-mail-credentials-live-in-pass.md) |
| `hypridle` alongside Noctalia's idle service | Two countdowns to the same lock screen, one of them configured in a directory this repo does not manage | [006](006-idle-has-one-owner.md) |
| Persistent workspaces, for a fixed row of pips | It is a compositor change that buys a cosmetic one and gives up the dynamic model | [017](017-workspaces-stay-dynamic.md) |
| `rustup` in the package list | `Conflicts With: rust cargo` plus `--noconfirm` would silently swap a working toolchain for one that ships none | [015](015-pacman-first.md) |
| Inferring an edge from a failed focus dispatch | The scrolling layout reports "no column that way" as a success and "no row that way" as an error, so only half of it is detectable | [004](004-edges-are-read-not-inferred.md) |
| `m~n` / `m±1` for per-monitor workspaces | The first is not valid syntax and answers `ok`; the second walks only workspaces that already exist | [003](003-workspace-numbers-are-arithmetic.md) |
| Sandboxing the installer with `HOME` | `HOME` and `XDG_CONFIG_HOME` are two different roots and overriding one relinked a live desktop into `/tmp`. `--root` instead | [012](012-installer-is-data-plus-an-engine.md) |

## Adding one

Next number, `NNN-short-kebab-title.md`, a line in both tables above if it settles
something against. `tests/lint.sh decisions-index` fails when a file is missing
from the index or the index links a file that is not there.
