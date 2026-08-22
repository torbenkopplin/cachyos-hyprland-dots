#!/usr/bin/env bash
# lint.sh -- everything about this repo that can be checked without a session.
#
#   tests/lint.sh              run every check
#   tests/lint.sh <name>...    run only these
#   tests/lint.sh --list       what each one checks
#
# The other half of the suite. `noct-check` measures a running desktop and
# therefore only works on the machine it is describing; this needs nothing but
# bash, and optionally shellcheck, lua and python3. That is the point: it is
# what CI can run, on a box with no Hyprland, no Noctalia and no pacman.
#
# What it is for
# --------------
# There are 3000-odd lines of bash in here, and until this file existed nothing
# read a single one of them except by being run. The failures it catches are the
# cheap ones -- a typo in a path, a manifest row pointing at a file that was
# renamed, a link whose target no longer exists -- and the reason they are worth
# catching mechanically is that all of them look exactly like a working setup
# until the moment somebody installs onto a fresh machine.
#
# The one class it exists for specifically: a links.tsv row whose source has
# been deleted deploys a DANGLING SYMLINK, and a dangling symlink in ~/.config
# is how a session fails to start. That is check `manifest-sources`.

set -uo pipefail
export LC_ALL=C

REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$REPO" || exit 1

GREEN=$'\e[32m'; RED=$'\e[31m'; YELLOW=$'\e[33m'; DIM=$'\e[2m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
[[ -t 1 ]] || { GREEN=; RED=; YELLOW=; DIM=; BOLD=; RESET=; }

PASS=0; FAIL=0; SKIP=0
pass() { printf '%sPASS%s  %-20s %s\n' "$GREEN" "$RESET" "$1" "${2-}"; PASS=$((PASS+1)); }
fail() { printf '%sFAIL%s  %-20s %s\n' "$RED" "$RESET" "$1" "${2-}"; FAIL=$((FAIL+1)); }
skip() { printf '%sSKIP%s  %-20s %s\n' "$YELLOW" "$RESET" "$1" "${2-}"; SKIP=$((SKIP+1)); }
info() { printf '      %s%s%s\n' "$DIM" "$1" "$RESET"; }

# verdict <name> <problems...> -- pass when the array is empty, fail listing it.
verdict() {
    local name=$1 ok=$2; shift 2
    if (( $# == 0 )); then
        pass "$name" "$ok"
    else
        fail "$name" "$# problem(s)"
        local p; for p in "$@"; do info "$p"; done
    fi
}

# ---------------------------------------------------------------------------
# What is a shell script here, and what is Lua
#
# Found by shape rather than listed, so a new file is covered the day it is
# added. bin/* has no extension by design -- those are commands -- so they are
# recognised by their shebang.
# ---------------------------------------------------------------------------

shell_files() {
    git ls-files -z | while IFS= read -r -d '' f; do
        case $f in
            *.sh) printf '%s\n' "$f" ;;
            *.fish|*.lua|*.md|*.toml|*.json|*.tsv|*.py|*.conf|*.js) ;;
            *) [[ -f $f ]] && head -c 40 "$f" | grep -qE '^#!.*(bash|sh)$|^#!.*(bash|sh) ' \
                   && printf '%s\n' "$f" ;;
        esac
    done
}

lua_files()  { git ls-files -z '*.lua' | tr '\0' '\n'; }
toml_files() { git ls-files -z '*.toml' | tr '\0' '\n'; }
json_files() { git ls-files -z '*.json' | tr '\0' '\n'; }
py_files()   { git ls-files -z '*.py'   | tr '\0' '\n'; }
md_files()   { git ls-files -z '*.md'   | tr '\0' '\n'; }

# ---------------------------------------------------------------------------
# Syntax
# ---------------------------------------------------------------------------

check_shell_syntax() {
    local -a problems=()
    local f out n=0
    while IFS= read -r f; do
        [[ -n $f ]] || continue
        n=$((n+1))
        out=$(bash -n "$f" 2>&1) || problems+=("$f: ${out//$'\n'/ }")
    done < <(shell_files)
    verdict shell-syntax "$n shell scripts parse" "${problems[@]}"
}

