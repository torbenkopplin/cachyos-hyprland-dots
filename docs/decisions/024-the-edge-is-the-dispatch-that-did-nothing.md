# 024 — The edge is the dispatch that did nothing

**Settled 2026-08-19** in code, written down 2026-09-15. Status: in force.
Supersedes the *mechanism* of [004](004-edges-are-read-not-inferred.md); its
warning still stands.

`lib/nav.lua` decides whether focus is at the end of a tape or the bottom of a
column by **dispatching `layout("focus <dir>")` and comparing the focused
window's address before and after**. Unchanged address, no neighbour that way,
hand off to the monitor or the workspace.

```lua
local before = hl.get_active_window().address
hl.dispatch(hl.dsp.layout("focus " .. dir))
return before ~= hl.get_active_window().address
```

## What this replaces, and why

[004](004-edges-are-read-not-inferred.md) describes reading `column.index`,
`index_in_column` and `#column.windows` off `window.layout` and comparing against
the column range on the workspace. That is no longer what the file does, and the
reason is [the vertical band](003-workspace-numbers-are-arithmetic.md): an index
comparison has to know **which axis the tape runs on** before it can say what
"the end" means, and nothing can tell it.

- `WSBANDS` cannot: it keys on connector name, and a laptop plugged into a
  monitor it has never seen has no entry for it.
- `window.layout` cannot: both `layout.direction` and `layout.column.direction`
  are nil — checked.

`layout("focus <dir>")` takes **screen** directions and already walks whichever
structure runs that way, so it knows the axis natively. Asking it and looking at
the result sidesteps the question entirely.

## Why this is not the thing 004 settled against

004 warns against inferring an edge from a **failed dispatch** — from
`ok = false`. That warning is still correct and still load-bearing: the scrolling
layout reports "no column that way" as a *success*, so `ok` would only ever
detect the vertical case.

This does not read `ok`. It reads the compositor's state afterwards, which is
true either way. The distinction is the whole decision.

## What made it safe

At an edge, `layout("focus <dir>")` is a **complete no-op** — measured on both a
horizontal and a vertical band: focus unchanged, and not one window moved. So
there is no re-centring to undo and nothing to compensate for, which is what
would have made "dispatch and look" unacceptable.

The same shape covers the moves, where focus follows the window and the address
is therefore identical either way: `window_moved()` compares
`workspace/column/row` instead. Same principle, different observable.

## Consequences

- `scrolling.wrap_focus` and `wrap_swapcol` must stay `false`, and
  `general.no_focus_fallback` must stay `true`. Wrapping turns every edge into a
  successful move and this stops detecting edges at all.
- `swapcol` is the one place the axis genuinely cannot be avoided, because it is
  tape-relative where `focus` is screen-absolute (`swapcol u`/`d` are rejected
  outright). `tape_forward()` derives it from where the windows actually are.
- `noct-check nav-axis` is the regression net, and it takes no pixel — so it is
  the one live navigation check that runs on any monitor.

Narrative: [design.md](../design.md#edges-are-read-not-inferred-from-a-failed-dispatch).
