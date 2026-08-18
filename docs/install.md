# Installing, and living with two setups

## From a GitHub link

Like end-4's, one command on a fresh system — it installs git if needed,
clones, and hands over to `install.sh`:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/torbenkopplin/cachyos-hyprland-dots/master/bootstrap.sh) --all
```

Arguments pass straight through, so look first:

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/torbenkopplin/cachyos-hyprland-dots/master/bootstrap.sh) --all --dry-run
```

Two environment variables if the defaults do not suit:

```sh
DOTS_DEST=~/src/dots DOTS_BRANCH=testing bash <(curl -fsSL .../bootstrap.sh)
```

`bootstrap.sh` clones over HTTPS so it works before any SSH key exists, then
switches the remote to SSH so you can push. It refuses to run as root — a
dotfiles install writes throughout `$HOME`, and doing that as root leaves you
with a root-owned `~/.config` you cannot edit.

Worth knowing about this pattern generally: `curl | bash` runs whatever is at
that URL at the moment you run it, before you have seen it. For your own repo
on your own machine that is a reasonable trade. If you ever hand the link to
someone else, point them at a tag rather than `master` so the thing they run is
the thing you tested.

## From a clone

```sh
git clone git@github.com:torbenkopplin/cachyos-hyprland-dots.git ~/repos/cachyos-hyprland-dots
cd ~/repos/cachyos-hyprland-dots
./install.sh --all --dry-run   # look first, always
./install.sh --all
```

| Flag | Does |
|---|---|
| *(none)* | Link configs into `~/.config` and scripts into `~/.local/bin` |
| `--packages` | Install everything below via pacman, an AUR helper, and npm |
| `--nvim` | Clone `torbenkopplin/nvimrc` to `~/.config/nvim` |
| `--browsers` | Install browser policies and `user.js` (needs sudo) |
| `--wallpapers` | Download wallpapers into `~/Pictures/Wallpapers` (a few hundred MB) |
| `--all` | All of the above, in dependency order — wallpapers included, last |
| `--login` | Replace the display manager with greetd + `noctalia-greeter` (needs sudo). **Not** in `--all` |
| `--dry-run` | Print what any of the above would do |
| `--status` | Show which setup currently owns each managed path |
| `--unlink` | Remove this script's links and restore whatever they replaced |

## The login screen

A CachyOS install boots into **plasmalogin** — SDDM under Plasma 6.5's name —
which is a Qt/Plasma login screen in front of a session with nothing else
Plasma in it: different fonts, different accent, different cursor, and the
Hyprland entry one of three in a list.

`./install.sh --login` swaps it for **greetd + `noctalia-greeter`**, which is
the same shell you are logging into. The greeter brings its own small wlroots
compositor, so it runs before Hyprland exists, and it can take the palette and
wallpaper from Noctalia: **`SUPER+,` → Security → Noctalia Greeter → Sync Now**.

It is the one step that changes what happens at boot, which is why it is not in
`--all`, why it only ever runs `systemctl enable` (never `--now`, which would
kill the session you are sitting in), and why it prints its own undo:

```sh
sudo systemctl disable greetd && sudo systemctl enable plasmalogin
```

If the greeter ever fails to come up, that is the line to run — `ctrl+alt+F2`
gets you a TTY to run it from. The previous `/etc/greetd/config.toml`, if there
was one, is kept as `config.toml.bak-<timestamp>`.

Run `--browsers` again after launching Firefox and Zen once — their profile
directories have generated names and do not exist until first launch, so
`user.js` cannot be placed before then. The script tells you when this applies.

Files are symlinked, so edits in the repo are live immediately and `git diff`
shows your real config. Anything already in the way is moved to
`*.bak-<timestamp>` rather than deleted, and `--unlink` moves it back.

## Switching with `~/repos/dots`

`~/repos/dots` is the older, copy-based setup (it *copies* files into `$HOME`;
this repo symlinks them). Both manage eight of the same paths:

```
~/.config/hypr/hyprland.lua                    ~/.config/fish/config.fish
~/.config/kitty/kitty.conf                     ~/.config/fish/auto-Hypr.fish
~/.config/kitty/scroll_mark.py                 ~/.config/fish/conf.d/fish_frozen_theme.fish
~/.config/kitty/search.py                      ~/.config/starship.toml
```

Switching is one command in each direction, and a round trip is byte-exact:

```sh
./install.sh            # take the shared paths over (the dots copies are backed up)
./install.sh --status    # see who owns what right now
./install.sh --unlink    # hand them back (the dots copies are restored)
```

`--unlink` is a full reverse, so nothing needs to be re-run in `~/repos/dots`
afterwards and no `*.bak-*` residue accumulates across switches.

Two things that are deliberately *not* switched:

- **`~/.config/hypr/host.lua`** — both configs read it the same way
  (`hl.monitor`, `hl.env`, and a `WSBANDS` table), so the machine's monitor
  layout is shared rather than duplicated. This repo's `host.lua.example`
  documents the same schema `dots/hosts/<host>/` already ships.