# The shellcheck pass, which is the whole reason a bash-heavy repo can be
# trusted at all. (This comment does not start with the tool's name, because a
# comment that does is parsed as a directive -- which is what the first run of
# this check reported about itself.)
#
# Warnings are a failure, not a note, so that a real one is never sitting in a
# list of accepted ones. Two whole rules are excluded, and both are excluded
# because they describe this repo's normal shape rather than a defect in it:
#
#   SC2034  "appears unused". Every file in install/lib and tests/lib is sourced
#           into another script's namespace, so a variable defined for its
#           reader to use is unused *in the file that defines it* by design.
#           Suppressing it per site would mean a directive on almost every
#           library variable in the repo.
#   SC1007  "remove space after =". Fires on `local i prev= now=`, which is how
#           every loop in tests/lib declares an empty accumulator. It is valid,
#           it is deliberate, and it appears in five files.
#
# The rest are the usual sourcing and style noise:
#
#   SC1090/SC1091  a sourced path shellcheck cannot follow. install.sh sources
#                  through a variable, and the directives are already in place.
#   SC2016         a single-quoted $ in an awk program or a fish snippet.
#   SC2312         "invoke separately to avoid masking" -- optional style.
#
# Anything else that fires is either a bug or worth a directive naming why it is
# not. Two of those directives were added the first time this ran.
check_shellcheck() {
    command -v shellcheck >/dev/null 2>&1 \
        || { skip shellcheck "not installed (pacman -S shellcheck)"; return; }

    local -a problems=()
    local -a files=()
    local f
    while IFS= read -r f; do [[ -n $f ]] && files+=("$f"); done < <(shell_files)

    local out
    if out=$(shellcheck --severity=warning \
                        --exclude=SC1090,SC1091,SC2016,SC2312,SC2034,SC1007 \
                        --shell=bash --format=gcc "${files[@]}" 2>&1); then
        pass shellcheck "${#files[@]} shell scripts, no warnings"
        return
    fi
    while IFS= read -r f; do [[ -n $f ]] && problems+=("$f"); done <<<"$out"
    verdict shellcheck "" "${problems[@]}"
}

check_lua_syntax() {
    local luac
    luac=$(command -v luac5.4 || command -v luac || true)
    [[ -n $luac ]] || { skip lua-syntax "no luac (pacman -S lua)"; return; }

    local -a problems=()
    local f out n=0
    while IFS= read -r f; do
        [[ -n $f ]] || continue
        n=$((n+1))
        out=$("$luac" -p "$f" 2>&1) || problems+=("${out//$'\n'/ }")
    done < <(lua_files)
    verdict lua-syntax "$n Lua files parse" "${problems[@]}"
}

# The configs Noctalia reads. A TOML file it cannot parse is not a partial
# config: the section is dropped, and the shell comes up with defaults and says
# nothing about it.
check_toml_syntax() {
    command -v python3 >/dev/null 2>&1 || { skip toml-syntax "no python3"; return; }

    local -a problems=()
    local f out n=0
    while IFS= read -r f; do
        [[ -n $f ]] || continue
        n=$((n+1))
        out=$(python3 -c 'import sys,tomllib; tomllib.load(open(sys.argv[1],"rb"))' "$f" 2>&1) \
            || problems+=("$f: $(printf '%s' "$out" | tail -1)")
    done < <(toml_files)
    verdict toml-syntax "$n TOML files parse" "${problems[@]}"
}

# The browser policies and the palette. A policies.json a browser cannot parse
# is ignored in full, so every setting in it silently does not apply.
check_json_syntax() {
    local -a problems=()
    local f out n=0
    local parse
    if command -v jq >/dev/null 2>&1; then parse=jq
    elif command -v python3 >/dev/null 2>&1; then parse=python3
    else skip json-syntax "no jq and no python3"; return; fi

    while IFS= read -r f; do
        [[ -n $f ]] || continue
        n=$((n+1))
        if [[ $parse == jq ]]; then
            out=$(jq empty "$f" 2>&1) || problems+=("$f: ${out//$'\n'/ }")
        else
            out=$(python3 -c 'import sys,json; json.load(open(sys.argv[1]))' "$f" 2>&1) \
                || problems+=("$f: $(printf '%s' "$out" | tail -1)")
        fi
    done < <(json_files)
    verdict json-syntax "$n JSON files parse" "${problems[@]}"
}

check_python_syntax() {
    command -v python3 >/dev/null 2>&1 || { skip python-syntax "no python3"; return; }
    local -a problems=()
    local f out n=0
    while IFS= read -r f; do
        [[ -n $f ]] || continue
        n=$((n+1))
        out=$(python3 -m py_compile "$f" 2>&1) || problems+=("$f: $(printf '%s' "$out" | tail -1)")
    done < <(py_files)
    rm -rf "$REPO/config/kitty/__pycache__" 2>/dev/null
    verdict python-syntax "$n kittens parse" "${problems[@]}"
}

