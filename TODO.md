# TODO

Done in this pass — kept for a moment so it can be checked off against the real
desktop, then delete:

- [x] **transparency is the terminal and nothing else.** `window = 1.0`, so the
      compositor fades no window at all, and `terminal = 0.55` reaches kitty
      undivided. The reason is measured rather than aesthetic: the compositor
      cannot tell glyphs from background, so every step of glass on a GTK or Qt
      app is a step of contrast off its text (at 0.60, ink at 78% of the
      foreground and a washed-out 5.3:1), while the same glassiness through kitty
      costs nothing. Three things came with it — no focus dim, since dimming
      unfocused windows would put back what the setting removes; the blur stays
      on, because it is now what a *terminal* looks through, and switching it off
      on `window` alone left kitty over a sharp wallpaper; and `SUPER+SHIFT+G`
      first press works, which it did not, because the cycle compared `"1.00"`
      against `"1.0"` as strings
- [x] **one machine can differ, in exactly two files.**
      `~/.config/noctalia/glass.local.conf` joins `~/.config/hypr/host.lua`:
      untracked, absent by default, read after the tracked file and winning
      outright — both of its keys before either of `glass.conf`'s, so a bare
      `window` here beats a per-scheme `window` there. `noct-glass show` and
      `noct-check glass-config` both say when it is in play
- [x] **`./install.sh --update`** — pull, relink, re-apply. It pulls first and
      re-execs itself, because bash reads a script as it runs it and this is a
      script an update rewrites; it refuses to pull over local changes and prints
      them, since every config here is a symlink into the checkout and those
      changes are the desktop you are running; and it finishes with `noct-glass
      apply` plus `noctalia msg templates-apply`, without which an update is only
      true of the next login
- [x] **the built-in kitty template is not off just because the config says so.**
      It rewrote the tracked, symlinked `kitty.conf` at 12:04:25 on 2026-08-19,
      eleven seconds before Noctalia saved `settings.toml` — the GUI's copy of
      `builtin_ids` loads last and wins. `noct-check kitty-untouched` catches it,
      and it matters more now: `--update` refuses to pull over exactly that kind
      of edit, which is the right refusal and a baffling one to hit
- [x] **two ways a measurement can be meaningless rather than wrong**, both now
      skipped rather than concluded from. A locked screen: `grim` photographs it
      without complaint, and a run through one reported that kitty ignores
      `SIGUSR1` (138.9 → 138.9; unlocked, 157.5 → 255.0). A probe off the fold: on
      the 3440x1440 + 1920x1080 pair a tape probe opened as the second row of a
      column on the short monitor with 114px on screen, and the skip blamed motion
- [x] **`install.sh` refuses a half-sandboxed environment.** Overriding `HOME`
      does not sandbox it: `CONFIG_HOME` comes from `XDG_CONFIG_HOME` and
      `BIN_HOME` from `HOME`. A test run of `--update` against a throwaway `HOME`
      therefore relinked the live `~/.config` to a checkout under `/tmp` and the
      checkout was then deleted — 42 dangling symlinks and a session that would
      not start. Nothing was lost (the displaced links were all sitting there as
      `*.bak-<stamp>`), but the trap is now a hard refusal when `HOME` has been
      overridden and `XDG_CONFIG_HOME` has not
- [x] **`--record` will not overwrite the other machine's baseline.** Both are
      called `cachyos-x8664`, so both wanted one file. It compares the recorded
      monitor geometry first and points at `NOCT_HOST` or `hostnamectl`
- [x] the checks are a framework rather than a file: `tests/` has a harness, a
      probe library, a measurement library and a baseline library, and
      `bin/noct-check` is only the runner. Three things came out of it —
      every live check now opens a **new** window to measure (an old one is
      running the config it started with, not the config on disk); every check
      records **numbers**, so `--record` on one machine and `--compare` on
      another says exactly which measurement moved; and `tests/deps.tsv`
      declares every external command with the `install.sh` list that installs
      it, which is what found `tree-sitter-cli` missing
- [x] `tree-sitter-cli` is in `install.sh` (`PKGS_DEV`). It had never been
      there — nothing in this repo names it, because the neovim config is its
      own repository — and this machine had it installed by hand, so there was
      nothing to notice
- [x] all four browsers are measured, not just Zen: `noct-check browser-glass`
      launches each one fresh on a throwaway profile, photographs an ordinary
      web page in it, and reports the effective opacity, the page's text
      contrast, and how far apart the four are
