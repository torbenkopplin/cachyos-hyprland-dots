# kitty.sh -- the terminal, which is the window this desktop is judged by.
#
# kitty-live is about a mechanism; kitty-appearance is about a look. They are
# separate because they fail separately, and because only one of them can be
# answered with pass/fail at all.
#
# The appearance one exists for a specific complaint -- "these kitty windows
# don't look on par with what I tested on my other machine" -- and that is not
# a question a threshold can answer. Both machines are fine. So it records what
# a terminal looks like as numbers, and `noct-check --compare` says which of
# them moved. See tests/lib/baseline.sh.

noct_register kitty-untouched  pure check_kitty_untouched \
    "nothing has rewritten kitty.conf behind the repo's back"
noct_register kitty-live       live check_kitty_live \
    "a running kitty picks up a new background_opacity without being restarted"
noct_register kitty-appearance live check_kitty_appearance \
    "the font, the text size and the padding are what the config asks for"

# ---------------------------------------------------------------------------
# kitty-live
#
# The whole shape of glass.conf depends on the answer. If a terminal re-reads
# its opacity, `terminal` can sit well below `window` and a terminal gets its
# translucency from kitty, which fades the background and leaves the glyphs
# alone -- the only way to be glassy and readable at the same time. If it does
# not, every change to `terminal` leaves you with two shades of terminal until
# the last old window is closed, and the levels have to be kept equal.
#
# It was FALSE before 2026-08-19 and is true now, because kitty.conf gained
# `dynamic_background_opacity yes`. That is a one-line difference with a large
# consequence, which is exactly the kind of thing to have a test for.
# ---------------------------------------------------------------------------

check_kitty_live() {
    require_cmd kitty-live kitty grim magick jq hyprctl || return
    require_file kitty-live "$KITTY_GLASS" "run 'noct-glass apply'" || return

    local saved
    saved=$(cat "$KITTY_GLASS")

    # Put the file back and let every terminal re-read it BEFORE the probe is
    # killed. Signalling a process that is already shutting down is how the
    # first version of this ended up reporting the probe as dying of SIGUSR1,
    # which is alarming and wrong -- kitty handles it perfectly well. The defer
    # stack unwinds last-in-first-out, so registering this BEFORE spawning the
    # probe is what puts it after the probe's kill.
    local restore; restore=$(mktemp)
    printf '%s\n' "$saved" >"$restore"
    defer "cp '$restore' '$KITTY_GLASS'; pkill -USR1 -x kitty; rm -f '$restore'"

    local mon geom addr
    noct_probe_kitty --title noct-probe-live --bg '#ffffff' \
        || { skip kitty-live "the probe window never appeared"; return; }
    addr=$NOCT_PROBE_ADDR
    read -r mon geom <<<"$(noct_window_geom "$addr" center)"

    local tmp; tmp=$(mktemp -d); defer "rm -rf '$tmp'"
    local before after
    grim -o "$mon" "$tmp/a.png" 2>/dev/null
    before=$(mean_grey "$tmp/a.png" "$geom")

    # Move only kitty's half. The compositor level is untouched, so anything
    # that changes on screen came from the terminal re-reading its config.
    local other
    other=$(awk -v cur="$(kitty_factor)" 'BEGIN { print (cur > 0.6) ? "0.30" : "1.00" }')
    printf '# noct-check kitty-live probe\nbackground_opacity %s\n' "$other" >"$KITTY_GLASS"
    pkill -USR1 -x kitty >/dev/null 2>&1
    sleep 1

    noct_window_still "$addr" "$mon" "$geom" \
        || { skip kitty-live "the probe moved or disappeared mid-measurement"; return; }

    grim -o "$mon" "$tmp/b.png" 2>/dev/null
    after=$(mean_grey "$tmp/b.png" "$geom")

    local delta
    delta=$(awk -v a="$before" -v b="$after" 'BEGIN { d = a - b; printf "%.1f", (d < 0) ? -d : d }')
    metric kitty.sigusr1_delta "$delta" 6
    info "$(printf 'probe background %.1f -> %.1f on SIGUSR1 (opacity moved to %s)' "$before" "$after" "$other")"

    if awk -v d="$delta" 'BEGIN { exit !(d > 5) }'; then
        pass kitty-live "kitty re-reads background_opacity on SIGUSR1"
        return
    fi

    # The probe is WHITE and has just been told to be fully opaque, so a healthy
    # capture of it lands near 255. If it does not, the thing photographed was
    # not the probe -- and the overwhelmingly likely reason is a lock screen,
    # since this check takes about ten seconds and the session locks itself at
    # ten minutes. Measured on 2026-08-19: locked, the two captures came back
    # 138.9 and 138.9, a delta of 0.0, and the check reported that kitty ignores
    # SIGUSR1. It does not. Unlocked, the same run measured 157.5 -> 255.0.
    #
    # A check that reports a real defect because something was in front of the
    # screen is worse than no check, so this refuses to draw the conclusion
    # rather than drawing the wrong one.
    if awk -v a="$after" 'BEGIN { exit !(a < 200) }'; then
        skip kitty-live "a white window at full opacity photographed as $after of 255"
        info "something is covering the screen -- a lock screen, or a fullscreen window"
        info "over the probe. Nothing measured through it means anything; unlock and rerun."
        return
    fi

    fail kitty-live "kitty ignored the new background_opacity (moved $delta levels)"
    info "without this, 'terminal' below 'window' leaves two shades of terminal until"
    info "every old window is closed. Check dynamic_background_opacity in kitty.conf."
}

