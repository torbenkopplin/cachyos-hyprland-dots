#!/usr/bin/env bash
# install-fakeroot.sh -- run the installer for real, into a throwaway directory.
#
#   tests/install-fakeroot.sh            run it
#   tests/install-fakeroot.sh --keep     leave the root behind to look at
#
# The installer's own test. Everything here runs on a machine with no Hyprland,
# no Noctalia and no pacman -- which is what makes it the part of the suite CI
# can run, and the reason ./install.sh grew a --root at all.
#
# What it asserts, and why each one is a thing that has gone wrong:
#
#   no dangling links   A links.tsv row pointing at a renamed file installs a
#                       symlink to nothing. Hyprland reads a dangling
#                       hyprland.lua as an empty config and the session does not
#                       start, with nothing on screen to say why.
#   every row deployed  A row that silently matches no files -- a tree that has
#                       been emptied, a path with a typo -- deploys nothing and
#                       reports nothing.
#   reruns are quiet    The installer is run again on every update. A second run
#                       that reports work is a second run that is doing work,
#                       which means one of the two runs is wrong.
#   backup and restore  This is what makes --unlink a real reverse, and what
#                       lets this setup and the copy-based one in ~/repos/dots
#                       swap places. If the backup half works and the restore
#                       half does not, you find out when you want your old
#                       config back and it is gone.
#   nothing escapes     Every path the installer writes has to be under the
#                       root. This is the check that would have caught the
#                       accident of 2026-08-19 before it happened.

set -uo pipefail
export LC_ALL=C

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO" || exit 1

KEEP=0
[[ ${1-} == --keep ]] && KEEP=1

GREEN=$'\e[32m'; RED=$'\e[31m'; DIM=$'\e[2m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
[[ -t 1 ]] || { GREEN=; RED=; DIM=; BOLD=; RESET=; }

PASS=0; FAIL=0
ok()   { printf '%sPASS%s  %-22s %s\n' "$GREEN" "$RESET" "$1" "${2-}"; PASS=$((PASS+1)); }
bad()  { printf '%sFAIL%s  %-22s %s\n' "$RED" "$RESET" "$1" "${2-}"; FAIL=$((FAIL+1)); }
info() { printf '      %s%s%s\n' "$DIM" "$1" "$RESET"; }

ROOT=$(mktemp -d -t noct-fakeroot-XXXXXX)
# A fixed point in time to compare the real home against at the end. The root's
# own mtime is not one: it changes every time the run writes into it, so it
# drifts forward and the escape check gets weaker as the run goes on.
STARTED=$(mktemp -t noct-fakeroot-stamp-XXXXXX)
cleanup() {
    rm -f "$STARTED"
    (( KEEP )) && { printf '\nroot kept: %s\n' "$ROOT"; return; }
    rm -rf "$ROOT"
}
trap cleanup EXIT

printf '%sinstaller, into a fake root%s  %s\n\n' "$BOLD" "$RESET" "$ROOT"

# ---------------------------------------------------------------------------
# 1. A full run, including the two steps that are not in --all.
# ---------------------------------------------------------------------------

first=$("$REPO/install.sh" --root "$ROOT" --all --login 2>&1)
status=$?
if (( status == 0 )); then
    ok "install --all"  "exit 0"
else
    bad "install --all" "exit $status"
    printf '%s\n' "$first" | sed 's/^/      /'
    exit 1
fi

# ---------------------------------------------------------------------------
# 2. No dangling symlinks, and everything points back into this checkout.
# ---------------------------------------------------------------------------