- [x] borders with more of a hacker vibe: the focused window's border is a 45°
      gradient from the palette (`primary` → `tertiary`), everything unfocused
      drops to a 15% hairline, and corners go 8 → 2 so a window reads as a frame
      rather than a card. `ROUNDING` in `conf/options.lua` is the one number
- [x] the bar is built out of the same parts as the windows: no slab, three
      floating capsules (navigation, time, status), each inset 10px like a window
      with the same radius and the same glass level
- [x] a band's `column_width` applies — it never had. The scrolling layout reads
      `direction` from a workspace rule but takes the width only from the global
      option, so `lib/colwidth.lua` sets that global as focus crosses monitors.
      It is a host-level setting, in `WSBANDS` where you expected it
- [x] ~~zen's translucency meets the desktop's, via a `browser` level in
      `glass.conf`~~ — **reverted 2026-08-19**, see below. Zen is still
      translucent; what was reverted is the attempt to make that *meet* the
      desktop's level. The other part that stands is why no Zen pref had ever
      applied: the profile root is `~/.config/zen`, not `~/.zen`
- [x] ~~`terminal` is back to matching `window`, because kitty applies
      `background_opacity` only at startup (measured): a terminal-specific level
      quietly gives you two shades of terminal until every window is restarted~~
      — **undone the same day** by `dynamic_background_opacity yes` in
      `kitty.conf`, which is what lets `terminal` sit at 0.55 under a `window` of
      1.0. `noct-check kitty-live` is the measurement that it holds
- [x] the bar is styled rather than assembled: one accent (`primary`, on the
      workspace you are on and the control-centre button), two text levels, and
      no widget stating in words what its icon says — `enp4s0` and a stray
      percentage are gone
- [x] the bar is one centred cluster made of Noctalia's own popup material —
      `surface_variant` cards at radius 12, sampled off the running control
      centre. The title has a fixed width so the cluster never slides
- [x] every translucent surface lands on the **same shade**: with `blur.xray` each
      window samples the wallpaper behind itself, so at the old blur two terminals
      over different parts of the photo read 4–6 levels apart at an identical
      opacity. `size 32 / passes 4`, dimmed and desaturated, brings that to 2
- [x] `SUPER+CTRL+hjkl` moves whole columns, and at the end of the tape the
      column goes to the next workspace
- [x] the Wi-Fi passphrase prompt opens at all — `$TERMINAL` is a command line,
      not a binary name, so the window had never been launched
- [x] match kitty's and zen's translucency — both now sit at the same visible
      level; `glass.conf` states what you see rather than what each layer
      multiplies by
- [x] workspaces work again — `m~n` was silently doing nothing, `lib/ws.lua`
      does the band arithmetic. They are already dynamic: a workspace exists
      while something is on it, and the bar shows exactly those
- [x] `mod+CTRL+hjkl` and `mod+SHIFT+hjkl` swapped — SHIFT moves the window,
      CTRL the whole column it sits in
- [x] arrows do everything hjkl does, same modifiers, including the resize
      submap
- [x] `mod+hjkl` continues across monitors and workspaces
- [x] tighter spacing (gaps 4/10, bar 30px) and animations on, 100–250ms, no
      overshoot
- [x] fonts: JetBrainsMono Nerd Font actually named correctly for kitty,
      Adwaita Sans for the shell UI
- [x] cursor: Bibata, exported *and* applied with `hyprctl setcursor`
- [x] signal-desktop in the package list
- [x] mail: aerc (modal, `:attach`, composes in nvim). No accounts.conf
      tracked — run `aerc` once for the wizard
- [x] video keeps the machine awake: one idle owner (Noctalia), inhibitor
      layers for fullscreen and for focused players, caffeine for the rest
- [x] touchpad scrolls naturally (touchpad only; a wheel is unaffected)
- [x] `/theme` works — it was being SIGTERMed at 2s for calling back into
      Noctalia while Noctalia waited for it. `/net` was broken the same way
- [x] shelly is the first choice for installing packages, with pacman + paru
      as the fallback, and it has fish aliases
- [x] README is a summary; the long-form docs moved to `docs/`

## Needs you

- [ ] **On the other machine:** `git pull && ./install.sh --update`. Then decide
      whether it keeps the old look — if compositor-wide glass was fine there,
      that is two lines in `~/.config/noctalia/glass.local.conf`:
      ```
      window   = 0.85
      terminal = 0.55
      ```
      Nothing in the repo needs changing for that, which is the point of the file.
- [ ] **Give the two machines different hostnames**, or remember `NOCT_HOST` on
      every `noct-check --record`. `sudo hostnamectl hostname <name>` — both are
      `cachyos-x8664` today, which is why they were fighting over one baseline.
