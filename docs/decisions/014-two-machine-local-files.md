# 014 — Exactly two files may differ per machine

**Settled 2026-08-19.** Status: in force.

Everything in this repo is the same on every machine, on purpose. Two files are
not, and neither is tracked or linked:

| File | Carries | Template |
|---|---|---|
| `~/.config/hypr/host.lua` | monitors, `WSBANDS` (band base, scroll direction, column width), GPU environment | `config/hypr/host.lua.example` |
| `~/.config/noctalia/glass.local.conf` | `window` and `terminal`, this screen's answer | `config/noctalia/glass.local.conf.example` |

Both are read **after** the tracked file and win outright — `glass.local.conf`
puts both of its keys ahead of either of `glass.conf`'s, so a bare `window` here
beats a per-scheme `window` there. `noct-glass show` and `noct-check glass-config`
both say when it is in play.

## Why these two and not a `hosts/<name>/` tree

They are the two things that are properties of the *hardware* rather than of the
setup:

- Monitor names, geometry and scroll direction cannot be shared: a laptop has no
  entry for a monitor it has never been plugged into, which is also why
  `lib/nav.lua` asks the compositor for the axis instead of reading `WSBANDS`
  ([004](004-edges-are-read-not-inferred.md)).
- A glass level is a property of the screen. If compositor-wide glass ever comes
  back on one machine ([010](010-glass-is-the-terminal-only.md)), it comes back
  here, in two lines, with nothing in the repo changing.

Keeping the list at two is the point. Every additional per-host file is a thing
that is configured in one place on one machine and nowhere on the other, and the
failure mode is silence.

## The one thing that cannot be host-agnostic and has no home for it

`60-wallpaper.toml` keys per-monitor wallpaper directories on connector names, and
Noctalia has no per-host mechanism the way `hypr/host.lua` does. An unmatched
`[wallpaper.monitor.X]` section is not an error — Noctalia ignores it and falls
back to the global `directory` — so on a machine with different connectors every
screen quietly shows the same 16:9 set.

`install.sh --wallpapers` warns when the sections name monitors this machine does
not have, because that is invisible otherwise.

## And a related trap

`tests/baselines/<host>.json` is named after the hostname, and a stock CachyOS
install is `cachyos-x8664` on **every** machine. `noct-check --record` refuses when
the file already there was recorded on different hardware, and prints the two ways
out: `NOCT_HOST=work`, or giving the machine a real hostname — which is better,
because it does not have to be remembered on every invocation.