mapfile -t links < <(find "$ROOT" -type l | sort)
dangling=()
outside=()
for l in "${links[@]}"; do
    target=$(readlink -f "$l" 2>/dev/null || true)
    [[ -e $target ]] || dangling+=("$l -> $(readlink "$l")")
    [[ $target == "$REPO"/* ]] || outside+=("$l -> $target")
done

if (( ${#links[@]} == 0 )); then
    bad "links created" "none at all"
elif (( ${#dangling[@]} )); then
    bad "no dangling links" "${#dangling[@]} of ${#links[@]}"
    printf '      %s\n' "${dangling[@]}"
else
    ok "no dangling links" "${#links[@]} links, every target exists"
fi

if (( ${#outside[@]} )); then
    bad "links point at the repo" "${#outside[@]} point elsewhere"
    printf '      %s\n' "${outside[@]}"
else
    ok "links point at the repo" "all ${#links[@]}"
fi

# ---------------------------------------------------------------------------
# 3. Every manifest row actually deployed something.
# ---------------------------------------------------------------------------

rows() { grep -v '^[[:space:]]*#' "install/manifest/$1.tsv" | grep -v '^[[:space:]]*$'; }

silent=()
while IFS=$'\t' read -r section kind src root dest; do
    [[ -n ${section:-} ]] || continue
    case $root in
        config) base=$ROOT/.config ;;
        bin)    base=$ROOT/.local/bin ;;
        *)      continue ;;
    esac
    [[ $dest == . ]] && target=$base || target=$base/$dest
    n=$(find "$target" -type l 2>/dev/null | wc -l)
    (( n )) || silent+=("$kind $src -> $dest deployed nothing")
done < <(rows links)

if (( ${#silent[@]} )); then
    bad "every row deployed" "${#silent[@]} row(s) silent"
    printf '      %s\n' "${silent[@]}"
else
    ok "every row deployed" "$(rows links | wc -l) rows"
fi

# The files a tree is supposed to skip. A README linked into ~/.config is
# harmless and wrong; an *.example linked there cannot be copied and edited,
# which is the entire point of it being an example.
stray=$(find "$ROOT" -name 'README.md' -o -name '*.example' | wc -l)
if (( stray )); then
    bad "skips docs and examples" "$stray found under the root"
    find "$ROOT" \( -name 'README.md' -o -name '*.example' \) | sed 's/^/      /'
else
    ok "skips docs and examples" "no README.md or *.example deployed"
fi

# ---------------------------------------------------------------------------
# 4. The things that are written rather than linked.
# ---------------------------------------------------------------------------

missing=()
while IFS=$'\t' read -r kind src rest; do
    [[ $kind == policy ]] || continue
    [[ -f $ROOT$rest ]] || missing+=("$rest")
done < <(rows browsers)
if (( ${#missing[@]} )); then
    bad "browser policies" "${#missing[@]} not written"
    printf '      %s\n' "${missing[@]}"
else
    ok "browser policies" "all written under the root"
fi

if [[ -f $ROOT/etc/greetd/config.toml ]] \
   && grep -q 'noctalia-greeter-session' "$ROOT/etc/greetd/config.toml"; then
    ok "greetd config" "written, and names the greeter session"
else
    bad "greetd config" "not written, or does not name the greeter"
fi

# ---------------------------------------------------------------------------
# 5. The steps that change the machine said so instead of doing it.
# ---------------------------------------------------------------------------

skipped=0
for step in packages "neovim config" wallpapers; do
    grep -qF "$step: skipped under --root" <<<"$first" && skipped=$((skipped+1))
done
if (( skipped == 3 )); then
    ok "machine steps skipped" "packages, neovim, wallpapers"
else
    bad "machine steps skipped" "$skipped of 3 said so"
fi

# ---------------------------------------------------------------------------
# 6. A rerun does nothing and says nothing.
# ---------------------------------------------------------------------------

second=$("$REPO/install.sh" --root "$ROOT" 2>&1)
noise=$(grep -cE '^  (link|backup|restore|unlink) ' <<<"$second")
if (( noise == 0 )); then
    ok "rerun is quiet" "no link, backup or restore lines"
else
    bad "rerun is quiet" "$noise line(s) of work on the second run"
    grep -E '^  (link|backup|restore|unlink) ' <<<"$second" | head -5 | sed 's/^/      /'
fi

# ---------------------------------------------------------------------------
# 7. Backup, and the restore that makes --unlink a real reverse.
# ---------------------------------------------------------------------------

victim=$ROOT/.config/hypr/hyprland.lua
rm -f "$victim"
printf 'THE OTHER SETUP\n' > "$victim"

third=$("$REPO/install.sh" --root "$ROOT" 2>&1)
if grep -q "backup $victim ->" <<<"$third" && [[ -L $victim ]]; then
    ok "displaces, never deletes" "the foreign file was moved aside"
else
    bad "displaces, never deletes" "no backup line, or the link was not made"
fi

"$REPO/install.sh" --root "$ROOT" --unlink >/dev/null 2>&1
if [[ -f $victim && ! -L $victim ]] && grep -q 'THE OTHER SETUP' "$victim"; then
    ok "unlink restores" "the foreign file is back, byte for byte"
else
    bad "unlink restores" "$victim is not what it was"
fi

left=$(find "$ROOT" -type l | wc -l)
if (( left == 0 )); then
    ok "unlink leaves nothing" "0 links remain"
else
    bad "unlink leaves nothing" "$left link(s) remain"
fi

# ---------------------------------------------------------------------------
# 8. Nothing escaped the root.
#
# Checked by mtime against the root itself: anything the run touched in the real
# home would be newer. This is the assertion the whole file is built around.
# ---------------------------------------------------------------------------

escaped=$(find "$HOME/.config" "$HOME/.local/bin" -maxdepth 1 -newer "$STARTED" \
               -not -name '.config' -not -name 'bin' 2>/dev/null | head -5)
if [[ -z $escaped ]]; then
    ok "nothing escaped the root" "the real ~/.config is untouched"
else
    bad "nothing escaped the root" "something in the real home is newer than the root"
    printf '      %s\n' "$escaped"
fi

printf '\n%s%d passed, %d failed%s\n' "$BOLD" "$PASS" "$FAIL" "$RESET"
(( FAIL == 0 ))
