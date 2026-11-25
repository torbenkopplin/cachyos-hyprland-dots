# bar.sh -- the bar is only ever on screen because something asked for it.
#
# lib/bar.lua has three reasons to show it (a Noctalia panel, SUPER+B, the
# pointer at the top edge) and one way to hide it, and the failure this guards is
# the one that was actually reported: a bar that gets stuck on for no apparent
# reason and cannot be talked down.
#
# Measured in PIXELS, and that is not incidental. The obvious indicator is the
# layer's geometry, and it is wrong: with auto_hide off, hiding the bar changes
# neither the layer's size nor its position nor its alpha, and it stays mapped --
# `hyprctl layers` reports `xywh: 1090 250 3420 30, a: 1` whether the bar is on
# screen or not. Noctalia simply stops drawing it. An hour went into a state
# machine that "passed" against that reading; the only honest signal is whether
# the pixels changed.
#
# Relative rather than absolute, too: the bar is a glass pill over whatever
# window happens to be behind, so there is no absolute grey that means "shown".
# What means shown is that the same patch looks different with it than without.

noct_register bar-hot-edge live check_bar_hot_edge \
    "the pointer at the top edge reveals the bar, and leaving retracts it"

noct_register bar-pill-config pure check_bar_pill_config \
    "10-bar.toml draws one pill the layer rule will blur, and the Settings UI is not overriding it"

noct_register bar-pill live check_bar_pill \
    "the bar is one centred pill, narrower than the screen, translucent and blurred"

# Geometry of the bar layer on the monitor the cursor is on, as "X,Y WxH" for
# grim, or empty if there is not one.
bar_layer_geom() {
    local mon; mon=$(hyprctl -j monitors 2>/dev/null | jq -r '.[]|select(.focused)|.name')
    # Keyed on the FOCUSED monitor rather than whichever layer happens to be
    # first: the two bars are different widths, and picking one at random makes
    # the measurement depend on enumeration order.
    hyprctl -j layers 2>/dev/null | jq -r --arg m "$mon" '
        to_entries[] | select(.key == $m) | .value.levels | to_entries[] | .value[]
        | select(.namespace | startswith("noctalia-bar-"))
        | "\(.x),\(.y) \(.w)x\(.h)"' 2>/dev/null | head -1
}

