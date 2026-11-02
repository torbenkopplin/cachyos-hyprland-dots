# 026 — Rotation follows the sensor, because the fold cannot be seen

**Settled 2026-10-24** on an HP ENVY x360 Convertible 15-eu0xxx, kernel
7.2.9-2-cachyos, Hyprland 0.56.2, iio-sensor-proxy 3.9. Status: in force.

The built-in panel turns as the device turns. `lib/rotate.lua` owns the policy;
`bin/hypr-autorotate` reads the accelerometer through iio-sensor-proxy and
reports an orientation once it has held for one second. `MOD + CTRL + R` locks the
panel where it is. Touch input and the stylus turn with the panel.

The keyboard and touchpad are not handled here at all. Folding the device turns
them off by itself.

## What was wanted, and why it cannot be had

Rotate **only in tablet mode**. That needs something to say the device is folded,
and on this machine nothing does. Measured by folding and turning it while every
input device was watched as root (read-only, `EVIOCGSW` polled as well as events
read):

- `HP WMI hotkeys` advertises `SW_TABLET_MODE` (and `SW_DOCK`) and never sets it.
  No event, and no change in the switch state either.
- No input device is removed or added. The keyboard and touchpad stay present;
  they simply go quiet.
- `/sys/devices/platform/hp-wmi/tablet` reads `0` throughout.
- The kernel logs nothing — no hp-wmi event, known or unknown.
- `amd_pmf`, which reports a platform posture on newer AMD machines, is not loaded
  on this one.

So the keyboard is cut off by the firmware, below Linux, and the OS is never told.

## Why following the sensor anyway is fine

Open as a laptop, the panel reads `normal`. A reading that does not hold for a
second — a lid being opened, a laptop being picked up — never reaches Hyprland.
What it gets wrong is carrying the laptop open on its side for longer than that,
and the lock covers that.

## How the pieces fit

- **The state is read, never remembered**, as in [023](023-the-panel-is-never-the-last-output.md).
  The reader writes the orientation to its RuntimeDirectory, which systemd removes
  whenever the reader stops, so any file there is a current reading. The lock is a
  file in `$XDG_RUNTIME_DIR`: a reload keeps it, a reboot clears it.
- **The rotation goes through `lib/lid.lua`** when that module owns the panel
  (`lid.transform()`). Its spec is the one it re-applies on every lid change, and
  a copy without the transform would put the panel upright again.
- **Touch input is turned by hand.** Hyprland does not turn touch input with the
  monitor, so `input.touchdevice.transform` and `input.tablet.transform` are set
  on every reconcile — a runtime value does not survive a reload.

The mapping, measured 2026-10-24 on all four sides with the touch transform
following each time:

| iio-sensor-proxy | Hyprland transform |
|---|---|
| `normal` | 0 |
| `left-up` | 1 |
| `bottom-up` | 2 |
| `right-up` | 3 |

`undefined` (lying flat) leaves the panel as it is.

## Settled against

**Gating rotation on the tablet-mode switch.** Built first, and it never fired:
the switch is advertised and never set (above). A machine whose switch works could
bring the gate back. It would need to read the switch state at startup as well as
listen for changes, because a switch binding only fires when the switch changes.

**A manual tablet-mode key.** Exact, but it has to be pressed before folding,
because the built-in keyboard is dead once folded — the same reason the lock
is a key you press before folding, or from an external keyboard.
