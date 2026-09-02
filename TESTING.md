# Post-install checklist

**Only what a person has to judge.** Everything mechanical was moved out of this
file, because a checklist item that a script could run is an item that will be
skipped on the day it matters:

| | |
|---|---|
| [`noct-check`](tests/README.md) | facts about the running session: measured, with numbers, and diffable between machines |
| [`tests/lint.sh`](tests/lint.sh) | everything checkable without a session — syntax, the manifests, the doc links |
| [`tests/install-fakeroot.sh`](tests/install-fakeroot.sh) | the installer, run for real into a throwaway directory |
| [docs/upstream.md](docs/upstream.md) | the version-stamped facts this config depends on |
| [docs/decisions/](docs/decisions/README.md) | why it is shaped this way, and what was tried and dropped |

The parts of this setup that turned out to be wrong were almost all **silent**: a
dispatcher that answers `ok` and does nothing, a launcher provider killed at a
deadline with no error shown, two idle daemons racing. So the order below is: run
the suite, then judge what it cannot.

Anything that fails: the fix is almost always in the file named in the heading.

---

## First, the suite

```sh
noct-check                 # the checks that do not touch the screen
noct-check --all           # plus the ones that open windows and flicker the display
noct-check --list          # the names, and what each one asserts
tests/lint.sh              # no session needed
tests/install-fakeroot.sh  # the installer, into a temp directory
```

Every live check opens a **new** window to measure. That is not politeness about
your workspace: a terminal you already had open is running the opacity it started
with, and a browser reads `user.js` exactly once, at launch. Measuring what is
already on screen answers a question about the past.

**When both machines pass and one of them looks better** — not a question a
threshold can answer, so the suite records measurements as well as verdicts:

```sh
noct-check --all --record                                # where it looks right
noct-check --all --compare tests/baselines/<host>.json   # where it does not
```

**A red `session-path` with green `provider-*`** means the providers are fine and
the session environment is not. Prove it before logging out:

```sh
NOCT_CHECK_PATH=$PATH noct-check provider-resolve provider-run
```

Two files set that PATH and which is read depends on how the session started:
`config/uwsm/env` when uwsm starts the compositor (the intended route, and what
`--login` points greetd at), `config/environment.d/` for any session started as a
systemd user unit. Picking `hyprland.desktop` instead of `hyprland-uwsm.desktop`
at the login screen bypasses the first, which is why there are two. The fix is
`./install.sh`, then log out and back in — it is read at login only.

---

## 0. It loads at all

- [ ] Session starts with no config-error overlay, and `hyprctl configerrors` is
      empty.
- [ ] If the emergency binds (`SUPER+Q`/`R`/`M`) are what you get, a file failed
      to parse — the notification says which one.

## 1. Layout and navigation — `conf/layout.lua`, `lib/nav.lua`

`noct-check nav-axis column-hop monitor-hop` covers the mechanics on whichever
band the focused monitor is on. What is left is feel and the cases a probe cannot
reach.

- [ ] Opening several windows scrolls the tape, and the animation reads as one
      movement rather than a jump — 100–250ms, no overshoot.
- [ ] `SUPER + +` / `-` cycles the six width presets, and the one you land on is
      a width you would actually work at.
- [ ] With a **floating** window focused, `SUPER+hjkl` behaves sanely rather than
      doing something clever.
- [ ] Every navigation bind behaves identically on the **arrow keys**. They come
      from the same table, so a difference means a bind went missing.
- [ ] On the **portrait** band (`direction = "down"`), the tape genuinely scrolls
      vertically while the landscape band scrolls right. This is the whole reason
      for the band model over a flat list.

## 2. Tap SUPER — `conf/binds.lua`

The failure mode to watch for is the launcher *also* opening after ordinary
chords. See [decision 007](docs/decisions/007-tap-super-is-a-release-bind.md).

- [ ] Tapping and releasing `SUPER` alone opens the launcher.
- [ ] `SUPER+J`, then releasing `SUPER`, does **not**.
- [ ] `SUPER+T`, then releasing, does **not**.
- [ ] `SUPER+Space` opens it as well (kept as a fallback).

If it does misfire, set `SUPER_TAP_ENABLED = true` in `conf/options.lua`.

### The MX Keys screenshot key — `input/keyd/mx-keys.conf`

Only on a machine with the MX Keys, and only after `./install.sh --input` and a
running `keyd`. The key sends `SUPER+SHIFT+S` in firmware; the remap turns it
into a bare `Print`. See [decision
020](docs/decisions/020-the-print-key-is-remapped-below-hyprland.md).

