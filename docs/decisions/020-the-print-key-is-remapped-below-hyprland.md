# 020 — The MX Keys print key is remapped below Hyprland, not bound inside it

**Measured 2026-08-26** on Hyprland 0.56.2, keyd 2.6.0, and an **MX Keys S**
(WPID `B378`, HID++ 4.5, firmware `RBK 81.01.B0015`) on a Logi Bolt receiver
(`046d:c548`). Status: in force, and scoped to that receiver — this is one
keyboard's firmware behaviour, not a family's.

The key where PrtSc belongs on an MX Keys does not send PrtSc. It sends the
Windows snipping-tool chord, `SUPER+SHIFT+S`, from firmware — so on a machine
whose compositor already means something by that chord, the screenshot key files
a window away instead of taking a picture.

There is nothing to change on the keyboard, and that was checked rather than
assumed — see [Why not Solaar](#why-not-solaar) below. What arrives is not one
key with a scancode to replace: it is three ordinary keycodes on the receiver's
ordinary keyboard interface. That is the whole shape of the problem, and it is
why the fix is a layer below the one that has the binds.

## How the chord was identified without root

`libinput debug-events` and `evtest` both need to read `/dev/input/event*`, and
this user is not in the `input` group, so the obvious instrument was not
available. Hyprland's Lua config is, and it takes binds at runtime:

```
$ hyprctl eval 'hl.bind([[SUPER + SHIFT + S]], hl.dsp.exec_cmd([[...]]), ...)'
ok
```

(`hyprctl keyword bind` answers `keyword can't work with non-legacy parsers. Use
eval.` — the Lua config of [002](002-hyprland-config-is-lua.md) has no legacy
parser to speak to. `eval` is the way in.)

Twenty-one candidate chords were bound that way, each one appending its own name
to a log, and the key was pressed once. Two lines came back from that single
press:

```
SUPER + SHIFT + S
SUPER + S
```

Both binds answered one keypress. That is the measurement that settles the
decision below: the chord does not reach the compositor as one thing to bind.

## Why not a Hyprland bind on the chord

The cheap fix is a bind: point `SUPER+SHIFT+S` at `screenshot-region` and move
the scratchpad. It was rejected for two reasons, in order of weight.

1. **A bind cannot subtract the modifiers.** Every other screenshot path in this
   setup is `Print` and `SUPER+Print`, and every other machine, keyboard and
   piece of documentation calls that key Print. A bind on the chord leaves the
   key *not* a Print key: it becomes a third meaning stacked on a chord that
   already had two, and anything that later wants "the screenshot key" has to
   know about this keyboard.
2. **The chord already answers to two binds.** `SUPER+S` fired from the same
   press as `SUPER+SHIFT+S`, so the scratchpad toggle would go on firing
   underneath whatever the chord was pointed at. Moving the scratchpad off `S`
   entirely would fix that, and it means giving up the `S`/`SHIFT+S` pair —
   toggle, and send — that the rest of the keymap is built out of.

## Why not Solaar

Solaar can see the key. `solaar show` lists it as control 14 of 21
reprogrammable keys:

```
14: Screen Capture, default: Snipping Tool => Snipping Tool
    analytics_key_events, divertable, reprogrammable, nonstandard
```

Both flags are real and neither one is what is needed.

**`reprogrammable`** is feature `REPROG CONTROLS V4 {1B04}`, and it remaps a
control onto *another control the device knows about* — Brightness, Volume,
Calculator, Host Switch. "Print Screen" is not a Logitech control, so it is not a
target. The feature that would help is `PERSISTENT REMAPPABLE KEYS {1C00}`, which
writes a scancode into the device; this keyboard's 34 features do not include it.
So there is no firmware state that makes this key send `KEY_SYSRQ`.

**`divertable`** means the key can be turned into an HID++ notification instead
of a keypress — which removes the chord but produces nothing in its place. What
fills the gap is a Solaar *rule* that synthesizes a keypress, and Solaar says
what that is worth here in its own first line of output:

```
rules cannot access modifier keys in Wayland, accessing process only works on
GNOME with Solaar Gnome extension installed
```

That is a per-user daemon, running a rule engine whose input synthesis is
degraded on this display server, to replace one line of a config file read by a
daemon that is already running. keyd stays.

## Why keyd, and the one feature that makes it work

keyd sits between the kernel and the compositor: it grabs the evdev device and
writes to a virtual one, so what Hyprland reads is already remapped. The feature
that matters is the **composite layer**, from `keyd(1)`:

> A special kind of layer called a *composite layer* can be defined by creating
> a layer with a name consisting of existing layers delimited by `+`. […]
> `[control+alt]` / `h = left` will cause the sequence *control+alt+h* to produce
> *left* (ignoring the control and alt modifiers attached to the active control
> and alt layers)

*Ignoring the modifiers* is the whole point. `[meta+shift]` with `s = sysrq`
emits a bare Print — not `SUPER+SHIFT+Print`, which is what a plain modifier
layer or any compositor-side bind would have produced. The `Print` bind that was
already in `conf/binds.lua` therefore answers the key that is labelled with it,
with nothing added for it to do so. The two binds that *were* added are aliases
for what the remap takes away, below.

`sysrq`, not `print`. keyd has both names: `sysrq` is `KEY_SYSRQ`, the keycode
PrtSc actually sends and the one xkb turns into the `Print` keysym Hyprland binds
against; `print` is `KEY_PRINT`, a different keycode that no PrtSc key emits.

The match is `k:046d:c548`. The id is the receiver, not the keyboard, and the
`k:` prefix — "the prefix `k:` may be used to exclusively match keyboards" — is
there because the same id is also the mouse, and keyd's own manual calls mouse
support experimental and warns that adding one may break the pointer. The
receiver presents three keyboard-ish devices under that id (`event18` keyboard,
`event20` consumer control, `event21` system control); they share one config and
one state, which is what makes it irrelevant which of them the firmware sends the
chord from.

## What it costs, and where that is written down

On the MX Keys, `SUPER+SHIFT+S` is now Print, so it can no longer send a window
to the scratchpad. It cannot be otherwise: the firmware chord and a typed chord
are the same three keycodes on the same interface, and no remapper can tell them
apart. `conf/binds.lua` therefore grew `SUPER+ALT+S` as a second bind for send-
to-scratchpad, which works from every keyboard; the laptop's built-in keyboard is
not matched by the config and still has both forms.

`SUPER+Print` is the second cost, and it is the one that is not recoverable.
`SUPER` is one of the three keycodes the key itself presses, so there is no way
to hold a *second* one on top of it: every press of that key arrives inside the
`[meta+shift]` layer and leaves it as a bare `Print`. `CTRL` is not part of the
layer and survives it — measured, with a `CTRL+Print` probe bind that fired — so
`conf/binds.lua` gained `CTRL+Print` alongside `SUPER+Print` for the fullscreen
shot. On this keyboard that is the fullscreen half of the pair; on the built-in
keyboard both work.

The remap is a root file, not a link — `keyd` reads `/etc/keyd` before any home
directory is guaranteed to be mounted — which is the same reasoning that makes a
browser policy a copy in [001](001-links-not-copies.md). It is written by
`./install.sh --input`, from `install/manifest/input.tsv`, and the package and
the unit are rows in `packages.tsv` and `services.tsv`. A conf in `/etc/keyd`
with no daemon running is a file nobody reads, so `do_input` says so instead of
reporting success.

## Not settled: one press in four came through unremapped

In the probe run that confirmed `CTRL+Print`, four presses produced four lines,
and one of them was the raw `SUPER + S` rather than a `Print`. Which of the four
presses it was could not be recovered from the log, and the measurement that
would have answered it — `sudo keyd monitor -t`, which prints the firmware's
actual down/up order with timings — was attempted and not captured.

The plausible cause, written down so the next person starts from a hypothesis
rather than from scratch: if the firmware's chord does not hold `meta` and
`shift` down across the `s` keydown — if `s` lands a moment early, or `shift`
lifts a moment sooner — then the composite layer is not active at the instant
that matters, keyd finds no binding, and the chord passes through as the
compositor sees it. `SUPER + S` is exactly what a `[meta]`-only window would
produce.

If it turns out to be that, the fix is not a different remapper; it is
`macro_sequence_timeout` or an `s` binding on the plain `[meta]` layer, and both
of those cost something on the same keyboard. It is recorded rather than fixed
because the remap is right far more often than not, and because the failure is
visible and harmless: a window goes to the scratchpad, and `SUPER+S` brings it
back.

## Settled against

| Not doing | Because |
|---|---|
| A Hyprland bind on `SUPER+SHIFT+S` | It cannot subtract the modifiers, so the key never becomes a Print key — and `SUPER+S` fires from the same press regardless |
| Moving the scratchpad off `S` | The `S` / `SHIFT+S` pair is the toggle/send shape the whole keymap uses |
| Solaar, or any keyboard-side setting | The key is `reprogrammable` only onto other Logitech controls, the device has no `PERSISTENT REMAPPABLE KEYS {1C00}` to write a scancode into, and the `divertable` route needs a Solaar rule to synthesize the keypress on a display server where Solaar itself reports its rules are degraded |
| `[meta]` + `shift` as a plain modifier layer | A non-composite layer only strips its own modifier, so it emits `SHIFT+Print` |
