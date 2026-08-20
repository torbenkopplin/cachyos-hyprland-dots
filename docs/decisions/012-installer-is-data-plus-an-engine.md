# 012 — The installer is a manifest plus an engine, and it has a `--root`

**Settled 2026-08-20.** Status: in force.

`install.sh` is 201 lines of flags and dispatch order. What gets deployed is
`install/manifest/*.tsv`; the code that reads it is `install/lib/*.sh`.

## What it replaced

One file of 1298 lines doing eleven jobs — link, unlink, status, update, reapply,
packages, npm, fish, units, nvim, browsers, wallpapers, login — with the package
list, the link list and the unit list as bash array literals in the middle of it.

The lists are data. Adding a config file to the deployment is now a line in
`links.tsv`; adding a package is a line in `packages.tsv`. Neither needs the
engine touched, and the reason each row exists is a comment above it — which is
the only way to know later whether a name can be deleted.

## `--root`, which is the point of the exercise

Four roots, redirected together: `~/.config`, `~/.local/bin`, `~`, and `/etc`.

```sh
./install.sh --root /tmp/fake --all --login
```

lands a complete deployment in a throwaway directory with no sudo and no
environment variables. Steps that change the *machine* rather than a path — the
package manager, systemd units, the login shell, the git clone, the wallpaper
download, the display-manager switch — say so and skip.

That buys two things:

1. **The installer is testable.** `tests/install-fakeroot.sh` runs it for real
   and asserts thirteen things, on a machine with no Hyprland and no pacman —
   which means CI runs it. Most importantly it asserts **no dangling symlinks**:
   a manifest row pointing at a renamed file installs a link to nothing, and a
   dangling `hyprland.lua` is a session that does not start with nothing on
   screen to say why.
2. **The accident of 2026-08-19 becomes structurally impossible.** `CONFIG_HOME`
   came from `XDG_CONFIG_HOME` and `BIN_HOME` from `HOME`, so a test run against
   a throwaway `HOME` relinked a live desktop's entire `~/.config` to a checkout
   under `/tmp` — which was then deleted. 42 dangling symlinks, no
   `hyprland.lua`, and a session that could not start. Nothing was lost (every
   displaced link was sitting there as `*.bak-<stamp>`) and finding the cause
   took far longer than the repair.

   The refusal added that day is still there — it fires when `HOME` has been
   overridden and `XDG_CONFIG_HOME` has not — but a refusal only catches the case
   somebody thought of. `--root` removes the need to get two variables right.

## `--check`

Verifies every name in `packages.tsv` against the repos, the AUR RPC and the npm
registry, and installs nothing. The install path is deliberately permissive about
a name that resolves nowhere — it is reported in the summary rather than aborting
a fresh machine halfway through — and the cost of that was a typo staying
invisible until somebody read a summary carefully. Run it after editing the file.

## Two things that did not change

- **`--update` still pulls, then re-execs itself.** bash reads a script from disk
  as it executes it, so a pull that rewrites `install.sh` under a running
  `install.sh` can resume at a byte offset that now means something else. The
  split widens that rather than narrowing it: the libraries are sourced at
  startup, so a pull can now also rewrite a file this process has already read.
- **`--update` refuses to pull over local changes.** Every config here is a
  symlink into the checkout, so uncommitted changes *are* the desktop you are
  running. Stashing them would change it out from under you; merging is a
  decision only you can make. It prints exactly what is in the way.

See also [001](001-links-not-copies.md), [015](015-pacman-first.md).
