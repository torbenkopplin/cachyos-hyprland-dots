# glass.sh -- the frosted glass, from the config file down to the pixels.
#
# Four questions, and they fail independently:
#
#   glass-config    does what was generated match what glass.conf asked for?
#   glass-live      does the running session match what was generated?
#   glass-visible   does any of it reach the screen?
#   glass-legible   what did it cost the text?
#
# The first two are cheap and static. The last two need a window, and they get
# a new one -- see tests/lib/probe.sh for why measuring a terminal you already
# had open answers a different question than the one being asked.

noct_register glass-config   pure check_glass_config \
    "the generated files agree with glass.conf"
noct_register glass-live     pure check_glass_live \
    "the running compositor agrees with the generated files"
noct_register keyword-inert  pure check_keyword_inert \
    "hyprctl keyword is still a no-op, so A/B tests must go through noct-glass"
noct_register glass-visible  live check_glass_visible \
    "the wallpaper actually reads through a new terminal"
noct_register glass-legible  live check_glass_legible \
    "text survives the opacity it is being asked to survive"
noct_register blur-stacks    live check_blur_stacks \
    "a floating window samples the window beneath it, not the wallpaper"

HYPR_GLASS=$CONFIG_HOME/hypr/generated/glass.lua
KITTY_GLASS=$CONFIG_HOME/kitty/generated-glass.conf

# The thresholds glass-visible judges against, both in levels of 255 as seen --
# i.e. after the window's opacity has already been applied to them.
#
#   LIFT      how much brighter the window is than it would be if it were
#             opaque. Below about 10 this is not a look, it is a rounding
#             error: the 0.82/brightness-0.65 combination measured 7 and read
#             as flat grey.
#   STRUCTURE the spatial variation of the backdrop, which is what makes it
#             read as a window onto something rather than as a tint. A flat
#             wash scores near 0 whatever its lift.
LIFT_MIN=${LIFT_MIN:-12}
STRUCTURE_MIN=${STRUCTURE_MIN:-4}

# The WCAG AA floor for body text. Not an aesthetic threshold -- 4.5:1 is where
# text stops being comfortable to read for people who need the contrast, and a
# desktop-wide opacity is exactly the kind of change that walks a terminal
# under it without anything looking obviously wrong.
CONTRAST_MIN=${CONTRAST_MIN:-4.5}

# The floor for glyph opacity. Contrast alone does not catch "the text looks
# faded": the compositor lifts the background at the same time as it dims the
# glyphs, so the ratio holds up while everything visibly greys out. At window
# 0.60 the ink measured 78% of the foreground and read as washed out at a
# perfectly legal 5.3:1.
GLYPH_MIN=${GLYPH_MIN:-0.80}

# lua_num <key> -- a numeric field out of the generated Lua.
lua_num() { sed -n "s/^[[:space:]]*$1[[:space:]]*=[[:space:]]*\([0-9.]*\).*/\1/p" "$HYPR_GLASS" | head -1; }

# live_num <hyprland option> -- the value the compositor is actually using.
live_num() { hyprctl getoption "$1" 2>/dev/null | sed -n 's/^\(float\|int\): //p' | head -1; }

kitty_factor() { sed -n 's/^background_opacity[[:space:]]*//p' "$KITTY_GLASS" 2>/dev/null | head -1; }

# ---------------------------------------------------------------------------

check_glass_config() {
    require_file glass-config "$HYPR_GLASS"  "run 'noct-glass apply'" || return
    require_file glass-config "$KITTY_GLASS" "run 'noct-glass apply'" || return

    local levels win term browser
    levels=$(noct_glass_levels) || { fail glass-config "noct-glass show failed"; return; }
    read -r win term browser <<<"$levels"

    metric glass.window   "$win"     0.01
    metric glass.terminal "$term"    0.01
    metric glass.browser  "$browser" 0.01
    metric blur.size       "$(lua_num size)"       0.5
    metric blur.passes     "$(lua_num passes)"     0.5
    metric blur.brightness "$(lua_num brightness)" 0.02
    metric blur.vibrancy   "$(lua_num vibrancy)"   0.02

    local lua_win ko want_ko
    lua_win=$(lua_num active_opacity)
    ko=$(kitty_factor)
    want_ko=$(awk -v t="$term" -v w="$win" 'BEGIN { f = t / w; if (f > 1) f = 1; printf "%.2f", f }')

    if ! num_eq "$lua_win" "$win"; then
        fail glass-config "glass.lua says active_opacity $lua_win, noct-glass says window $win"
        return
    fi
    if ! num_eq "$ko" "$want_ko"; then
        fail glass-config "kitty background_opacity is $ko, should be $want_ko for terminal $term / window $win"
        return
    fi
    pass glass-config "generated files agree with glass.conf (window $win  terminal $term  browser $browser)"
}

