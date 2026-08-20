# 007 — Tapping SUPER is a release bind, with a fallback kept in the drawer

**Settled 2026-08-15.** Status: in force, fallback unused.

`hl.bind("SUPER + SUPER_L", …, { release = true })` opens the launcher. The
modmask has to name the mod being pressed — `SUPER + SUPER_L`, not `SUPER_L`.

## Why this is safe

It is what the wiki says to do for a bare modifier, and what `~/repos/dots` has
been running. Hyprland's keybind manager has dedicated arming and sub-chord
suppression for release binds, so it does not fire every time you let go of SUPER
after a chord.

## The fallback, and why it stays switched off

`lib/supertap.lua` watches `input.keyboard.key`, which is emitted *before* the
keybind manager sees the event and therefore sees every key including ones binds
consume. It requires the tap to be both quick and uninterrupted. Switch it on
with `SUPER_TAP_ENABLED = true` in `conf/options.lua`.

It is kept because the failure mode is specific and plausible, and it is off
because the plain bind behaves and is far less machinery. `SUPER+Space` stays
bound as a second way in either way.

Narrative: [design.md](../design.md#tapping-super-is-a-release-bind-and-that-is-fine).
