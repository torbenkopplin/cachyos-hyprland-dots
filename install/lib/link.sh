# link.sh -- deploying, undeploying, and reporting on the links.
#
# Driven entirely by install/manifest/links.tsv. The three modes share one
# function on purpose: --status and --unlink have to visit exactly the paths a
# plain run would create, and the only way to guarantee that is for all three
# to walk the same list.

# --status buckets: which setup owns each managed path right now.
STAT_LINKED=() STAT_FOREIGN=() STAT_ABSENT=()

# same_target <path> <source> -- is <path> already our symlink to <source>?
#
# Both sides are fully resolved before they are compared, and that is the whole
# point: the repo can be reached by more than one spelling. Here ~/repos is
# itself a symlink to /mnt/data/repos, so install.sh run from the first spelling
# sets REPO to ~/repos/... while `readlink -f` on the link it created answers
# /mnt/data/repos/... -- and comparing a resolved destination against an
# unresolved $src made every one of our own links look like somebody else's.
#
# Every run then "backed up" the previous run's perfectly good symlink and
# relinked it. Two runs on 2026-09-11 left 106 stale *.bak-* files that way, and
# one of them -- a dangling link in ~/.config/noctalia/palettes/ -- was enough to
# empty Noctalia's custom-palette picker while the palette itself still applied.
# It also quietly broke --unlink: restore_backup() takes the NEWEST backup, which
# by then was a link into this repo rather than the original file it was meant to
# put back.
#
# Resolve both sides or neither.
same_target() {
    [[ -L $1 ]] || return 1
    [[ $(readlink -f "$1") == "$(readlink -f "$2")" ]]
}

