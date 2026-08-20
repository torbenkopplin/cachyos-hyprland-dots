# 017 — Workspaces stay dynamic

**Settled 2026-08-18.** Status: in force.

Nothing is persistent. A workspace exists while something is on it, and the bar
shows exactly those. The per-monitor band ([003](003-workspace-numbers-are-arithmetic.md))
only decides what number a new one gets.

## What settled it

The question came from the bar: its workspace widget draws the workspaces that
*exist*, so it shows a varying number of pips rather than a fixed row of ten.

That is not a widget option. A fixed row of ten per monitor means
`persistent = true` on the workspace rules in `conf/workspaces.lua`, which is a
compositor change, and it gives up the dynamic model to buy a cosmetic one.

Checked rather than assumed: `noctalia config validate` names an unknown widget
key and rejects a value outside a key's allowed set, so writing a deliberately
wrong value is how the widget's real schema was found. There is no key for this.

## Consequence

The bar's workspace row is as long as the number of workspaces in use. That is
the model working, not a gap.