check_bar_hot_edge() {
    require_cmd bar-hot-edge hyprctl jq grim magick || return
    have_eval || { skip bar-hot-edge "this Hyprland has no 'hyprctl eval' to read the config's state with"; return; }

    # Switched off deliberately is not a failure. The option is the authority on
    # whether the poll exists at all, so read it rather than inferring it from a
    # bar that never moves.
    if ! grep -qE '^BAR_HOT_EDGE[[:space:]]*=[[:space:]]*true' \
            "$NOCT_REPO/config/hypr/conf/options.lua" 2>/dev/null; then
        skip bar-hot-edge "BAR_HOT_EDGE is off in conf/options.lua -- the bar is keyboard-only by choice"
        return
    fi

    local geom; geom=$(bar_layer_geom)
    [[ -n $geom ]] || { skip bar-hot-edge "no noctalia bar layer on screen -- is the shell running?"; return; }

    # The patch: inside the bar, away from its rounded ends.
    local bx by bw bh
    bx=${geom%%,*}; by=${geom#*,}; by=${by%% *}
    bw=${geom##* }; bh=${bw#*x}; bw=${bw%%x*}
    if (( bw < 200 || bh < 8 )); then
        skip bar-hot-edge "the bar layer is ${bw}x${bh} -- too small to sample"
        return
    fi
    # The whole bar strip, compared as an IMAGE between states.
    #
    # Two earlier designs failed here, and both failed the same way -- by assuming
    # where the content is. One patch in the middle worked until the capsules moved
    # to start/centre/end and the centred one got narrower than the patch (1.4
    # levels, a working bar called broken). Five patches spread across worked no
    # better: four of them sit in the gaps between capsules and never change at all.
    #
    # Diffing the whole strip assumed nothing, and that held for as long as the
    # bar's content was spread across it. It is not any more (decision 028): the
    # bar is one pill in the centre that is as wide as its content, so the same
    # pill is a fifth of a 1920px strip and a tenth of a 4096px one, and the
    # share of the strip that changes falls with the monitor's width. Measured
    # 2026-11-15 on 1920: 5.0% of the whole strip changed -- exactly on the
    # threshold below -- and 18% of a 600px window around the centre.
    #
    # So the window. The pill is centred by construction, which is the one thing
    # about where the content is that this form guarantees, and a fixed window
    # around the centre holds the same pill on every monitor.
    local tmp; tmp=$(mktemp -d); defer "rm -rf '$tmp'"

    local win=600
    (( win > bw )) && win=$bw
    local strip="$(( bx + (bw - win) / 2 )),$by ${win}x${bh}"

    # Where the pointer was, so it can be put back.
    local keepx keepy
    read -r keepx keepy < <(hyprctl cursorpos 2>/dev/null | tr -d ',' )

    warp() { hyprctl dispatch "hl.dsp.cursor.move({ x = $1, y = $2 })" >/dev/null 2>&1; sleep 0.9; }
    shot() { grim -g "$strip" "$tmp/$1.png" 2>/dev/null; }

    # Percentage of the strip whose pixels changed by more than ~12/255.
    #
    # A mean over the difference image is the wrong statistic: the capsules cover
    # about two thirds of the 1060px portrait strip but only a fifth of the 3420px
    # one, so the same working reveal means 7 on one monitor and 3 on the other,
    # and any threshold that fits both fits neither. How MUCH of the strip changed
    # is the same question without the dilution -- and it also ignores a clock
    # digit ticking between captures, which is well under one percent of the area.
    diffpct() {
        magick "$tmp/$1.png" "$tmp/$2.png" -compose difference -composite \
            -colorspace Gray -threshold 5% -format '%[fx:mean*100]' info: 2>/dev/null
    }

    # Somewhere in the middle of the monitor: not the edge, so nothing is asking.
    local mtop
    mtop=$(hyprctl -j monitors 2>/dev/null | jq -r '.[]|select(.focused)|.y')
    local midy=$(( mtop + 400 ))
    local edgey=$(( mtop + 3 ))
    local centrex=$(( bx + bw / 2 ))

    # A known starting state, and not just "wait and hope". lib/bar.lua only sends
    # anything on a transition, so a bar left visible by something outside it --
    # a stray `noctalia msg bar-show`, say -- would still be visible here and the
    # reveal would measure zero change. Toggling the pin twice runs apply(force)
    # twice and ends with nothing wanting the bar, which is the baseline we need.
    warp "$centrex" "$midy"
    hyprctl eval 'require("lib.bar").toggle_pin()' >/dev/null 2>&1; sleep 0.6
    hyprctl eval 'require("lib.bar").toggle_pin()' >/dev/null 2>&1; sleep 1.0

    shot away || { skip bar-hot-edge "grim could not capture the bar region"; return; }
    warp "$centrex" "$edgey"; shot atedge
    warp "$centrex" "$midy";  shot back

    [[ -n $keepx && -n $keepy ]] && warp "$keepx" "$keepy"

    local d_reveal d_restore
    d_reveal=$(diffpct away atedge)
    d_restore=$(diffpct away back)

    metric bar.reveal_pct "$d_reveal" 8

    info "$(printf 'percent of the bar strip that changed: at the top edge %.1f%%, after leaving %.1f%%' \
                   "$d_reveal" "$d_restore")"

    local -a problems=()
    awk -v d="$d_reveal" 'BEGIN { exit !(d >= 5) }' \
        || problems+=("the pointer at the top edge changed only $d_reveal% of the bar strip -- it did not reveal")
    awk -v d="$d_restore" 'BEGIN { exit !(d < 5) }' \
        || problems+=("after moving away $d_restore% of the strip still differs from the hidden state -- it did not retract")

    if (( ${#problems[@]} == 0 )); then
        pass bar-hot-edge "the top edge reveals the bar ($d_reveal% of the strip changes) and leaving puts it back"
    else
        fail bar-hot-edge "${#problems[@]} finding(s) about the bar's hot edge"
        local p; for p in "${problems[@]}"; do info "$p"; done
        info ""
        info "BAR_HOT_EDGE in conf/options.lua switches this off deliberately -- if it is"
        info "false, this check should be skipped rather than failed. Otherwise: lib/bar.lua"
        info "polls hl.get_cursor_pos() on an hl.timer, reveals within HOT_EDGE_REVEAL_PX of"
        info "the monitor's top, and holds until the pointer passes HOT_EDGE_KEEP_PX so the"
        info "bar does not vanish as you reach for it."
    fi
}

# ---------------------------------------------------------------------------
# bar-pill-config -- the pill as configured, without touching the screen.
#
# Two ways for the pill to break that look like working config:
#
#   * its opacity drifts to or below conf/rules.lua's ignore_alpha. Hyprland
#     blurs only the parts of a layer above that alpha, so a pill at 0.45 is an
#     error nowhere -- it is tinted clear glass with the windows sharp behind
#     it. At 1.0 it is paint. The two numbers live in two programs' configs, and
#     this is the one place both are read.
#
#   * the Settings UI saves to settings.toml in the state dir, which loads AFTER
#     every file in ~/.config/noctalia. One visit to the bar's page and
#     10-bar.toml is overridden for every key the page touched, whole
#     capsule_group lists included -- which is how the brightness widget went
#     missing on 2026-11-15: the GUI's copy of the status group predated it.
# ---------------------------------------------------------------------------

check_bar_pill_config() {
    require_cmd bar-pill-config python3 || return
    local bar=$NOCT_REPO/config/noctalia/10-bar.toml
    local rules=$NOCT_REPO/config/hypr/conf/rules.lua
    local settings=${XDG_STATE_HOME:-$HOME/.local/state}/noctalia/settings.toml
    local design=${XDG_CONFIG_HOME:-$HOME/.config}/noctalia/90-design.toml
    require_file bar-pill-config "$bar"   "this checkout has no bar config"   || return
    require_file bar-pill-config "$rules" "this checkout has no layer rules" || return

    local ignore
    ignore=$(sed -n '/name *= *"noctalia-surfaces"/,/})/s/.*ignore_alpha *= *\([0-9.]*\).*/\1/p' "$rules" | head -1)
    if [[ -z $ignore ]]; then
        fail bar-pill-config "conf/rules.lua sets no ignore_alpha on the noctalia-surfaces rule"
        info "Without it the whole invisible surface is blurred, not just the pill: a"
        info "full-width frosted strip across the top of the screen."
        return
    fi

    local out
    out=$(python3 -I - "$bar" "$settings" "$ignore" "$design" <<'PY'
import os, sys, tomllib

bar_path, settings_path, ignore, design_path = sys.argv[1], sys.argv[2], float(sys.argv[3]), sys.argv[4]

def problem(msg):
    print(msg)

with open(bar_path, "rb") as f:
    bar = tomllib.load(f).get("bar", {}).get("default", {})

# The active design (noct-design) loads after 10-bar.toml; its capsule_group
# list replaces the tracked one whole.
if os.path.exists(design_path):
    with open(design_path, "rb") as f:
        bar = {**bar, **tomllib.load(f).get("bar", {}).get("default", {})}

bg = bar.get("background_opacity", 1.0)
if bg != 0:
    problem(f"background_opacity is {bg}: the surface spans the monitor, so anything "
            f"above 0 is a full-width slab behind the pill")

if bar.get("start") or bar.get("end"):
    problem("the start and end lanes are not empty: the pill is the centre lane and nothing else")

centre = bar.get("center", [])
groups = {g.get("id"): g for g in bar.get("capsule_group", [])}
if len(centre) != 1 or not str(centre[0]).startswith("group:"):
    problem(f"the centre lane is {centre}: it should be exactly one capsule group, "
            f"which is what draws the pill")
else:
    pill = groups.get(centre[0][len("group:"):])
    if pill is None:
        problem(f"{centre[0]} names no capsule_group, so Noctalia drops it and draws nothing")
    else:
        op = pill.get("opacity", 1.0)
        if not bar.get("compositor_blur", True):
            # A solid design: nothing is blurred, so anything below 1 is clear glass.
            if op != 1:
                problem(f"the pill's opacity is {op} with compositor_blur off: "
                        f"the windows behind it show through sharp")
        elif not ignore < op < 1:
            problem(f"the pill's opacity is {op}. It has to be above conf/rules.lua's "
                    f"ignore_alpha ({ignore}), or Hyprland stops blurring it, and below 1, "
                    f"or it is paint")

if not bar.get("dead_zone", {}).get("click_through", False):
    problem("dead_zone.click_through is off: while the bar is up, the invisible surface "
            "takes every click across the top of the screen")

if os.path.exists(settings_path):
    with open(settings_path, "rb") as f:
        gui = tomllib.load(f).get("bar", {})
    for name, table in gui.items():
        if isinstance(table, dict) and table:
            problem(f"the Settings UI overrides [bar.{name}] ({', '.join(sorted(table))}) "
                    f"in {settings_path}, which loads after 10-bar.toml and wins")
PY
) || { fail bar-pill-config "could not read the bar config: $out"; return; }

    local -a problems=()
    local line
    while IFS= read -r line; do
        [[ -n $line ]] && problems+=("$line")
    done <<<"$out"

    if (( ${#problems[@]} == 0 )); then
        pass bar-pill-config "one capsule group in the centre, its opacity right for its blur (ignore_alpha $ignore), nothing overriding it"
        return
    fi

    fail bar-pill-config "${#problems[@]} finding(s) about the bar's config"
    local p; for p in "${problems[@]}"; do info "$p"; done
    info ""
    info "A Settings UI override goes by deleting its [bar.*] tables, capsule_group"
    info "entries included, from that file. Close the Settings window first, so its"
    info "copy is not saved back over the edit."
}

# ---------------------------------------------------------------------------
# bar-pill -- the pill on screen: where it is, how wide, and what it is made of.
#
# Measured over a backdrop the check brings with it, because the real one is
# the worst there is: a dark pill over a dark wallpaper and dark window tops
# moves almost nothing, and has no shape behind it for a blur to remove. So a
# probe window goes across the top of the monitor, under the bar, and is
# painted twice:
#
#   striped  black and white bars a character cell wide (a block and a space),
#            which is exactly what a blur exists to remove;
#   plain    the probe's own background, flat.
#
# The bar is captured hidden and shown over each. The pill composites as
#
#   seen = fill x a + blur(backdrop) x (1 - a)
#
# so across the two backdrops the fill cancels out, and
#
#   a    = 1 - (striped_seen - plain_seen) / (striped_back - plain_back)
#   blur = sd(striped_seen) / (sd(striped_back) x (1 - a))
#
# `blur` is how much of the stripes' contrast survives, against what an
# UNBLURRED pill at that opacity would let through: about 1 means Hyprland is
# not blurring it, well under 1 means it is. Both are read in a band along the
# top of the pill -- inside the border, above the glyphs -- so no text averages
# into either number.
#
# The plain pair also finds the pill. A dark pill over a flat bright probe moves
# every column it covers by a hundred levels or more and nothing else, so its
# ends are where the difference stops. A "pill" that reaches the ends of the
# strip is the full-width slab this form replaced.
# ---------------------------------------------------------------------------

check_bar_pill() {
    require_cmd bar-pill kitty grim magick jq hyprctl || return
    have_eval || { skip bar-pill "this Hyprland has no 'hyprctl eval' to pin the bar with"; return; }

    # With no blur anywhere there is nothing to measure, and a "not blurred"
    # verdict would be about noct-glass's switch rather than about the bar.
    if [[ $(sed -n 's/.*enabled[[:space:]]*=[[:space:]]*\(true\|false\).*/\1/p' "$HYPR_GLASS" 2>/dev/null | head -1) == false ]]; then
        skip bar-pill "the blur is off (nothing is translucent) -- there is no blur to measure"
        return
    fi

    local geom; geom=$(bar_layer_geom)
    [[ -n $geom ]] || { skip bar-pill "no noctalia bar layer on screen -- is the shell running?"; return; }
    local bx by bw bh
    bx=${geom%%,*}; by=${geom#*,}; by=${by%% *}
    bw=${geom##* }; bh=${bw#*x}; bw=${bw%%x*}

    # The focused monitor in layout pixels, as it sits on the desk: a
    # quarter-turn swaps the axes and the scale divides them (lib/nav.lua).
    local mx my mw
    read -r mx my mw < <(hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused)
        | (if ((.transform // 0) % 2) == 1 then .height else .width end) as $w
        | "\(.x) \(.y) \(($w / .scale) | floor)"')
    [[ -n $mw ]] || { skip bar-pill "no focused monitor to measure on"; return; }

    local tmp; tmp=$(mktemp -d); defer "rm -rf '$tmp'"

    # The probe paints when it is told to, not when it starts: the float rule
    # opens it at 900px, and stripes laid out for that would stop short of a
    # wider monitor's ends. Each step waits for a file to appear in $tmp.
    #
    # The first row has to start at the window's very top edge, or the band the
    # material is read from sits over blank probe. Three settings stand in the
    # way, and the first run tripped on the third: the padding, the default
    # placement strategy (it centres the grid), and kitty.conf's own
    # window_margin_width 11.75, which is a MARGIN, not padding -- 16px of blank
    # above the stripes with the padding already at zero.
    kitty --class "$NOCT_PROBE_CLASS" --title noct-probe-pill \
        -o background=#ffffff -o foreground=#000000 \
        -o window_padding_width=0 -o window_margin_width=0 \
        -o placement_strategy=top-left -o cursor_blink_interval=0 \
        sh -c '
            printf "\033[?25l"
            until [ -e "$1/stripes" ]; do sleep 0.1; done
            set -- "$1" $(stty size)
            row=""; i=0
            while [ "$i" -lt $(( $3 / 2 )) ]; do row="$row█ "; i=$((i + 1)); done
            clear; i=1
            while [ "$i" -lt "$2" ]; do printf "%s\n" "$row"; i=$((i + 1)); done
            until [ -e "$1/plain" ]; do sleep 0.1; done
            clear
            exec sleep 120' sh "$tmp" >/dev/null 2>&1 &
    local pid=$!
    defer "kill $pid 2>/dev/null; wait $pid 2>/dev/null"

    local addr
    addr=$(noct_wait_window ".class == \"$NOCT_PROBE_CLASS\" and (.title // \"\") == \"noct-probe-pill\"") \
        || { skip bar-pill "the probe window never appeared"; return; }

    hyprctl dispatch "hl.dsp.window.resize({ x = $mw, y = 120, window = \"address:$addr\" })" >/dev/null 2>&1
    hyprctl dispatch "hl.dsp.window.move({ x = $mx, y = $my, window = \"address:$addr\" })" >/dev/null 2>&1
    sleep 1
    local at
    at=$(hyprctl -j clients 2>/dev/null | jq -r --arg a "$addr" \
        '.[] | select(.address == $a) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')
    if [[ $at != "$mx,$my ${mw}x120" ]]; then
        skip bar-pill "the probe would not go across the top of the monitor (it is at $at)"
        return
    fi

    # The pointer well away from the hot edge, and back where it was afterwards.
    local keepx keepy
    read -r keepx keepy < <(hyprctl cursorpos 2>/dev/null | tr -d ',')
    [[ -n $keepx && -n $keepy ]] \
        && defer "hyprctl dispatch 'hl.dsp.cursor.move({ x = $keepx, y = $keepy })'"
    hyprctl dispatch "hl.dsp.cursor.move({ x = $(( mx + mw / 2 )), y = $(( my + 400 )) })" >/dev/null 2>&1

    # A known start, as in bar-hot-edge: two toggles of the pin leave nothing
    # wanting the bar. After that each toggle is one show or one hide.
    local pin='require("lib.bar").toggle_pin()'
    hyprctl eval "$pin" >/dev/null 2>&1; sleep 0.6
    hyprctl eval "$pin" >/dev/null 2>&1; sleep 1.0

    local strip="$bx,$by ${bw}x${bh}"
    _bar_pill_pair() {  # <name> -- the strip with the bar hidden, then shown
        grim -g "$strip" "$tmp/$1-hidden.png" 2>/dev/null || return 1
        hyprctl eval "$pin" >/dev/null 2>&1; sleep 1.0
        grim -g "$strip" "$tmp/$1-shown.png" 2>/dev/null || return 1
        hyprctl eval "$pin" >/dev/null 2>&1; sleep 1.0
    }

    # Wait for the paint to be on screen rather than for a fixed time. A fixed
    # 0.8s was not enough on the first run: the hidden capture was still plain
    # and the stripes arrived in time for the shown one, which read as a pill
    # with nothing behind it to measure.
    _bar_pill_backdrop() {  # <striped|plain> -- wait until the strip looks like it
        local i sd
        for (( i = 0; i < 20; i++ )); do
            grim -g "$strip" "$tmp/wait.png" 2>/dev/null || return 1
            sd=$(magick "$tmp/wait.png" -colorspace Gray -format '%[fx:standard_deviation*255]' info: 2>/dev/null)
            if [[ $1 == striped ]]; then
                awk -v s="$sd" 'BEGIN { exit !(s > 30) }' && return 0
            else
                awk -v s="$sd" 'BEGIN { exit !(s < 10) }' && return 0
            fi
            sleep 0.25
        done
        return 1
    }

    touch "$tmp/stripes"
    _bar_pill_backdrop striped || { skip bar-pill "the probe never showed its stripes"; return; }
    _bar_pill_pair striped     || { skip bar-pill "grim could not capture the bar strip"; return; }
    touch "$tmp/plain"
    _bar_pill_backdrop plain   || { skip bar-pill "the probe never cleared its stripes"; return; }
    _bar_pill_pair plain       || { skip bar-pill "grim could not capture the bar strip"; return; }

    # Image pixels from here on; k converts to layout pixels and back.
    local iw ih
    read -r iw ih < <(magick identify -format '%w %h' "$tmp/plain-shown.png" 2>/dev/null)
    local k; k=$(awk -v i="$iw" -v b="$bw" 'BEGIN { printf "%.4f", i / b }')

    # The pill's ends, along the middle row of the strip. 24 levels is a tenth of
    # the range; the pill moves its columns by several times that.
    local left right
    read -r left right < <(magick "$tmp/plain-shown.png" "$tmp/plain-hidden.png" \
            -compose difference -composite -colorspace Gray \
            -crop "${iw}x1+0+$(( ih / 2 ))" +repage -depth 8 gray:- 2>/dev/null \
        | od -An -v -tu1 | tr -s ' ' '\n' | sed '/^$/d' \
        | awk '$1 > 24 { if (l == "") l = NR - 1; r = NR - 1 } END { print l, r }')
    if [[ -z $left ]]; then
        fail bar-pill "the bar was pinned and nothing across its strip changed -- no pill was drawn"
        return
    fi

    # Its top edge, down the middle of it.
    local top
    top=$(magick "$tmp/plain-shown.png" "$tmp/plain-hidden.png" \
            -compose difference -composite -colorspace Gray \
            -crop "1x${ih}+$(( (left + right) / 2 ))+0" +repage -depth 8 gray:- 2>/dev/null \
        | od -An -v -tu1 | tr -s ' ' '\n' | sed '/^$/d' \
        | awk '$1 > 24 { print NR - 1; exit }')

    local width offset
    width=$(awk -v l="$left" -v r="$right" -v k="$k" 'BEGIN { printf "%d", (r - l + 1) / k }')
    offset=$(awk -v l="$left" -v r="$right" -v i="$iw" -v k="$k" \
        'BEGIN { printf "%.1f", ((l + r) / 2 - (i - 1) / 2) / k }')

    # The band: rows 3-6 below the top edge, 24px in from each end -- clear of
    # the 1px border and its anti-aliasing, of the rounded ends, and of the
    # glyphs, which start around row 7 of a 34px pill.
    local r0 r1 c0 c1 band
    r0=$(awk -v t="${top:-0}" -v k="$k" 'BEGIN { printf "%d", t + 3 * k }')
    r1=$(awk -v t="${top:-0}" -v k="$k" 'BEGIN { printf "%d", t + 6 * k }')
    c0=$(awk -v l="$left"  -v k="$k" 'BEGIN { printf "%d", l + 24 * k }')
    c1=$(awk -v r="$right" -v k="$k" 'BEGIN { printf "%d", r - 24 * k }')
    band="$(( c1 - c0 ))x$(( r1 - r0 + 1 ))+$c0+$r0"

    local sb sbsd ss sssd pb ps _
    read -r sb sbsd <<<"$(patch_stats "$tmp/striped-hidden.png" "$band")"
    read -r ss sssd <<<"$(patch_stats "$tmp/striped-shown.png"  "$band")"
    read -r pb _    <<<"$(patch_stats "$tmp/plain-hidden.png"   "$band")"
    read -r ps _    <<<"$(patch_stats "$tmp/plain-shown.png"    "$band")"

    info "$(printf 'pill %dpx wide, centre %+.1fpx off the monitor'"'"'s; band %s' "$width" "$offset" "$band")"
    info "$(printf 'backdrop striped %.1f (sd %.1f) / plain %.1f; through the pill %.1f (sd %.1f) / %.1f' \
                   "$sb" "$sbsd" "$pb" "$ss" "$sssd" "$ps")"

    local -a problems=()

    # Geometry first: it needs nothing but the plain pair.
    awk -v o="$offset" 'BEGIN { exit !(o <= 4 && o >= -4) }' \
        || problems+=("the pill's centre is ${offset}px off the monitor's -- it is meant to sit in the centre lane alone")
    if (( left <= iw / 50 || right >= iw - 1 - iw / 50 )); then
        problems+=("it runs from ${left} to ${right} of a ${iw}px strip -- a full-width slab, not a pill")
    fi
    metric bar.pill_offset "$offset" 2
    metric bar.pill_width "$width"

    # The material needs both backdrops to differ, and the stripes to be there.
    # Without them the verdict is about the geometry alone, and says so.
    local material="translucent and blurred"
    if awk -v s="$sbsd" 'BEGIN { exit !(s < 30) }'; then
        material="material NOT measured: the stripes did not land behind the pill (sd $sbsd)"
    elif awk -v a="$sb" -v b="$pb" 'BEGIN { d = a - b; if (d < 0) d = -d; exit !(d < 20) }'; then
        material="material NOT measured: the striped and plain backdrops measured the same"
    else
        local a blur
        a=$(awk -v ss="$ss" -v ps="$ps" -v sb="$sb" -v pb="$pb" \
            'BEGIN { printf "%.2f", 1 - (ss - ps) / (sb - pb) }')
        metric bar.pill_alpha "$a" 0.05
        if awk -v a="$a" 'BEGIN { exit !(a > 0.97) }'; then
            problems+=("the pill measures opaque (a = $a): nothing behind it shows through")
        else
            blur=$(awk -v s="$sssd" -v b="$sbsd" -v a="$a" \
                'BEGIN { printf "%.2f", s / (b * (1 - a)) }')
            metric bar.pill_blur "$blur" 0.15
            info "$(printf 'opacity %.2f; %.0f%% of the contrast an unblurred pill would pass gets through' \
                           "$a" "$(awk -v b="$blur" 'BEGIN { print b * 100 }')")"
            awk -v b="$blur" 'BEGIN { exit !(b > 0.5) }' \
                && problems+=("the stripes come through the pill at ${blur} of their unblurred contrast -- Hyprland is not blurring it (opacity at or below the layer rule's ignore_alpha?)")
        fi
    fi

    if (( ${#problems[@]} == 0 )); then
        pass bar-pill "one centred pill ${width}px wide, $material"
    else
        fail bar-pill "${#problems[@]} finding(s) about the pill on screen"
        local p; for p in "${problems[@]}"; do info "$p"; done
        info ""
        info "noct-check bar-pill-config reads the same things off the config files."
    fi
}
