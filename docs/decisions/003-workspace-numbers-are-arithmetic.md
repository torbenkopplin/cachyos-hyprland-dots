# 003 — Workspace numbers are arithmetic, not a selector

**Settled 2026-08-18** on Hyprland 0.56.2. Status: in force.

Each monitor owns a band of ten workspace ids — monitor 0 gets 1–10, monitor 1
gets 11–20 — so `SUPER+3` has to mean "the third workspace of the monitor I am
looking at". `lib/ws.lua` does that arithmetic in Lua: read the focused monitor,
find its band in `WSBANDS` by connector name, dispatch the absolute id, clamp at
the band edges.

## What settled it

Hyprland has two selectors that look like they already say that, and neither one
does:

| Selector | What it actually does |
|---|---|
| `m~3` | **Nothing.** Not valid syntax in 0.56 — the dispatcher answers `ok` and no workspace changes |
| `m+1` / `m-1` | Walks the workspaces that currently *exist* on this monitor. In a dynamic setup that is usually one, so there is never a next one |

That first row is why every number key was dead and why `J` at the bottom of a
column did nothing. Both failed **silently**, in a config that looked correct —
which is the shape of almost every real bug in this repo.

## Consequences

- The band table is per machine, so it lives in the untracked `host.lua`
  ([014](014-two-machine-local-files.md)).
- Workspaces stay dynamic ([017](017-workspaces-stay-dynamic.md)); the band only
  decides what number a new one gets.
- `~/repos/dots` solved the same problem with a shell script that shelled out to
  `hyprctl` on every keypress. In a Lua config it is a table lookup.

Narrative: [design.md](../design.md#workspace-numbers-are-arithmetic-not-a-selector).
Facts: [upstream.md](../upstream.md#hyprland).
