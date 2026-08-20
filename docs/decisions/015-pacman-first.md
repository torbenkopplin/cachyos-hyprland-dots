# 015 — pacman first, shelly preferred, the AUR as a fallback

**Settled 2026-08-18.** Status: in force.

Every name in the `repo` phase of `packages.tsv` is attempted with pacman
**regardless of where it usually lives**, and only what pacman cannot resolve
falls through to an AUR helper.

## Why

CachyOS rebuilds its repos with architecture-specific optimisations
(x86-64-v3/v4, LTO, BOLT), so a package that exists in the repos is meaningfully
better than the same package built locally from the AUR. That includes names that
are "AUR-only" elsewhere — `noctalia`, `satty`, `claude-code` are all tried at
pacman first, and on this machine all 59 resolved from the repos and the AUR
fallback was never reached.

## Frontend order, and why shelly is first

`shelly` is CachyOS's own manager, and it installs repository packages **and** AUR
packages through one tool — so a fresh CachyOS machine needs no separate AUR
helper for the installer to finish. It authenticates through polkit rather than
sudo, which means a graphical password prompt in a session and nothing at all in a
bare TTY, where it simply fails and the pacman path picks the list up.

pacman + paru/yay stays as the fallback, unchanged, so this still works on plain
Arch.

## Three details that are load-bearing

- **`pacman -T`, not `-Q`,** for "is it installed". `-T` resolves *provides*, so a
  package installed under a different name than the one asked for — very common
  with `-bin` and `-git` variants — is not reinstalled on every run. That is what
  makes every frontend idempotent, including the ones with no `--needed`.
- **Batch first, then one at a time.** The whole list goes in one transaction,
  which is fast and resolves dependencies together; if that fails it retries
  individually so a single unknown name cannot block the other twenty.
- **A name that resolves nowhere is reported, not fatal.** Aborting a fresh
  machine halfway through is worse than finishing and listing what is missing.
  `./install.sh --check` is the pass that catches such a name *before* a fresh
  machine does ([012](012-installer-is-data-plus-an-engine.md)).

## Two packages deliberately absent

- **`rustup`**, though `conf.d/rustup.fish` is named after it. It declares
  `Conflicts With: rust cargo`, and pacman runs with `--noconfirm`, which *answers*
  the "remove them?" prompt rather than aborting — so on any machine that already
  has the repo toolchain this would swap a working rust/cargo for a rustup that
  ships no toolchain at all until `rustup default stable` is run by hand. Nothing
  here needs it; `conf.d/rustup.fish` works either way.
- **`hypridle`** — see [006](006-idle-has-one-owner.md).

And one that is conditional: the Bibata cursor has its own phase, because the AUR
variants all ship `/usr/share/icons/Bibata-*` and pacman aborts an entire
transaction on a file conflict. Asking for one on a machine that already has
another would take the rest of the package step down with it.
