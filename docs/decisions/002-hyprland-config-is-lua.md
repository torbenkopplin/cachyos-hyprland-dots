# 002 — The Hyprland config is Lua, split into options, conf and lib

**Settled 2026-08-15.** Status: in force.

`hyprland.lua` requires `conf/*` in a fixed order, and `conf/binds.lua` calls
into `lib/*` for the behaviour Hyprland does not have. No plugins.

- **`conf/options.lua` first, and it is all globals.** Hyprland gives each
  `require`d file its own error boundary but they share one global table, so a
  later file can read what an earlier one set. That is what makes one file the
  place to change almost anything.
- **`lib/` is where the missing features live** — `nav`, `ws`, `colwidth`, `bar`,
  `supertap`. Each exists because the compositor cannot do the thing from a
  config file alone; see 003, 004, 005, 007, 008.
- **`host.lua` is loaded with `pcall(dofile, ...)`**, not `require`, so
  `hyprctl reload` re-reads it and a machine without one still gets a working
  session.
- **Generated files are reached by absolute path.** Hyprland resolves `require()`
  against the *realpath* of the config, which is the checkout when installed as a
  symlink — so nothing written next to the symlink is reachable through
  `require()`. `generated/colors.lua` and `generated/glass.lua` are loaded with
  `pcall(dofile, CONFIG_HOME .. ...)`, and the `pcall` is not optional: both
  legitimately do not exist until Noctalia has rendered a palette once.

## Why Lua rather than `hyprland.conf`

The navigation model needs to read the layout's own state and do arithmetic on it
(003, 004). In `hyprland.conf` that is a shell script and a process spawn per
keypress, which is what `~/repos/dots` does; in Lua it is a table lookup in
process.

The cost is that `hyprctl keyword` does not work at all under the Lua parser —
see [005](005-per-monitor-column-width.md).
