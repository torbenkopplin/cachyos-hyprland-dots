# 006 — Idle has exactly one owner

**Settled 2026-08-18.** Status: in force.

Noctalia's idle service does the locking: `70-idle.toml`, lock at 10 minutes,
screen off at 15, lock-and-suspend at 30. `hypridle` is not installed, and
`install.sh` disables the unit if it finds it enabled.

## What settled it

`hypridle` does the same job from a config directory this repo does not manage,
and a CachyOS Hyprland install ships it — a machine upgraded from `~/repos/dots`
has it enabled as a user unit. Two countdowns to the same lock screen, with two
different sets of timeouts and only one of them written down anywhere, is how you
end up locked out mid-video with no idea which of them did it.

`systemctl --user status hypridle` is the check. `install/manifest/services.tsv`
is where the disable is declared, and it only fires when the unit is actually
enabled or active, so a machine that never had it says nothing.

## Playback keeps the screen awake in three layers

No single one covers the whole case:

1. **Apps that ask.** mpv, VLC and the browsers hold a Wayland idle inhibitor
   while something plays, and Hyprland stops issuing idle notifications for as
   long as one is held — so the countdown never starts. This is the layer that
   covers video in a browser tab.
2. **Anything fullscreen** — `idle_inhibit = fullscreen` on every window.
3. **A focused media player**, even windowed — `idle_inhibit = focus` for mpv,
   VLC, Celluloid and Haruna, so a paused film does not lock the screen you are
   looking at.

`SUPER+CTRL+P` → Caffeine is the manual override, and the one to use when what is
playing is audio in a terminal.

## The general rule this is an instance of

Anything that counts down to an irreversible action gets exactly one owner. It
applies again to the palette (one renderer, [010](010-glass-is-the-terminal-only.md))
and to the login screen ([016](016-greetd-instead-of-plasmalogin.md)).

Narrative: [design.md](../design.md#idle-has-exactly-one-owner).
