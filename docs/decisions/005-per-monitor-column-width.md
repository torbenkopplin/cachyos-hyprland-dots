# 005 — Per-monitor column width, applied as focus crosses monitors

**Settled 2026-08-18** on Hyprland 0.56.2. Status: in force.

A band's `column_width` is a real per-monitor setting: a portrait screen wants
halves or the whole width where an ultrawide wants a third. `lib/colwidth.lua`
supplies the per-monitor option Hyprland does not have, by setting the global
`scrolling:column_width` as focus crosses monitors.

## What settled it

A workspace rule's `layout_opts` carries the scroll `direction` and the
scrolling layout does read it — but it takes the width **only** from the global
option. Measured: a new window on the 0.5 band came out at 0.333, like
everything else. The portrait band that asked for halves quietly got thirds.

Two more facts fell out of building it, both of which the first version got
wrong:

- `hyprctl keyword` is a **silent no-op under the Lua parser** — it answers
  `keyword can't work with non-legacy parsers. Use eval.` So the live equivalent
  is `hyprctl eval 'hl.config({...})'`, and an A/B test written with `keyword`
  measures nothing and reports success. `noct-check keyword-inert` pins this.
- `monitor.focused` fires **before** the switch is recorded. Inside the handler
  `hl.get_active_monitor()` still answers with the monitor you left, so
  everything reading a monitor from an event takes the event's own argument.

## Why no poll and no timer

The global value is only ever consulted when a new column is created, and a new
column appears on the monitor you are looking at — so "set it on focus change"
and "set it when a column is created" are indistinguishable in effect.

Existing columns are deliberately left alone: otherwise every glance at the
other screen would undo your `SUPER+PLUS` resizing.

Narrative: [design.md](../design.md#workspace-numbers-are-arithmetic-not-a-selector).
