# fish

**This config is new.** There was no fish configuration on the Ubuntu machine
to carry over — only `shell fish` in `kitty.conf`, which showed the intent
without any settings behind it. So what is here was written from the
preferences you have already stated (vim keys, quiet, keyboard-first) rather
than migrated. Treat it as a starting point.

`install.sh --packages` makes fish your login shell with `chsh`, adding it to
`/etc/shells` first if the package did not. It takes effect at your next login,
not in the shell you ran the installer from.

## nvm does not work in fish

This is the one thing worth knowing before you hit it.

`nvm` is a bash/zsh **shell function**, not a program. `nvm use 20` has to
mutate the environment of the shell it runs in, which is why there is no binary
to put on `PATH` and why no amount of `PATH` fixing makes it work under fish.

The installer handles this by installing
[`jorgebucaran/nvm.fish`](https://github.com/jorgebucaran/nvm.fish) through
fisher — a native reimplementation that keeps the `nvm` command name, so
`nvm use`, `nvm install` and `nvm list` all behave as you expect. The AUR `nvm`
package is still installed too, because bash is still on the system and still
works.

If the fisher step failed (the installer says so), run:

```fish
fisher install jorgebucaran/nvm.fish
```

Node itself also comes from pacman as a system package. That is deliberate
rather than redundant: mason, inside neovim, needs a `node` on `PATH` even when
neovim was launched from the app launcher rather than a shell — where nothing
has sourced a version manager. The system copy is the floor; nvm shadows it in
shells where you have selected a version.

## Layout

| File | Loaded |
|---|---|
| `conf.d/*.fish` | automatically, before `config.fish`, for **every** shell |
| `config.fish` | after `conf.d`, for every shell |

`config.fish` guards its contents with `status is-interactive`, so scripts and
the non-interactive shells that editors spawn stay fast and side-effect free.
Environment that must exist everywhere — `PATH`, `EDITOR` — goes in
`conf.d/environment.fish` instead, outside that guard.