# ---------------------------------------------------------------------------
# The manifests
#
# These are the checks that matter most, because a manifest row is the one kind
# of mistake here that produces a broken *deployment* rather than a broken file.
# ---------------------------------------------------------------------------

rows() { grep -v '^[[:space:]]*#' "install/manifest/$1.tsv" 2>/dev/null | grep -v '^[[:space:]]*$'; }

# Every source path a manifest names has to exist. A row pointing at a file that
# was renamed does not fail the install: link() happily creates a symlink to a
# path that is not there, and a dangling symlink in ~/.config/hypr is how a
# session fails to start with nothing to read about why.
check_manifest_sources() {
    local -a problems=()
    local n=0 section kind src root dest label rest

    while IFS=$'\t' read -r section kind src root dest; do
        [[ -n ${section:-} ]] || continue
        n=$((n+1))
        case $kind in
            file)                [[ -f $src ]] || problems+=("links.tsv: no such file: $src") ;;
            tree|exec-tree)      [[ -d $src ]] || problems+=("links.tsv: no such directory: $src") ;;
            *)                   problems+=("links.tsv: unknown kind '$kind' for $src") ;;
        esac
        case $root in
            config|bin) ;;
            *) problems+=("links.tsv: unknown root '$root' for $src") ;;
        esac
        [[ -n $dest ]] || problems+=("links.tsv: empty destination for $src")
    done < <(rows links)

    while IFS=$'\t' read -r kind src rest; do
        [[ -n ${kind:-} ]] || continue
        n=$((n+1))
        [[ -f $src ]] || problems+=("browsers.tsv: no such file: $src")
        case $kind in
            policy|userjs) ;;
            *) problems+=("browsers.tsv: unknown kind '$kind'") ;;
        esac
    done < <(rows browsers)

    verdict manifest-sources "$n manifest rows point at something that exists" "${problems[@]}"
}

# Two rows cannot own the same destination: whichever runs last wins, and which
# one that is depends on the order of a file nobody reads that closely.
#
# Compared on the EXPANDED set of paths, not on the rows, because the collision
# that matters is not two identical rows -- it is a `file` row whose destination
# lands inside a `tree` row's directory. Those two rows look nothing alike and
# produce one path, and the first version of this check walked straight past it.
manifest_destinations() {
    local section kind src root dest rel
    while IFS=$'\t' read -r section kind src root dest; do
        [[ -n ${section:-} ]] || continue
        local prefix
        [[ $dest == . ]] && prefix=$root || prefix=$root/$dest
        case $kind in
            file)
                printf '%s\t%s\n' "$prefix" "$src"
                ;;
            tree|exec-tree)
                [[ -d $src ]] || continue
                while IFS= read -r -d '' f; do
                    rel=${f#"$src"/}
                    [[ $(basename "$rel") == README.md ]] && continue
                    [[ $(basename "$rel") == *.example ]] && continue
                    printf '%s\t%s\n' "$prefix/$rel" "$f"
                done < <(find "$src" -type f -print0 | sort -z)
                ;;
        esac
    done < <(rows links)
}

check_manifest_collisions() {
    local -a problems=()
    local -A owner=()
    local path src n=0

    while IFS=$'\t' read -r path src; do
        [[ -n ${path:-} ]] || continue
        n=$((n+1))
        if [[ -n ${owner[$path]:-} ]]; then
            problems+=("$path is deployed by both ${owner[$path]} and $src")
        fi
        owner[$path]=$src
    done < <(manifest_destinations)

    verdict manifest-collisions "$n destinations, each claimed once" "${problems[@]}"
}

# The vocabulary of the other two manifests, which the engine reads with a case
# statement and warns about at install time -- i.e. too late to be useful.
check_manifest_fields() {
    local -a problems=()
    local phase group name scope unit action

    while IFS=$'\t' read -r phase group name; do
        [[ -n ${phase:-} ]] || continue
        case $phase in repo|cursor|npm|claude|login) ;;
            *) problems+=("packages.tsv: unknown phase '$phase' for $name") ;;
        esac
        [[ -n ${group:-} ]] || problems+=("packages.tsv: no group for $name")
        [[ -n ${name:-} ]]  || problems+=("packages.tsv: row with no package name")
    done < <(rows packages)

    while IFS=$'\t' read -r scope unit action; do
        [[ -n ${scope:-} ]] || continue
        case $scope in system|user) ;;
            *) problems+=("services.tsv: unknown scope '$scope' for $unit") ;;
        esac
        case $action in enable|disable) ;;
            *) problems+=("services.tsv: unknown action '$action' for $unit") ;;
        esac
        [[ $unit == *.* ]] || problems+=("services.tsv: $unit has no unit suffix")
    done < <(rows services)

    verdict manifest-fields "every manifest field is a value the engine knows" "${problems[@]}"
}

