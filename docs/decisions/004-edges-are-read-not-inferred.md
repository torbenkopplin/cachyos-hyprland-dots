# 004 — Edges are read from the layout, not inferred from a failed dispatch

**Settled 2026-08-18**, widened **2026-08-19**. Status: in force.

`lib/nav.lua` decides whether focus is at the end of a tape or the bottom of a
column by reading the layout's own bookkeeping off `window.layout` —
`column.index`, `index_in_column`, `#column.windows` — and comparing against the
column range on the workspace.

## What settled it

The tempting alternative is to dispatch a focus move and check whether it
returned `ok = false`. That is unreliable here, and asymmetrically so: the
scrolling layout reports "no column that way" as a **success** (it just
re-centres), while "no row that way" is a genuine `NOT_FOUND`. Only the vertical
case would ever be detectable.

## Consequences

- `scrolling.wrap_focus` and `wrap_swapcol` must stay `false`, and
  `general.no_focus_fallback` must stay `true`, or the readings stop meaning
  what nav.lua thinks they mean.
- **The axis is asked of the compositor, not of `WSBANDS`** (2026-08-19). A band
  that scrolls `down` swaps the two axes, and the first version assumed a
  horizontal tape: `SUPER+J` reported "end of column" on the first press because
  each column held one window, and `SUPER+L` asked for a column that a vertical
  band does not have. A laptop also has no `WSBANDS` entry for a monitor it has
  never been plugged into, so the config cannot be the source of truth for this.
- `noct-check nav-axis` is the regression net, and it derives the axis from where
  two probe windows actually land. Verified to fail against the pre-fix file.

Narrative: [design.md](../design.md#edges-are-read-not-inferred-from-a-failed-dispatch).