check_glass_live() {
    require_cmd glass-live hyprctl || return
    require_file glass-live "$HYPR_GLASS" "run 'noct-glass apply'" || return

    # Pairs of "generated Lua key" -> "hyprctl option". A mismatch here means
    # the session is running something other than what is on disk, which is
    # what happens when a reload is skipped or a `keyword` is believed.
    local -a keys=(active_opacity   decoration:active_opacity
                   inactive_opacity decoration:inactive_opacity
                   size             decoration:blur:size
                   passes           decoration:blur:passes
                   brightness       decoration:blur:brightness
                   vibrancy         decoration:blur:vibrancy)
    local i want got bad=()
    for ((i = 0; i < ${#keys[@]}; i += 2)); do
        want=$(lua_num "${keys[i]}")
        got=$(live_num "${keys[i+1]}")
        [[ -n $want && -n $got ]] || continue
        num_eq "$want" "$got" || bad+=("${keys[i+1]}: session $got, file $want")
    done

    if (( ${#bad[@]} == 0 )); then
        pass glass-live "the session matches generated/glass.lua"
    else
        fail glass-live "the session and the generated config disagree"
        local b; for b in "${bad[@]}"; do info "$b"; done
        info "fix: noct-glass apply (which reloads); 'hyprctl keyword' cannot do it -- see keyword-inert"
    fi
}

check_keyword_inert() {
    require_cmd keyword-inert hyprctl || return

    # Deliberately a no-op value: whatever is already in force.
    local cur reply
    cur=$(live_num decoration:active_opacity)
    [[ -n $cur ]] || { skip keyword-inert "could not read the current opacity"; return; }
    reply=$(hyprctl keyword decoration:active_opacity "$cur" 2>&1)

    if [[ $reply == *"non-legacy parsers"* ]]; then
        pass keyword-inert "hyprctl keyword is refused, as expected under the Lua config"
        info "so any A/B test must go through noct-glass, which writes the file and reloads"
    elif [[ $reply == ok ]]; then
        fail keyword-inert "hyprctl keyword now works -- the measurement could use it, and this check is obsolete"
    else
        skip keyword-inert "unrecognised reply: $reply"
    fi
}

# ---------------------------------------------------------------------------
# glass-visible -- the only check that measures what you actually see.
#
# Measured on a TILED probe. Tiled, specifically, because tiled windows do not
# overlap, so the thing behind one of them is the wallpaper and nothing else --
# which is the backdrop the whole effect is designed against. A floating probe
# would sample whatever it happened to land on (see blur-stacks, which is the
# check that this is true).
#
# White, and blank. White because what is being measured is the window moving
# between its own colour and its backdrop, and a near-black probe over a
# near-black desktop has almost nowhere to move -- measured, 5 levels, which is
# noise. The lift for the colour you actually look at is derived from the
# measurement afterwards; see noct_lift.
# ---------------------------------------------------------------------------

PROBE_WHITE=255

check_glass_visible() {
    require_cmd glass-visible grim magick hyprctl jq kitty || return
    require_file glass-visible "$KITTY_GLASS" "run 'noct-glass apply'" || return

    # Before anything is borrowed or moved.
    local win_configured term_configured
    read -r win_configured term_configured _ <<<"$(noct_glass_levels)"

    local addr
    noct_probe_kitty --class "$NOCT_PROBE_TAPE_CLASS" --title noct-probe-glass --bg '#ffffff'
    case $? in
        0) ;;
        2) skip glass-visible "the probe never came to rest anywhere measurable"; return ;;
        *) skip glass-visible "the probe window never appeared"; return ;;
    esac
    addr=$NOCT_PROBE_ADDR

    if [[ $(hyprctl -j clients | jq -r --arg a "$addr" '.[]|select(.address==$a)|.floating') == true ]]; then
        skip glass-visible "the probe landed floating -- its backdrop would not be the wallpaper"
        return
    fi

    noct_glass_borrow
    local three rc
    three=$(noct_measure_surface "$addr" center); rc=$?
    case $rc in
        0) ;;
        2) skip glass-visible "the probe would not hold still -- something is animating over it"; return ;;
        3) skip glass-visible "the probe would not stay put between captures"; return ;;
        *) skip glass-visible "a capture failed"; return ;;
    esac

    local seen seen_sd own back back_sd
    read -r seen seen_sd own back back_sd <<<"$three"

    local solved a backdrop backdrop_sd
    solved=$(noct_solve "$seen" "$own" "$back" "$back_sd")
    read -r a backdrop backdrop_sd <<<"$solved"

    # For kitty this ratio IS the effective opacity: noct-glass collapses
    # terminal onto window while an override is held, and kitty re-reads
    # background_opacity on the SIGUSR1 that follows, so the calibration
    # captures are taken with kitty at 1.00. See noct_solve.
    local scheme_bg lift structure
    scheme_bg=$(kitty_colour background) || scheme_bg=
    if [[ -z $scheme_bg ]]; then
        skip glass-visible "no generated-colors.conf -- nothing says what an opaque terminal would look like"
        return
    fi
    lift=$(noct_lift "$backdrop" "$scheme_bg" "$a")
    structure=$(noct_structure "$backdrop_sd" "$a")

    metric glass.effective_opacity "$a"           0.03
    metric glass.backdrop          "$backdrop"    10
    metric glass.lift              "$lift"        4
    metric glass.structure         "$structure"   2
    metric scheme.background       "$scheme_bg"   6

    # The raw captures, reported because every number below is derived from
    # them and a derived number that looks wrong is impossible to argue with
    # otherwise. own is the probe painted white at compositor 1.00, so on a
    # healthy session it lands within a few levels of 255.
    info "$(printf 'captures: configured %s, opaque %s, backdrop-only %s (of 255)' \
                   "$seen" "$own" "$back")"
    info "$(printf 'backdrop %s of 255 (variation %s), terminal effective opacity %s' \
                   "$backdrop" "$backdrop_sd" "$a")"
    info "$(printf 'against a scheme background of %s: lift %s (want >= %s), structure %s (want >= %s)' \
                   "$scheme_bg" "$lift" "$LIFT_MIN" "$structure" "$STRUCTURE_MIN")"

    # The effective opacity of a terminal should be the `terminal` level
    # exactly: kitty contributes terminal/window and the compositor contributes
    # window, and the two multiply back to it. A gap here means one of the two
    # is not where the file says, which glass-live and kitty-live localise.
    #
    # Compared against the levels read BEFORE the measurement started, because
    # the measurement is holding an override at 0.02 until the check ends and
    # asking noct-glass now would report that instead of the configuration.
    num_eq "$a" "$term_configured" 0.05 \
        || info "note: effective opacity $a is not the configured terminal level $term_configured -- see kitty-live"

    if awk -v l="$lift" -v s="$structure" -v lm="$LIFT_MIN" -v sm="$STRUCTURE_MIN" \
           'BEGIN { exit !(l >= lm && s >= sm) }'; then
        pass glass-visible "the wallpaper reads through a new terminal"
    else
        fail glass-visible "the frosted effect is below what the eye picks up"
        info "lift is (backdrop - own colour) x (1 - opacity): lower 'terminal' in glass.conf,"
        info "or raise blur_brightness; structure needs a SMALLER blur_size, not a brighter one."
    fi
}

