# 023 — The built-in panel is never the last output

**Settled 2026-09-10** by the journal of a session that had to be rebooted.
Status: in force. Supersedes the lid recipe that was inlined in
`host.lua.example`; the mechanism is `config/hypr/lib/lid.lua` now.

The rule, and it is the whole decision:

> The built-in panel is off only while the lid is shut **and** something else is
> actually driving a screen.

Re-decided on **every monitor event**, not on lid transitions alone.

## What it replaces

The old form was "lid shut → disable `eDP-1`", as two `switch:` binds plus a
one-off reconcile at parse time, with a guard that refused to disable the panel
when `#hl.get_monitors() < 2`. It is a correct description of a lid and a wrong
description of a session, and the difference cost a reboot.

## What happened

Docked to the ultrawide, lid shut, so `eDP-1` is disabled and **the external
display is the only enabled output**. Noctalia's idle timer locked and suspended
at 16:27:01. The wake at 16:27:10 came from the external keyboard.

Coming back from s2idle the DP link renegotiates, and Hyprland loses the output
for a moment. `hl.get_monitors()` answers with *enabled* monitors only — a
disabled one is absent rather than present with a flag, verified through
`hyprctl repl` — so the count went to zero. A compositor with no outputs has
nowhere to put the lock screen: the session was alive, it held the keyboard, and
it painted nothing.

Two lines in the journal at the instant of the resume say it outright:

```
16:27:10  uwsm_hyprland.desktop: XWAYLAND: mode -1x-1 is not available
16:27:10  gnome-text-editor: gdk_monitor_set_scale: assertion 'scale > 0.' failed
```

A mode of `-1x-1` and a scale of `0` are what a client is handed when the
monitor behind it has no geometry.

**Nothing recovered it**, because the only two things that reconciled the panel's
state were a lid transition and a config reload. Waking on the external keyboard
is not a transition, so the wake produced no event at all.

### The measurement that identifies it, and it is not a Hyprland log

The session's own log dies with the session — `/run/user/1000/hypr/…` — so the
evidence that survived a reboot is `pam_unix`. Every resume is followed within
seconds by a `pam_unix(login:account)` line from noctalia's lock screen, which is
a password being typed. That is the signal that someone got a screen back:

| resume | woken by | lid after | first `pam_unix` |
|---|---|---|---|
| 2026-09-10 00:36:22 | lid opened | open | 00:36:31 (+9s) |
| 2026-09-10 08:31:42 | lid opened | open | 08:31:48 (+6s) |
| 2026-09-10 14:32:11 | lid opened | open | 14:32:16 (+5s) |
| **2026-09-10 16:27:10** | **external keyboard** | **shut** | **16:40:43 (+13m 33s)** |

The one that woke with the lid shut is the one with no lock screen for thirteen
and a half minutes — and 16:40:43 is not a recovery either. It is 8 seconds
after the display topology changed at 16:40:35, i.e. after the dock was pulled.
The session was rebooted at 16:41:48.

`logind` is not a factor and was never misconfigured: it is all defaults, so
`HandleLidSwitchDocked=ignore`, and `Docked` reads `true` with the ultrawide
attached. The lid switch reaches nothing but this config, which is the premise
the old code was built on and is still correct.

## Why the rule is stated the way it is

**"Something else is actually driving a screen"** is asked of Hyprland, not of
`/sys/class/drm/*/status`. The old code read the kernel, and so counted a
connector that is merely *connected* — which is precisely the state the external
display is in for the moment after a resume when it has no mode set and shows
nothing. "Connected" is not "a screen you can see", and it was the wrong
question.

**"Every monitor event"** — `monitor.added`, `monitor.removed` and
`monitor.layout_changed` — because the failing case produces no lid event by
definition. It also closes a second hole the old code had, on the same cause:
unplugging the dock with the lid still shut left the panel disabled and nothing
scheduled to notice.

**The asymmetry is the point.** A lit panel under a closed lid is a thing you fix
by opening the lid. A session with no outputs is a thing you can only reboot, so
when the two are in tension the panel wins. There is also no "lid closed → turn
the panel off" case anywhere in the module: an undocked laptop closing its lid
must not disable the only screen it has, and the rule above already says so
without a special case, which is what the old `< 2` guard was for.