# tests/deps.tsv names a package group; a group renamed on one side and not the
# other is a check that quietly stops checking. noct-check tests this too, but it
# needs a machine, and this is the half that does not.
check_deps_groups() {
    local -a problems=()
    local cmd pkg group scope why n=0

    while IFS=$'\t' read -r cmd pkg group scope why; do
        [[ -n ${cmd:-} ]] || continue
        [[ $group == - ]] && continue
        n=$((n+1))
        rows packages | awk -F'\t' -v g="$group" '$2 == g { found = 1 } END { exit !found }' \
            || problems+=("deps.tsv: $cmd names group '$group', which packages.tsv does not have")
    done < <(grep -v '^[[:space:]]*#' tests/deps.tsv | awk -F'\t' 'NF >= 5')

    verdict deps-groups "$n declared dependencies name a group that exists" "${problems[@]}"
}

# ---------------------------------------------------------------------------
# Documentation
#
# Not style, only the one thing that rots on its own: a relative link to a file
# that has been moved or renamed. This repo's docs cross-reference heavily and
# the decisions log is meant to be followed, so a dead link costs a reader the
# reasoning rather than a paragraph.
# ---------------------------------------------------------------------------

check_doc_links() {
    command -v python3 >/dev/null 2>&1 || { skip doc-links "no python3"; return; }

    local -a problems=()
    local out
    out=$(python3 - <<'PY'
import os, re, sys, subprocess
files = subprocess.run(['git','ls-files','-z','*.md'], capture_output=True, text=True
                       ).stdout.split('\0')
link = re.compile(r'\[[^\]]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)')
bad = []
for f in filter(None, files):
    base = os.path.dirname(f)
    for target in link.findall(open(f, encoding='utf-8').read()):
        if target.startswith(('http://', 'https://', 'mailto:', '#')):
            continue
        path = target.split('#', 1)[0]
        if not path:
            continue
        if not os.path.exists(os.path.normpath(os.path.join(base, path))):
            bad.append(f'{f}: -> {target}')
for b in bad:
    print(b)
PY
    )
    while IFS= read -r l; do [[ -n $l ]] && problems+=("$l"); done <<<"$out"
    verdict doc-links "every relative link in the docs resolves" "${problems[@]}"
}

