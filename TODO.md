# TODO

Open items only. Anything settled is in
[docs/decisions/](docs/decisions/README.md) with the date and the measurement
that settled it; anything learned about somebody else's software is in
[docs/upstream.md](docs/upstream.md). Ticked items are deleted rather than kept,
because the decisions log is the memory.

## Needs you

- [ ] **On the other machine:** `git pull && ./install.sh --update`. The installer
      moved this pass — `install.sh` is now a front door over
      `install/manifest/*.tsv` and `install/lib/*.sh` — so the pull brings new
      files that have to be linked, which `--update` does. Nothing else changes.
      Then decide whether that machine keeps the old look: if compositor-wide
      glass was fine there, that is two lines in
      `~/.config/noctalia/glass.local.conf`:
      ```
      window   = 0.85
      terminal = 0.55
      ```
      Nothing in the repo needs changing for that, which is the point of the file
      ([decision 014](docs/decisions/014-two-machine-local-files.md)).

- [ ] **Give the two machines different hostnames.** `sudo hostnamectl hostname
      <name>` — both are `cachyos-x8664` today, which is why they were fighting
      over one baseline file. The alternative is remembering `NOCT_HOST=` on every
      `noct-check --record`, which is the worse option because it has to be
      remembered.

- [ ] **Re-record the baselines, one per machine.**
      `tests/baselines/cachyos-x8664.json` is from 01:17 on 2026-08-19, before
      `window` went 0.85 → 1.0, so all four `browser.*.effective_opacity` values
      still say 0.85 and `glass-config`'s message still quotes `window 0.85`.
      Zen's will now sit wherever the mod puts it.
      Needs a live session: `noct-check --all --record`.
      `glass-visible` and `glass-legible` need a workspace with room on the
      monitor the probe opens on — an empty workspace, or the primary monitor
      alone — or they skip.

- [ ] **Enable the pre-commit hook**, once per checkout:
      `git config core.hooksPath .githooks`. It runs `tests/lint.sh` and
      `tests/install-fakeroot.sh`, takes about four seconds, and
      `git commit --no-verify` skips it.

- [ ] **Run `./install.sh --check` on the OTHER machine.** Done here on
      2026-08-22: 65 repo names, 1 from the AUR, 3 from npm, every name resolves.
      It has not been run on the second machine, which is the one that has never
      installed from this manifest.

- [ ] **`aerc` account setup**, which is now three commands rather than a wizard.
      `config/aerc/aerc.conf` is tracked and linked; `accounts.conf` is not, and
      the settings for this domain are already filled in
      ([decision 019](docs/decisions/019-mail-credentials-live-in-pass.md)):
      ```sh
      cp ~/.config/aerc/accounts.conf.example ~/.config/aerc/accounts.conf
      chmod 600 ~/.config/aerc/accounts.conf   # aerc refuses to start without this
      gpg --quick-generate-key "<your name and address>"
      pass init <the key id gpg printed>
      pass insert mail/<account>
      ```
      Then `./install.sh --packages` for `w3m` and `pass`, which are new.

      The real settings are already written to
      `~/.config/aerc/accounts.conf`, outside the repo and mode 600 — no
      address, hostname or account name appears anywhere in the repository, and
      `tests/lint.sh no-secrets` fails the commit if one ever does. The `pass`
      entry name to use is in that file. The one unknown left is whether the
      server wants the full address or the short name as the login; the
      alternative is commented directly above the line, and a wrong guess fails
      loudly at first connect.

- [ ] **Get the same logins working on the second machine**, which needs two
      things `install.sh` cannot do for you, because both are secrets:

      1. **The GPG key.** `pass` decrypts with it, so without it the second
         machine has a password store it cannot read. Either move the one key
         across (`gpg --export-secret-keys --armor` on one, `gpg --import` on
         the other — over a USB stick or `scp`, not a paste into anything
         hosted), or give each machine its own key and name both as recipients:
         `pass init <key-a> <key-b>`, which re-encrypts every entry to both and
         means no secret key ever leaves the machine that made it.
      2. **The store itself**, `~/.password-store`. Copy it, or `pass git init`
         and push it to a **private** remote. Not this one, and not any public
         one: `pass` encrypts the *contents* of each entry and not its
         *filename*, so a published store still lists `mail/work-gmail` and
         every other account name in plain sight.

      `accounts.conf` is the third file that has to exist on that machine, and
      it is a copy rather than a link precisely so it can differ — see
      [decision 014](docs/decisions/014-two-machine-local-files.md) for the
      other two files in that category.

