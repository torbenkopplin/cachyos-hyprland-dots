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

# ---------------------------------------------------------------------------
# nav-axis
#
# The bug this exists for: navigation assumed every band was a HORIZONTAL tape.
# A band carries its own `direction` (conf/workspaces.lua, from WSBANDS), so a
# portrait monitor scrolls down -- and on that monitor the old code tested the
# wrong structure on both axes. J reported "end of column" on the first press,
# because each column holds one window, and jumped a workspace while the next
# column sat visibly below. L looked for an in-column neighbour that a vertical
# band does not have, and did nothing at all.
#
# Neither monitor-hop nor column-hop noticed, because neither of them asks
# anything about J/K. This is the check that would have.
#
# Everything here is derived from GEOMETRY rather than from WSBANDS, for the same
# reason lib/nav.lua is: the band table is keyed on connector name, and a laptop
# plugged into an unfamiliar monitor has no entry to read. Two windows on one
# workspace are enough -- whichever axis their positions differ on is the axis
# the tape runs on.
# ---------------------------------------------------------------------------

noct_register nav-axis live check_nav_axis \
    "SUPER+hjkl walks the tape on whichever axis the band actually scrolls"

# Address, workspace and monitor of whatever is focused right now.
nav_focus_state() {
    hyprctl -j activewindow 2>/dev/null \
        | jq -r '[(.address // "none"), (.workspace.id // "none"), (.monitor // "none")] | @tsv'
}

nav_probe_geom() {
    hyprctl -j clients 2>/dev/null | jq -r --arg a "$1" \
        '.[]|select(.address==$a)|[.at[0], .at[1], .workspace.id, .floating] | @tsv'
}

# Spawn a tiled probe and wait for its GEOMETRY to stop changing.
#
# Deliberately not noct_probe_kitty: that settles on a pixel patch, and a patch
# cannot be taken from a window whose column sits in the lower half of a portrait
# monitor -- noct_window_geom clips against the monitor's untransformed width and
# height, so on a `transform = 3` screen every coordinate past 1080 reads as off
# the edge. This check never looks at a pixel, so it does not have to care.
nav_spawn_probe() {
    local title=$1 i prev= now=
    kitty --class "$NOCT_PROBE_TAPE_CLASS" --title "$title" sh -c 'clear; sleep 120' \
        >/dev/null 2>&1 &
    local pid=$!
    defer "kill $pid 2>/dev/null; wait $pid 2>/dev/null"

    NOCT_PROBE_ADDR=$(noct_wait_window \
        ".class == \"$NOCT_PROBE_TAPE_CLASS\" and (.title // \"\") == \"$title\"") || return 1

    # The tape may still be scrolling to it, and a geometry read mid-animation
    # would put the axis comparison on coordinates that are about to change.
    for (( i = 0; i < 32; i++ )); do
        now=$(hyprctl -j clients 2>/dev/null | jq -r --arg a "$NOCT_PROBE_ADDR" \
                '.[]|select(.address==$a)|"\(.at[0]),\(.at[1]),\(.size[0]),\(.size[1])"')
        [[ -n $now && $now == "$prev" ]] && return 0
        prev=$now
        sleep 0.25
    done
    return 1
}

