# session.sh -- the parts of the setup that are neither a file nor a package:
# the login shell, the units, and the neovim config.

# ---------------------------------------------------------------------------
# Fish
#
# Two things: make it the login shell, and restore its plugins.
#
# Plugins are not vendored -- config/fish/fish_plugins is the source of truth and
# `fisher update` installs everything listed in it. That is the whole point of a
# plugin manager, and it is how nvm gets into fish: the list names
# jorgebucaran/nvm.fish, a native reimplementation.
#
# Why that is needed at all: `nvm` proper is a bash/zsh *shell function*, not a
# program. `nvm use 20` has to mutate the environment of the calling shell, so
# there is no binary to put on PATH and no way to make the bash version work
# under fish.
# ---------------------------------------------------------------------------

do_fish() {
    command -v fish >/dev/null 2>&1 || { warn "fish not installed, skipping shell setup"; return 0; }

    heading "Fish"

    needs_machine "fish" || return 0

    # --- default shell -------------------------------------------------------
    local fish_path current
    fish_path=$(command -v fish)
    current=$(getent passwd "$USER" | cut -d: -f7)

    if [[ $current == "$fish_path" ]]; then
        say "already the default shell"
    elif (( DRY_RUN )); then
        say "would: chsh -s $fish_path"
    else
        # chsh refuses a shell that is not listed in /etc/shells.
        if ! grep -qxF "$fish_path" /etc/shells 2>/dev/null; then
            say "adding $fish_path to /etc/shells"
            printf '%s\n' "$fish_path" | as_root tee -a /etc/shells >/dev/null
        fi
        if chsh -s "$fish_path"; then
            say "default shell -> fish (takes effect on next login)"
        else
            warn "chsh failed -- run 'chsh -s $fish_path' yourself"
        fi
    fi

    # --- plugins from fish_plugins ------------------------------------------
    if (( DRY_RUN )); then
        say "would: fisher update  (installs everything in fish_plugins)"
        return 0
    fi

    if ! fish -c 'type -q fisher' >/dev/null 2>&1; then
        # fisher is a single function file; bootstrapping it by hand is its own
        # documented install path, and cheaper than failing here.
        say "bootstrapping fisher"
        if ! fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher' >/dev/null 2>&1; then
            warn "could not bootstrap fisher -- fish plugins (incl. nvm) unavailable"
            note "install fisher, then run: fisher update"
            return 0
        fi
    fi

    if fish -c 'fisher update' >/dev/null 2>&1; then
        say "fisher: installed plugins from fish_plugins"
    else
        warn "fisher update failed -- check 'fisher list' in a fish shell"
    fi
}

# ---------------------------------------------------------------------------
# Units
#
# Driven from install/manifest/services.tsv. `enable` is unremarkable -- the
# launcher providers all talk to a daemon and installing the package does not
# start it. `disable` is the interesting half: it exists for hypridle, which
# does the same job as Noctalia's idle service from a config directory this repo
# does not manage, and two countdowns to the same lock screen is how you end up
# locked out mid-video with no idea which of them did it.
# ---------------------------------------------------------------------------

do_services() {
    say "services"

    needs_machine "services" || return 0

    local scope unit action
    local -a ask act
    while IFS=$'\t' read -r scope unit action; do
        [[ -n ${scope:-} ]] || continue

        # Two forms of the same command: `ask` for the read-only queries, which
        # must never prompt for a password, and `act` for the change.
        case $scope in
            system) ask=(systemctl);          act=("${SUDO_ARGV[@]}" systemctl) ;;
            user)   ask=(systemctl --user);   act=(systemctl --user) ;;
            *)      warn "services.tsv: unknown scope '$scope'"; continue ;;
        esac

        # A unit that is not installed is not a problem: the package step
        # already reports anything it could not get.
        "${ask[@]}" list-unit-files "$unit" >/dev/null 2>&1 || continue

        case $action in
            enable)
                run "${act[@]}" enable --now "$unit"
                ;;
            disable)
                # Only when it is actually doing something, so a machine that
                # never had it says nothing.
                "${ask[@]}" is-enabled "$unit" >/dev/null 2>&1 ||
                    "${ask[@]}" is-active "$unit" >/dev/null 2>&1 || continue
                say "$unit is running as well as Noctalia's idle service -- disabling it"
                note "two idle daemons means two countdowns to the lock screen"
                run "${act[@]}" disable --now "$unit"
                ;;
            *)  warn "services.tsv: unknown action '$action' for $unit" ;;
        esac
    done < <(manifest services)
}

# ---------------------------------------------------------------------------
# Neovim config
#
# Its own repository, so it is cloned rather than vendored here -- that keeps one
# source of truth and lets it be pushed to independently of these dotfiles.
# ---------------------------------------------------------------------------

NVIM_HTTPS=https://github.com/torbenkopplin/nvimrc.git
NVIM_SSH=git@github.com:torbenkopplin/nvimrc.git

do_nvim() {
    heading "Neovim config"

    needs_machine "neovim config" || return 0

    local dest=$CONFIG_HOME/nvim

    if [[ -d $dest/.git ]]; then
        say "already a git checkout: $(disp "$dest")"
        note "leaving it alone; pull it yourself if you want the latest"
        return 0
    fi

    if [[ -e $dest ]]; then
        say "backup $(disp "$dest") -> $(disp "$dest").bak-$STAMP"
        run mv "$dest" "$dest.bak-$STAMP"
    fi

    # Cloned over HTTPS so this works before any SSH key is on the machine, then
    # the remote is switched to SSH to match how it is actually pushed.
    if (( DRY_RUN )); then
        say "would: git clone $NVIM_HTTPS $dest"
        say "would: git -C $dest remote set-url origin $NVIM_SSH"
    elif git clone --quiet "$NVIM_HTTPS" "$dest"; then
        say "cloned $(disp "$dest")"
        git -C "$dest" remote set-url origin "$NVIM_SSH"
        note "origin set to SSH ($NVIM_SSH) -- needs your key to push"
    else
        warn "could not clone $NVIM_HTTPS"
    fi

    note "LSP servers install themselves on first launch, via mason"
}