# ---------------------------------------------------------------------------
# glass-legible -- what the opacity costs the text.
#
# The compositor cannot tell a window's glyphs from its background, so `window`
# fades both. Two things follow, and they are checked differently.
#
# GLYPH OPACITY is exactly `window`, by construction. Nothing to measure.
#
# CONTRAST is derived rather than sampled, and that is the whole trick here.
# Sampling it means finding "the text" in a screenshot, and there is no
# reliable way to do that: a terminal's glyphs are about 1% of its pixels and
# most of them are not the scheme's foreground. The same session scored 9.4:1
# and 4.1:1 twenty minutes apart with nothing changed but the scrollback.
#
# So: measure the background of a probe painted in the scheme's OWN background
# colour -- which is robust, being the overwhelming majority of the pixels --
# and compute the rest from numbers that are already known exactly.
#
#   seen_bg = K x ko x a + B x (1 - ko x a)        -> solve for the backdrop B
#   seen_fg = F x a + B x (1 - a)
#
# with K and F the scheme's background and foreground, ko kitty's own
# background_opacity and a the window level.
# ---------------------------------------------------------------------------

check_glass_legible() {
    require_cmd glass-legible grim magick jq hyprctl kitty || return

    local fg bg_colour ko level
    fg=$(kitty_colour foreground)        || { skip glass-legible "no generated-colors.conf to read the scheme from"; return; }
    bg_colour=$(kitty_colour background) || { skip glass-legible "no generated-colors.conf to read the scheme from"; return; }
    ko=$(kitty_factor)
    [[ -n $ko ]] || { skip glass-legible "nothing generated yet -- run 'noct-glass apply'"; return; }
    level=$(noct_glass_levels | awk '{print $1}')

    # Painted in the scheme's own background, because this check is about what
    # the scheme's own text lands on. A white probe would measure a terminal
    # nobody has.
    local scheme_hex mon geom
    scheme_hex=$(sed -n 's/^background[[:space:]]*\(#[0-9A-Fa-f]\{6\}\).*/\1/p' \
                     "$CONFIG_HOME/kitty/generated-colors.conf" | head -1)
    noct_probe_kitty --class "$NOCT_PROBE_TAPE_CLASS" --title noct-probe-legible --bg "$scheme_hex"
    case $? in
        0) ;;
        2) skip glass-legible "the probe never came to rest anywhere measurable"; return ;;
        *) skip glass-legible "the probe window never appeared"; return ;;
    esac
    read -r mon geom <<<"$(noct_window_geom "$NOCT_PROBE_ADDR" center)"

    local tmp; tmp=$(mktemp -d); defer "rm -rf '$tmp'"
    grim -o "$mon" "$tmp/legible.png" 2>/dev/null || { skip glass-legible "grim failed"; return; }
    local seen_bg
    seen_bg=$(median_grey "$tmp/legible.png" "$geom") || { skip glass-legible "the patch is too small to take a median of"; return; }

    local report
    report=$(awk -v sbg="$seen_bg" -v K="$bg_colour" -v F="$fg" -v ko="$ko" -v a="$level" '
        function lin(v,  c) { c = v / 255; return (c <= 0.03928) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
        BEGIN {
            own = ko * a                      # how much of the terminal survives
            b   = (own < 0.999) ? (sbg - K * own) / (1 - own) : 0
            sfg = F * a + b * (1 - a)
            ratio = (lin(sfg) + 0.05) / (lin(sbg) + 0.05)
            printf "%.1f %.0f %.2f", b, sfg, ratio
        }')
    local backdrop sfg ratio
    read -r backdrop sfg ratio <<<"$report"

    metric text.contrast      "$ratio" 0.6
    metric text.glyph_opacity "$level" 0.03

    info "$(printf 'background %s on a backdrop of %s, text lands at %s of a foreground of %s' \
                   "$seen_bg" "$backdrop" "$sfg" "$fg")"
    info "$(printf 'contrast %s:1 (want >= %s), glyph opacity %s (want >= %s)' \
                   "$ratio" "$CONTRAST_MIN" "$level" "$GLYPH_MIN")"

    local ok_ratio ok_glyph
    ok_ratio=$(awk -v r="$ratio" -v w="$CONTRAST_MIN" 'BEGIN { print (r >= w) ? 1 : 0 }')
    ok_glyph=$(awk -v a="$level" -v g="$GLYPH_MIN" 'BEGIN { print (a >= g) ? 1 : 0 }')

    if (( ok_ratio && ok_glyph )); then
        pass glass-legible "text is bright and readable at the configured levels"
        return
    fi

    if (( ! ok_glyph )); then
        fail glass-legible "the compositor is fading glyphs to $level, below the $GLYPH_MIN floor"
    else
        fail glass-legible "text contrast works out at ${ratio}:1, below the ${CONTRAST_MIN}:1 floor"
    fi
    info "Glyph opacity is exactly 'window' -- the compositor applies it to text and"
    info "background alike. The fix is to raise 'window' and take the glassiness out"
    info "of 'terminal' instead, which kitty applies to the background only and"
    info "costs nothing in ink."
}

# ---------------------------------------------------------------------------
# blur-stacks -- do floating windows sample what is under them?
#
# `blur.xray` on means every window blurs the WALLPAPER rather than whatever is
# beneath it. For the tape that is right -- tiled windows do not overlap. For a
# floating window it is wrong: something is deliberately underneath, and the
# translucency should compound with it.
#
# conf/rules.lua turns xray off to get that. Whether Hyprland honours it is not
# something a config file reports on -- an unknown rule key parses fine and does
# nothing, which is how this repo has been bitten before.
# ---------------------------------------------------------------------------

check_blur_stacks() {
    require_cmd blur-stacks kitty grim magick jq hyprctl || return

    # Without something tiled under where the probe lands there is nothing to
    # stack against and the comparison is vacuous.
    local tiled
    tiled=$(hyprctl -j clients 2>/dev/null \
            | jq -r '[ .[] | select(.floating == false and .size[0] > 400 and .size[1] > 400) ] | length')
    (( tiled > 0 )) || { skip blur-stacks "no tiled window for a floating probe to sit on"; return; }

    # Where a floating probe lands is conf/rules.lua's decision, so it is asked
    # rather than recomputed: spawn one, note the rectangle, kill it, and
    # photograph what was underneath before spawning the real probe there.
    local mon geom
    noct_probe_kitty --title noct-probe-rect \
        || { skip blur-stacks "the probe window never appeared"; return; }
    read -r mon geom <<<"$(noct_window_geom "$NOCT_PROBE_ADDR" center)"
    noct_unwind          # closes that probe, so the rectangle is clear again
    sleep 0.6

    local tmp under
    tmp=$(mktemp -d); defer "rm -rf '$tmp'"
    grim -o "$mon" "$tmp/under.png" 2>/dev/null
    under=$(mean_grey "$tmp/under.png" "$geom")

    # Nearly transparent, so what it shows is almost entirely its backdrop.
    # Both the colour and the opacity go on this window's command line, so they
    # apply to it and to no other -- nobody's terminal flickers to make a
    # measurement.
    local mon2 geom2
    noct_probe_kitty --title noct-probe-stack --bg '#ffffff' --opacity 0.02 \
        || { skip blur-stacks "the probe window never appeared"; return; }
    read -r mon2 geom2 <<<"$(noct_window_geom "$NOCT_PROBE_ADDR" center)"
    [[ $mon2 == "$mon" && $geom2 == "$geom" ]] \
        || { skip blur-stacks "the second probe landed somewhere else -- nothing to compare"; return; }

    grim -o "$mon" "$tmp/through.png" 2>/dev/null
    local through
    through=$(mean_grey "$tmp/through.png" "$geom")

    metric blur.stack_delta "$(awk -v u="$under" -v p="$through" 'BEGIN { d = u - p; printf "%.1f", (d < 0) ? -d : d }')" 8

    info "$(printf 'under the probe: %.1f; seen through the probe: %.1f' "$under" "$through")"

    # With xray on the probe would show the blurred wallpaper instead, which on
    # a dark desktop is a long way from the window it is covering.
    if awk -v u="$under" -v p="$through" 'BEGIN { d = u - p; if (d < 0) d = -d; exit !(d < 20) }'; then
        pass blur-stacks "a floating window samples the window beneath it"
    else
        fail blur-stacks "a floating window is not sampling what is under it"
        info "blur_xray in glass.conf must be false for the effect to stack. Note that"
        info "the per-window form does not work: Hyprland accepts \`xray\` as a window"
        info "rule and ignores it -- it is a layer rule. See conf/rules.lua."
    fi
}
