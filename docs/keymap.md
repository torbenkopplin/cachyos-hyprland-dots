# Keymap

Every key in the session, grouped by what it does. The short version -- the
dozen you need on the first day -- is in the [README](../README.md#the-keys-that-matter-first).

`SUPER` throughout, written `M`.

## Navigation

| Key | Action |
|---|---|
| `M + H` / `L` | Focus left / right along the tape → next **monitor** at the edge |
| `M + J` / `K` | Focus down / up within the column → next **workspace** at the edge |
| `M + SHIFT + H/J/K/L` | Move the focused window, with the same handoff |
| `M + CTRL + SHIFT + H/L` | Send window to the monitor left / right, unconditionally |
| **arrows** | Every directional bind above is on the arrow keys too, same modifiers |
| `M + Tab` | Window switcher |

`SHIFT` means "bring the window with you" everywhere — with a direction, with a
number key, with the scratchpad. (It used to be `CTRL` for directions and
`SHIFT` for numbers; the two are swapped now, which is the change to unlearn if
you have been using this a while.)

## Arranging the tape

| Key | Action |
|---|---|
| `M + CTRL + H` / `L` | Swap this column with its neighbour |
| `M + O` | Consume — pull the next window into this column |
| `M + I` | Expel — push this window out into its own column |
| `M + SHIFT + .` | Promote to a new column |
| `M + [` / `]` | Scroll the tape without moving focus |
| `M + Z` | Bring the focused column back into view |
| `M + SHIFT + Z` | Scroll lock — focus moves, the tape stays put |

## Sizing

| Key | Action |
|---|---|
| `M + +` / `-` | Cycle the six column width presets (¼ … full) |
| `M + =` / `SHIFT + -` | Widen / narrow by 5% |
| `M + SHIFT + F` | Expand into whatever free space is left |
| `M + SHIFT + E` | Even out the visible columns |
| `M + R` | **Resize mode**: `hl` width, `jk` height (arrows too), `Esc`/`Enter` to leave |

## Windows and workspaces

| Key | Action |
|---|---|
| `M + BackSpace` / `Q` | Close window (either) |
| `M + SHIFT + Q` | Kill |
| `M + F` / `M` | Fullscreen / maximize |
| `M + V` | Toggle floating |
| `M + P` | Pin above workspaces |
| `M + G` | Toggle tab group |
| `M + 1…9`, `0` | Workspace *n* **on this monitor** |
| `M + SHIFT + 1…9`, `0` | Send window to workspace *n* on this monitor |
| `` M + ` `` | Previous workspace |
| `M + S` / `SHIFT + S` | Scratchpad: toggle / send to |

## Shell

| Key | Action |
|---|---|
| **tap `SUPER`** | **Launcher** |
| `M + Space` | Launcher (fallback, in case the tap detector misbehaves) |
| `M + A` | Control centre |
| `M + N` | Notifications |
| `M + X` | Clipboard history |
| `M + ,` | Shell settings |
| `M + W` | Wallpaper picker |
| `M + SHIFT + W` | Browse Wallhaven |
| `M + B` | Pin / unpin the bar |
| `M + SHIFT + G` | Cycle frosted glass level |
| `M + CTRL + Escape` | Lock |
| `M + Escape` | Session menu |

## System control — straight into the launcher

| Key | Prefix | What you get |
|---|---|---|
| `M + CTRL + O` | `/aout` | Audio **o**utput device — switches default *and* moves live streams |
| `M + CTRL + I` | `/ain` | Audio **i**nput device |
| `M + CTRL + B` | `/bt` | Bluetooth — connect, disconnect, scan, radio |
| `M + CTRL + N` | `/net` | Networks — connect, disconnect, Wi-Fi in range, radio |
| `M + CTRL + P` | `/power` | Power profile, night light, caffeine |
| `M + CTRL + T` | `/theme` | Colour scheme — wallpaper, built-in, or your own |

Inside the launcher, `Ctrl+J` / `Ctrl+K` move the selection (plain `j`/`k` go
into the search box, since you are typing).

**Providers get about two seconds.** Noctalia runs a dmenu provider's `command`
synchronously and SIGTERMs it at roughly 2000 ms; what you see when it does is
"No results found", with the reason only in `~/.cache/noctalia/noctalia.log` at
debug level. Measured on v5.0.0-beta.8 — the docs do not mention a limit. Two
rules come out of it, and both are enforced in `bin/noct-common.sh`:

- **A provider must not call `noctalia msg` while listing.** The shell is
  blocked waiting for the provider, so the IPC call cannot be answered and the
  provider is killed at the deadline — a deadlock that presents as an empty
  list. `/theme` needs the active scheme, so it reads Noctalia's own state
  files instead (`noct_scheme` / `noct_setting`).
- **Nothing that blocks on hardware or the network.** `/net` asks nmcli for the
  *cached* scan (`--rescan no`) and offers **Rescan** as an entry instead; that
  runs from `exec`, which is detached and has no deadline.

## Apps

| Key | Action |
|---|---|
| `M + T` / `Return` | kitty (either) |
| `M + SHIFT + Return` | Floating kitty |
| `M + E` | File manager |
| `M + SHIFT + B` | Browser |
| `Print` / `M + Print` | Screenshot region / screen |
| `M + C` | Colour picker |

---

See also: [design notes](design.md) for *why* the directional keys behave the
way they do at an edge, and [theming](theming.md) for what `/theme`,
`SUPER+SHIFT+G` and `SUPER+W` actually change.
