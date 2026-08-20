# packages.sh -- getting the names in install/manifest/packages.tsv onto the
# machine, and (with --check) finding out whether they exist at all.
#
# Package frontends
# -----------------
# shelly is CachyOS's own manager (`shelly` in the cachyos repo) and it is
# preferred wherever it exists, for one reason that matters here: it installs
# repository packages AND AUR packages through one tool, so a fresh CachyOS
# machine needs no separate AUR helper for this script to finish. It
# authenticates through polkit rather than sudo, which means a graphical
# password prompt in a session -- and nothing at all in a bare TTY, where it
# simply fails and the pacman path below picks the list up.
#
# pacman + paru/yay stays as the fallback, unchanged, so this script still works
# on plain Arch.

detect_aur_helper() {
    local helper
    for helper in paru yay; do
        command -v "$helper" >/dev/null 2>&1 && { printf '%s' "$helper"; return 0; }
    done
    return 1
}

have_shelly() { command -v shelly >/dev/null 2>&1; }

# pkg_installed <name> -- true when the name is already satisfied.
#
# `pacman -T` rather than `-Q`: it resolves *provides* too, so a package
# installed under a different name than the one asked for (very common with -bin
# and -git variants) does not get reinstalled on every run. This is what makes
# every frontend below idempotent, including the ones with no --needed.
pkg_installed() { pacman -T -- "$1" >/dev/null 2>&1; }

# pkg_group <phase> -- the names in that phase, in manifest order.
pkg_group() {
    local phase=$1 p g n
    while IFS=$'\t' read -r p g n; do
        [[ $p == "$phase" ]] && printf '%s\n' "$n"
    done < <(manifest packages)
    return 0
}

# The cursor theme is its own phase because it has a predicate: the AUR variants
# all ship /usr/share/icons/Bibata-*, and pacman aborts an entire transaction on
# a file conflict, so asking for one on a machine that already has another would
# take the rest of the package step down with it.
cursor_packages() {
    compgen -G '/usr/share/icons/Bibata-*' >/dev/null 2>&1 && return 0
    pkg_group cursor
}

# Names that could not be resolved from the repositories, for the AUR pass.
UNRESOLVED=()