- [ ] `systemctl is-active keyd` says `active`.
- [ ] Pressing the screenshot key opens the region selector, and does **not**
      send the focused window to the scratchpad. Press it **several times** — one
      press in four leaked through as the raw chord when this was measured, and
      one press is not enough to see that.
- [ ] `CTRL` + the screenshot key takes the fullscreen shot. `SUPER` + it does
      not, and cannot: `SUPER` is one of the keycodes the key itself sends.
- [ ] `SUPER+ALT+S` sends a window to the scratchpad from that keyboard.
- [ ] On the laptop's built-in keyboard, `SUPER+SHIFT+S` still sends to the
      scratchpad and `SUPER+Print` still takes the fullscreen shot — the remap is
      matched on the receiver's id and nothing else.

If the key files a window away *every* time, the remap is not loaded at all:
`sudo keyd monitor` prints the id of whatever you press, and a keyboard reached
over Bluetooth rather than through the receiver has a different one — another line
in the `[ids]` section. If it does it occasionally, that is the open question in
decision 020, and `sudo keyd monitor -t` is the measurement that would close it.

## 3. The bar — `lib/bar.lua` + `10-bar.toml`

`noct-check bar-hot-edge` measures the pointer reveal and the stuck case.

- [ ] No bar at login, and windows use the **full** screen height — no reserved
      gap at the top.
- [ ] The launcher slides it in; closing slides it out. Control centre
      (`SUPER+A`), clipboard (`SUPER+X`) and the session menu do the same.
- [ ] A **notification** does *not* reveal it. Nor does changing workspace.
- [ ] Moving the pointer **onto** the bar does not make it vanish.
- [ ] `SUPER+B` pins it; again releases it. Both presses force, so this doubles as
      a resync — if the bar is ever stuck, two presses end it.
- [ ] It renders **above** a fullscreen window.
- [ ] It reads as **one thing you look at**, centred, rather than three things in
      the far corners. One accent, two text levels, and no widget stating in words
      what its icon already says. See
      [decision 009](docs/decisions/009-the-bar-is-three-capsules.md).

## 4. Workspaces — `conf/workspaces.lua` + `host.lua`

- [ ] `SUPER+2` goes to the second workspace **on the monitor you are looking
      at** — on the second monitor that is id 12, not 2 (`hyprctl
      activeworkspace`).
- [ ] The bar's workspace row shows only the workspaces that exist. That is the
      dynamic model working, not a gap —
      [decision 017](docs/decisions/017-workspaces-stay-dynamic.md).

## 5. Launcher providers — `bin/noct-*` + `20-launcher.toml`

`noct-check provider-resolve provider-run` covers everything mechanical: each
provider findable the way the *launcher* finds it, answering, answering inside the
two-second budget, and keeping device ids out of the visible line. Two things it
cannot do:

- [ ] Two devices with the **same name** both stay selectable (the second gets a
      ` (2)` suffix). Only testable with a duplicate.
- [ ] Connecting to a **new, secured** Wi-Fi network runs `nmcli --ask` in the
      floating scratch window, and the passphrase is **not echoed**. Needs a
      network this machine has not joined before — the no-echo half cannot be
      faked, and everything up to the prompt is already verified.

Then the judgment calls:

- [ ] Picking an output moves audio that is **already playing**, not just the
      default for the next thing.
- [ ] `/net` appears **immediately** — it reads nmcli's cached scan rather than
      scanning. "Rescan" is an entry in the list.
- [ ] `SUPER+CTRL+O/I/B/N/P/T` each open the launcher already filtered.

## 6. Launcher keys — `00-shell.toml`

The chord names here are the one part of `00-shell.toml` taken from
documentation that contradicts itself.

- [ ] `Ctrl+J` / `Ctrl+K` move the selection; arrows still work; `Esc` closes.
- [ ] Noctalia reported no parse error for `[keybinds]`. If it did, one of the
      chord names is wrong — remove it and `noctalia msg config-reload`.

## 7. Theming — `30-theme.toml` + `40-templates.toml`

`noct-check glass-config glass-live glass-visible glass-legible kitty-live
kitty-appearance kitty-untouched` covers the numbers. This is what they look like.

- [ ] Change the wallpaper (`/wall`). The bar, panels, **window borders** and
      **already-open terminals** all move to the new palette, live.
- [ ] A full-screen TUI (`btop`, vim) survived the repaint without corruption.
- [ ] `/theme` → **noirblaze** puts the shell in the monochrome-and-pink scheme,
      and open neovim looks at home in it.
- [ ] A built-in (Gruvbox) switches cleanly, and a **Wallpaper:** entry goes back
      to wallpaper-derived colours.
- [ ] The choice survives a restart.
- [ ] On a **fresh** install, before any palette has been rendered, Hyprland still
      starts and kitty still has colours — the fallbacks in `conf/look.lua` and
      `kitty.conf` are doing their job.