- **Files only `dots` manages** — `hypridle.conf`, `hyprlock.conf`,
  `hypr/scripts/`, and the extra `fish/conf.d` entries stay in place. They keep
  working when you switch back. One caveat in this direction: `install.sh`
  disables the `hypridle` **user unit**, because idle is Noctalia's job here
  (see [Idle has exactly one owner](design.md#idle-has-exactly-one-owner)) and
  two idle daemons fight over the same lock screen. Switching back to `dots` means
  `systemctl --user enable --now hypridle` — its config was never touched.

While this setup is deployed, `dots/update.sh` will *not* re-import the shared
paths — it skips symlinked targets and says so. Without that it would copy this
repo's configs into the dots tree and commit them.

Symlinking is safe for both programs: Hyprland only ever reads its config, and
Noctalia only ever reads `~/.config/noctalia` — it writes GUI changes to
`~/.local/state/noctalia/settings.toml`, a different tree. That state file
loads *after* your config, so **a setting changed in the Noctalia GUI silently
wins over the same setting in these files.** If something here appears to be
ignored, look there first.

## What `--packages` installs

| Group | Why |
|---|---|
| hyprland, portals, kitty, qt6ct, hyprpicker, hyprlock | the session itself |
| ttf-jetbrains-mono-nerd, adwaita-fonts, noto-fonts(-emoji) | kitty's font; Adwaita Sans for the shell UI; everything else |
| signal-desktop, aerc | the two applications this setup assumes: messenger, and a keyboard-driven mail client |
| uwsm | `options.lua` sets `LAUNCH_PREFIX = "uwsm app -- "`, so **every** app bind goes through it. Clear `LAUNCH_PREFIX` if you do not boot Hyprland via uwsm |
| nautilus | `options.lua` `FILE_MANAGER` |
| polkit **and** hyprpolkitagent | `polkit` is only the library — the agent is what shows the password prompt |
| libnotify | `notify-send`, which every `bin/noct-*` script uses to report what it did |
| noctalia, satty | the shell and its screenshot editor |
| libpulse, networkmanager, bluez, power-profiles-daemon | the backends `/aout` `/ain` `/bt` `/net` `/power` shell out to — without these those providers just say "not installed" |
| neovim, git, base-devel, nodejs, npm | editor, and what mason needs to build its servers |
| fish, fisher, fastfetch | the login shell and its plugin manager |
| starship, eza | what your fish config calls: the prompt, and `ls`/`lt` |
| claude-code | tried as a package, npm as fallback |
| ripgrep, fd, fzf, bat | what the neovim config calls out to (fzf-lua and its previewer) |
| yazi, ffmpeg, 7zip, jq, poppler, imagemagick, chafa | file manager and its preview pipeline |
| brave-bin, zen-browser-bin, chromium, firefox | browsers |
| bibata-cursor-theme-bin (AUR) | the cursor named by `CURSOR_THEME` in `conf/options.lua`. The only entry with no repo build; if it fails you keep the default pointer and nothing else changes |
| eslint, mermaid-cli (npm, into `~/.local`) | used directly by the neovim config |

**`hypridle` is not installed, on purpose** — see [Idle has exactly one
owner](design.md#idle-has-exactly-one-owner). Noctalia's idle service does that
job and this repo configures it; a second daemon means a second countdown to
the same lock screen. `hyprlock` stays, as a lock you can call by hand.

**Mail is `aerc`, with no account config tracked.** The brief was keyboard
driven, vim-style, TUI, and able to attach files: aerc is modal, takes
`:commands`, has `:attach`, and composes in `$EDITOR` (nvim, per `conf/env.lua`).
neomutt is the more configurable alternative and needs a `.muttrc` before it
does anything; aerc has a first-run wizard. What is *not* here is
`accounts.conf` — it holds your address, your server names and a password
command, which is either a secret in git or a keyring reference that only works
on one machine. Run `aerc` once and answer the wizard.

**`rustup` is not installed, on purpose.** It declares `Conflicts With: rust
cargo`, and because pacman runs with `--noconfirm` it would answer the "remove
them?" prompt instead of stopping — swapping a working repo toolchain for a
rustup that carries no toolchain until `rustup default stable` is run by hand.
Cargo from the repos is already on `PATH` at `/usr/bin/cargo`, and CachyOS builds
it with the same architecture optimisations that are the reason this installer
prefers repo packages in the first place. `conf.d/rustup.fish` keeps its name but
works with either toolchain: it sources `~/.cargo/env.fish` only if rustup
created it, and adds `~/.cargo/bin` to `PATH` either way so `cargo install`
binaries stay reachable. Install rustup yourself if you want per-project
toolchain pinning.

**LSP servers are not installed.** Your neovim config already installs `tsgo`,
`eslint`, `vimls`, `lua_ls` and `lemminx` through mason on first launch, and a
second copy on `PATH` would only cause confusion. That is also why `nodejs` is
in the list — mason needs it.

**nvm comes from `fish_plugins`, not from a package.** `nvm` proper is a bash
shell function — `nvm use` mutates the calling shell, so there is no binary to
put on `PATH` and it cannot work under fish. Your config already uses
`jorgebucaran/nvm.fish`, the native reimplementation; the installer runs
`fisher update` to restore it. System `nodejs` is installed alongside it
because mason needs a `node` on `PATH` when neovim is launched from the app
launcher, where nothing has sourced a version manager.

Every name above was checked against the enabled CachyOS repos on 2026-08-18 and
all of them resolve there — including `brave-bin`, `zen-browser-bin`, `noctalia`,
`satty` and `claude-code`, so the AUR pass is currently never reached. The
installer still cannot verify names at runtime, so a failed batch retries
package-by-package and anything unresolved is listed in a warning summary at the
end. **Read that summary** rather than assuming a clean run.

`noctalia` here is the 5.x native shell, which is what the numbered TOML
fragments and `~/.local/state/noctalia/settings.toml` in this repo target — not
`noctalia-shell` 4.x, the older Quickshell-based generation that is also in the
repos. Installing both would be a mistake.

`~/.local/bin` must be on `PATH` — the launcher runs provider commands through
`sh -lc`.

Requires **Hyprland ≥ 0.55** for the Lua config and the built-in scrolling
layout. On 0.54 and earlier none of this loads. Neovim must be recent enough
for `vim.pack` (0.12+), which your config uses.

---

## Layout of the repo

```
config/hypr/
  hyprland.lua        requires everything below, in order
  host.lua.example    per-machine template: monitors, WSBANDS, GPU env
                      (copy to ~/.config/hypr/host.lua; never tracked)
  conf/
    options.lua       ← start here: apps, modifiers, workspace count, toggles
    env.lua           session environment
    look.lua          colours, gaps, animations
    input.lua         keyboard, touchpad, focus behaviour, gestures
    layout.lua        the scrolling layout
    rules.lua         window + layer rules
    workspaces.lua    per-monitor workspace bands, built from WSBANDS
    autostart.lua
    binds.lua         every keybind
  lib/
    nav.lua           niri/PaperWM directional focus and window movement
    ws.lua            per-monitor workspace bands: which id a number key means
    supertap.lua      tap-SUPER launcher
    bar.lua           bar visibility driven by panel layer events
config/noctalia/
  00-shell.toml       shell behaviour, launcher, vim keys in shell surfaces
  10-bar.toml         the bar
  20-launcher.toml    the /aout /ain /bt /net /power providers
  30-theme.toml       palette source (wallpaper-derived by default)
  40-templates.toml   which apps the palette is rendered into
  50-glass.toml       the colors_changed hook that runs noct-glass
  60-wallpaper.toml   per-monitor wallpaper folders
  70-idle.toml        lock / screen-off / suspend timeouts (the only idle owner)
  glass.conf          frosted-glass levels, per scheme (read by noct-glass)
  wallpapers.conf     the Wallhaven sets noct-wallfetch pulls
  palettes/
    noirblaze.json        your neovim colourscheme, as a desktop palette
  templates/
    hyprland-colors.lua   window borders -> hypr/generated/colors.lua
    kitty-colors.conf     new kitty windows -> kitty/generated-colors.conf
    terminal-colors.sh    OSC repaint of already-open terminals
config/kitty/
  kitty.conf          carried over; theme + glass come from generated includes
  search.py           third-party kitten (GPLv3), scroll_mark.py
  README.md           what is not tracked here, and why
config/fish/
  config.fish         carried over from ~/dotfiles, CHANGED lines marked
  auto-Hypr.fish      tty1 autostart, adapted for uwsm
  fish_plugins        fisher restores the plugins from this
  conf.d/             frozen theme colours, rustup env
  README.md           what changed, what is not tracked, and why
config/starship/
  starship.toml       carried over
config/yazi/
  yazi.toml           carried over from the Ubuntu setup
browsers/
  README.md           what is versioned here, and what deliberately is not
  brave|chromium|firefox/policies.json
  firefox|zen/user.js
bin/
  noct-common.sh      shared helpers: the title -> payload map, sanitising
  noct-audio          PipeWire sink/source switching
  noct-bluetooth      bluetoothctl
  noct-network        NetworkManager
  noct-power          power profiles, night light, caffeine
  noct-theme          colour scheme picker
  noct-glass          frosted glass level, per scheme
  noct-wallfetch      fills the wallpaper folders from Wallhaven
bootstrap.sh          curl-able one-command installer
install.sh
docs/                 keymap.md, design.md, theming.md, install.md (this file)
TESTING.md            post-install checklist — start here on first boot
```

To change almost anything, start in `config/hypr/conf/options.lua`.

### Editor support

Hyprland ships Lua stubs at `/usr/share/hypr/stubs`; `config/hypr/.luarc.json`
already points lua-ls at them, so `hl.*` autocompletes and typos get flagged.
Until Hyprland is installed, expect `undefined global hl` warnings.