- [ ] **Re-record the baselines**, one per machine, after the glass change. The
      committed one says `window 0.85` and is from the 1920x1080 machine.
      `glass-visible` and `glass-legible` need a workspace with room on the
      monitor the probe opens on — an empty workspace, or the primary monitor
      alone — or they skip, as they did here.
- [x] **`./install.sh --login`** — installs greetd + noctalia-greeter, disables
      plasmalogin, enables greetd. It needs a sudo password, so it could not be
      run for you. Takes effect at the next boot; undo is
      `sudo systemctl disable greetd && sudo systemctl enable --now plasmalogin`
      from `ctrl+alt+F2`.
- [x] After that: `SUPER+,` → Security → Noctalia Greeter → **Sync Now**, so
      the login screen uses the current wallpaper and palette.
- [x] **Navigation works on a band that scrolls `down`.** `SUPER+J`/`K` walks the
      tape and only changes workspace past the end of it; `SUPER+L` crosses to the
      other monitor instead of doing nothing. `lib/nav.lua` no longer assumes a
      horizontal tape, and works the axis out from the compositor rather than from
      `WSBANDS` — a laptop has no entry for a monitor it has never been plugged
      into. `noct-check nav-axis` is the regression net; verified that it fails
      against the pre-fix file.
- [ ] **Pixel checks misjudge a rotated monitor.** `noct_window_geom`
      (`tests/lib/probe.sh`) clips the patch against the monitor's `width` and
      `height` as `hyprctl monitors` reports them — 1920x1080 for `HDMI-A-1` —
      while window coordinates are in *logical* space, 1080x1920 under
      `transform = 3`. So anything past y=1080 on that screen reads as off the
      edge and every pixel measurement skips: `glass-visible`, `glass-legible`,
      `blur-stacks`, `browser-glass`, and `column-hop` — which uses
      `noct_probe_kitty` and so skips whenever the focused monitor is the portrait
      one with a full workspace. It passes from `DP-3`; that difference is this bug
      and nothing else. The comment already in `noct_window_settle`
      diagnoses this as a probe "under the fold", which is what it looks like from
      the inside. Fix is to swap width/height when `transform` is odd (1, 3, 5, 7).
      `nav-axis` sidesteps it by never taking a pixel.
- [ ] `aerc` account setup (first run walks you through it).
- [x] **Zen's transparency is back on, unmatched.** `browsers/zen/user.js` sets
      `zen.widget.linux.transparency` and `browser.tabs.allow_transparent_browser`
      to **true** again, and the "transparent zen" mod plus the "Zen Internet"
      extension are installed inside Zen, which no file here can do. What stays
      dropped is the *match* — no `browser` level, no generated stylesheet, so Zen
      is translucent at whatever the mod paints and at nothing this repo chose.
      `user.js` is read only at startup, so a restart is what applies it.
- [x] **`noct-check browser-glass` no longer asserts parity, and the spread is
      gone.** Retired rather than exempted: it failed when the four browsers were
      more than 0.06 apart, and a deliberately translucent Zen is exactly that, so
      the gate could only fire on the intended state. Removed rather than demoted
      to a warning — the 0.06 was the compositor's focus dim, which is itself gone
      at `inactive_opacity = 1.0`. Not kept as a metric either: a baseline
      tolerance is the same gate under another name. Still fails on the three real
      faults: more opaque than the compositor allows, **any browser but Zen** under
      it, or page text below 4.5:1. That middle one is what keeps the other three
      effect-free.
- [ ] **Re-record the baseline.** `tests/baselines/cachyos-x8664.json` is from
      01:17 on 2026-08-19, before `window` went 0.85 → 1.0, so all four
      `browser.*.effective_opacity` values still say 0.85 and `glass-config`'s
      message still quotes `window 0.85`. Zen's will now sit wherever the mod puts
      it. `browser.spread` is already gone, since nothing emits it any more.
      Needs a live session: `noct-check --record`.
- [ ] On any **other** machine that ran this repo before 2026-08-19, delete the
      stylesheet noct-glass used to generate — nothing writes it now, and Zen
      would go on reading it, tinting the page area to reach a `browser` level
      that no longer exists. Done on both profiles on this machine:
      ```sh
      grep -lZ "Generated by noct-glass" ~/.config/zen/*/chrome/userChrome.css | xargs -0 -r rm -v
      ```
      `-Z`/`-0` are load-bearing: Zen's profile directories have spaces in their
      names (`bxz0cb9y.Default Profile`), so a plain `grep -l | xargs rm` splits
      every path in two and each `rm` fails with "No such file or directory" —
      which reads exactly like "there was nothing to remove". That is why this
      machine was recorded as already clean when both files were still there.
