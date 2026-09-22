# 025 — Bands are opt-in; by default workspaces belong to no monitor

**Settled 2026-09-22** on Hyprland 0.56.2. Status: in force.
Narrows the premise of [003](003-workspace-numbers-are-arithmetic.md), whose
arithmetic is unchanged.

A machine with no `WSBANDS` in `host.lua` has **no bands**: one set of
`WORKSPACE_BAND` workspaces, shared by every monitor, pinned to none of them.
`SUPER+3` is workspace 3 on whichever screen you are looking at, always.

Bands — monitor N owning `N*BAND+1 .. N*BAND+BAND` — remain available and remain
the right model for a desk with fixed screens, because they are also the only way
to give a monitor its own scroll direction and column width
([005](005-per-monitor-column-width.md)). They are now something a machine asks
for rather than something it gets.

## What settled it

The dock-and-undock case. Work on the external, pull the cable, carry on on the
built-in panel — which should cost nothing, and cost a window-by-window move from
11–13 to 1–3 every time.

The cause was the fallback in `lib/ws.lua`, which had drifted from its own
docstring. The comment said *"for a machine with no host.lua, which has no bands
at all"*; the code said:

```lua
return (mon.id or 0) * WORKSPACE_BAND
```

That bands by Hyprland's **monitor id**, which is assignment order and not
identity. Measured on this machine with the lid shut:

```
id=0  eDP-1  disabled=true      ← holds id 0 while disabled
id=1  DP-1   (LG ultrawide)     ← the only live screen
```

so the base was 10 and the number keys addressed 11–20. Boot with only the
ultrawide and the same physical screen is id 0, `SUPER+1` means workspace 1, and
whatever was left on 11–13 is still on the monitor with no key that reaches it.

Worse together than either half alone: with no `WSBANDS`, `conf/workspaces.lua`
passes `monitor = nil`, so nothing was pinned to anything either. Addressing keyed
to a volatile id, over workspaces free to be parked anywhere.

## Consequences

- Unplugging a monitor carries its workspaces to the one that is left with their
  numbers intact. There is nothing to move by hand, which is the whole point.
- Reconnecting does **not** send them back. That is the trade: pinning is what
  makes a workspace return, and pinning is what strands it when the screen it is
  pinned to is not there. A fixed desk should set `WSBANDS` and get the other
  half of the bargain.
- Two screens cannot each show "workspace 1". Per-monitor numbering that also
  survives a replug is `split-monitor-workspaces`, a plugin, and not config.
- `M.neighbour` clamps to `1..WORKSPACE_BAND` rather than a band's edge. J and K
  still stop rather than wrap.

## Settled against

**Keying bands on connector name instead** — `base_of` already prefers a
`WSBANDS` entry matching `mon.name`, so this is the one-line version and it does
fix the id instability. It does not fix the case: this machine meets a different
screen most weeks, every one of them needs its own entry to be addressable, and
anything it has not met yet falls through to whatever the fallback is. A model
that requires knowing the monitor in advance is the wrong model for a laptop.
