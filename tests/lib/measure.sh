# measure.sh -- reading numbers off the screen.
#
# Everything here answers one question: given a rectangle of the screen, how
# much of what you see is the window and how much is the wallpaper behind it?
#
# The arithmetic, once, since every check in the suite leans on it. A
# translucent window composites as
#
#   seen = own x a + backdrop x (1 - a)
#
# with `a` the effective opacity -- whoever supplies it, compositor or
# application. Three unknowns, so three captures at two known compositor levels
# pin the whole line down:
#
#   own    = the window at compositor 1.00. Nothing shows through, so this is
#            the window's own colour.
#   back   = the window at compositor 0.02. Almost everything shows through, so
#            this is very nearly the backdrop. The residual 2% is taken back
#            out below rather than ignored -- at a dark scheme it is worth a
#            level and a half.
#   seen   = the window as configured. This is the one that answers the
#            question; the other two only calibrate it.
#
# and then
#
#   a    = (seen - back) / (own - back)
#   lift = seen - own                     how much brighter than opaque
#
# `lift` is the number that decides whether an effect is visible. `a` is the
# number that decides whether two windows read as the same material. They are
# different questions and both are checked.

# ---------------------------------------------------------------------------
# Reading a patch
# ---------------------------------------------------------------------------

# patch_stats <png> <geometry> -- mean and standard deviation, in levels of 255.
#
# The standard deviation is not decoration. It is how much SHAPE survives the
# blur, and shape is the difference between a window that reads as glass and
# one that reads as paint. A flat wash and a photograph can have identical
# means.
patch_stats() {
    magick "$1" -crop "$2" +repage -colorspace Gray \
        -format '%[fx:mean*255] %[fx:standard_deviation*255]' info: 2>/dev/null
}

mean_grey() {
    magick "$1" -crop "$2" +repage -colorspace Gray -format '%[fx:mean*255]' info: 2>/dev/null
}

# median_grey <png> <geometry> -- the p50 grey of a patch.
#
# The median, and only the median. A terminal's background is the overwhelming
# majority of its pixels, so p50 lands on it whatever is being displayed --
# which makes it the one thing here that can be read off an arbitrary screen
# and trusted. A mean moves with the content; a median does not.
median_grey() {
    magick "$1" -crop "$2" +repage -colorspace Gray -depth 8 gray:- 2>/dev/null \
        | od -An -v -tu1 | tr -s ' ' '\n' | sed '/^$/d' | sort -n \
        | awk '{ v[NR] = $1 } END { if (NR < 10000) exit 1; printf "%d", v[int(NR*0.50)+1] }'
}

# capture_stable <monitor> <geometry> <tmp prefix>
#
# Two captures that agree, or nothing. A terminal scrolling or a cursor
# blinking mid-measurement is the difference between a number and a guess, and
# a guess here is worse than a skip: it is a confident wrong answer about how
# the desktop looks.
#
# Prints "<mean> <sd>". Returns 1 if grim failed, 2 if the surface would not
# hold still after three tries.
capture_stable() {
    local mon=$1 geom=$2 out=$3 a b i
    for i in 1 2 3; do
        grim -o "$mon" "$out.1.png" 2>/dev/null || return 1
        grim -o "$mon" "$out.2.png" 2>/dev/null || return 1
        a=$(patch_stats "$out.1.png" "$geom")
        b=$(patch_stats "$out.2.png" "$geom")
        if awk -v x="${a%% *}" -v y="${b%% *}" 'BEGIN { d = x - y; if (d < 0) d = -d; exit !(d < 1.0) }'; then
            printf '%s' "$a"
            return 0
        fi
        sleep 0.5
    done
    return 2
}

# ---------------------------------------------------------------------------
# The compositor level, as a measuring instrument
#
# `hyprctl keyword` is inert under the Lua config -- see the keyword-inert
# check -- so the only way to move the window level is to write the file and
# reload, which is what noct-glass does. That makes it slow and visible, and it
# is why everything that needs a calibrated measurement takes all three
# captures in one pass rather than each check doing its own.
# ---------------------------------------------------------------------------

NOCT_STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
NOCT_OVERRIDE_FILE=$NOCT_STATE_HOME/noctalia/glass-override

# noct_glass_borrow -- take control of the window level, and register putting it
# back. Everything after this can call noct_glass_set freely.
#
# Restoring is not the same as re-applying: `noct-glass apply` CLEARS the
# override before it applies, so writing the file and then calling apply loses
# the very thing it was restoring. `set` is the command that means "this level,
# and remember it".
NOCT_GLASS_RESTORE=

noct_glass_borrow() {
    if [[ -f $NOCT_OVERRIDE_FILE ]]; then
        NOCT_GLASS_RESTORE="set $(cat "$NOCT_OVERRIDE_FILE")"
    else
        NOCT_GLASS_RESTORE=apply
    fi
    defer "\"$NOCT_GLASS\" $NOCT_GLASS_RESTORE"
}

