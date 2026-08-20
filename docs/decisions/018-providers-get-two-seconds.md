# 018 — A launcher provider gets two seconds, so it may not ask anything slow

**Measured 2026-08-18** on Noctalia v5.0.0-beta.8. Status: in force.

Noctalia runs a dmenu provider's `command` synchronously on its render thread and
SIGTERMs it after ~2 seconds. A provider that overruns produces **no output at
all**, and the launcher shows "No results found" — there is no partial list and
no error you would see without turning the log level up.

Undocumented, so it could change: re-measure with a `sleep 3` provider if lists
start emptying.

## The two rules that follow

1. **`list` must not call `noctalia msg`.** The shell is blocked waiting for the
   provider while the provider waits for the shell, so the IPC call never returns
   and the whole thing is killed at the deadline. Read the state files instead —
   `noct_setting()` in `bin/noct-common.sh` — which is where Noctalia persists
   this anyway. `/theme` and `/net` were both broken exactly this way.
2. **`list` must not run anything that can block on the network or on hardware**
   — a Wi-Fi scan, a Bluetooth discovery, an HTTP request. Ask for cached
   results, and offer the slow thing as an *entry* the user can pick: `exec` is
   run detached and has no deadline.

## Why the payload is not in the line

The contract gives nowhere in a result line to hide machine-readable data:
`command`'s stdout becomes the visible list, a tab splits title from description,
and **both halves are shown**. So the line carries only what you should read, and
the payload goes into a side map in `$XDG_RUNTIME_DIR` keyed by the title.

That also settles the quoting question: a network name or a device id never
reaches a shell at all, because it is only ever read back out of the map file.

`noct-check provider-run` measures the budget and fails a provider that leaks an
address into the visible line.