**`MOD + CTRL + D` forces the panel on regardless**, and it is `locked` so it
works with the lock screen up. It needs no screen to press, which is the entire
point of having it. It does not pin the panel on — the next monitor event
reconciles as usual — because the state it exists for is "nothing to look at",
and in that state reconcile already agrees.

## Measured facts the module depends on

All 2026-09-10 unless noted, on Hyprland 0.56.2:

| | |
|---|---|
| `hl.get_monitors()` returns **enabled** monitors only | with `eDP-1` disabled it returned `1 :: DP-1` |
| `hl.monitor()` applies from an **event handler** | armed a handler on `monitor.added`, fired it with `hyprctl output create headless`, and `eDP-1` came back enabled |
| `hl.monitor()` applies from a **bind callback** | 2026-08-26 |
| `hl.monitor()` does **not** apply from `hyprctl repl` | the call returns, the output does not change — worth knowing before testing any of this from the repl |
| `hyprctl keyword monitor` does not work at all here | refused under a Lua config: "keyword can't work with non-legacy parsers" (2026-08-26) |
| re-applying a spec that omits `disabled` does not clear a disable | the key has to be present and `false` (2026-08-26) |
| enabling a **disabled** output fires `monitor.added` | so the steady-state triggers cover a re-enable, not just a hotplug (2026-09-11) |
| `hl.timer(fn, { timeout = ms, type = "oneshot" })` fires from config **parse** time | measured 2026-09-11 — which is what makes the reload fix below possible at all |
| an `hl.timer()` handle that nothing holds **never fires** | it is collected first. The same call with the result discarded did nothing; assigning it to something that outlives the call made it fire (2026-09-11) |
| an explicit `position` is required, not `"auto"` | with auto, an output that comes back after being disabled is placed after the one that stayed, so opening the lid put the panel to the *right* of the ultrawide (2026-08-26) |

## The reload is its own hole, and it cost a second session

**2026-09-11.** The first version of this module was correct in steady state and
wrong across `hyprctl reload`, which left a session that could not be logged back
into and had to be rebooted — the same symptom as the bug it was written to fix,
from the opposite cause.

`hyprctl reload` does two things at once:

1. destroys and recreates every event subscription, by design, so callbacks
   cannot double up — `CLuaEventHandler` is rebuilt per config load; and
2. re-applies the monitor rules it has just parsed.

So an output that comes back **as part of that reload** fires `monitor.added`
while there is nothing subscribed to hear it. And the reconcile that `setup()`
runs at parse time has already happened, against the monitor set as it was
*before* the reload. Neither end of the reload sees the change. `hyprland.start`
is no help: it does not fire on a reload.

The state that leaves behind is the panel **lit under a shut lid**, with the
external display also up. Not a black session, which is why it is easy to miss —
but the lock screen is then spread across an output nobody can see, and which of
the two takes the keyboard is not something you get to choose. That is what
"couldn't relog" was.

Three reconciles now, each covering what the others miss: at parse time (safe
direction on a cold start), on `hyprland.start` (the cold start's real answer,
the same hook `lib/colwidth.lua` uses), and a **one-shot 500 ms timer**, which is
the only one of the three that covers a reload.

### And the guard is exception-safe

The re-entrancy guard is set around an `hl.monitor()` call that is now wrapped in
`pcall`. A raise in there would otherwise leave `applying` stuck true and wedge
every later reconcile — the panel would keep whatever state it happened to be in
for the rest of the session, which is precisely the failure mode this whole
decision exists to rule out.

## The state is read, never remembered

`reconcile()` reads the panel's current state back out of `hl.get_monitors()`
every time rather than caching what it last applied. A cache was the first
version and it is wrong for the same reason the whole bug is: it describes an
intention rather than the session. Measured while testing this — a probe that
enabled the panel directly left the cache saying "off", and the next reconcile
agreed with itself and did nothing.

What is kept is a one-bit re-entrancy guard, because `hl.monitor()` fires the
very events that call back into `reconcile()`, and re-deciding from a
half-applied state recurses until Hyprland's dispatch-depth limit of 32 stops
it.

## The general rule this is an instance of

The same shape as [006](006-idle-has-one-owner.md): anything that can take away
the last way back into a session gets one owner and one rule, stated as an
invariant rather than as a list of transitions. A transition list is only ever
complete until the hardware invents a new one — and a resume with the lid
already shut is not a transition at all.
