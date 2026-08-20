# 016 — greetd + noctalia-greeter, and it is opt-in

**Settled 2026-08-19.** Status: in force, and the only step not in `--all`.

`./install.sh --login` installs greetd and noctalia-greeter, writes
`/etc/greetd/config.toml`, disables whatever display manager is enabled and
enables greetd.

## Why replace the shipped one

A CachyOS install boots into plasmalogin (SDDM under Plasma 6.5's new name): a
Qt/Plasma login screen in front of a session that has nothing else Plasma in it —
different fonts, different accent colour, different cursor, and a session list
where the Hyprland entry is one of three.

noctalia-greeter brings its own small wlroots compositor, so it runs before
Hyprland exists, and it reads the palette and wallpaper Noctalia already resolved.
The login screen becomes the shell you are logging into.

## Why it is not in `--all`

It is the one step that changes what happens at **boot**. Everything else here is
reversible by rerunning something.

It prints its own undo, and you are not locked out if the greeter fails to come
up: switch to a TTY with ctrl+alt+F2, log in, and
`sudo systemctl disable greetd && sudo systemctl enable --now plasmalogin`.

Two deliberate details:

- **`enable`, not `enable --now`.** Restarting the display manager from inside a
  session it started would kill that session — this one. It takes effect at the
  next boot.
- **The greeter session binary is resolved with `command -v`**, not hardcoded: a
  repo build lands in `/usr/bin` and a manual one in `/usr/local/bin`. It is the
  `-session` entry point rather than the greeter binary, because that is what
  starts the bundled compositor.

## What is still not automated

Appearance sync is a GUI action in beta.8 — `SUPER+,` → Security → Noctalia
Greeter → Sync Now. There is no `noctalia msg greeter-sync`, so nothing verifies
it from a script. Worth re-checking on the next Noctalia release.