# ours <path> -- a symlink pointing somewhere inside this repo.
#
# `readlink -m` rather than -f: a link left behind by a file that has since MOVED
# within the repo is dangling, and that is exactly a case worth recognising --
# the palette moved from config/noctalia/palettes/ to vendor/ and left one.
ours() {
    [[ -L $1 ]] || return 1
    [[ $(readlink -m "$1") == "$(readlink -m "$REPO")"/* ]]
}

# restore_backup <path> -- move the most recent <path>.bak-* back into place.
#
# This is what makes --unlink a real reverse of the install rather than just a
# delink: whatever was at the path before (typically the older copy-based
# deployment) is put back, so switching between the two setups is one command in
# each direction and leaves no residue to accumulate.
restore_backup() {
    local dst=$1 dir base bak
    dir=$(dirname "$dst"); base=$(basename "$dst")

    local -a baks=()
    while IFS= read -r -d '' bak; do baks+=("$bak"); done \
        < <(find "$dir" -maxdepth 1 -name "$base.bak-*" -print0 2>/dev/null | sort -z)
    (( ${#baks[@]} )) || return 0

    # Stamps are fixed-width, so lexical order is chronological.
    bak=${baks[-1]}

    # In a dry run the link was never actually removed, so the destination still
    # being occupied says nothing.
    if (( ! DRY_RUN )) && [[ -e $dst || -L $dst ]]; then
        warn "not restoring ${bak##*/} -- something is already at $(disp "$dst")"
        return 0
    fi

    say "restore $(disp "$dst")  (from ${bak##*/})"
    run mv "$bak" "$dst"
    (( ${#baks[@]} > 1 )) && note "$(( ${#baks[@]} - 1 )) older backup(s) of this file left alone"
    return 0
}

link() {
    local src=$1 dst=$2 dir
    dir=$(dirname "$dst")

    if (( STATUS )); then
        if same_target "$dst" "$src"; then
            STAT_LINKED+=("$dst")
        elif [[ -e $dst || -L $dst ]]; then
            STAT_FOREIGN+=("$dst")
        else
            STAT_ABSENT+=("$dst")
        fi
        return 0
    fi

    if (( UNLINK )); then
        if same_target "$dst" "$src"; then
            say "unlink $(disp "$dst")"
            run rm -f "$dst"
        fi
        # Attempted even when there was no link of ours to remove, so a
        # half-finished switch still gets its originals back.
        restore_backup "$dst"
        return 0
    fi

    run mkdir -p "$dir"

    # Already correct? Say nothing, so reruns are quiet.
    same_target "$dst" "$src" && return 0

    # Anything else in the way is moved aside, never deleted -- unless it is one
    # of our own links, which is not something a backup preserves. Git already
    # has every byte it pointed at, and the copy left behind is worse than
    # useless: it is another entry in a directory somebody else reads. Noctalia
    # enumerates ~/.config/noctalia/palettes/ to fill its palette picker, and a
    # displaced link sitting there was enough to empty it.
    #
    # What still gets a backup is what the rule is actually for: a file this
    # setup did not write. CachyOS's own hyprland.lua and kitty.conf are the
    # only copy that exists, and --unlink puts them back.
    if [[ -e $dst || -L $dst ]]; then
        if ours "$dst"; then
            say "replace $(disp "$dst")  (a link into this repo; git has it)"
            run rm -f "$dst"
        else
            say "backup $dst -> $dst.bak-$STAMP"
            run mv "$dst" "$dst.bak-$STAMP"
        fi
    fi

    say "link   $(disp "$dst")"
    run ln -s "$src" "$dst"
}

# tree_files <source dir> -- the files under it that belong to the repo, NUL-
# separated and sorted: tracked ones, plus new ones not yet added, but nothing
# .gitignore excludes. A plain `find` deployed whatever was lying in the
# working tree -- bin/__pycache__/*.pyc from a syntax check went into
# ~/.local/bin and was made executable, and an editor's .swp or an install's
# own *.bak-* in config/hypr would have gone the same way. Falls back to `find`
# outside a git checkout, which bootstrap.sh never produces.
tree_files() {
    local src_root=$1 f
    if git -C "$REPO" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        git -C "$REPO" ls-files -z --cached --others --exclude-standard -- "${src_root#"$REPO"/}" |
            while IFS= read -r -d '' f; do
                # A tracked file deleted but not yet committed is still listed.
                [[ -f $REPO/$f ]] && printf '%s\0' "$REPO/$f"
            done | sort -z
    else
        find "$src_root" -type f -print0 | sort -z
    fi
}

# link_tree <source dir> <destination dir> <executable?>
#
# Individual files are linked rather than the directory itself, so either
# program can still create its own files alongside yours without fighting the
# repo.
link_tree() {
    local src_root=$1 dst_root=$2 executable=$3 rel
    [[ -d $src_root ]] || return 0
    while IFS= read -r -d '' file; do
        rel=${file#"$src_root"/}
        # Documentation belongs in the repo, not scattered through ~/.config.
        [[ $(basename "$rel") == README.md ]] && continue
        # So do the templates for the untracked per-machine files. They are
        # meant to be COPIED to a new name (host.lua, glass.local.conf) and
        # edited; a symlink into the repo cannot be either.
        [[ $(basename "$rel") == *.example ]] && continue
        (( executable )) && { (( UNLINK || STATUS )) || run chmod +x "$file"; }
        link "$file" "$dst_root/$rel"
    done < <(tree_files "$src_root")
}

# root_path <root name> <relative destination>
root_path() {
    local base
    case $1 in
        config) base=$CONFIG_HOME ;;
        bin)    base=$BIN_HOME ;;
        *)      warn "links.tsv: unknown root '$1'"; return 1 ;;
    esac
    if [[ $2 == . ]]; then printf '%s' "$base"; else printf '%s' "$base/$2"; fi
}

do_link() {
    local section kind src root dest last_section="" dst
    while IFS=$'\t' read -r section kind src root dest; do
        [[ -n ${section:-} ]] || continue

        if [[ $section != "$last_section" ]]; then
            # Capitalised for the heading, so the manifest can stay lower case.
            heading "${section^}"
            last_section=$section
        fi

        dst=$(root_path "$root" "$dest") || continue

        case $kind in
            file)      link "$REPO/$src" "$dst" ;;
            tree)      link_tree "$REPO/$src" "$dst" 0 ;;
            exec-tree) link_tree "$REPO/$src" "$dst" 1 ;;
            *)         warn "links.tsv: unknown kind '$kind' for $src" ;;
        esac
    done < <(manifest links)
}

# Reported instead of the link/backup lines when --status is given.
do_status() {
    heading "Status"
    say "linked to this repo:  ${#STAT_LINKED[@]}"
    say "owned by something else: ${#STAT_FOREIGN[@]}"
    say "not present:          ${#STAT_ABSENT[@]}"

    if (( ${#STAT_FOREIGN[@]} )); then
        heading "Paths another setup owns (${#STAT_FOREIGN[@]})"
        note "./install.sh would back these up before linking over them"
        local f
        for f in "${STAT_FOREIGN[@]}"; do say "$(disp "$f")"; done
    fi

    # Backups mean a previous run took these over; --unlink puts them back.
    local -a baks=()
    local b
    while IFS= read -r -d '' b; do baks+=("$b"); done \
        < <(find "$CONFIG_HOME" "$BIN_HOME" -name '*.bak-*' -print0 2>/dev/null)
    if (( ${#baks[@]} )); then
        heading "Restorable backups (${#baks[@]})"
        note "--unlink moves the newest of these back for each path"
        for b in "${baks[@]}"; do say "$(disp "$b")"; done
    fi

    heading "Verdict"
    if (( ${#STAT_LINKED[@]} == 0 )); then
        say "this setup is NOT deployed"
    elif (( ${#STAT_FOREIGN[@]} == 0 )); then
        say "this setup is deployed"
    else
        say "partially deployed -- ${#STAT_LINKED[@]} linked, ${#STAT_FOREIGN[@]} still owned elsewhere"
    fi
}
