# 001 — Deploy by symlink, one file at a time, and be reversible

**Settled 2026-08-15.** Status: in force.

`install.sh` links individual files from the checkout into `~/.config` and
`~/.local/bin`. It never copies, never links a whole directory, and never
deletes anything.

## Why a link

Editing the deployed config edits the repo, so there is no "did I remember to
copy it back" step and no second copy to drift. It is safe for everything here
because none of these programs write to the paths they read:

| Path | Why a link is safe |
|---|---|
| `~/.config/hypr/*` | Hyprland only ever reads its config |
| `~/.config/noctalia/*` | Noctalia saves GUI changes to `~/.local/state/noctalia/settings.toml`, a different tree — so the app cannot clobber a tracked file or replace a link |
| `~/.config/yazi/*` | read-only as far as yazi is concerned |
| `~/.local/bin/noct-*` | plain scripts |

The one exception found the hard way is Noctalia's **built-in kitty template**,
which rewrites `kitty.conf` itself — see
[010](010-glass-is-the-terminal-only.md) and `noct-check kitty-untouched`.

## Why one file at a time

Linking `~/.config/hypr` as a directory would mean Hyprland could not create a
file next to yours without it landing in the repo. Per-file links leave both
programs free to write their own things alongside.

## Why it has to be reversible

The copy-based setup in `~/repos/dots` owns some of the same paths. Anything in
the way is moved to `<path>.bak-<stamp>`, and `--unlink` puts the newest one
back — so the two setups can swap places, one command in each direction, with no
residue. `--status` says which of them owns each path right now.

`tests/install-fakeroot.sh` asserts the round trip: plant a foreign file, run
the installer, and get the file back byte for byte after `--unlink`.

See also [012](012-installer-is-data-plus-an-engine.md).