# pacman_install <packages...>
#
# Named for what it means -- "get these from the repositories" -- rather than for
# which binary does it. Already-installed names are dropped first, then the whole
# list goes in one transaction, which is fast and resolves dependencies together.
# If that fails it retries one at a time, so a single unknown name cannot block
# the other twenty; anything still missing afterwards goes to UNRESOLVED for the
# AUR pass rather than being reported as an error here.
pacman_install() {
    local -a want=("$@") pkgs=()
    local pkg
    for pkg in "${want[@]}"; do
        pkg_installed "$pkg" || pkgs+=("$pkg")
    done

    if (( ! ${#pkgs[@]} )); then
        (( ${#want[@]} )) && note "already installed: ${#want[@]} package(s)"
        return 0
    fi

    if (( DRY_RUN )); then
        if have_shelly; then
            say "would: shelly install standard ${pkgs[*]}"
        else
            say "would: pacman -S --needed ${pkgs[*]}"
        fi
        return 0
    fi

    if have_shelly && shelly install standard --no-confirm "${pkgs[@]}" >/dev/null 2>&1; then
        say "shelly: ${pkgs[*]}"
    elif as_root pacman -S --needed --noconfirm "${pkgs[@]}" >/dev/null 2>&1; then
        say "pacman: ${pkgs[*]}"
    else
        note "batch failed, resolving individually"
        for pkg in "${pkgs[@]}"; do
            if as_root pacman -S --needed --noconfirm "$pkg" >/dev/null 2>&1; then
                say "pacman: $pkg"
            fi
        done
    fi

    # One truth at the end, whichever frontend ran: what is still not there.
    for pkg in "${pkgs[@]}"; do
        pkg_installed "$pkg" || UNRESOLVED+=("$pkg")
    done
}

# Only reached for what the repositories could not provide.
aur_install() {
    local -a want=("$@") pkgs=()
    local pkg
    for pkg in "${want[@]}"; do
        pkg_installed "$pkg" || pkgs+=("$pkg")
    done
    (( ${#pkgs[@]} )) || return 0

    if (( DRY_RUN )); then
        if have_shelly; then
            say "would: shelly install aur ${pkgs[*]}"
        else
            say "would: $(detect_aur_helper || echo '<no AUR helper>') -S --needed ${pkgs[*]}"
        fi
        return 0
    fi

    # shelly builds AUR packages itself, so this is the branch that runs on
    # CachyOS whether or not paru is installed.
    if have_shelly; then
        shelly install aur --no-confirm "${pkgs[@]}" >/dev/null 2>&1 || true
        local -a left=()
        for pkg in "${pkgs[@]}"; do
            if pkg_installed "$pkg"; then say "shelly: $pkg"; else left+=("$pkg"); fi
        done
        pkgs=("${left[@]}")
        (( ${#pkgs[@]} )) || return 0
    fi

    local helper
    if ! helper=$(detect_aur_helper); then
        warn "not installed, and no AUR helper to try: ${pkgs[*]}"
        note "install shelly or paru, then rerun with --packages"
        return 0
    fi

    for pkg in "${pkgs[@]}"; do
        if "$helper" -S --needed --noconfirm "$pkg" >/dev/null 2>&1; then
            say "$helper: $pkg"
        else
            warn "could not install: $pkg"
        fi
    done
}

do_packages() {
    heading "Packages"

    needs_machine "packages" || return 1

    if ! command -v pacman >/dev/null 2>&1; then
        warn "pacman not found -- this step only works on CachyOS/Arch"
        return 1
    fi

    # Everything goes at pacman first, including the names that are usually
    # AUR-only: CachyOS builds its repos with architecture-specific
    # optimisations, so a repo package is worth preferring wherever one exists.
    local -a pkgs=()
    local p
    while IFS= read -r p; do pkgs+=("$p"); done < <(pkg_group repo; cursor_packages)

    say "repositories"
    pacman_install "${pkgs[@]}"

    if (( ${#UNRESOLVED[@]} )); then
        heading "AUR fallback"
        note "not in any enabled repo: ${UNRESOLVED[*]}"
        aur_install "${UNRESOLVED[@]}"
    fi
}

# npm_install <packages...>
#
# Same shape as pacman_install: one batch first, then one at a time so a single
# bad name cannot block the rest. Nothing falls through to another source, so
# failures are warned about here rather than collected.
npm_install() {
    local -a pkgs=("$@")
    (( ${#pkgs[@]} )) || return 0

    if (( DRY_RUN )); then
        say "would: npm install -g ${pkgs[*]}"
        return 0
    fi

    if npm install -g "${pkgs[@]}" >/dev/null 2>&1; then
        say "npm: ${pkgs[*]}"
        return 0
    fi

    note "batch failed, resolving individually"
    local pkg
    for pkg in "${pkgs[@]}"; do
        if npm install -g "$pkg" >/dev/null 2>&1; then
            say "npm: $pkg"
        else
            warn "could not install: $pkg"
        fi
    done
}

do_npm_globals() {
    local -a globals=()
    local p
    while IFS= read -r p; do globals+=("$p"); done < <(pkg_group npm)
    (( ${#globals[@]} )) || return 0

    command -v npm >/dev/null 2>&1 || { warn "npm missing, skipped: ${globals[*]}"; return 0; }

    # Global installs go under ~/.local so they never need root and land on the
    # PATH this script already asks you to have. Without this npm would try to
    # write to /usr/lib/node_modules.
    say "npm globals (prefix ~/.local)"
    run npm config set prefix "$HOME_DIR/.local"
    npm_install "${globals[@]}"
}

do_claude() {
    local pkg
    pkg=$(pkg_group claude | head -1)
    [[ -n $pkg ]] || return 0

    command -v claude >/dev/null 2>&1 && { say "claude-code already installed"; return 0; }

    if (( DRY_RUN )); then
        say "would: npm install -g $pkg  (if no package)"
        return 0
    fi

    command -v npm >/dev/null 2>&1 || { warn "claude-code not installed (no package, no npm)"; return 0; }

    say "claude-code via npm"
    if npm install -g "$pkg" >/dev/null 2>&1; then
        say "installed: $pkg"
    else
        warn "could not install claude-code"
    fi
}

# ---------------------------------------------------------------------------
# --check: do these names exist?
#
# The install path is deliberately permissive -- a name that resolves nowhere is
# reported in the summary rather than aborting a run halfway through a fresh
# machine. The cost of that is a typo staying invisible until somebody sets up a
# new machine and reads the summary carefully. This is the pass that finds it
# first, and it is why editing packages.tsv should be followed by --check.
#
# Repositories first, then the AUR RPC for whatever is left, then npm. Nothing
# is installed and nothing needs root.
# ---------------------------------------------------------------------------

do_check() {
    heading "Package names"

    command -v pacman >/dev/null 2>&1 \
        || { warn "pacman not found -- names can only be checked on CachyOS/Arch"; return 0; }

    local -a names=() missing=() unknown=()
    local p
    while IFS= read -r p; do names+=("$p"); done \
        < <(pkg_group repo; pkg_group cursor; pkg_group login)

    say "${#names[@]} names against the repositories"
    local pkg
    for pkg in "${names[@]}"; do
        pacman -Si -- "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
    done

    if (( ${#missing[@]} )); then
        say "${#missing[@]} not in a repository -- asking the AUR"
        if ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
            note "curl and jq are what query the AUR; skipping that half"
            note "not in any repo: ${missing[*]}"
        else
            local -a args=()
            for pkg in "${missing[@]}"; do args+=("arg[]=$pkg"); done
            local found
            found=$(curl -fsSL "https://aur.archlinux.org/rpc/v5/info?$(IFS='&'; printf '%s' "${args[*]}")" \
                    2>/dev/null | jq -r '.results[].Name' 2>/dev/null) || found=""
            for pkg in "${missing[@]}"; do
                grep -qxF "$pkg" <<<"$found" || unknown+=("$pkg")
            done
            local aur_count
            aur_count=$(( ${#missing[@]} - ${#unknown[@]} ))
            (( aur_count )) && say "$aur_count in the AUR"
        fi
    fi

    # npm names, which resolve nowhere near pacman.
    local -a npm_names=()
    while IFS= read -r p; do npm_names+=("$p"); done < <(pkg_group npm; pkg_group claude)
    if (( ${#npm_names[@]} )); then
        if command -v npm >/dev/null 2>&1; then
            say "${#npm_names[@]} names against the npm registry"
            for pkg in "${npm_names[@]}"; do
                npm view "$pkg" version >/dev/null 2>&1 || unknown+=("$pkg (npm)")
            done
        else
            note "npm not installed; ${#npm_names[@]} npm name(s) not checked"
        fi
    fi

    if (( ${#unknown[@]} )); then
        warn "${#unknown[@]} name(s) resolve nowhere: ${unknown[*]}"
        note "a name like this installs nothing and only shows up in the summary"
        note "of a --packages run on a fresh machine. Fix it in"
        note "install/manifest/packages.tsv, or delete the row."
    else
        say "every name resolves"
    fi
}
