# binds.sh -- keybinds whose failure mode is doing nothing at all.
#
# Both of these are driven through `hyprctl eval`, which runs Lua inside the
# compositor and is the only way to reach a keybind's implementation without
# pressing the key. Note that `hyprctl dispatch` is also Lua here -- the old
# shell syntax (`dispatch movewindow mon:r`) is a parse error, not a move.

noct_register monitor-hop live check_monitor_hop \
    "SUPER+CTRL+SHIFT+hjkl lands the window on another monitor"
noct_register column-hop  live check_column_hop \
    "SUPER+CTRL+hl runs a column off the tape onto the next monitor"

# `hyprctl eval` arrived with the Lua config; on an older Hyprland these checks
# cannot run at all, and saying so is better than failing as though the binds
# were broken.
have_eval() { hyprctl eval 'return true' 2>&1 | grep -qv "^error"; }

# ---------------------------------------------------------------------------
# monitor-hop
#
# The bind was directional only, and a directional monitor selector resolves to
# nothing when no monitor lies that way. On a desk whose second screen is to the
# LEFT, "send it right" therefore did nothing at all -- and a keybind that
# silently does nothing is indistinguishable from one that is not bound.
#
# It is worth a test rather than a look, because the obvious fix does not work
# either: the dispatcher fails INSIDE Hyprland without raising a Lua error, so
# a pcall around it returns true and any fallback behind that pcall never runs.
# The version that looked right and did nothing passed every check but this one.
# ---------------------------------------------------------------------------

check_monitor_hop() {
    require_cmd monitor-hop hyprctl kitty jq || return
    have_eval || { skip monitor-hop "this Hyprland has no 'hyprctl eval' to drive the bind with"; return; }

    local count
    count=$(hyprctl -j monitors 2>/dev/null | jq -r 'length')
    (( count >= 2 )) || { skip monitor-hop "only one monitor -- nothing to hop to"; return; }
    if (( count > 2 )); then
        skip monitor-hop "$count monitors: the hop is strictly directional above two, so there is no all-directions guarantee to assert"
        return
    fi

    local addr
    noct_probe_kitty --title noct-probe-hop \
        || { skip monitor-hop "the probe window never appeared"; return; }
    addr=$NOCT_PROBE_ADDR

    probe_monitor() { hyprctl -j clients 2>/dev/null | jq -r --arg a "$addr" '.[]|select(.address==$a)|.monitor'; }

    local dir before after stuck=()
    for dir in l r u d; do
        hyprctl dispatch "hl.dsp.window.focus({ address = \"$addr\" })" >/dev/null 2>&1
        sleep 0.3
        before=$(probe_monitor)
        hyprctl eval "require(\"lib.nav\").monitor_hop(\"$dir\")" >/dev/null 2>&1
        sleep 0.6
        after=$(probe_monitor)
        [[ $before == "$after" ]] && stuck+=("$dir")
    done

    if (( ${#stuck[@]} == 0 )); then
        pass monitor-hop "every direction moves the window to the other monitor"
    else
        fail monitor-hop "these directions did nothing: ${stuck[*]}"
        info "with exactly two monitors nav.monitor_hop is meant to fall back to \"the"
        info "other one\" when nothing lies in the direction asked for. Check that the"
        info "fallback reads the monitor back rather than relying on pcall -- the"
        info "dispatcher fails without raising."
    fi
}

# ---------------------------------------------------------------------------
# column-hop
#
# The keymap has one rule and this is where it used to be broken: h/l is the
# horizontal axis, j/k is the workspace axis. Focus and windows both run out of
# columns and hand off to the monitor that way; the COLUMN used to hand off to
# the next workspace instead, which put a workspace move on the horizontal keys
# and made the whole chord feel arbitrary.
#
# Driven on a TILED probe, because a column is a thing only a tiled window has.
# The probe deliberately does not use the noct-probe class: conf/rules.lua
# floats that one, and a floating window has no column to push.
# ---------------------------------------------------------------------------

tape_probe_monitor() {
    hyprctl -j clients 2>/dev/null | jq -r --arg c "$NOCT_PROBE_TAPE_CLASS" '.[]|select(.class==$c)|.monitor' | head -1
}

check_column_hop() {
    require_cmd column-hop hyprctl kitty jq || return
    have_eval || { skip column-hop "this Hyprland has no 'hyprctl eval' to drive the bind with"; return; }

    local count
    count=$(hyprctl -j monitors 2>/dev/null | jq -r 'length')
    (( count >= 2 )) || { skip column-hop "only one monitor -- nothing to hand off to"; return; }

    local addr
    noct_probe_kitty --class "$NOCT_PROBE_TAPE_CLASS" --title "$NOCT_PROBE_TAPE_CLASS" \
        || { skip column-hop "the probe window never appeared"; return; }
    addr=$NOCT_PROBE_ADDR

    # A floating probe would have no column at all and the check would be
    # measuring nothing.
    if [[ $(hyprctl -j clients | jq -r --arg a "$addr" '.[]|select(.address==$a)|.floating') == true ]]; then
        skip column-hop "the probe landed floating -- a window rule is catching $NOCT_PROBE_TAPE_CLASS"
        return
    fi

    local dir start now crossed stuck=() i
    for dir in r l; do
        start=$(tape_probe_monitor)
        crossed=0
        # Enough pushes to walk off any reasonable tape. Each one either swaps
        # the column along or, at the end, hands it to the next monitor.
        for i in 1 2 3 4 5 6; do
            hyprctl dispatch "hl.dsp.window.focus({ address = \"$addr\" })" >/dev/null 2>&1
            sleep 0.25
            hyprctl eval "require(\"lib.nav\").column_horizontal(\"$dir\")" >/dev/null 2>&1
            sleep 0.6
            now=$(tape_probe_monitor)
            [[ -n $now && $now != "$start" ]] && { crossed=1; break; }
        done
        (( crossed )) || stuck+=("$dir")
    done

    if (( ${#stuck[@]} == 0 )); then
        pass column-hop "a column pushed off the tape lands on the next monitor"
    else
        fail column-hop "pushing the column never left the monitor: ${stuck[*]}"
        info "nav.column_horizontal should call monitor_in_direction at the tape edge and"
        info "move the whole column to that monitor's active workspace. If it is calling"
        info "bands.neighbour instead, it is doing the old thing -- moving to the next"
        info "workspace, which is what SUPER+CTRL+J/K is for."
    fi
}
