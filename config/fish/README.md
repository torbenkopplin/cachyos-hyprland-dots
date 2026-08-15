# fish

Carried over from `~/dotfiles/fish/.config/fish/`, which `~/.config/fish`
symlinks to on the Ubuntu machine. Only platform-forced changes were made, and
each is marked `CHANGED` in the file it appears in.

## What changed, and why

| Change | Reason |
|---|---|
| `batcat` → `bat` | Debian renames the binary to avoid a clash with its own `bat` package. Arch has no clash and ships it as `bat`. |
| dropped the quickshell `sequences.txt` line | That was illogical-impulse writing terminal colours. Noctalia does it two other ways — its kitty template for new windows, its OSC template for open ones — and neither needs sourcing. |
| dropped `alias q 'qs -c ii'` | Started quickshell with the illogical-impulse config, which this setup replaces. |
| added `EDITOR` / `VISUAL` | Hyprland exports them, but a bare TTY or SSH session never goes through Hyprland, so `git commit` would fall back to vi there. |
| `auto-Hypr.fish` starts via uwsm | The rest of this repo assumes uwsm. Original command kept as a fallback. |

Your `fish_prompt` function is kept even though `starship init fish` overrides
it a few lines later — it is the fallback you get if starship is ever missing,
and without it you would drop to fish's stock prompt rather than yours.

## What is deliberately not tracked

**`functions/` and `completions/`** — these are fisher-installed plugin files
(`nvm.fish`, `fisher.fish`, `_nvm_*.fish`). `fish_plugins` is the source of
truth and `fisher update` restores them, which is the whole point of a plugin
manager. Versioning the installed copies would mean updating them by hand.

**`fish_variables`** — fish's universal variable store. Generated, machine-local
state, rewritten constantly.

**`conf.d/fish_frozen_key_bindings.fish`** — a fish 4.3 migration shim that
erases a universal variable at every startup. It cleans up state on the machine
that upgraded; it is not configuration and carrying it forward to a fresh
install just re-runs a migration that never applied there.

`conf.d/fish_frozen_theme.fish` **is** kept — despite the generated header, it
holds your actual syntax-highlighting colours (`fish_color_comment red` is not
a default). Editing it by hand is fine; just know `fish_config` will rewrite it
if you use the web theme tool.

## nvm

You already solved this — `fish_plugins` lists `jorgebucaran/nvm.fish`, the
fish-native reimplementation, and `conf.d/nvm.fish` comes from it.

Worth recording why it is needed at all: `nvm` proper is a bash/zsh **shell
function**, not a program. `nvm use 20` has to mutate the environment of the
calling shell, so there is no binary to put on `PATH` and no way to make the
bash version work under fish. That is why the commented-out `NVM_DIR` block in
`config.fish` stays commented out.

The installer runs `fisher update`, which reads `fish_plugins` and reinstalls
both plugins on the new machine.

Node itself also comes from pacman as a system package. That is deliberate
rather than redundant: mason, inside neovim, needs a `node` on `PATH` even when
neovim was launched from the app launcher rather than a shell — where nothing
has sourced a version manager. The system copy is the floor; nvm shadows it in
shells where you have selected a version.

## Overlap with ~/dotfiles

This repo now carries `fish`, `kitty` and `hypr`, all of which your existing
`~/dotfiles` stow repo also provides. On the new machine, only one of them
should own each of those paths. `~/dotfiles` still holds things this repo does
not cover at all — `gtk-3.0`, `gtk-4.0`, `kvantum`, `mpv`, `git`, `fastfetch`,
`quickshell`, `illogical-impulse` — so it is not redundant, just overlapping.
Decide per directory before running both installers.