# Every decision file is in the index, and every index entry is a file. The
# index is how the log gets read at all; a decision missing from it is a
# decision that will be made again.
check_decisions_index() {
    local dir=docs/decisions index=docs/decisions/README.md
    [[ -d $dir ]] || { skip decisions-index "no docs/decisions yet"; return; }
    [[ -f $index ]] || { fail decisions-index "no $index"; return; }

    local -a problems=()
    local f base n=0
    for f in "$dir"/*.md; do
        base=$(basename "$f")
        [[ $base == README.md ]] && continue
        n=$((n+1))
        grep -q "($base)" "$index" || problems+=("not in the index: $base")
    done

    local ref
    while IFS= read -r ref; do
        [[ -n $ref ]] || continue
        [[ -f $dir/$ref ]] || problems+=("the index links a file that is not there: $ref")
    done < <(grep -oE '\(([0-9]{3}-[a-z0-9-]+\.md)\)' "$index" | tr -d '()')

    verdict decisions-index "$n decisions, all indexed" "${problems[@]}"
}

# ---------------------------------------------------------------------------
# Runner
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# no-secrets -- nothing personal or secret is tracked.
#
# The remote is public, and this repo's whole pattern is that a file with real
# values in it is COPIED to ~/.config rather than symlinked out of config/ --
# accounts.conf, glass.local.conf, host.lua. That pattern is one careless `git
# add` away from failing, and it fails silently: a committed address looks
# exactly like a committed example.
#
# Three rules, in increasing order of how easy the mistake is to make.
# ---------------------------------------------------------------------------

check_no_secrets() {
    local -a problems=()
    local f real

    # 1. For every tracked X.example there must be no tracked X. The .example
    #    suffix IS the statement that the real file is local-only, so tracking
    #    both is a contradiction the linker also cannot resolve -- it skips
    #    *.example and would deploy the real one.
    while IFS= read -r f; do
        real=${f%.example}
        git -C "$REPO" ls-files --error-unmatch -- "$real" >/dev/null 2>&1 \
            && problems+=("$real is tracked, but $f says it should be local-only")
    done < <(git -C "$REPO" ls-files '*.example')

    # 2. No email address outside the placeholder domains. The allowlist is
    #    deliberately tiny and literal: git@github.com for the SSH remotes, and
    #    systemd's unit@instance.service, which is email-shaped and is not an
    #    address.
    #
    #    Two placeholder forms pass: anything mentioning example.com/org/net,
    #    which is reserved for documentation precisely so this rule can be
    #    strict, and a placeholder local part (you@, user@, me@) in front of a
    #    provider's own public hostname -- because `you@imap.gmail.com` names a
    #    service endpoint and no person. A real address matches neither.
    while IFS= read -r f; do
        problems+=("$f -- personal address in a tracked file; real values belong in ~/.config only")
    done < <(git -C "$REPO" ls-files -z \
        | xargs -0 grep -nHoE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' 2>/dev/null \
        | grep -vE 'example\.(com|org|net)' \
        | grep -vE ':[0-9]+:(you|user|name|me|your\.name)@' \
        | grep -vE '(^|[^A-Za-z0-9._%+-])git@github\.com' \
        | grep -vE '@[A-Za-z0-9.-]+\.service')

    # 3. No password inline in a URL. aerc, and anything else taking a URL,
    #    accepts user:password@host -- so this is the shape a leaked secret
    #    actually has. Matches only a userinfo field with a colon in it, so
    #    imaps://user%40host@server and git@github.com:owner/repo do not.
    while IFS= read -r f; do
        problems+=("$f -- looks like a password inline in a URL")
    done < <(git -C "$REPO" ls-files -z \
        | xargs -0 grep -nHE '://[^/[:space:]@"'"'"']+:[^/[:space:]@"'"'"']+@' 2>/dev/null)

    # 4. No absolute home directory. A baseline is recorded output and it is
    #    committed on purpose, so whatever a check printed ends up public --
    #    and "/home/<name>" names the machine's user account to everyone who
    #    clones. tests/lib/harness.sh collapses $HOME to ~ in every string it
    #    records, so a hit here means either a hand-edited baseline or a path
    #    written somewhere that redaction does not reach.
    while IFS= read -r f; do
        problems+=("$f -- absolute home path; use ~ (harness.sh tilde) so the account name stays private")
    done < <(git -C "$REPO" ls-files -z \
        | xargs -0 grep -nHoE '/home/[A-Za-z0-9._-]+' 2>/dev/null \
        | grep -vE '/home/(user|users|you|youruser|username|USER)([^A-Za-z0-9._-]|$)')

    verdict no-secrets "no tracked file carries an address, a password or a copy-me file" "${problems[@]}"
}

CHECKS=(
    "shell-syntax|check_shell_syntax|every shell script parses"
    "shellcheck|check_shellcheck|no shellcheck warnings above the exception list"
    "lua-syntax|check_lua_syntax|every Lua file parses"
    "toml-syntax|check_toml_syntax|every TOML file parses"
    "json-syntax|check_json_syntax|every JSON file parses"
    "python-syntax|check_python_syntax|the kitty kittens parse"
    "manifest-sources|check_manifest_sources|no manifest row points at a missing file"
    "manifest-collisions|check_manifest_collisions|no two rows claim one destination"
    "manifest-fields|check_manifest_fields|every field is a value the engine knows"
    "deps-groups|check_deps_groups|deps.tsv names package groups that exist"
    "doc-links|check_doc_links|every relative link in the docs resolves"
    "decisions-index|check_decisions_index|the decisions log and its index agree"
    "no-secrets|check_no_secrets|no credential, address or copy-me file is tracked"
)

if [[ ${1-} == --list ]]; then
    printf '%s%-22s %s%s\n' "$BOLD" "check" "what it asserts" "$RESET"
    for c in "${CHECKS[@]}"; do
        IFS='|' read -r name _ desc <<<"$c"
        printf '%-22s %s\n' "$name" "$desc"
    done
    exit 0
fi

printf '%sstatic checks%s  %s\n' "$BOLD" "$RESET" "$REPO"
printf '\n'

ran=0
for c in "${CHECKS[@]}"; do
    IFS='|' read -r name fn _ <<<"$c"
    if (( $# )); then
        for want in "$@"; do [[ $want == "$name" ]] && { "$fn"; ran=$((ran+1)); }; done
    else
        "$fn"; ran=$((ran+1))
    fi
done

if (( ! ran )); then
    printf 'no such check: %s\n' "$*" >&2
    printf 'tests/lint.sh --list shows the names\n' >&2
    exit 2
fi

printf '\n%s%d passed, %d failed, %d skipped%s\n' "$BOLD" "$PASS" "$FAIL" "$SKIP" "$RESET"
(( FAIL == 0 ))