- [ ] **The last Wi-Fi check** in [TESTING.md §5](TESTING.md#5-launcher-providers--binnoct---20-launchertoml)
      needs a **secured network this machine has not joined before**. Everything
      up to the passphrase prompt is verified; the no-echo half cannot be faked.

- [ ] **On any other machine that ran this repo before 2026-08-19**, delete the
      stylesheet `noct-glass` used to generate. Nothing writes it now, and Zen
      would go on reading it, tinting the page area to reach a `browser` level
      that no longer exists:
      ```sh
      grep -lZ "Generated by noct-glass" ~/.config/zen/*/chrome/userChrome.css | xargs -0 -r rm -v
      ```
      `-Z`/`-0` are load-bearing — Zen's profile directories have spaces in their
      names, so a plain `grep -l | xargs rm` splits every path in two and each
      `rm` fails with "No such file or directory", which reads exactly like
      "there was nothing to remove". Done on both profiles on this machine.

- [ ] **Say which of these three numbers to move, if any.** `ROUNDING = 2`
      (`conf/options.lua`), `capsule_radius = 12` (`10-bar.toml`), and
      `blur_brightness = 1.00` (`glass.conf`). The last is the dial between "one
      uniform shade" and "you can see the wallpaper's shape through a window" —
      [decision 011](docs/decisions/011-the-blur-is-small.md).

## Bugs

- [ ] **Confirm the rotated-monitor fix on the portrait screen.** `noct_window_geom`
      (`tests/lib/probe.sh`) now swaps width and height when `transform` is odd,
      which is what was making `glass-visible`, `glass-legible`, `blur-stacks`,
      `browser-glass` and `column-hop` skip on `HDMI-A-1` and pass from `DP-3`.
      Verified against a synthetic `transform = 3` monitor — the patch went from
      empty to 756x700 — but not yet against the real portrait screen, which was
      not attached when it was fixed. `noct-check --all` from that monitor is the
      check.

- [ ] **A capture patch ignores monitor scale, and grim's units are unmeasured.**
      `noct_window_geom` treats window coordinates and grim's PNG pixels as the
      same units. That holds at `scale = 1`, which is what both machines run, so
      nothing is wrong today. What is unknown is whether `grim -o` writes panel
      pixels or logical ones on a scaled output — until that is measured, every
      pixel check is presumed wrong on a monitor at any scale but 1.
      `hyprctl output create headless` plus a scale is how to settle it without
      owning a HiDPI screen.

- [ ] **What the review of the sleep/rotation work left open** (2026-11-02,
      after `6dc9e9d` fixed the rest). One possible bug, two clean-ups:

      1. **Noctalia may lock itself out after a logout from a session not
         started by uwsm.** `noctalia.service` is `Restart=always`,
         `RestartSec=1`, `StartLimitBurst=5` in 60 s. Under uwsm,
         `graphical-session.target` stops at logout and `PartOf` takes the shell
         down with it. Without uwsm, if nothing stops the target, Noctalia exits
         0 ("Wayland display closed"), is restarted into a dead display five
         times, and hits the start limit. A login inside that minute then gets
         "start request repeated too quickly" from autostart, so no bar and no
         lock screen. **Unconfirmed:** Hyprland 0.57 starts
         `graphical-session.target` itself (hyprwm/Hyprland#15776), and whether
         it also stops it on exit is the whole question. To settle it: log in via
         `hyprland.desktop` rather than the uwsm entry, log out, and
         `systemctl --user status noctalia graphical-session.target`. If it
         loops, `ExecStartPre` testing for the Wayland socket or
         `systemctl --user reset-failed noctalia` before the start in
         `conf/autostart.lua` would fix it.
      2. **`hyprland_env()` and `hypr_eval()` are copied** into both
         `bin/hypr-sleepwatch` and `bin/hypr-autorotate`, and `slurp()` into both
         `lib/lid.lua` and `lib/rotate.lua`. A shared module beside each pair
         (`bin/` already has `noct-common.sh` for the shell scripts) keeps one
         copy, so a fix such as picking the live instance differently lands
         once.
      3. **`rotate.setup()` must come after `lid.setup()`.** It reaches into the
         lid module through `package.loaded["lib.lid"]`, so called first it
         declares its own panel rule, and the lid module's re-applies then put
         the panel upright. `host.lua` and `host.lua.example` have the order
         right and the `setup()` comment says so, but nothing enforces it. One
         owner of the panel spec, with rotation handing `lid` a field instead of
         special-casing it, would remove both the order and the special case.

## Worth exploring

- [ ] **A tracked config for `spotify_player`.** Only the package is automated
      today ([`packages.tsv`](install/manifest/packages.tsv), `apps` group);
      nothing in `config/` names it, so it runs on its own defaults. It reads
      three files from `~/.config/spotify-player`, and they are worth deciding
      separately rather than as one job:
      - `theme.toml` — a `name` plus optional `palette` and `component_style`.
        This is the one with an actual argument behind it: the TUI is the only
        thing here that paints its own colours and does not inherit the shell
        palette, so it is either matched by hand or left looking like a
        different machine.
      - `keymap.toml` — `[[keymaps]]` entries, and `command = "None"` to drop a
        default bind. Only worth writing if a default collides with something
        kitty or Hyprland already takes.
      - `app.toml` — where `theme` is selected, and where the cover art is
        sized: `cover_img_length` defaults to `0`, meaning derive the column
        count from the terminal's cell aspect ratio, with `cover_img_width = 5`
        rows. The default is the right starting point; it is only worth pinning
        if kitty's cell ratio makes the art the wrong shape.

      Tracking any of them means a `config/spotify-player/` directory and a row
      per file in [`links.tsv`](install/manifest/links.tsv), the same shape as
      every other app here. Left undone deliberately for now: defaults that
      work are worth more than a config written before the app has been lived
      with, and a tracked file that only restates the default is a file that
      will drift from it silently.

## Waiting on upstream

- [ ] **If the bar capsules should ever be glass**, the only routes left are
      Noctalia honouring `capsule_opacity` (it accepts and ignores it today) or a
      theme-level surface alpha. Worth a look when Noctalia moves past
      5.0.0-beta.8 —
      [decision 009](docs/decisions/009-the-bar-is-three-capsules.md).

- [ ] **Nothing verifies the greeter's appearance sync from a script.** It is a
      GUI action in beta.8; `noctalia msg greeter-sync` does not exist. Worth
      re-checking on the next Noctalia release.

## Standing notes

- Keep committing as work lands, one theme per commit, so the history stays
  readable.
- **Work in a worktree, not on a branch in this checkout.** This checkout is the
  live config -- `~/.config/hypr`, `~/.local/bin` and the rest link into it -- so
  a branch switch or a rebase here rewrites the running session's files halfway
  through. `git worktree add ../dots-<topic>` (or `.claude/worktrees/`, which is
  ignored), then `git submodule update --init` in it -- a new worktree has an
  empty `vendor/noirblaze`, and `tests/lint.sh` fails on it. Land the work here
  with `git merge --ff-only` only when it is done.
  A change in a worktree is not live, and not what `noct-check` measures, until
  then.
- A fact learned about Hyprland, Noctalia, kitty or a browser goes in
  [docs/upstream.md](docs/upstream.md) with the date, the version and the check
  that holds it. A row with no check is a fact that will rot.
- A choice, and especially a choice made *against* something, goes in
  [docs/decisions/](docs/decisions/README.md). The dead ends are the half of that
  directory that earns its keep: six substantial pieces of work here were built,
  measured and removed, and the cost of that is not the building — it is somebody
  looking at the gap in six months and starting again.
- A new check goes in `tests/checks/` if it needs a session and `tests/lint.sh` if
  it does not, and **it is verified against the broken version before being
  trusted**. A check that has never failed is a check that has not been tested.