# noct_glass_reset -- back to the level that was in force when it was borrowed,
# without giving it back. A check measuring several windows in turn has to
# return to the CONFIGURED level before each one, because the first capture of
# every measurement is the one that answers the question and the other two only
# calibrate it.
noct_glass_reset() {
    [[ -n $NOCT_GLASS_RESTORE ]] || return 0
    # shellcheck disable=SC2086
    "$NOCT_GLASS" $NOCT_GLASS_RESTORE >/dev/null 2>&1
    sleep 1
}

noct_glass_set() {  # <level>
    "$NOCT_GLASS" set "$1" >/dev/null 2>&1
    # The compositor reloads asynchronously. A capture taken too early measures
    # the previous level and the whole solve comes out wrong in a way that
    # looks like a plausible number rather than an error.
    sleep 1
}

# noct_glass_levels -- "window terminal browser" from the config in force.
noct_glass_levels() {
    "$NOCT_GLASS" show 2>/dev/null | awk '{print $2, $4, $6}'
}

# ---------------------------------------------------------------------------
# The three-point measurement
# ---------------------------------------------------------------------------

# noct_measure_surface <window address> <center|page>
#
# Prints "seen_mean seen_sd own_mean back_mean back_sd". Returns
#   2  the surface would not hold still
#   3  the window would not come back to where it was between captures
#
# The caller must have called noct_glass_borrow first. That is deliberate: it
# puts the "and put it back" in the caller's defer stack, where it survives the
# caller failing for some other reason.
#
# Why the window is re-settled between captures
# ---------------------------------------------
# Changing the level means writing the generated config and calling `hyprctl
# reload`, and a reload re-lays out the tape -- so the window is quite likely
# somewhere else by the time the next capture is taken. The three captures have
# to be of the SAME rectangle of wallpaper or the arithmetic is comparing three
# different backdrops, and the failure looks like a plausible number rather
# than an error.
#
# Focusing the window scrolls the tape back to it, deterministically, so
# re-settling after each change puts it back where it was. If it does not come
# back to exactly the same geometry the measurement is abandoned rather than
# reported: this is the check that catches the whole class of "measured a
# different thing each time".
noct_measure_surface() {
    local addr=$1 shape=${2:-center}
    local tmp geom0 geom mon seen own back rc

    geom0=$(noct_window_geom "$addr" "$shape")
    [[ -n $geom0 ]] || return 3
    mon=${geom0%% *}; geom=${geom0#* }

    # Cleaned up here rather than deferred: this function is called from a
    # command substitution, and a subshell's defer stack is discarded with the
    # subshell. Nothing it leaves behind would ever be unwound.
    tmp=$(mktemp -d)

    seen=$(capture_stable "$mon" "$geom" "$tmp/seen"); rc=$?
    (( rc != 0 )) && { rm -rf "$tmp"; return $rc; }

    noct_glass_set 1.00
    noct_window_settle "$addr" "$shape" || { rm -rf "$tmp"; return 3; }
    [[ $(noct_window_geom "$addr" "$shape") == "$geom0" ]] || { rm -rf "$tmp"; return 3; }
    own=$(capture_stable "$mon" "$geom" "$tmp/own"); rc=$?
    (( rc != 0 )) && { rm -rf "$tmp"; return $rc; }

    noct_glass_set 0.02
    noct_window_settle "$addr" "$shape" || { rm -rf "$tmp"; return 3; }
    [[ $(noct_window_geom "$addr" "$shape") == "$geom0" ]] || { rm -rf "$tmp"; return 3; }
    back=$(capture_stable "$mon" "$geom" "$tmp/back"); rc=$?
    (( rc != 0 )) && { rm -rf "$tmp"; return $rc; }

    rm -rf "$tmp"
    printf '%s %s %s' "$seen" "${own%% *}" "$back"
}

# noct_solve <seen_mean> <own_mean> <back_mean> <back_sd>
#
# Prints "ratio backdrop backdrop_sd".
#
#   backdrop   the blurred wallpaper behind the window, with the 0.02 residual
#              taken back out. The same number for every window on a monitor,
#              which is what makes it worth recording: two machines whose
#              terminals measure differently, with backdrops 40 levels apart,
#              have a wallpaper difference and not a config difference.
#
#   ratio      (seen - backdrop) / (own - backdrop).
#
# What `ratio` MEANS depends on the window, and this is the one piece of
# arithmetic in the suite that is easy to get wrong, so it is spelled out.
#
# Write the window's own paint as colour C at its own alpha `s`, over the
# compositor level w:
#
#   seen = C x s x w + backdrop x (1 - s x w)
#
# The two calibration captures are taken at w = 1 and w = 0.02, and `ratio` is
# the position of `seen` on the line between them. So:
#
#   * If `s` is 1 during the calibration captures, `own` is C itself and the
#     ratio comes out as s x w -- the EFFECTIVE opacity, everything included.
#     That is the kitty case, and not by luck: noct-glass collapses terminal
#     and browser onto the window level whenever an override is in force, and
#     kitty re-reads background_opacity on the SIGUSR1 that follows. So while
#     this suite is holding the level, kitty is at 1.00 by construction.
#
#   * If `s` does not move -- because the application read its configuration
#     once, at startup, and this suite has not restarted it -- then `own`
#     already contains `s`, it cancels, and the ratio comes out as w alone: the
#     COMPOSITOR level and nothing about the application. That is every
#     Firefox-family browser, which reads userChrome.css exactly once.
#
# Both are useful and neither is the other. The caller knows which case it is
# in and names the result accordingly; noct_alpha_own below is how the second
# case recovers `s` when the colour C is known from the file that set it.
noct_solve() {
    awk -v sm="$1" -v k="$2" -v bm="$3" -v bsd="$4" 'BEGIN {
        b = (bm - 0.02 * k) / 0.98
        span = k - b
        # Degenerate when the window and its backdrop are the same colour:
        # there is then nothing to divide by and any ratio is built out of
        # noise. Reported as 1, which reads as "opaque" -- the safe direction,
        # since it fails a translucency check rather than passing one.
        r = (span > 1 || span < -1) ? (sm - b) / span : 1
        if (r < 0) r = 0
        if (r > 1) r = 1
        printf "%.2f %.1f %.1f", r, b, bsd / 0.98
    }'
}

