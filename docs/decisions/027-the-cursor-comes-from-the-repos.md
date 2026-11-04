# 027 — The cursor comes from the repos: Vimix, not Bibata

**Settled 2026-11-04** on Hyprland 0.57.1. Status: in force.
Retires the conditional cursor phase described at the end of
[015](015-pacman-first.md); the rest of 015 is unchanged.

`CURSOR_THEME` is `Vimix-cursors`, and `vimix-cursors` is an ordinary `repo`
row in `packages.tsv`. There is no `cursor` phase any more.

## What settled it

Bibata had two costs, and neither was the theme's fault.

- **It was the installer's only AUR-only package.** Every other name in the
  manifest resolves from the repos on CachyOS, so Bibata was the one reason a
  fresh machine needed the AUR at all.
- **It needed its own phase.** The AUR variants (`bibata-cursor-theme`, `-bin`,
  `-git`, and end-4's illogical-impulse build) all ship
  `/usr/share/icons/Bibata-*`, and pacman aborts a whole transaction on a file
  conflict. So the cursor ran behind a predicate, separately from everything
  else, to keep a conflict from taking the rest of the package step down.

Removing end-4's packages on 2026-11-04 took the Bibata build with them and
put the question back on the table. `vimix-cursors` is in `extra`, ships
`Vimix-cursors` and `Vimix-white-cursors`, and conflicts with nothing.

## Also fixed on the way

GTK apps take the cursor theme from gsettings, not from `XCURSOR_THEME`, and
nothing here ever set it — this machine's still said `Bibata-Modern-Classic`
from end-4. `conf/autostart.lua` now sets `cursor-theme` and `cursor-size`
next to `hyprctl setcursor`, from the same two options.

## Settled against

| Not doing | Because |
|---|---|
| Keeping Bibata, AUR and all | The only AUR dependency of the install, plus a phase and a predicate that exist for one package |
| Other repo themes (Capitaine, Breeze, Dracula, Comix, Vanilla DMZ) | Taste. Any of them is a one-line change to `CURSOR_THEME` plus its row in `packages.tsv` |