### The glass, which is the part worth looking at rather than reading

See [decision 010](docs/decisions/010-glass-is-the-terminal-only.md) and
[011](docs/decisions/011-the-blur-is-small.md).

- [ ] **You can make out what the wallpaper is** through a terminal. Not "there is
      a grey wash" — its shape.
- [ ] **Two terminals side by side are not quite the same shade**, because each
      samples the photo behind itself. That is the price of the above, and it is
      the intended trade.
- [ ] **A terminal is glassy and nothing else is.** A GTK app (nautilus) and a Qt
      app are **opaque**, deliberately.
- [ ] An unfocused window is **not dimmed**.
- [ ] Text in a terminal is trivially legible.
- [ ] mpv/imv/gimp/obs stay fully opaque (the opt-out list in `rules.lua`).
- [ ] `SUPER+SHIFT+G` does something on the **first** press, and cycles every
      window with it. `noct-glass show` says `[override: SUPER+SHIFT+G]` while one
      is held; changing scheme clears it.

## 8. kitty, fish and the tools

`noct-check deps-installed` covers everything declared in `tests/deps.tsv`. These
are the ones nothing declares:

- [ ] The starship prompt renders with its nerd-font glyphs intact, and `cat`,
      `ls`, `lt` are `bat` and `eza`.
- [ ] `ctrl+f` opens the search kitten.
- [ ] `y` opens yazi and leaves the shell in the directory you quit from; Enter on
      a text file opens it in neovim.
- [ ] `nvm --version` works **in fish** (this is nvm.fish, not the bash one), and
      `node --version` works with no nvm version selected.
- [ ] `cargo --version` and `claude --version` work; `~/.cargo/bin` is on `PATH`.
- [ ] `eslint --version` and `mmdc --version` work (npm globals, in `~/.local`).
- [ ] `echo $SHELL` says fish **after a fresh login** — `chsh` does not affect the
      session you ran it in.
- [ ] `git status` in this repo is clean after a scheme change. If `kitty.conf`
      shows as modified, Noctalia's built-in template rewrote it — see
      `noct-check kitty-untouched`.

## 9. Wallpapers — `noct-wallfetch` + `60-wallpaper.toml`

- [ ] **Rename the monitor sections in `60-wallpaper.toml`** to this machine's
      connectors. `install.sh --wallpapers` warns when they do not match, and
      unmatched sections are not an error — every screen just quietly shows the
      same 16:9 set.
- [ ] The ultrawide folder holds genuinely wide images (`file *.jpg`).
- [ ] `SUPER+W` shows the folder for the monitor selected in the picker, and
      applying one recolours the shell.
- [ ] `SUPER+SHIFT+W` opens the Wallhaven browser.

## 10. Browsers

`noct-check browser-glass` measures all four. It compares **nothing** between
them: Zen is deliberately translucent and the other three deliberately are not —
[decision 013](docs/decisions/013-zen-is-translucent-unmatched.md).

- [ ] All four launch, and `brave://policy`, `chrome://policy`, `about:policies`
      show the keys applied with **no errors**.
- [ ] Firefox's new tab has no sponsored shortcuts or stories.
- [ ] Sync still works in each — nothing here should have disabled it.
- [ ] After launching Firefox and Zen once, rerun `./install.sh --browsers`: it
      finds the profiles that did not exist before and links `user.js` into them.
- [ ] In Zen: `zen.widget.linux.transparency` is **true**, the **transparent zen**
      mod is enabled, and a page with no background of its own (`about:blank`) is
      translucent.
- [ ] A Zen page does **not** read as the same shade as a terminal. That is
      correct and deliberate.
- [ ] `<profile>/chrome/userChrome.css` either does not exist or has nothing of
      ours in it. If an old machine still has the generated sheet, delete it —
      the `grep -lZ … | xargs -0` form is in
      [decision 013](docs/decisions/013-zen-is-translucent-unmatched.md), and the
      `-Z` is load-bearing.
- [ ] `git status` stays clean after a browsing session — no profile data is
      tracked.

## 11. Idle and the login screen

[Decision 006](docs/decisions/006-idle-has-one-owner.md).

- [ ] `systemctl --user is-active hypridle` says **inactive**. Two idle daemons is
      how you get locked out mid-video.
- [ ] A **fullscreen** video keeps the screen awake; an ordinary window does not.
- [ ] A video in a **windowed** browser tab also keeps it awake — this is the
      inhibitor layer, and the one that covers real use.
- [ ] A focused, windowed mpv keeps it awake even when **paused**.
- [ ] `SUPER+CTRL+P` → Caffeine holds it awake for anything else, audio in a
      terminal included.

