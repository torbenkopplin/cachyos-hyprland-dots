#!/usr/bin/env bash
# install.sh -- link this repo into place.
#
# Symlinks are safe for everything here:
#
#   ~/.config/hypr/*      Hyprland only ever reads its config.
#   ~/.config/noctalia/*  Noctalia only ever reads ~/.config/noctalia. It saves
#                         GUI changes to ~/.local/state/noctalia/settings.toml,
#                         a different tree entirely -- so the app can never
#                         clobber a tracked file or replace a link.
#   ~/.local/bin/noct-*   plain scripts.
#
# Individual files are linked rather than whole directories, so either program
# can still create its own files alongside yours without fighting the repo.
#
#   ./install.sh            link everything, backing up whatever is in the way
#   ./install.sh --dry-run  show what would happen
#   ./install.sh --unlink   remove only the links this script created

set -euo pipefail

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
BIN_HOME=$HOME/.local/bin
STAMP=$(date +%Y%m%d-%H%M%S)

DRY_RUN=0
UNLINK=0
for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=1 ;;
        --unlink)  UNLINK=1 ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "unknown option: $arg" >&2; exit 2 ;;
    esac
done

say()  { printf '  %s\n' "$*"; }
run()  { if (( DRY_RUN )); then say "would: $*"; else "$@"; fi; }

# link <source> <destination>
link() {
    local src=$1 dst=$2 dir
    dir=$(dirname "$dst")

    if (( UNLINK )); then
        if [[ -L $dst && $(readlink -f "$dst") == "$src" ]]; then
            say "unlink $dst"
            run rm -f "$dst"
        fi
        return
    fi

    run mkdir -p "$dir"

    # Already correct? Say nothing and move on, so reruns are quiet.
    if [[ -L $dst && $(readlink -f "$dst") == "$src" ]]; then
        return
    fi

    # Anything else in the way gets moved aside, never deleted.
    if [[ -e $dst || -L $dst ]]; then
        say "backup $dst -> $dst.bak-$STAMP"
        run mv "$dst" "$dst.bak-$STAMP"
    fi

    say "link   $dst"
    run ln -s "$src" "$dst"
}

# Link every file under a repo subtree into a destination root, preserving the
# relative layout.
link_tree() {
    local src_root=$1 dst_root=$2 rel
    while IFS= read -r -d '' file; do
        rel=${file#"$src_root"/}
        link "$file" "$dst_root/$rel"
    done < <(find "$src_root" -type f -print0 | sort -z)
}

echo "hyprland + noctalia dotfiles"
(( DRY_RUN )) && echo "(dry run -- nothing will be changed)"
echo

echo "config:"
link_tree "$REPO/config/hypr"     "$CONFIG_HOME/hypr"
link_tree "$REPO/config/noctalia" "$CONFIG_HOME/noctalia"

echo
echo "scripts:"
for script in "$REPO"/bin/*; do
    [[ -f $script ]] || continue
    (( UNLINK )) || run chmod +x "$script"
    link "$script" "$BIN_HOME/$(basename "$script")"
done

if (( UNLINK )); then
    echo
    echo "Unlinked. Backups named *.bak-* were left alone."
    exit 0
fi

echo
if [[ ":$PATH:" != *":$BIN_HOME:"* ]]; then
    echo "NOTE: $BIN_HOME is not on your PATH."
    echo "      The launcher's /net, /bt, /aout, /ain and /power providers run"
    echo "      through 'sh -lc' and will not find their scripts until it is."
    echo
fi

cat <<'EOF'
Next:
  1. Check the prerequisites in README.md are installed.
  2. Log into the Hyprland session.
  3. Work through TESTING.md -- it is the checklist for everything in here
     that could not be verified without a live session.
EOF
