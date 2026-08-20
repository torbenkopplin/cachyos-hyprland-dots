# 008 — The bar is event-driven, reconciled, and answers the pointer

**Settled 2026-08-18**, hardened **2026-08-20**. Status: in force.

`lib/bar.lua` tracks the set of open `noctalia-panel` /
`noctalia-attached-panel` / `noctalia-window-switcher` layer surfaces and calls
`bar-show` / `bar-hide` as that set becomes non-empty or empty. Noctalia's panels
are layer-shell surfaces and Hyprland emits `layer.opened` / `layer.closed` with
the surface, so there is no polling and no guessing how long you will spend in
the launcher.

Notifications and OSDs are deliberately excluded: a notification must not drag
the bar on screen with it.

## Reconcile before deciding

The set is rebuilt from `hl.get_layers()` before every decision, rather than
being maintained incrementally from events alone.

**What settled it:** a missed `layer.closed` strands an address in the set and
pins the bar up for the rest of the session. Trusting the event stream means
trusting it perfectly for hours. `SUPER+B` now *forces* rather than toggling from
believed state, which makes it a resync as well as a toggle — if the bar is ever
stuck, two presses of that key end it.

This is the design the second version has, and the first version should have had.

## The pointer

The top edge reveals the bar, polled with `hl.timer` + `hl.get_cursor_pos()`,
with hysteresis so it does not vanish as you reach for it.

A poll, not an event, because there is no "pointer entered a region" event to
subscribe to for a surface that is not mapped there yet.

## How it is tested, and why in pixels

`noct-check bar-hot-edge`, and it measures **pixels**. Hiding the bar leaves its
layer mapped at the same geometry and the same alpha, so the obvious reading says
nothing at all. It diffs the whole strip as an image and asks what *percentage*
of it changed — the only form that survived three layout changes. A single centre
patch and five spread patches both assumed where the content was, and both called
a working bar broken when it moved.

Verified to fail with the poll disabled.

Narrative: [design.md](../design.md#the-bar-is-event-driven-not-timed).
