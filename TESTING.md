# Post-install checklist

Everything in this repo was written against the Hyprland 0.55 Lua API source,
the scrolling-layout docs and the Noctalia v5 IPC/config reference — but none of
it has run on a live session yet. This is the list of things to confirm on the
CachyOS partition, roughly in dependency order. Tick as you go.

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
- [ ] Opening one window fills the screen; opening a second gives you two
      half-width columns.
- [ ] Opening several windows scrolls the tape rightwards.

## 2. Navigation — `lib/nav.lua`

This is the part most likely to need adjusting, since it depends on the exact
shape of `window.layout`.

- [ ] `SUPER+H`/`L` moves between columns.
- [ ] `SUPER+J`/`K` moves between windows **within a column** (stack two windows
      in one column with `SUPER+,` first).
- [ ] At the **last column**, `SUPER+L` moves focus to the next monitor.
- [ ] At the **first column**, `SUPER+H` moves to the previous monitor.
- [ ] At the **bottom of a column**, `SUPER+J` goes to the next workspace.
- [ ] At the **top of a column**, `SUPER+K` goes to the previous workspace.
- [ ] On an **empty** workspace, `SUPER+J`/`K` still change workspace.
- [ ] Nothing **wraps** — at the last workspace `SUPER+J` does nothing, it does
      not jump back to the first.
- [ ] `SUPER+CTRL+<hjkl>` does all of the above dragging the window along.
- [ ] With a **floating** window focused, `SUPER+hjkl` still behaves sanely.

> If edge detection misfires, dump what the layout actually reports:
> ```sh
> hyprctl eval 'local w = hl.get_active_window()
>   local l = w.layout
>   return string.format("col=%s row=%s in_col=%s",
>     tostring(l.column.index), tostring(l.index_in_column), tostring(#l.column.windows))'
> ```
> The assumption in `lib/nav.lua` is that both indices are **0-based**.

## 3. Tap SUPER — `lib/supertap.lua`

The failure mode to watch for is the launcher opening after ordinary chords.

- [ ] Tapping and releasing `SUPER` alone opens the launcher.
- [ ] `SUPER+J`, then releasing `SUPER`, does **not** open the launcher.
- [ ] `SUPER+Return`, then releasing, does **not** open the launcher.
- [ ] Holding `SUPER` for a second and releasing does **not** open it.
- [ ] `SUPER+Space` opens the launcher as a fallback.

> If it never fires, the keycodes may differ — check yours with `wev` and
> compare against `SUPER_L = 133` / `SUPER_R = 134` in `lib/supertap.lua`.
> If it fires too eagerly, lower `SUPER_TAP_MS` in `conf/options.lua`.
> To disable entirely: `SUPER_TAP_ENABLED = false`.

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

## 5. Workspaces — `conf/workspaces.lua`

- [ ] `hyprctl workspaces` shows 5 persistent workspaces **per monitor**.
- [ ] The leftmost monitor owns 1–5, the next 6–10, and so on.
- [ ] `SUPER+2` goes to the second workspace **on the monitor you are looking
      at**, whichever that is.
- [ ] Hotplugging a monitor gives it its own stack.

## 6. Launcher providers — `bin/noct-*` + `20-launcher.toml`

First, straight from a terminal — this is where parsing bugs show up plainly:

- [ ] `noct-audio list sinks` prints `title <TAB> base64` lines.
- [ ] `noct-audio list sources` does too, with no `.monitor` entries.
- [ ] `noct-bluetooth list`
- [ ] `noct-network list`
- [ ] `noct-power list`

Then through the launcher:

- [ ] `/aout` lists outputs, the current one marked `●`.
- [ ] Picking one switches the default **and moves audio that is already
      playing** — test with music running.
- [ ] `/ain` switches the microphone.
- [ ] `/bt` lists paired devices; connect and disconnect both work; "Scan for
      devices" finds something new and reopens the list.
- [ ] `/net` lists the active connection first, then saved profiles, then Wi-Fi
      in range.
- [ ] Connecting to a **new, secured** Wi-Fi network opens a kitty window with
      `nmcli --ask` and the passphrase is not echoed.
- [ ] `/power` switches profile and toggles night light.
- [ ] `SUPER+CTRL+O/I/B/N/P` each open the launcher already filtered.

> If a provider shows nothing at all, the launcher swallowed a shell error.
> Run its `command` by hand first. If it says "not installed", see the
> prerequisites in README.md.

## 7. Launcher keys — `00-shell.toml`

- [ ] `Ctrl+J` / `Ctrl+K` move the selection in the launcher.
- [ ] Arrow keys still work.
- [ ] `Esc` closes.
- [ ] Noctalia did not report a config parse error for `[keybinds]` — if it did,
      one of the chord names is wrong; remove it and check
      `noctalia msg config-reload`.

## 8. Theming — `30-theme.toml` + `40-templates.toml`

- [ ] `noctalia theme --list-templates` lists the built-in ids used in
      `40-templates.toml`: `kitty`, `gtk3`, `gtk4`, `qt`, `kcolorscheme`,
      `btop`. Drop any that do not exist — the ids were taken from CachyOS's
      shipped config, not confirmed against a running binary.
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

## 9. Focus discipline

The point of the whole setup — worth testing deliberately:

- [ ] A background app finishing a task does **not** steal focus or scroll the
      tape away from what you are reading.
- [ ] A fullscreen video keeps the screen awake; an ordinary window does not.
- [ ] Moving the mouse does not change which monitor is active.

---

## Known-uncertain details

Written from documentation, not from a running system. Check these first if
something misbehaves:

| Thing | Uncertainty | Where |
|---|---|---|
| `column.index` / `index_in_column` are 0-based | Read from the C++ source (`LuaWindow.cpp`), not observed | `lib/nav.lua` |
| Noctalia panel layer namespaces | Taken from Noctalia's own blur layer rule | `lib/bar.lua` |
| `[keybinds]` chord names (`ctrl+k`, `iso_left_tab`) | Format documented, these exact names not confirmed | `00-shell.toml` |
| dmenu `prefix` is a bare word | Docs contradict themselves — the config reference says bare (`"ssh"` → `/ssh`), one example page shows `"/cmd"` | `20-launcher.toml` |
| `control-center` widget id is hyphenated while others are snake_case | Matches upstream doc titles, which are genuinely inconsistent | `10-bar.toml` |
| `hl.get_workspace_windows(<id>)` accepts a numeric id | Documented as taking a workspace selector | `lib/nav.lua` |
| Gesture action `scroll_move` | Documented, untested | `conf/input.lua` |
| Built-in template ids (`kitty`, `qt`, `kcolorscheme`, …) | Taken from CachyOS's shipped config; verify with `noctalia theme --list-templates` | `40-templates.toml` |
| A `post_hook` is run through a shell (so `${VAR:-default}` expands) | Docs say hooks are rendered by the template engine then executed; shell semantics assumed | `40-templates.toml` |
| `hyprctl reload` picks up a newly created `generated/colors.lua` | Hyprland reloads on config change; whether it watches `require`d files is unconfirmed, hence the explicit reload | `40-templates.toml` |
