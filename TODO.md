# TODO

Done in this pass — kept for a moment so it can be checked off against the real
desktop, then delete:

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
      `glass.conf`~~ — **reverted 2026-08-19**, see below. The one part of it that
      stands is why no Zen pref had ever applied: the profile root is
      `~/.config/zen`, not `~/.zen`
- [x] `terminal` is back to matching `window`, because kitty applies
      `background_opacity` only at startup (measured): a terminal-specific level
      quietly gives you two shades of terminal until every window is restarted
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

- [x] **`./install.sh --login`** — installs greetd + noctalia-greeter, disables
      plasmalogin, enables greetd. It needs a sudo password, so it could not be
      run for you. Takes effect at the next boot; undo is
      `sudo systemctl disable greetd && sudo systemctl enable --now plasmalogin`
      from `ctrl+alt+F2`.
- [x] After that: `SUPER+,` → Security → Noctalia Greeter → **Sync Now**, so
      the login screen uses the current wallpaper and palette.
- [ ] `aerc` account setup (first run walks you through it).
- [ ] **Two things inside Zen, which no file here can do.** Disable the
      "transparent zen" mod (`about:preferences` → Zen Mods) and remove or
      disable the "Zen Internet" extension. Then **restart Zen** — `user.js` sets
      `zen.widget.linux.transparency` and
      `browser.tabs.allow_transparent_browser` to false at every startup, but
      only at startup. Afterwards `noct-check browser-glass` should have all four
      browsers within 0.06 of each other at `window`.
- [ ] On any **other** machine that ran this repo before 2026-08-19, delete the
      stylesheet noct-glass used to generate — nothing writes it now, and Zen
      would go on reading it. Done on this machine already:
      ```sh
      grep -l "Generated by noct-glass" ~/.config/zen/*/chrome/userChrome.css | xargs -r rm -v
      ```
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

- ~~zen utilises a mod and an extension to achieve blurred transparent
  background. this effect should properly match with kitty and other translucent
  apps. other browsers should not have a transparent effect on the entire app,
  meaning either none at all or if there are similar extensions only when those
  take effect.~~

  **Decided against 2026-08-19, and the mechanism is removed rather than turned
  down.** Built first, as a `browser` level in `glass.conf` written into a
  generated Zen stylesheet, and it measured correct while looking wrong to use.
  The second half of the ask is now what the whole of it is: no browser has a
  transparent effect on the entire app, because a browser gets the compositor's
  `window` level and nothing else — exactly like nautilus.

  Full reasoning in
  [docs/theming.md](docs/theming.md#what-was-tried-with-zen-and-dropped). The
  short version: the tint only ever showed on pages that paint no background of
  their own, so it was invisible on almost everything real; it needed a
  specificity fight with somebody else's extension that would have broken
  silently; and the 0.06 focus step left no room between "indistinguishable from
  a window" and "looks like a window in the other focus state", which is the
  ground the effect had to stand on.

  **If it ever comes back**, the thing to fix first is not the number — it is
  that the effect depends on four parts nobody here owns (a mod, an extension and
  two prefs), all read once at startup. Anything rebuilt on that will fail the
  same way.