- [ ] Say which of these numbers to move, if any: `ROUNDING = 2`
      (`conf/options.lua`), `capsule_radius = 12` (`10-bar.toml`), and
      `blur_brightness = 1.00` (`glass.conf`) — the last one is the dial between
      "one uniform shade" and "you can see the wallpaper's shape through a
      window".
- [ ] The last unticked Wi-Fi check in `TESTING.md` §6 needs a **secured network
      this machine has not joined before** — everything up to the passphrase
      prompt is verified, the no-echo half cannot be faked.
- [x] Work through the new checks in `TESTING.md` §2, §5, §6, §9, §11 — the
      keymap swap, the workspace bands, the two-second provider budget, the
      shelly path, and idle.

## Open

- [x] The bar's workspace widget shows only occupied workspaces. That is
      Noctalia's dynamic behaviour and it matches the band model. **Settled
      2026-08-18:** it is not a widget option — the widget draws the workspaces
      that exist, so a fixed row of ten per monitor means `persistent = true` on
      the workspace rules in `conf/workspaces.lua`, which is a compositor change
      and gives up the dynamic model. The widget's own keys are all checkable:
      `noctalia config validate` names an unknown one and rejects a bad enum
      value, so writing a deliberately wrong value is how you find both.
- [ ] Nothing verifies the greeter's appearance sync from a script; it is a GUI
      action in beta.8 (`noctalia msg greeter-sync` does not exist yet). Worth
      re-checking on the next Noctalia release.

## Standing notes

- Keep committing as work lands, one theme per commit, so the history stays
  readable.
- Anything confirmed or disproven on a live session goes in the
  **Known-uncertain details** table in `TESTING.md` with the date — that table
  is the memory of what has actually been observed rather than read.


## Settled against

- ~~frosted glass on every window, so the whole desktop reads as one material~~

  **Decided against 2026-08-19, after installing it on a work machine.** It was
  built, measured and correct: `window = 0.85` frosted GTK and Qt apps, which is
  the only way those can be frosted at all, and `noct-check glass-visible`
  confirmed the wallpaper reading through. What it could not do is separate a
  window's text from its background, so the price of the effect was a permanent
  discount on every glyph in every app — 85% of its colour at 0.85, 78% at 0.60.

  An effect you stop noticing in a minute, paid for all day. So `window` is 1.0
  and the terminal keeps the glass, where it costs nothing. Full reasoning in
  [docs/theming.md](docs/theming.md#why-the-compositor-level-was-given-up).

  **If it comes back**, it comes back per machine in `glass.local.conf`, not in
  the tracked file — the level is a property of the screen, not of the setup.

- ~~zen utilises a mod and an extension to achieve blurred transparent
  background. this effect should properly match with kitty and other translucent
  apps. other browsers should not have a transparent effect on the entire app,
  meaning either none at all or if there are similar extensions only when those
  take effect.~~

  **Half decided against 2026-08-19, and the half that went is the *matching*.**
  It was built first as a `browser` level in `glass.conf` written into a generated
  Zen stylesheet, and it measured correct while looking wrong to use. The mechanism
  is removed rather than turned down: nothing here writes CSS into a profile or has
  a level for a browser.

  The rest of the ask survives, and one line of it was over-applied and then put
  back. Zen *does* have the mod and the extension, and its transparency prefs are
  `true` again as of later the same day — so it is translucent, at whatever the mod
  paints. No other browser is, which is the "either none at all, or only where an
  extension takes effect" half, and that is satisfied. What you do not get is the
  first sentence: it does not match kitty, and nothing measures whether it does.

  Full reasoning in
  [docs/theming.md](docs/theming.md#what-was-tried-with-zen-and-dropped). The
  short version: the tint only ever showed on pages that paint no background of
  their own, so it was invisible on almost everything real; it needed a
  specificity fight with somebody else's extension that would have broken
  silently; and the 0.06 focus step left no room between "indistinguishable from
  a window" and "looks like a window in the other focus state", which is the
  ground the effect had to stand on.

  **If the matching ever comes back**, the thing to fix first is not the number —
  it is that it depended on four parts nobody here owns (a mod, an extension and
  two prefs), all read once at startup. Anything rebuilt on that will fail the same
  way. Two of those four are still in play now that the transparency is back on,
  which is why the mod looking broken has a documented cause rather than a debug
  session: see
  [theming](docs/theming.md#zens-own-transparency-is-back-on-unmatched).
