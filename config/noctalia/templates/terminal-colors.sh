#!/usr/bin/env bash
# TEMPLATE -- rendered by Noctalia into ~/.cache/noctalia/terminal-colors.sh
# whenever the palette changes, then executed by that template's post_hook.
#
# Why this exists
# ---------------
# The built-in `kitty` template rewrites kitty's colour *config*, which only
# affects terminals started afterwards. This repaints the terminals you already
# have open, using OSC escape sequences that every terminal understands (kitty,
# foot, ghostty, alacritty, wezterm, konsole...). It is the difference between
# "new windows match the wallpaper" and "everything matches the wallpaper".
#
# Colours reach your *shell* through the same route: prompts, ls, git and most
# TUIs paint with the 16 ANSI slots set below, so they follow automatically
# without any per-tool configuration.
#
# The {{ ... }} placeholders are substituted by Noctalia before this runs; the
# \033 escapes are interpreted by printf at runtime, which is why this file
# stays readable ASCII in the repo.

set -u

# OSC 10/11/12 = default foreground / background / cursor.
# OSC 4;N      = ANSI palette slot N.
payload=$(
    printf '\033]10;%s\007' '{{ colors.terminal_foreground.default.hex }}'
    printf '\033]11;%s\007' '{{ colors.terminal_background.default.hex }}'
    printf '\033]12;%s\007' '{{ colors.terminal_cursor.default.hex }}'

    printf '\033]4;0;%s\007'  '{{ colors.terminal_normal_black.default.hex }}'
    printf '\033]4;1;%s\007'  '{{ colors.terminal_normal_red.default.hex }}'
    printf '\033]4;2;%s\007'  '{{ colors.terminal_normal_green.default.hex }}'
    printf '\033]4;3;%s\007'  '{{ colors.terminal_normal_yellow.default.hex }}'
    printf '\033]4;4;%s\007'  '{{ colors.terminal_normal_blue.default.hex }}'
    printf '\033]4;5;%s\007'  '{{ colors.terminal_normal_magenta.default.hex }}'
    printf '\033]4;6;%s\007'  '{{ colors.terminal_normal_cyan.default.hex }}'
    printf '\033]4;7;%s\007'  '{{ colors.terminal_normal_white.default.hex }}'

    printf '\033]4;8;%s\007'  '{{ colors.terminal_bright_black.default.hex }}'
    printf '\033]4;9;%s\007'  '{{ colors.terminal_bright_red.default.hex }}'
    printf '\033]4;10;%s\007' '{{ colors.terminal_bright_green.default.hex }}'
    printf '\033]4;11;%s\007' '{{ colors.terminal_bright_yellow.default.hex }}'
    printf '\033]4;12;%s\007' '{{ colors.terminal_bright_blue.default.hex }}'
    printf '\033]4;13;%s\007' '{{ colors.terminal_bright_magenta.default.hex }}'
    printf '\033]4;14;%s\007' '{{ colors.terminal_bright_cyan.default.hex }}'
    printf '\033]4;15;%s\007' '{{ colors.terminal_bright_white.default.hex }}'
)

# Write to every pty we own. The -w test is what keeps this from touching other
# users' terminals, and from erroring on ptys that have gone away mid-loop.
#
# The upstream docs suggest `tee /dev/pts/[0-9]*`, which writes blindly; this
# is the same idea with the permission check made explicit.
shopt -s nullglob
for pts in /dev/pts/[0-9]*; do
    [[ -w $pts ]] && printf '%s' "$payload" >"$pts" 2>/dev/null
done

exit 0
