# deps.sh -- does install.sh actually install everything this setup needs?
#
# The failure this is built around
# --------------------------------
# tree-sitter-cli was never in install.sh. Not a regression -- it had never
# been there. The machine it was all developed on had it, installed by hand
# long before, so every parser built, every buffer highlighted, and nothing
# anywhere was wrong. A fresh machine got a neovim whose treesitter could not
# build a parser, with an error message that talks about the grammar rather
# than the missing tool.
#
# No scan of this repository could have found it, because this repository never
# mentions tree-sitter: the neovim config is a separate repository, cloned by
# `install.sh --nvim`. That is the general shape of the problem -- the things a
# dotfiles repo depends on are not all things it names -- and the only fix is a
# list somebody writes down. tests/deps.tsv is that list.
#
# Three checks over it, because there are three ways it can be wrong.

noct_register deps-manifest  pure check_deps_manifest \
    "install.sh installs every dependency the manifest declares"
noct_register deps-installed pure check_deps_installed \
    "this machine actually has them"
noct_register deps-declared  pure check_deps_declared \
    "nothing in bin/ or tests/ depends on a tool the manifest does not name"

DEPS_TSV=$NOCT_REPO/tests/deps.tsv
INSTALL_SH=$NOCT_REPO/install.sh

# deps_rows -- the manifest, comments and blank lines removed.
deps_rows() {
    [[ -f $DEPS_TSV ]] || return 1
    grep -v '^[[:space:]]*#' "$DEPS_TSV" | awk -F'\t' 'NF >= 5'
}

# ---------------------------------------------------------------------------
# deps-manifest -- the manifest against install.sh.
#
# Checked against the named list rather than against the file as a whole, and
# that matters: a package named in a comment, or sitting in PKGS_LOGIN when it
# is needed by every machine, both look like "install.sh mentions it" to a
# grep and neither one installs it on an ordinary run.
# ---------------------------------------------------------------------------

