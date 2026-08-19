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
# Relative rather than absolute, too: the bar is #323232 capsules over whatever
# window happens to be behind, so there is no absolute grey that means "shown".
# What means shown is that the same patch looks different with it than without.

noct_register bar-hot-edge live check_bar_hot_edge \
    "the pointer at the top edge reveals the bar, and leaving retracts it"

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
    # Diffing the whole strip assumes nothing. Whatever the lanes hold, whatever
    # the material, if the bar drew something the pixels differ somewhere.
    # Measured on the portrait bar with separate capsules: hidden mean 44, shown
    # mean 51, and the difference image means 7 with a max of 175.
    local tmp; tmp=$(mktemp -d); defer "rm -rf '$tmp'"

    local strip="$bx,$by ${bw}x${bh}"

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
