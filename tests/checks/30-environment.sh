# environment.sh -- the facts that explain the other numbers.
#
# This check asserts almost nothing. Its job is to record the things that
# differ between two machines and CAUSE everything else to differ, so that a
# comparison has an answer in it rather than just a discrepancy.
#
# A terminal that measures six levels less lift on one machine is a mystery. A
# terminal that measures six levels less lift, next to a line saying the
# wallpaper's mean luma is forty lower, is not a mystery -- it is a different
# photograph, working exactly as designed. Half the value of a baseline is in
# the metrics that are allowed to differ.
#
# Everything here is recorded WITHOUT a tolerance, which is how a metric says
# "report me when I change, never fail because of it". See tests/lib/baseline.sh.

noct_register environment pure check_environment \
    "record what this machine is, so a comparison against another one can be read"

check_environment() {
    local notes=()
    # Its own metrics, not the run's: the count is reported, and which checks
    # ran before this one is not a fact about the machine.
    local before=${#NOCT_METRICS[@]}

    if command -v hyprctl >/dev/null 2>&1; then
        metric hypr.version "$(hyprctl version 2>/dev/null | sed -n 's/^Hyprland \([^ ]*\).*/\1/p' | head -1)"

        if command -v jq >/dev/null 2>&1; then
            local mons
            mons=$(hyprctl -j monitors 2>/dev/null)
            metric monitor.count "$(jq -r 'length' <<<"$mons")"
            # The focused monitor only. Recording every monitor would make the
            # comparison depend on which order they enumerate in, which is not
            # stable and is not interesting.
            local m
            m=$(jq -r '[.[]|select(.focused)][0] // .[0] | "\(.width) \(.height) \(.scale) \(.refreshRate|floor)"' <<<"$mons")
            local w h s r
            read -r w h s r <<<"$m"
            metric monitor.width   "$w"
            metric monitor.height  "$h"
            metric monitor.scale   "$s"
            metric monitor.refresh "$r"
            notes+=("$(printf '%sx%s at scale %s, %sHz' "$w" "$h" "$s" "$r")")
        fi
    fi

    command -v kitty  >/dev/null 2>&1 && metric kitty.version "$(kitty --version 2>/dev/null | awk '{print $2}')"
    command -v noctalia >/dev/null 2>&1 && metric noctalia.version "$(noctalia --version 2>/dev/null | awk '{print $NF}')"

    # The GPU, because the blur is a shader and two vendors' shaders are not
    # the same shader. A blur that reads as structure on one card and as a flat
    # wash on another is not a configuration difference and no amount of
    # retuning glass.conf fixes it.
    if command -v lspci >/dev/null 2>&1; then
        local gpu
        gpu=$(lspci 2>/dev/null | sed -n 's/.*VGA compatible controller: //p' | head -1)
        [[ -n $gpu ]] && metric gpu "$gpu"
    fi

    # The wallpaper. This is the single largest reason two machines running the
    # same config look different: every visible number in the glass checks is
    # measured against it, and it is per-machine by nature.
    local settings=$NOCT_STATE_HOME/noctalia/settings.toml wallpaper=
    if [[ -f $settings ]]; then
        wallpaper=$(sed -n '/^\[wallpaper.last\]/,/^\[/ s/^path[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$settings" | head -1)
        [[ -z $wallpaper ]] && wallpaper=$(sed -n '/^\[wallpaper.default\]/,/^\[/ s/^path[[:space:]]*=[[:space:]]*"\(.*\)"/\1/p' "$settings" | head -1)
    fi
    if [[ -n $wallpaper && -f $wallpaper ]] && command -v magick >/dev/null 2>&1; then
        # The name is deliberately not recorded -- two machines with different
        # wallpapers is expected and uninteresting. The BRIGHTNESS is what
        # every lift measurement is taken against, and its spread is what
        # decides whether the blur reads as shape or as a wash.
        local luma
        luma=$(magick "$wallpaper" -resize 200x200 -colorspace Gray \
                      -format '%[fx:mean*255] %[fx:standard_deviation*255]' info: 2>/dev/null)
        if [[ -n $luma ]]; then
            metric wallpaper.luma      "${luma%% *}"
            metric wallpaper.variation "${luma##* }"
            notes+=("$(printf 'wallpaper luma %.0f, variation %.0f' "${luma%% *}" "${luma##* }")")
        fi
    fi

    # The colour scheme, which decides the terminal's own colour and therefore
    # how much room there is between it and the backdrop for a lift to happen in.
    local scheme=$CONFIG_HOME/kitty/generated-colors.conf
    if [[ -f $scheme ]]; then
        local bg fg
        bg=$(kitty_colour background 2>/dev/null)
        fg=$(kitty_colour foreground 2>/dev/null)
        [[ -n $bg ]] && metric scheme.background_grey "$bg"
        [[ -n $fg ]] && metric scheme.foreground_grey "$fg"
        [[ -n $bg && -n $fg ]] && {
            metric scheme.contrast "$(contrast_ratio "$fg" "$bg")"
            notes+=("$(printf 'scheme %s on %s, %s:1 before any opacity' "$fg" "$bg" "$(contrast_ratio "$fg" "$bg")")")
        }
    fi

    local n; for n in "${notes[@]}"; do info "$n"; done
    pass environment "recorded $(( ${#NOCT_METRICS[@]} - before )) facts about this machine"
}