Only after `./install.sh --login`
([decision 016](docs/decisions/016-greetd-instead-of-plasmalogin.md)):

- [ ] `systemctl is-enabled greetd` says enabled, and `/etc/greetd/config.toml`
      points `command` at a path that exists.
- [ ] **Reboot.** The greeter comes up and the Hyprland (uwsm) session is
      preselected.
- [ ] `SUPER+,` → Security → Noctalia Greeter → **Sync Now**, then reboot: the
      login screen wears the current wallpaper and palette. Nothing verifies this
      from a script — there is no `noctalia msg greeter-sync` in beta.8.
- [ ] If it does not come up: `ctrl+alt+F2`, log in,
      `sudo systemctl disable greetd && sudo systemctl enable --now plasmalogin`.

## 12. Two setups on one machine

`~/dotfiles` (stow) provides `fish`, `kitty` and `hypr` as well, plus things this
repo does not cover: `gtk-3.0`, `gtk-4.0`, `kvantum`, `mpv`, `git`, `fastfetch`,
`quickshell`, `illogical-impulse`.

`./install.sh --status` says which setup owns each path, and `--unlink` hands them
back. Running both is recoverable — but it is not a decision to make by accident.

- [ ] Decide which repo owns `fish`, `kitty` and `hypr` before deploying both.
- [ ] `~/.config/fish` is a directory of symlinks into **one** repo, not a mix.
- [ ] The configs this repo does not carry still come from `~/dotfiles`.

---

## When something is wrong

**`hyprctl eval` prints `ok` or an error, never the value you return.** Every
`return ...` check reads its own hope. Assert, or write to a file:

```sh
# Did the lib/ modules load? `ok` is the pass.
hyprctl eval 'assert(type(require("lib.nav").focus_horizontal) == "function")'
hyprctl eval 'assert(type(require("lib.ws").neighbour) == "function")'
hyprctl eval 'assert(type(require("lib.colwidth").apply) == "function")'

# What does the layout actually report for the focused window?
hyprctl eval 'local l = hl.get_active_window().layout
  local f = io.open("/tmp/layout.txt", "w")
  f:write(string.format("col=%s row=%s in_col=%s\n", tostring(l.column.index),
    tostring(l.index_in_column), tostring(#l.column.windows))); f:close()'
cat /tmp/layout.txt   # both indices are 0-based
```

**A provider showing "No results found" has usually been killed, not failed.**
Noctalia gives it ~2 seconds and the only trace is in the log:

```sh
noctalia msg log-level-set debug
# open the provider, then:
grep dmenu ~/.cache/noctalia/noctalia.log | tail
#   [WRN] [dmenu] [theme] command failed (exit 143)   <- 143 = SIGTERM
noctalia msg log-level-set info
```

The two ways to overrun are calling `noctalia msg` while listing (a deadlock) and
anything that blocks on hardware or the network —
[decision 018](docs/decisions/018-providers-get-two-seconds.md). If it says "not
installed" instead, the backend package is missing.

**A pixel measurement that skipped** is usually one of two things, and neither is
a fault in the config: the screen was locked (`grim` photographs a lock screen
without complaint) or the probe landed somewhere too small to read. Both are in
[docs/upstream.md](docs/upstream.md#measurement-itself), along with the rotated-monitor
case that is still open.

**A column that arrived as N columns** rather than one: each window moved to a
workspace starts a column of its own, so `move_column()` re-consumes them. Verify
with `noct-check column-hop` rather than by eye.

---

## What used to be in this file

It was 1002 lines and three genres. Nothing was deleted without a home:

| Was here | Is now |
|---|---|
| 67 ticked items with their reasoning | [docs/decisions/](docs/decisions/README.md), one file per decision, with the measurement that settled it |
| The "Known-uncertain details" table | [docs/upstream.md](docs/upstream.md), grouped by dependency, each row with the version and the check that holds it |
| "Settled: nav.lua, and what `wsnav.sh` was really doing" | [decision 003](docs/decisions/003-workspace-numbers-are-arithmetic.md) and [004](docs/decisions/004-edges-are-read-not-inferred.md) |
| Items a check now covers — provider timing, glass levels, font substitution, `git status` after a scheme change, workspace band arithmetic, the installer's idempotence | `noct-check`, `tests/lint.sh`, `tests/install-fakeroot.sh` |
| Items a *reader* needed rather than a tester — why the blur is small, why the bar has three capsules | [docs/decisions/](docs/decisions/README.md), [design.md](docs/design.md), [theming.md](docs/theming.md) |

The checklist itself is about 230 lines now, and the rest is the two appendices.
If the checklist grows past that again, something in it belongs in the suite: an
item here should be one that genuinely needs eyes.