check_nav_axis() {
    require_cmd nav-axis hyprctl kitty jq || return
    have_eval || { skip nav-axis "this Hyprland has no 'hyprctl eval' to drive the binds with"; return; }

    local keep; keep=$(nav_focus_state | cut -f1)

    # An empty workspace in the focused monitor's own band, because a probe
    # opened onto a tape that is already full lands off-screen and cannot be
    # measured. lib/ws.lua does the band arithmetic -- switch(n) is the n-th
    # workspace of whichever monitor is focused, which is exactly SUPER+<n>.
    local n empty=
    for n in 9 8 7 6; do
        hyprctl eval "require(\"lib.ws\").switch($n)" >/dev/null 2>&1
        sleep 0.4
        if [[ $(hyprctl -j activeworkspace 2>/dev/null | jq -r '.windows') == 0 ]]; then
            empty=$(hyprctl -j activeworkspace 2>/dev/null | jq -r '.id')
            break
        fi
    done
    if [[ -z $empty ]]; then
        skip nav-axis "no empty workspace in this monitor's band to open the probes on"
        [[ -n $keep && $keep != none ]] \
            && hyprctl dispatch "hl.dsp.focus({ window = \"address:$keep\" })" >/dev/null 2>&1
        return
    fi
    info "probing on workspace $empty, which was empty"

    local a b
    nav_spawn_probe nav-axis-a \
        || { skip nav-axis "the first probe window never came to rest"; return; }
    a=$NOCT_PROBE_ADDR
    nav_spawn_probe nav-axis-b \
        || { skip nav-axis "the second probe window never came to rest"; return; }
    b=$NOCT_PROBE_ADDR

    local ax ay aws afloat bx by bws bfloat
    IFS=$'\t' read -r ax ay aws afloat < <(nav_probe_geom "$a")
    IFS=$'\t' read -r bx by bws bfloat < <(nav_probe_geom "$b")

    if [[ $afloat == true || $bfloat == true ]]; then
        skip nav-axis "a probe landed floating -- a window rule is catching $NOCT_PROBE_TAPE_CLASS"
        return
    fi
    if [[ -z $aws || $aws != "$bws" ]]; then
        skip nav-axis "the two probes did not land on the same workspace ($aws / $bws)"
        return
    fi

    # Which axis do they differ on, and which of the two is further along it?
    # A tie means they are stacked in one column rather than spread along the
    # tape, and there is no tape step to measure.
    local dx=$(( ax > bx ? ax - bx : bx - ax ))
    local dy=$(( ay > by ? ay - by : by - ay ))
    local axis first last fwd navfn
    if (( dy > dx )); then
        axis=vertical; fwd=d; navfn=focus_vertical
        if (( ay < by )); then first=$a; last=$b; else first=$b; last=$a; fi
    elif (( dx > dy )); then
        axis=horizontal; fwd=r; navfn=focus_horizontal
        if (( ax < bx )); then first=$a; last=$b; else first=$b; last=$a; fi
    else
        skip nav-axis "the probes are not offset on either axis -- nothing to walk"
        return
    fi

    info "band scrolls $axis (probes ${dx}px apart in x, ${dy}px in y), so the tape is on $( [[ $axis == vertical ]] && echo J/K || echo H/L )"

    local -a problems=()

    # 1. A step along the tape must land on the other column and stay put.
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$first\" })" >/dev/null 2>&1
    sleep 0.3
    hyprctl eval "require(\"lib.nav\").$navfn(\"$fwd\")" >/dev/null 2>&1
    sleep 0.5
    local got_addr got_ws got_mon
    IFS=$'\t' read -r got_addr got_ws got_mon < <(nav_focus_state)

    if [[ $got_addr != "$last" ]]; then
        problems+=("a step along the tape did not reach the next column")
        if [[ $got_ws != "$aws" ]]; then
            problems+=("  it left the workspace instead ($aws -> $got_ws) -- the edge test is on the wrong axis")
        else
            problems+=("  focus did not move at all -- the dispatched direction is across the tape, not along it")
        fi
    fi

    # 2. From the far end there is nothing left on the tape, so it must hand off.
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$last\" })" >/dev/null 2>&1
    sleep 0.3
    hyprctl eval "require(\"lib.nav\").$navfn(\"$fwd\")" >/dev/null 2>&1
    sleep 0.6
    IFS=$'\t' read -r got_addr got_ws got_mon < <(nav_focus_state)

    if [[ $got_ws == "$aws" && $got_addr == "$last" ]]; then
        problems+=("at the end of the tape nothing happened -- it should hand off to the next $( [[ $axis == vertical ]] && echo workspace || echo monitor )")
    fi

    # Put the user back where they were before the probes opened.
    [[ -n $keep && $keep != none ]] \
        && hyprctl dispatch "hl.dsp.focus({ window = \"address:$keep\" })" >/dev/null 2>&1

    if (( ${#problems[@]} == 0 )); then
        pass nav-axis "a $axis band walks its tape and only hands off at the end"
    else
        fail nav-axis "${#problems[@]} finding(s) about which axis the keys walk"
        local p; for p in "${problems[@]}"; do info "$p"; done
        info ""
        info "lib/nav.lua must not assume the tape is horizontal. layout(\"focus <dir>\")"
        info "takes SCREEN directions and walks whatever runs that way by itself, and at"
        info "an edge it is a no-op -- so the edge is detected by asking whether focus"
        info "actually moved, not by comparing a row index against a column length."
    fi
}
