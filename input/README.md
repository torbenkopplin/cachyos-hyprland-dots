# input/

Input remapping that has to happen **below** the compositor, and therefore
outside `~/.config`.

| File | Goes to | Why it is not a link |
|---|---|---|
| `keyd/mx-keys.conf` | `/etc/keyd/mx-keys.conf` | `keyd` starts before anyone logs in and reads `/etc/keyd` as root. A symlink into a home directory is not a thing to put there — the home may not be mounted yet, and `keyd` only loads `*.conf`. |

`install.sh --input` writes these with `install -Dm644` as root, the same way
`--browsers` writes a managed browser policy. `install/manifest/input.tsv` is
the list; `install/lib/input.sh` is the twenty lines that read it.

What is remapped, and why it cannot be fixed in `conf/binds.lua`, is in
[decision 020](../docs/decisions/020-the-print-key-is-remapped-below-hyprland.md).
