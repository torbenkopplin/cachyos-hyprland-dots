# fish -- interactive shell configuration.
#
# NOTE: this file is new. There was no fish config on the Ubuntu machine to
# carry over -- only kitty's `shell fish` line, showing the intent. So this is
# built from the preferences you have already stated (vim keys, quiet, keyboard
# first) rather than migrated. Nothing here is precious; edit freely.
#
# Fragments in conf.d/ are sourced automatically, before this file.

# ---------------------------------------------------------------------------
# Interactive-only
#
# Everything below is skipped for scripts and for the non-interactive shells
# that editors and tools spawn, which keeps them fast and side-effect free.
# ---------------------------------------------------------------------------

if status is-interactive

    # Vim keys at the prompt, to match the compositor, the editor and the
    # launcher. `fish_default_key_bindings` restores emacs-style if you want
    # the prompt to behave differently from everything else.
    fish_vi_key_bindings

    # Keep the cursor shape meaningful in each mode -- it is the only visual
    # cue that you are in normal mode and about to delete a line.
    set -g fish_cursor_default block
    set -g fish_cursor_insert  line
    set -g fish_cursor_visual  block
    set -g fish_cursor_replace_one underscore

    # No banner on every new terminal.
    set -g fish_greeting

    # yazi: `y` opens the file manager and, on quit, leaves the shell in
    # whatever directory you navigated to. This is yazi's own documented
    # wrapper -- without it, quitting always drops you back where you started.
    function y --description 'yazi, and cd to where you left off'
        set -l tmp (mktemp -t "yazi-cwd.XXXXXX")
        yazi $argv --cwd-file="$tmp"
        if set -l cwd (command cat -- "$tmp"); and test -n "$cwd"; and test "$cwd" != "$PWD"
            builtin cd -- "$cwd"
        end
        rm -f -- "$tmp"
    end

end
