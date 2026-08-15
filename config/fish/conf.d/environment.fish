# Environment that must exist in every fish shell, interactive or not.
#
# Hyprland already exports EDITOR, VISUAL, TERMINAL and the Qt/GTK variables
# via conf/env.lua, and everything launched from the session inherits them.
# This file covers the cases that do not go through Hyprland: a bare TTY, an
# SSH session into this machine, and a systemd user unit.

# ~/.local/bin holds the noct-* launcher providers and the npm globals
# (eslint, mmdc). fish_add_path is idempotent and prepends only once, so this
# is safe to re-source.
fish_add_path --path $HOME/.local/bin

if not set -q EDITOR
    set -gx EDITOR nvim
end
if not set -q VISUAL
    set -gx VISUAL nvim
end