# noct_alpha_own <own_mean> <backdrop> <own colour, 0..255>
#
# The application's OWN alpha, for a window whose paint colour is known because
# this repo wrote it. own = C x s + backdrop x (1 - s), so s falls straight out.
# Returns 1 if the colour and the backdrop are too close to divide by.
noct_alpha_own() {
    awk -v own="$1" -v b="$2" -v c="$3" 'BEGIN {
        span = c - b
        if (span < 1 && span > -1) exit 1
        s = (own - b) / span
        if (s < 0) s = 0
        if (s > 1) s = 1
        printf "%.2f", s
    }'
}

# noct_lift <backdrop> <window own colour> <effective opacity>
#
# What the frosted effect is worth, in levels of 255:
#
#   lift = (backdrop - own colour) x (1 - effective opacity)
#
# Derived rather than measured, and deliberately. Measuring it means measuring
# a window painted in the scheme's own near-black background, which over a dark
# desktop has almost nowhere to move: that measured 5 levels once and was
# indistinguishable from noise. The two hard quantities -- the backdrop and the
# effective opacity -- are measured off a WHITE probe, where the signal is
# large, and the lift for the colour you actually use follows exactly.
noct_lift() {
    awk -v b="$1" -v c="$2" -v a="$3" 'BEGIN { printf "%.1f", (b - c) * (1 - a) }'
}

# noct_structure <backdrop sd> <effective opacity>
#
# How much of the wallpaper's SHAPE reaches the eye. A window can have plenty
# of lift and still read as paint rather than glass: at blur size 32 / passes 4
# the backdrop's spatial variation fell to 20 levels, which after the window's
# opacity arrived as 2, and every window looked like a flat grey card.
noct_structure() {
    awk -v sd="$1" -v a="$2" 'BEGIN { printf "%.1f", sd * (1 - a) }'
}

# ---------------------------------------------------------------------------
# Colours
# ---------------------------------------------------------------------------

# hex_grey <rrggbb> -- the luma of a hex colour, 0..255, ITU-R BT.601.
hex_grey() {
    local hex=${1#\#}
    printf '%d' "$(( (0x${hex:0:2} * 299 + 0x${hex:2:2} * 587 + 0x${hex:4:2} * 114) / 1000 ))"
}

# kitty_colour <foreground|background> -- that palette entry as a grey level,
# read from what the scheme actually rendered rather than from the palette
# source, so a template that failed to render shows up as a skip.
kitty_colour() {
    local hex
    hex=$(sed -n "s/^$1[[:space:]]*#\([0-9A-Fa-f]\{6\}\).*/\1/p" \
              "$CONFIG_HOME/kitty/generated-colors.conf" 2>/dev/null | head -1)
    [[ -n $hex ]] || return 1
    hex_grey "$hex"
}

# contrast_ratio <grey a> <grey b> -- WCAG contrast between two grey levels.
contrast_ratio() {
    awk -v x="$1" -v y="$2" '
        function lin(v,  c) { c = v / 255; return (c <= 0.03928) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
        BEGIN {
            a = lin(x) + 0.05; b = lin(y) + 0.05
            printf "%.2f", (a > b) ? a / b : b / a
        }'
}

# num_eq <a> <b> [epsilon] -- equal to two decimals, the precision everything
# in the generated configs is written at.
num_eq() { awk -v a="$1" -v b="$2" -v e="${3-0.005}" 'BEGIN { exit !(a - b < e && b - a < e) }'; }
