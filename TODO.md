# TODO

Done in this pass — kept for a moment so it can be checked off against the real
desktop, then delete:

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
- [x] zen's translucency meets the desktop's: its own background is tinted to
      0.6, which lands at 0.54 once the compositor has had its turn, against a
      tenth of the wallpaper for a terminal. Also fixes why no Zen pref had ever
      applied — the profile root is `~/.config/zen`, not `~/.zen`
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
- [ ] **Restart Zen.** `user.js` is only read at startup, and it is already
      linked into both profiles under `~/.config/zen`. Then look at reddit or
      youtube next to a terminal: they should read as the same material at
      different depths. The alpha in `zen_transparency_color` is the knob —
      raise it towards 1.0 to converge on the rest of the desktop. `TESTING.md`
      §10 has the two things that could still be wrong on the Zen side.
- [ ] Say which of the three new numbers to move, if any: `ROUNDING = 2`
      (`conf/options.lua`), `capsule_opacity = 0.90` (`10-bar.toml`), and the
      Zen tint above. They are deliberately in three separate files because
      each governs a different surface.
- [ ] The last unticked Wi-Fi check in `TESTING.md` §6 needs a **secured network
      this machine has not joined before** — everything up to the passphrase
      prompt is verified, the no-echo half cannot be faked.
- [x] Work through the new checks in `TESTING.md` §2, §5, §6, §9, §11 — the
      keymap swap, the workspace bands, the two-second provider budget, the
      shelly path, and idle.

## Open

- [x] The bar's workspace widget shows only occupied workspaces. That is
      Noctalia's dynamic behaviour and it matches the band model, but if you
      want a fixed row of ten pills per monitor, that is a `[widget.workspaces]`
      option — the settings GUI is the fastest way to find its name, since the
      config validator does not check widget keys.
- [ ] Nothing verifies the greeter's appearance sync from a script; it is a GUI
      action in beta.8 (`noctalia msg greeter-sync` does not exist yet). Worth
      re-checking on the next Noctalia release.

## Standing notes

- Keep committing as work lands, one theme per commit, so the history stays
  readable.
- Anything confirmed or disproven on a live session goes in the
  **Known-uncertain details** table in `TESTING.md` with the date — that table
  is the memory of what has actually been observed rather than read.