# install_list_contents <PKGS_NAME> -- the words inside that array literal.
# Comments are stripped first, so a package named only in a comment does not
# count as installed -- which is precisely the mistake worth catching.
install_list_contents() {
    awk -v want="$1" '
        $0 ~ "^" want "=\\(" { inside = 1 }
        inside {
            line = $0
            sub(/#.*/, "", line)
            gsub(/^[^(]*\(/, "", line)
            if (line ~ /\)/) { sub(/\).*/, "", line); print line; exit }
            print line
        }' "$INSTALL_SH"
}

check_deps_manifest() {
    require_file deps-manifest "$DEPS_TSV" "it is the manifest itself" || return
    require_file deps-manifest "$INSTALL_SH" "this is not a checkout of the repo" || return

    local cmd pkg list scope why problems=() count=0
    while IFS=$'\t' read -r cmd pkg list scope why; do
        [[ -n $cmd ]] || continue
        count=$((count + 1))
        [[ $list == - ]] && continue    # base system: nothing installs it

        if ! grep -qE "^$list=\(|^$list=\( " "$INSTALL_SH" \
           && ! grep -qE "^$list=" "$INSTALL_SH"; then
            problems+=("$cmd: install.sh has no list called $list")
            continue
        fi
        if ! install_list_contents "$list" | grep -qw -- "$pkg"; then
            problems+=("$cmd needs $pkg, and $list does not install it")
            problems+=("  why it is needed: $why")
        fi
    done < <(deps_rows)

    metric deps.declared "$count"

    if (( ${#problems[@]} == 0 )); then
        pass deps-manifest "install.sh installs all $count declared dependencies"
    else
        fail deps-manifest "install.sh is missing $(( ${#problems[@]} / 2 )) declared dependency(ies)"
        local p; for p in "${problems[@]}"; do info "$p"; done
        info ""
        info "Add the package to that list in install.sh. A machine set up from this repo"
        info "does not get it otherwise, and nothing else in the suite will say so."
    fi
}

# ---------------------------------------------------------------------------
# deps-installed -- the manifest against this machine.
#
# This is the cross-machine check. install.sh being correct says nothing about
# whether it has been RUN here, or run since the list last grew -- and a tool
# installed by hand on one machine years ago is invisible on exactly the day
# somebody sets up a second one.
# ---------------------------------------------------------------------------

check_deps_installed() {
    require_file deps-installed "$DEPS_TSV" "it is the manifest itself" || return

    local cmd pkg list scope why missing_core=() missing_opt=() have=0
    while IFS=$'\t' read -r cmd pkg list scope why; do
        [[ -n $cmd ]] || continue
        if command -v "$cmd" >/dev/null 2>&1; then
            have=$((have + 1))
            continue
        fi
        if [[ $scope == core ]]; then
            missing_core+=("$cmd ($pkg) -- $why")
        else
            missing_opt+=("$cmd ($pkg)")
        fi
    done < <(deps_rows)

    metric deps.present "$have"

    (( ${#missing_opt[@]} )) && info "optional, absent: ${missing_opt[*]}"

    if (( ${#missing_core[@]} == 0 )); then
        pass deps-installed "$have of the declared dependencies are on this machine"
    else
        fail deps-installed "${#missing_core[@]} core dependency(ies) are not installed here"
        local m; for m in "${missing_core[@]}"; do info "$m"; done
        info ""
        info "Fix: ./install.sh --packages"
    fi
}

# ---------------------------------------------------------------------------
# deps-declared -- the code against the manifest.
#
# The manifest is hand-written, so it rots unless something notices. What can
# be found mechanically is every place the code GUARDS on a tool -- `command -v
# X` and the providers' `need X` -- and any tool worth guarding is a tool worth
# writing down. So a new guard fails this check until it is declared, with a
# package and a reason.
#
# The guards are also the honest list of what the code reaches for: a tool used
# without a guard produces a stack of shell errors rather than a diagnosis, and
# that is a separate bug in the script that used it.
# ---------------------------------------------------------------------------

check_deps_declared() {
    require_file deps-declared "$DEPS_TSV" "it is the manifest itself" || return

    local declared guarded undeclared=()
    declared=$(deps_rows | cut -f1 | sort -u)

    # Comments are stripped before anything is matched, and `need` is only
    # taken in command position. Without both, this scan reads the prose --
    # "the checks need a tiled window", "you need two monitors" -- and reports
    # `a` and `two` as undeclared dependencies, which is how the first version
    # of it produced four findings and no information.
    guarded=$(cat "$NOCT_REPO"/bin/* "$NOCT_REPO"/tests/lib/*.sh "$NOCT_REPO"/tests/checks/*.sh 2>/dev/null \
              | sed 's/#.*//' \
              | grep -oE '(command -v[[:space:]]+|(^|[;&|(){}][[:space:]]*)need[[:space:]]+)[a-z0-9._+-]+' \
              | awk '{print $NF}' | sort -u)

    local g
    while IFS= read -r g; do
        [[ -n $g ]] || continue
        # Things this repo installs itself are not dependencies of it.
        case $g in
            noct-*|noctalia-greeter-session) continue ;;
            # Package managers are alternatives, not requirements: install.sh
            # tries shelly, then pacman, then an AUR helper, and the whole
            # point of the guard is that it works with whichever exists.
            shelly|pacman|paru|yay|claude) continue ;;
        esac
        grep -qx -- "$g" <<<"$declared" || undeclared+=("$g")
    done <<<"$guarded"

    if (( ${#undeclared[@]} == 0 )); then
        pass deps-declared "every guarded tool in bin/ and tests/ is in the manifest"
    else
        fail deps-declared "${#undeclared[@]} tool(s) are guarded in the code but not declared"
        local u; for u in "${undeclared[@]}"; do info "$u"; done
        info ""
        info "Add each to tests/deps.tsv with the package that provides it, the install.sh"
        info "list that installs it, and one line on why it is needed. If it is genuinely"
        info "optional -- a nicety whose absence is fine -- say so in the scope column."
    fi
}