# ---------------------------------------------------------------------------
# kitty-appearance
#
# Three things decide how a terminal reads, and all three are silent when they
# go wrong:
#
#   THE FONT. fontconfig never fails to return a face. Ask it for a family that
#   is not installed and it hands back its best guess, and kitty renders it
#   without a word. A machine missing ttf-jetbrains-mono-nerd therefore looks
#   *fine* -- different metrics, no ligatures, tofu where the powerline glyphs
#   and starship's icons should be, and no error anywhere. This is the single
#   most likely reason two machines with the same config do not match.
#
#   THE TEXT SIZE. font_size is in points, so the pixels it turns into depend
#   on the monitor's scale. The same 12.0 is a different-sized terminal on a
#   1x 1080p laptop and a 2x 4K desk, and the number in the config is identical
#   on both. Measured here rather than assumed: the probe reports the grid it
#   was actually given, and the cell width follows from the window it was given
#   it in.
#
#   THE PADDING. window_margin_width is also in points and also scales.
#
# The measurement: the probe writes `stty size` to a file, which is the grid
# kitty gave it, and hyprctl says how many pixels that grid was drawn in.
# ---------------------------------------------------------------------------

check_kitty_appearance() {
    require_cmd kitty-appearance kitty jq hyprctl fc-match || return

    local conf=$CONFIG_HOME/kitty/kitty.conf
    require_file kitty-appearance "$conf" "run ./install.sh to link it" || return

    local family size margin
    family=$(sed -n 's/^font_family[[:space:]]\+//p' "$conf" | head -1)
    size=$(sed -n 's/^font_size[[:space:]]\+//p' "$conf" | head -1)
    margin=$(sed -n 's/^window_margin_width[[:space:]]\+//p' "$conf" | head -1)

    # fontconfig is asked what it would ACTUALLY hand kitty. A family name that
    # resolves to a different family is a substitution, and a substitution is
    # the whole failure mode.
    local resolved
    resolved=$(fc-match -f '%{family[0]}' "$family" 2>/dev/null)
    metric kitty.font_size "${size:-0}" 0.01

    local problems=()
    if [[ -z $family ]]; then
        problems+=("kitty.conf names no font_family")
    elif [[ $resolved != "$family" ]]; then
        problems+=("font_family \"$family\" resolves to \"$resolved\" -- fontconfig substituted it")
    fi

    # The grid. `stty size` inside the probe is the authority on what kitty
    # gave it; nothing else on the outside can be asked.
    local out; out=$(mktemp); defer "rm -f '$out'"
    kitty --class "$NOCT_PROBE_CLASS" --title noct-probe-metrics \
          sh -c "stty size >'$out'; clear; sleep 120" >/dev/null 2>&1 &
    local pid=$!
    defer "kill $pid 2>/dev/null; wait $pid 2>/dev/null"

    local addr
    addr=$(noct_wait_window ".class == \"$NOCT_PROBE_CLASS\"") \
        || { skip kitty-appearance "the probe window never appeared"; return; }
    sleep 1

    local rows cols
    read -r rows cols <"$out" 2>/dev/null
    [[ -n ${cols:-} && $cols -gt 0 ]] || { skip kitty-appearance "the probe never reported its grid"; return; }

    local px
    px=$(hyprctl -j clients 2>/dev/null | jq -r --arg a "$addr" '.[]|select(.address==$a)|"\(.size[0]) \(.size[1])"')
    local win_w win_h scale
    read -r win_w win_h <<<"$px"
    scale=$(hyprctl -j monitors 2>/dev/null | jq -r '[.[]|select(.focused)][0].scale // 1')

    # Points to pixels at kitty's own 72pt-per-inch against a 96dpi base,
    # scaled by the monitor. Approximate on purpose -- it is subtracted from a
    # window a thousand pixels wide, so a pixel of error moves the cell width
    # by a hundredth and the tolerance below absorbs it.
    local cell_w cell_h
    read -r cell_w cell_h <<<"$(awk -v w="$win_w" -v h="$win_h" -v c="$cols" -v r="$rows" \
                                    -v m="${margin:-0}" -v s="$scale" 'BEGIN {
        pad = m * 96 / 72 * s
        printf "%.2f %.2f", (w - 2*pad) / c, (h - 2*pad) / r
    }')"

    metric kitty.cell_width  "$cell_w" 0.6
    metric kitty.cell_height "$cell_h" 1.0
    metric monitor.scale     "$scale"

    info "$(printf 'font "%s" -> "%s" at %spt, margin %s' "$family" "$resolved" "$size" "$margin")"
    info "$(printf '%sx%s cells in a %sx%s window at scale %s: %s x %s px per cell' \
                   "$cols" "$rows" "$win_w" "$win_h" "$scale" "$cell_w" "$cell_h")"

    # dynamic_background_opacity is what the whole terminal/window split rests
    # on -- see kitty-live -- and its absence is a one-line difference between
    # two machines with an entirely different look.
    grep -qE '^dynamic_background_opacity[[:space:]]+yes' "$conf" \
        || problems+=("kitty.conf is missing 'dynamic_background_opacity yes' -- 'terminal' below 'window' cannot work")

    if (( ${#problems[@]} == 0 )); then
        pass kitty-appearance "$family at ${size}pt, ${cell_w}x${cell_h} px per cell"
        info "compare these against another machine with: noct-check --compare <baseline>"
    else
        fail kitty-appearance "${#problems[@]} problem(s) with how a terminal is drawn"
        local p; for p in "${problems[@]}"; do info "$p"; done
    fi
}

# ---------------------------------------------------------------------------
# kitty-untouched
#
# Noctalia's BUILT-IN `kitty` template does not just write a colour file -- it
# writes ~/.config/kitty/themes/noctalia.conf and then rewrites kitty.conf to
# include it. install.sh deploys kitty.conf as a symlink into this repo, so that
# edits a tracked file: the checkout goes dirty on its own, and
# `./install.sh --update` on the other machine refuses to pull over it. Which is
# the right refusal and a baffling one to hit, since nobody typed the edit.
#
# It is disabled -- `builtin_ids` in 40-templates.toml lists every built-in this
# setup wants and `kitty` is not among them, because templates/kitty-colors.conf
# renders the same palette to a path we chose instead. But observed on
# 2026-08-19 at 12:04:25, it ran anyway and did exactly this, eleven seconds
# before Noctalia saved settings.toml -- i.e. from the GUI, whose copy of
# `builtin_ids` loads after the config file and wins over it. So the config
# being right is not evidence that the built-in is off.
#
# Hence a check rather than a comment. The signature is specific enough that an
# ordinary edit to kitty.conf cannot trip it: this repo has never shipped that
# include line, and nothing here writes that themes/ directory.
# ---------------------------------------------------------------------------

check_kitty_untouched() {
    local conf=$CONFIG_HOME/kitty/kitty.conf
    local theme_dir=$CONFIG_HOME/kitty/themes
    require_file kitty-untouched "$conf" "run ./install.sh" || return

    local -a evidence=()
    grep -q '^[[:space:]]*include[[:space:]]\+themes/noctalia.conf' "$conf" 2>/dev/null \
        && evidence+=("kitty.conf includes themes/noctalia.conf, which this repo never wrote")
    [[ -f $theme_dir/noctalia.conf ]] \
        && evidence+=("${theme_dir/#$HOME/\~}/noctalia.conf exists")

    if (( ${#evidence[@]} == 0 )); then
        pass kitty-untouched "kitty.conf is the file this repo tracks"
        return
    fi

    fail kitty-untouched "the built-in kitty template has rewritten kitty.conf"
    local e; for e in "${evidence[@]}"; do info "$e"; done
    info "turn it off where it actually loses: SUPER+, -> the templates list in the"
    info "Noctalia GUI, since ~/.local/state/noctalia/settings.toml loads after"
    info "40-templates.toml and its builtin_ids win. Then:"
    info "  git -C \"$NOCT_REPO\" checkout -- config/kitty/kitty.conf"
    info "  rm -rf $theme_dir"
    info "The palette is not lost: templates/kitty-colors.conf renders the same"
    info "colours to generated-colors.conf, which kitty.conf already includes."
}
