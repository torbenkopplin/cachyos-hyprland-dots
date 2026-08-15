# fish -- carried over from ~/dotfiles/fish/.config/fish/config.fish.
#
# Changes on the way across are marked CHANGED and are only the ones the
# platform forces: Debian binary names, and the shell replacing quickshell.
# Everything else is yours, in your order.

if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
  source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# Shadowed by starship below, which defines its own fish_prompt. Kept as the
# fallback you get if starship is ever missing -- without it you would drop to
# fish's stock prompt rather than yours.
function fish_prompt -d "Write out the prompt"
  # This shows up as USER@HOST /home/user/ >, with the directory colored
  # $USER and $hostname are set by fish, so you can just use them
  # instead of using `whoami` and `hostname`
  printf '%s@%s %s%s%s > ' $USER $hostname \
    (set_color $fish_color_cwd) (prompt_pwd) (set_color normal)
end

function y
	set tmp (mktemp -t "yazi-cwd.XXXXXX")
	command yazi $argv --cwd-file="$tmp"
	if read -z cwd < "$tmp"; and [ "$cwd" != "$PWD" ]; and test -d "$cwd"
		builtin cd -- "$cwd"
	end
	rm -f -- "$tmp"
end

fish_add_path ~/.local/bin

# nvm is handled by the nvm.fish plugin (see fish_plugins and conf.d/nvm.fish),
# not by the bash version. These lines were already commented out; kept so it
# stays obvious that the bash nvm is deliberately not sourced here.
# set -gx NVM_DIR "$HOME/.nvm"
# [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# CHANGED (addition): Hyprland exports EDITOR via conf/env.lua, but a bare TTY
# or an SSH session never goes through Hyprland. Without this, `git commit` in
# those contexts falls back to vi.
if not set -q EDITOR
  set -gx EDITOR nvim
end
if not set -q VISUAL
  set -gx VISUAL nvim
end

if status is-interactive # Commands to run in interactive sessions can go here

  # No greeting
  set fish_greeting

  # Use starship
  starship init fish | source

  # CHANGED: was the quickshell/illogical-impulse sequences file. Noctalia
  # themes terminals two ways instead -- its kitty template writes
  # current-theme.conf for new windows, and the terminal-colors.sh template
  # pushes OSC sequences into open ones. Neither needs anything sourced here.

  # Aliases
  alias clear "printf '\033[2J\033[3J\033[1;1H'" # fix: kitty doesn't clear properly
  alias celar "printf '\033[2J\033[3J\033[1;1H'"
  alias claer "printf '\033[2J\033[3J\033[1;1H'"

  alias .. "cd .."
  alias ... "cd ../.."
  alias .... "cd ../../.."
  alias ..... "cd ../../../.."
  alias ...... "cd ../../../../.."
  alias ....... "cd ../../../../../.."

  # alias ls 'eza --icons'
  alias pamcan pacman

  # CHANGED: dropped `alias q 'qs -c ii'` -- that started quickshell with the
  # illogical-impulse config, which this setup replaces with Noctalia.

  # CHANGED: batcat -> bat. Debian renames the binary because of a clash with
  # its own `bat` package; Arch has no such clash and ships it as `bat`.
  alias cat='bat --paging=never --theme="base16"'
  alias ls='eza -al --color=always --group-directories-first --icons' # preferred listing
  alias lt='eza -T --color=always --group-directories-first --icons' # tree listing

  alias pl='git pull'
  alias ph='git push'
  alias st='git status'
  alias co='git checkout'
  alias cob='git checkout -b'
  alias stash='git stash'
  alias pop='git stash pop'
  alias diff='git diff'

  if test -f /etc/debian_version
    alias update='sudo apt update ; sudo apt upgrade -y'
  else if test -f /etc/arch-release
    alias update='sudo pacman -Syu'
  end
end
