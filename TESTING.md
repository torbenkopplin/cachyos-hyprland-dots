# Post-install checklist

Most of this repo was written against the Hyprland Lua API source, the
scrolling-layout docs and the Noctalia v5 IPC/config reference rather than
against a running system. Some of it has since been confirmed on a live session
— what has, and what that changed, is recorded in
[Known-uncertain details](#known-uncertain-details) with a date. This is the
list of things to confirm on the CachyOS partition, roughly in dependency
order. Tick as you go.

The parts that turned out to be wrong were all *silent*: a dispatcher that
answers `ok` and does nothing, a launcher provider killed at a deadline with no
error shown, two idle daemons racing. So prefer the checks that read back a
value over the ones that just look at the screen.

Anything that fails: the fix is almost always in the file named in the
right-hand column.

---

## 0. It loads at all

- [ ] `hyprctl version` reports **0.55 or newer**. Below that, Lua configs and
      the built-in scrolling layout do not exist and nothing here works.
- [ ] Session starts with no config-error overlay.
- [ ] `hyprctl configerrors` is empty.
- [ ] If the emergency binds (`SUPER+Q`/`R`/`M`) are what you get, a file failed
      to parse — check the notification for which one.
- [ ] The `lib/` modules loaded. `conf/binds.lua` does
      `local nav = require("lib.nav")` and calls into it; if Hyprland's scoped
      `require()` did not hand back the module table, `SUPER+H` would pop an
      error notification instead of moving focus. Check with:
      ```sh
      hyprctl eval 'return type(require("lib.nav").focus_horizontal)'   -- expect: function
      ```

## 1. Layout — `conf/layout.lua`

- [ ] `hyprctl getoption general:layout` says `scrolling`.
- [ ] Opening one window gives it a **third** of the screen, not the whole
      screen — `fullscreen_on_one_column` is off and `column_width` is 0.333,
      both carried over from `~/repos/dots`.
- [ ] Opening several windows scrolls the tape rightwards.
- [ ] `SUPER + +` / `-` cycles the six width presets.

## 2. Navigation — `lib/nav.lua`

This is the part most likely to need adjusting, since it depends on the exact
shape of `window.layout`.

- [ ] `SUPER+H`/`L` moves between columns.
- [ ] `SUPER+J`/`K` moves between windows **within a column** (stack two windows
      in one column with `SUPER+O` first).
- [ ] At the **last column**, `SUPER+L` moves focus to the next monitor.
- [ ] At the **first column**, `SUPER+H` moves to the previous monitor.
- [ ] At the **bottom of a column**, `SUPER+J` goes to the next workspace.
- [ ] At the **top of a column**, `SUPER+K` goes to the previous workspace.
- [ ] On an **empty** workspace, `SUPER+J`/`K` still change workspace.
- [ ] Nothing **wraps** — at the last workspace `SUPER+J` does nothing, it does
      not jump back to the first.
- [ ] `SUPER+SHIFT+<hjkl>` does all of the above dragging the window along.
      (This moved off `CTRL`, which now reorders columns.)
- [ ] Every one of the checks above behaves identically on the **arrow keys**
      with the same modifiers — they are bound from the same table, so a
      difference means a bind went missing rather than a behaviour differing.
- [ ] `SUPER+CTRL+H`/`L` swaps this column with its neighbour, without changing
      which window is focused.
- [ ] With a **floating** window focused, `SUPER+hjkl` still behaves sanely.

> If edge detection misfires, dump what the layout actually reports:
> ```sh
> hyprctl eval 'local w = hl.get_active_window()
>   local l = w.layout
>   return string.format("col=%s row=%s in_col=%s",
>     tostring(l.column.index), tostring(l.index_in_column), tostring(#l.column.windows))'
> ```
> The assumption in `lib/nav.lua` is that both indices are **0-based**.

## 3. Tap SUPER — the `SUPER + SUPER_L` release bind

Same bind `~/repos/dots` uses, so this should already behave. The failure mode
to watch for is the launcher also opening after ordinary chords.

- [ ] Tapping and releasing `SUPER` alone opens the launcher.
- [ ] `SUPER+J`, then releasing `SUPER`, does **not** open the launcher.
- [ ] `SUPER+T`, then releasing, does **not** open the launcher.
- [ ] `SUPER+Space` opens the launcher as well (kept as a fallback).

> If it does misfire after chords, set `SUPER_TAP_ENABLED = true` in
> `conf/options.lua`. That swaps in `lib/supertap.lua`, which watches raw key
> events and requires the tap to be quick and uninterrupted. It is kept for
> exactly this case; if the release bind behaves, leave it off — the plain
> bind is the documented approach and far less machinery.

## 4. The bar — `lib/bar.lua` + `10-bar.toml`

- [ ] No bar visible at login, and windows use the **full screen height**
      (no reserved gap at the top).
- [ ] Opening the launcher slides the bar in.
- [ ] Closing the launcher slides it back out.
- [ ] Control centre (`SUPER+A`), clipboard (`SUPER+X`) and the session menu do
      the same.
- [ ] A **notification** appearing does *not* reveal the bar.
- [ ] Changing workspace does *not* reveal the bar.
- [ ] `SUPER+B` pins it on; `SUPER+B` again releases it back to following panels.
- [ ] The bar renders **above** a fullscreen window (`layer = "overlay"`).

> If the namespaces are wrong, list them while a panel is open:
> `hyprctl layers | grep noctalia`
> and reconcile with `PANEL_NAMESPACES` in `lib/bar.lua`.

## 5. Workspaces — `conf/workspaces.lua` + `host.lua`

The band model is adopted from `~/repos/dots`: monitor id N owns workspaces
N*10+1 … N*10+10, and each band carries its own scroll direction.

- [ ] Copy `config/hypr/host.lua.example` to `~/.config/hypr/host.lua` and fill
      in `WSBANDS` with your real monitor names and ids (`hyprctl monitors`).
- [ ] Without a `host.lua`, Hyprland still starts — the fallback is a single
      band. Confirm this before relying on the pcall.
- [ ] `hyprctl workspacerules` shows one band of 10 per monitor. (`hyprctl
      workspaces` lists only the ones that *exist* — workspaces here are
      dynamic, so an empty one is not there at all. That is the intended
      behaviour, not a missing rule.)
- [ ] `SUPER+2` goes to the second workspace **on the monitor you are looking
      at**, whichever that is. On the second monitor that is id 12, not 2 —
      check with `hyprctl activeworkspace`.
- [ ] `SUPER+SHIFT+2` sends the window there and follows it.
- [ ] `SUPER+J` past the **last** workspace of a band does nothing, and
      `SUPER+K` past the first does nothing. The clamp is what keeps a
      workspace step from landing on another monitor's numbers.
- [ ] A workspace never migrates to a monitor outside its band.

> Both of the workspace selectors that *look* like they would do this are
> traps: `m~n` is not valid syntax in 0.56 (the dispatcher answers `ok` and
> nothing happens) and `m±1` walks only the workspaces that already exist. If
> the number keys ever go dead again, that is the first thing to check —
> `lib/ws.lua` does the arithmetic instead, and it can be exercised directly:
> ```sh
> hyprctl dispatch '(function() require("lib.ws").switch(3)
>   return hl.dsp.exec_cmd("true") end)()'
> ```
- [ ] With a portrait monitor configured `direction = "down"`, that band
      genuinely scrolls vertically while a landscape band scrolls right —
      this is the whole reason for the band model over a flat list.

## 6. Launcher providers — `bin/noct-*` + `20-launcher.toml`

First, straight from a terminal — this is where parsing bugs show up plainly.
Each should print readable `title <TAB> description` lines with **no base64 or
device ids visible**; the payloads go to a side map in `$XDG_RUNTIME_DIR`:

- [ ] `noct-audio list sinks` — outputs, current one marked `●`
- [ ] `noct-audio list sources` — inputs, with no `.monitor` entries
- [ ] `noct-bluetooth list`
- [ ] `noct-network list`
- [ ] `noct-power list`
- [ ] `noct-theme list` — and it marks the active scheme without asking the
      running shell for it (`grep -c 'noctalia msg' bin/noct-theme` counts only
      the `act` path; see the two-second rule below)
- [ ] Every one of those returns in **well under two seconds**:
      `for p in "noct-audio list sinks" "noct-bluetooth list" "noct-network list" \
      "noct-power list" "noct-theme list"; do /usr/bin/time -f "%e $p" sh -c "$p" >/dev/null; done`
- [ ] `cat "$XDG_RUNTIME_DIR"/noct-*.map` — one `title <TAB> payload` per result
- [ ] Two devices with the *same* name both stay selectable (the second gets a
      ` (2)` suffix). Only testable if you have a duplicate; skip otherwise.

Then through the launcher:

- [ ] `/aout` lists outputs, the current one marked `●`.
- [ ] Picking one switches the default **and moves audio that is already
      playing** — test with music running.
- [ ] `/ain` switches the microphone.
- [ ] `/bt` lists paired devices; connect and disconnect both work; "Scan for
      devices" finds something new and reopens the list.
- [ ] `/net` lists the active connection first, then saved profiles, then Wi-Fi
      in range — and it appears **immediately**, because it reads nmcli's
      cached scan. "Rescan" is an entry in that list; picking it re-runs the
      scan and reopens the list.
- [ ] Connecting to a **new, secured** Wi-Fi network opens a kitty window with
      `nmcli --ask` and the passphrase is not echoed.
- [ ] `/power` switches profile and toggles night light.
- [ ] `SUPER+CTRL+O/I/B/N/P/T` each open the launcher already filtered.

> **A provider that shows "No results found" has usually been killed, not
> failed.** Noctalia gives `command` about two seconds and then SIGTERMs it;
> the only trace is in the log. Turn it up and reproduce:
> ```sh
> noctalia msg log-level-set debug
> # open the provider, then:
> grep dmenu ~/.cache/noctalia/noctalia.log | tail
> #   [WRN] [dmenu] [theme] command failed (exit 143)   <- 143 = SIGTERM
> noctalia msg log-level-set info
> ```
> The two ways to overrun are calling `noctalia msg` while listing (a deadlock:
> the shell is blocked waiting for the provider) and anything that blocks on
> hardware or the network. Both are documented at the top of
> `bin/noct-common.sh`. To see where a provider is actually stuck, run it under
> `bash -x` from a temporary dmenu entry and read the trace.
>
> If instead it says "not installed", the backend package is missing — see
> [docs/install.md](docs/install.md).

## 7. Launcher keys — `00-shell.toml`

- [ ] `Ctrl+J` / `Ctrl+K` move the selection in the launcher.
- [ ] Arrow keys still work.
- [ ] `Esc` closes.
- [ ] Noctalia did not report a config parse error for `[keybinds]` — if it did,
      one of the chord names is wrong; remove it and check
      `noctalia msg config-reload`.

## 8. Theming — `30-theme.toml` + `40-templates.toml`

- [ ] `noctalia theme --list-templates` lists the built-in ids used in
      `40-templates.toml`: `gtk3`, `gtk4`, `qt`, `kcolorscheme`, `btop`.
      (Verified against noctalia v5.0.0-beta.8; all five exist.)
- [ ] `builtin_ids` does **not** contain `kitty`. The built-in rewrites
      `kitty.conf`, which is a tracked symlink — see the note in
      `config/kitty/README.md`. Colours come from the `kitty` *user* template.
- [ ] Before adding any built-in id, check where it writes. An id whose output
      path is a file this repo tracks will edit the checkout itself. `starship`
      and the community `yazi` template are the ones to look at twice, since
      this repo tracks `starship.toml` and `yazi.toml`.
- [ ] Change the wallpaper (`/wall` in the launcher). The bar and panels
      recolour.
- [ ] `~/.config/hypr/generated/colors.lua` now exists and contains real hex
      values, not `{{ ... }}` placeholders.
- [ ] **Window borders changed colour** — the focused window's border tracks
      the new palette. (This is the user template + `hyprctl reload`.)
- [ ] Terminals that were **already open** repainted immediately.
- [ ] The shell prompt, `ls` colours and `git` output changed with them.
- [ ] A full-screen TUI (`btop`, vim) survived the repaint without corruption.
- [ ] `noctalia msg templates-apply` re-renders without changing the theme.
- [ ] On a **fresh** install, before any palette render, Hyprland still starts
      cleanly — `generated/colors.lua` is absent and the `pcall(require, ...)`
      in `hyprland.lua` must swallow that silently.

> If borders never change, check the template rendered at all:
> ```sh
> cat ~/.config/hypr/generated/colors.lua
> ```
> If terminals never change, run the rendered script by hand and watch for
> errors:
> ```sh
> bash "${XDG_CACHE_HOME:-$HOME/.cache}/noctalia/terminal-colors.sh"
> ```

## 8b. Colour scheme switching — `/theme`

- [ ] `/theme` lists your palettes, the ten built-ins, the nine wallpaper
      generators, and the mode toggle.
- [ ] The active scheme is marked `●`.
- [ ] Selecting **noirblaze** switches the shell to the monochrome + pink
      palette from your neovim theme.
- [ ] Terminals repaint to match, and open neovim looks at home in them.
- [ ] Selecting **Gruvbox** (or any built-in) switches cleanly.
- [ ] Selecting a **Wallpaper:** entry goes back to wallpaper-derived colours.
- [ ] The choice survives a restart (it is persisted to `settings.toml`).
- [ ] `noctalia msg color-scheme-get` agrees with what you picked.

> noirblaze is dark-only by design. Toggling to light mode will keep the dark
> colours — that is Noctalia's documented fallback when a palette omits
> `light`, not a bug. Add a `"light"` object to `palettes/noirblaze.json` if
> you want a real one.

## 8c. Frosted glass — `bin/noct-glass`

- [ ] `noct-glass show` prints **two** levels (`window` and `terminal`), each
      with a **decimal point**, not a comma.
      (awk formats per locale; the script pins `LC_ALL=C` to prevent `0,90`,
      which Hyprland would refuse to parse. Worth re-checking if you ever edit
      the script.)
- [ ] `~/.config/hypr/generated/glass.lua` and
      `~/.config/kitty/generated-glass.conf` both exist after the first scheme
      change, and contain real numbers.
- [ ] A new kitty window is translucent, with the wallpaper blurred behind it.
- [ ] **A terminal and a browser side by side show the same amount of
      wallpaper.** They used to compound — kitty applied its level, the
      compositor applied another on top — and the terminal came out visibly
      darker. With `window` and `terminal` equal (the default),
      `generated-glass.conf` should say `background_opacity 1.00`.
- [ ] **A GTK app (nautilus) and a Qt app are frosted too** — this is the point
      of driving it from the compositor rather than per-app.
- [ ] Text is legible at the default level. If not, raise `window` in
      `glass.conf`; the compositor fades glyphs along with the background.
- [ ] mpv/imv/gimp/obs stay **fully opaque** (the opt-out list in rules.lua).
- [ ] Switching scheme via `/theme` changes the levels to whatever
      `glass.conf` lists for it (`noct-glass show` confirms) without you doing
      anything else.
- [ ] `SUPER+SHIFT+G` cycles the level and **terminals already open change with
      everything else** — noct-glass sends kitty SIGUSR1 after writing. If they
      do not, check that `pkill -USR1 -x kitty` reaches them.
- [ ] Stepping to `1.00` leaves nothing translucent, terminals included.
- [ ] At level `1.00`, `glass.lua` has `enabled = false` for blur.
- [ ] Changing scheme afterwards clears the manual override.
- [ ] Hyprland does not error on `generated/glass.lua` after a `hyprctl reload`.

> Neovim will look opaque inside a transparent kitty until `Normal`/`NormalNC`
> use `bg = "none"` — that change belongs in your nvim repo, not this one.
> See `config/kitty/README.md`.

## 8d. kitty and fish

- [ ] kitty starts with no config errors. There is no `--debug-config` flag in
      kitty 0.48; bad config lines go to stderr at startup, so
      `kitty sh -c exit 2>&1` is the check.
- [ ] `ctrl+f` still opens the search kitten.
- [ ] The font really is JetBrainsMono Nerd Font, not a fallback that merely
      looks like one: `fc-match "JetBrainsMono Nerd Font"` names a
      `JetBrainsMonoNerdFont-*.ttf`. The family name has no space in
      "JetBrainsMono"; the spaced spelling only resolves by falling through
      fontconfig's matching rules.
- [ ] Colours match the active scheme, and change when you switch scheme.
- [ ] `~/.config/kitty/generated-colors.conf` exists and holds real hex values,
      not `{{ }}` placeholders.
- [ ] `git status` is clean after a scheme change. If `config/kitty/kitty.conf`
      shows as modified, Noctalia's built-in `kitty` template is enabled and is
      editing the repo — see `config/kitty/README.md`.
- [ ] On a **fresh** machine, before Noctalia has rendered a palette, kitty
      still starts — the two `include`s point at files that do not exist yet
      and kitty should warn rather than fail.
- [ ] `echo $SHELL` reports fish **after a fresh login** (chsh does not affect
      the shell you ran the installer from).
- [ ] The starship prompt renders, with the nerd-font glyphs intact.
- [ ] `y` opens yazi and leaves the shell in the directory you quit from.
- [ ] `cat`, `ls` and `lt` work — these are aliased to `bat` and `eza`, and
      `cat` in particular was `batcat` on Debian, so a wrong package name here
      shows up as "command not found" on every use.
- [ ] `sin`, `sinaur`, `sfind`, `srem`, `supd`, `supg` exist as aliases for the
      matching `shelly` subcommands, and `update` is `shelly upgrade`. On a
      machine without shelly none of them exist and `update` falls back to
      `pacman -Syu` — the block is guarded on the binary, not the distro.
- [ ] `fisher list` shows `jorgebucaran/fisher` and `jorgebucaran/nvm.fish`.
- [ ] `nvm --version` works **in fish** (this is nvm.fish, not the bash one).
- [ ] `node --version` works in a shell where no nvm version is selected —
      this is the system package mason depends on.
- [ ] `cargo --version` works. With the repo `rust` package this is
      `/usr/bin/cargo` and `~/.cargo/env.fish` does not exist at all —
      `conf.d/rustup.fish` tests for it before sourcing, so a **new shell must
      print no error**. Check that specifically; the previous version sourced it
      unconditionally and complained on every startup.
- [ ] `~/.cargo/bin` is on `PATH` (`contains ~/.cargo/bin $PATH`), so binaries
      from `cargo install` are reachable. Nothing else adds it when cargo came
      from the repos rather than rustup.
- [ ] `claude --version` works.
- [ ] `auto-Hypr.fish` is still inert. It sits at the top level of the fish
      config, which fish does **not** auto-source — only `conf.d/` is. Move it
      there only if you actually want tty1 autostart, and read the warning in
      the file first.

## 8e. Wallpapers — `noct-wallfetch` + `60-wallpaper.toml`

- [ ] **Rename the monitor sections in `60-wallpaper.toml`.** `DP-3` and
      `HDMI-A-1` are placeholders; check `hyprctl monitors`. An unmatched
      `[wallpaper.monitor.X]` is ignored silently, so a typo here looks like
      "per-monitor directories don't work" rather than an error.
- [ ] `noct-wallfetch --list` shows the six sets.
- [ ] `noct-wallfetch --dry-run` lists files without downloading.
- [ ] `noct-wallfetch` fills `~/Pictures/Wallpapers/{ultrawide,standard,portrait}`.
- [ ] Re-running is idempotent — second run reports "already had", not new
      downloads.
- [ ] The ultrawide folder has genuinely wide images (`file *.jpg` should show
      3440×1440 or 3840×1080), not cropped 16:9.
- [ ] `SUPER+W` picker shows the folder for the monitor selected in its
      toolbar, and a different set when you switch monitor.
- [ ] Applying a wallpaper recolours the shell (palette is wallpaper-derived).
- [ ] `SUPER+SHIFT+W` opens the Wallhaven browser. If nothing happens the
      plugin did not enable — check `noctalia msg plugins list`.

> Only **four** true-ultrawide Dragon Ball wallpapers exist on Wallhaven, which
> is why the ultrawide folder is filled from three sets. If you would rather
> have only Dragon Ball there, delete the `anime-ultrawide` line from
> `wallpapers.conf` and accept four images.

## 9. Installer — `install.sh`

- [ ] `./install.sh --all --dry-run` completes with no errors before you run
      it for real.
- [ ] The **warning summary** at the end is empty. Any "could not install"
      line is a package name that does not exist in the CachyOS repos and
      needs correcting in `install.sh`.
- [ ] `nvim` starts, mason installs `tsgo`, `eslint`, `vimls`, `lua_ls`,
      `lemminx` on first launch, and `:checkhealth` is clean.
- [ ] `yazi` opens; pressing Enter on a text file opens it in neovim — this
      confirms both `$EDITOR` and that the carried-over `%s` opener syntax is
      still valid on the current yazi.
- [ ] `eslint --version` and `mmdc --version` work (npm globals in
      `~/.local/bin`).
- [ ] `nvm --version` works after sourcing it in a new shell.
- [ ] Rerunning `./install.sh` is quiet and idempotent — no new backups, and
      `--packages` says "already installed: N package(s)" rather than handing
      the whole list to a package manager again.
- [ ] On CachyOS, `--packages --dry-run` says **`would: shelly install
      standard …`**. On plain Arch, or with shelly removed, the same line says
      `pacman`. Both paths must work; shelly authenticates through polkit, so
      it is the pacman path that runs in a bare TTY.
- [ ] `systemctl --user is-enabled hypridle` says **disabled** after
      `--packages`. Two idle daemons is the failure this prevents; see §11.
- [ ] `--wallpapers` reports **"per-monitor sections match the connected
      monitors"**. A warning here means `60-wallpaper.toml` names connectors this
      machine does not have, and those screens will silently fall back to the
      global `directory` — rename the sections to match `hyprctl monitors`.
- [ ] After adding a file to the repo, rerun `./install.sh` before expecting it
      to work. Linking is per file, so a new template or script is not in
      `~/.config` until it has been linked.

## 10. Browsers

- [ ] Brave, Zen, Chromium and Firefox all launch.
- [ ] `brave://policy` and `chrome://policy` show the keys applied, with **no
      errors and no "unknown policy" entries**.
- [ ] `about:policies` in Firefox likewise.
- [ ] Firefox's new tab has no sponsored shortcuts or stories.
- [ ] Sync still works in each browser — nothing here should have disabled it.
- [ ] After launching Firefox and Zen once, rerun `./install.sh --browsers`
      and confirm `user.js` landed in each profile.
- [ ] `about:config` shows `browser.startup.page` = 3 in both.
- [ ] **No profile data is tracked**: `git status` stays clean after a browsing
      session, and `git ls-files | grep -iE 'cookies|logins|places'` finds
      nothing.

## 11. Focus discipline

The point of the whole setup — worth testing deliberately:

- [ ] A background app finishing a task does **not** steal focus or scroll the
      tape away from what you are reading.
- [ ] Moving the mouse does not change which monitor is active.

### Idle and locking

Exactly one thing may own this. Noctalia does; `hypridle` must not be running
alongside it.

- [ ] `systemctl --user is-active hypridle` says **inactive**, and
      `pgrep hypridle` finds nothing.
- [ ] After a config reload the log registers our three behaviours:
      `grep 'registered idle behavior' ~/.cache/noctalia/noctalia.log | tail -3`
      → `lock timeout=600s`, `screen-off timeout=900s`,
      `lock-and-suspend timeout=1800s`.
- [ ] A **fullscreen** video keeps the screen awake; an ordinary window does not.
- [ ] A video playing in a **windowed** browser tab also keeps it awake — that
      one depends on the browser holding a Wayland idle inhibitor rather than
      on any rule here, so it is the case worth actually sitting through.
- [ ] A focused, windowed mpv keeps it awake even when paused
      (`idle_inhibit = focus`).
- [ ] `SUPER+CTRL+P` → Caffeine holds it awake for anything else, and the
      shortcut in the control centre shows it as on.

### The login screen (only after `./install.sh --login`)

- [ ] `systemctl is-enabled greetd` says enabled and
      `systemctl is-enabled plasmalogin` says disabled.
- [ ] `/etc/greetd/config.toml` points `command` at a path that exists
      (`command -v noctalia-greeter-session`).
- [ ] **Reboot.** The greeter comes up, the Hyprland (uwsm) session is
      selectable, and logging in lands in this setup.
- [ ] `SUPER+,` → Security → Noctalia Greeter → **Sync Now**, then reboot: the
      greeter shows the current wallpaper and palette.
- [ ] If it does not come up: `ctrl+alt+F2`, log in, and
      `sudo systemctl disable greetd && sudo systemctl enable --now plasmalogin`
      puts the old one back. Confirm you can do this *before* trusting it.

---

## Settled: nav.lua, and what it turned out `wsnav.sh` was really doing

Two implementations of directional navigation existed — `lib/nav.lua` here, and
`~/repos/dots/.../scripts/wsnav.sh`, the proven one. This was written up as an
open question because `nav.lua` had never run on a live session. It has now.

**The layout reading in `nav.lua` was right.** `column.index` and
`index_in_column` are 0-based, `window.layout` is populated for every tiled
window on a scrolling workspace, and `hl.get_workspace_windows(<id>)` takes a
numeric id. Directional focus, the monitor handoff at the ends of the tape, and
the window-dragging variants all behave.

**What was wrong was the workspace half, and `wsnav.sh` had already solved it.**
Its per-monitor band arithmetic was not an implementation detail of doing this
in bash — it was load-bearing, because the selectors that look like they say
"the n-th workspace of this monitor" do not work:

| Selector | What it does |
|---|---|
| `m~n` | nothing; not valid syntax in 0.56, and the dispatcher still answers `ok` |
| `m±1` | walks only the workspaces that currently *exist* on the monitor — usually one |

So the arithmetic moved into `lib/ws.lua`, in-process: read the focused
monitor, find its band in `WSBANDS` by connector name, dispatch the absolute
id, clamp at the band edges. Same behaviour as `wsnav.sh`, no `jq`, no process
spawn per keypress.

`wsnav.sh` remains a working fallback if `window.layout` ever changes shape:
copy it to `config/hypr/scripts/`, and replace the `nav.*` bindings in
`conf/binds.lua` with `hl.dsp.exec_cmd(wsnav .. " focus up|down")` and
`" movecol left|right"`. It needs `jq`, which is already in the package list
for yazi.

---

## Known-uncertain details

Written from documentation, not from a running system. Check these first if
something misbehaves:

| Thing | Uncertainty | Where |
|---|---|---|
| ~~`column.index` / `index_in_column` are 0-based~~ | **Verified 2026-08-18** on a live session, along with the rest of the `window.layout` reading | `lib/nav.lua` |
| Noctalia panel layer namespaces | Taken from Noctalia's own blur layer rule | `lib/bar.lua` |
| `[keybinds]` chord names (`ctrl+k`, `iso_left_tab`) | Format documented, these exact names not confirmed | `00-shell.toml` |
| dmenu `prefix` is a bare word | Docs contradict themselves — the config reference says bare (`"ssh"` → `/ssh`), one example page shows `"/cmd"` | `20-launcher.toml` |
| `control-center` widget id is hyphenated while others are snake_case | Matches upstream doc titles, which are genuinely inconsistent | `10-bar.toml` |
| ~~`hl.get_workspace_windows(<id>)` accepts a numeric id~~ | **Verified 2026-08-18** | `lib/nav.lua` |
| ~~`m~n` selects the n-th workspace of the focused monitor~~ | **Disproven 2026-08-18 on Hyprland 0.56.2.** Not valid syntax; the dispatcher answers `ok` and nothing happens, which is why every number key was dead. `lib/ws.lua` does band arithmetic instead | `lib/ws.lua`, `conf/binds.lua` |
| Noctalia gives a dmenu provider ~2 seconds | **Measured 2026-08-18**: a provider that runs longer is SIGTERMed (exit 143) and the launcher shows "No results found". Undocumented, so it could change — re-measure with a `sleep 3` provider if lists start emptying | `bin/noct-common.sh` |
| Hyprland pauses idle notifications while a client holds a Wayland idle inhibitor | Protocol behaviour, and the layer the windowed-browser-video case rests on. The two window rules are the belt and braces | `conf/rules.lua`, `70-idle.toml` |
| `shelly install standard/aur --no-confirm` is non-interactive enough for a script | It authenticates through **polkit**, so it needs an agent; in a bare TTY it fails and the pacman path takes over. Both paths are exercised by `--dry-run` | `install.sh` |
| `noctalia-greeter-session` is the greetd entry point | From upstream's README; the packaged path is resolved with `command -v` rather than hardcoded | `install.sh` |
| Gesture action `scroll_move` | Documented, untested | `conf/input.lua` |
| Built-in template ids (`qt`, `kcolorscheme`, …) | Taken from CachyOS's shipped config; verify with `noctalia theme --list-templates` | `40-templates.toml` |
| A `post_hook` is run through a shell (so `${VAR:-default}` expands) | Docs say hooks are rendered by the template engine then executed; shell semantics assumed | `40-templates.toml` |
| `hyprctl reload` picks up a newly created `generated/colors.lua` | Hyprland reloads on config change; whether it watches `require`d files is unconfirmed, hence the explicit reload | `40-templates.toml` |
| Every package name resolves on CachyOS | **Verified 2026-08-18**: `--packages` completed and all 52 names are installed from the repos — the AUR fallback was never reached | `install.sh` |
| Noctalia reads custom palettes from `~/.config/noctalia/palettes/<name>.json` | Documented; the exact JSON key set for a palette was taken from the docs example | `palettes/noirblaze.json` |
| yazi's `%s` opener placeholder is still current | Carried over verbatim from your working config rather than modernised | `config/yazi/yazi.toml` |
| Brave policy names (`BraveRewardsDisabled`, `BraveAIChatEnabled`, …) | Brave-specific policies are less stable than Chromium's; `brave://policy` is the check | `browsers/brave/policies.json` |
| Zen reads `user.js` from profiles under `~/.zen` | Zen is a Firefox fork so this should hold, but its profile root is not documented as firmly | `install.sh` |
| ~~Noctalia's `kitty` template writes `current-theme.conf`~~ | **Disproven 2026-08-18 on noctalia v5.0.0-beta.8.** It writes `themes/noctalia.conf` and *rewrites `kitty.conf`* to include it, clobbering the tracked symlink. The built-in is now disabled; a user template renders `generated-colors.conf` instead | `40-templates.toml`, `config/kitty/kitty.conf` |
| Colour roles used by `kitty-colors.conf` (`terminal_*`, `primary`, `outline_variant`) | Verified 2026-08-18: all render to real hex, no leftover placeholders | `templates/kitty-colors.conf` |
| A user template named after a built-in id (`kitty`, `hyprland`) does not collide with it | Verified 2026-08-18: both render while the built-in id is absent from `builtin_ids` | `40-templates.toml` |
| `fisher` exists as a package | If not, install it by its documented one-liner and rerun; the installer warns rather than failing | `install.sh` |
| `colors_changed` fires on a scheme change, not only a wallpaper change | Documented as "after the theme palette is resolved"; if it only fires for wallpapers, call `noct-glass apply` from `noct-theme act` instead | `50-glass.toml` |
| Wallhaven result counts hold over time | Measured 2026-08-15; the 21:9 Dragon Ball supply was 4 and can only grow | `wallpapers.conf` |
| `[plugins].enabled` activates the wallhaven plugin declaratively | Documented, but the plugin system is beta; `noctalia msg plugins enable noctalia/wallhaven` is the fallback | `60-wallpaper.toml` |
| `blur.xray` samples the wallpaper rather than windows behind | Documented behaviour; turn it off in `noct-glass` if windows behind show through oddly | `bin/noct-glass` |
| `uwsm start -S -F hyprland.desktop` is the right invocation | Adapted from your `start-hyprland`; the original is kept as a fallback in the same file | `config/fish/auto-Hypr.fish` |
| `starship`, `eza`, `fastfetch`, `claude-code` resolve as package names | Verified against the CachyOS repos 2026-08-18; all resolve | `install.sh` |

---

## Overlap with `~/dotfiles`

This repo now carries `fish`, `kitty` and `hypr`. Your existing `~/dotfiles`
stow repo provides all three as well, plus things this repo does not cover:
`gtk-3.0`, `gtk-4.0`, `kvantum`, `mpv`, `git`, `fastfetch`, `quickshell`,
`illogical-impulse`.

On the new machine only one of them should own each path. `install.sh` backs up
whatever it finds, including a stow symlink, so running both is recoverable —
but it is not a decision to make by accident.

- [ ] Decide which repo owns `fish`, `kitty` and `hypr` before deploying both.
- [ ] `~/.config/fish` is a directory of symlinks into *one* repo, not a mix.
- [ ] The configs this repo does not carry (`gtk`, `mpv`, `git`, …) still come
      from `~/dotfiles`.
