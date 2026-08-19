# browsers.sh -- all four of them, and one question about each.
#
# The complaint this was built around: "all browsers have some level of
# transparency which is ok, but not always pretty."
#
# Every browser IS translucent, because bin/noct-glass fades every window
# through the compositor and a browser is a window. Nothing in a browser has to
# agree to that and nothing can opt out of it.
#
# Zen is translucent beyond that, on purpose. The "transparent zen" mod plus
# zen.widget.linux.transparency make it draw its own window and page area
# transparent, and browsers/zen/user.js switches those prefs on. What this repo
# gave up on 2026-08-19 is TINTING the result to a `browser` level in glass.conf
# so a page and a terminal would read as one material -- see docs/theming.md. The
# static zen-sheet check went with the stylesheet it guarded.
#
# So this check measures and no longer arbitrates. It used to fail when the four
# browsers were more than a focus step apart; that assertion was retired the same
# day, because a deliberately translucent Zen is exactly the spread it was
# written to catch and a gate on it could only fail by design. What survives is
# every number it took, plus the two findings that are still true: a browser
# cannot be more opaque than the compositor makes it, and page text has to stay
# readable.
#
# Every measurement here is taken on a browser this suite started itself,
# against a throwaway profile. See tests/lib/probe.sh for why -- the short
# version is that a Firefox-family browser reads its configuration exactly once,
# at startup, so a running one is evidence about the past.

noct_register browser-glass  live check_browser_glass \
    "how translucent each installed browser actually is, measured on a page it painted"

# Printed for scale, not enforced. Two surfaces further apart than this read as
# two materials rather than one, and the number is not taste: the compositor dims
# an UNFOCUSED window by this much (write_hypr in bin/noct-glass), so two windows
# further apart than it look exactly like the same window in two different focus
# states -- which is precisely the "zen when active looks like kitty when
# inactive" report that started all of this.
#
# It was the parity threshold until 2026-08-19. It is now context in an info
# line, so that a reader can tell a spread that means something from a spread
# that is rounding.
BROWSER_FOCUS_STEP=${BROWSER_FOCUS_STEP:-0.06}

# ---------------------------------------------------------------------------
# browser-glass
#
# One number per browser: how much of the wallpaper reaches your eye through an
# ordinary web page. Measured, not derived, on a browser this suite started
# itself, showing a page that paints an opaque white background -- because that
# is what every page you look at does.
#
# Three captures, at the configured window level and at the two calibration
# levels, and noct_solve turns them into the position of the configured one on
# the line between the other two. For a page that paints its own background
# that position IS the effective opacity of the window.
#
# Then a readability number, computed the same way glass-legible computes it
# for a terminal: a light page and its dark text both fade towards the same
# backdrop, so the contrast between them is the page's own contrast scaled by
# the opacity. This is what "not always pretty" is, put on a scale.
#
# And then the spread across them, as information: they are no longer expected to
# agree, because one of them is translucent by itself on purpose.
# ---------------------------------------------------------------------------

check_browser_glass() {
    require_cmd browser-glass grim magick jq hyprctl || return

    local -a browsers=()
    mapfile -t browsers < <(noct_browsers_present)
    (( ${#browsers[@]} )) || { skip browser-glass "none of the four browsers is installed"; return; }

    local win
    read -r win _ <<<"$(noct_glass_levels)"

    # Borrowed once, for all of them. Every set of the level costs a config
    # write, a compositor reload and a settle, so doing it per browser would
    # triple the slowest check in the suite.
    noct_glass_borrow
    local outer; outer=$(noct_defer_mark)

    local -a measured=() problems=()
    local b addr three seen own back back_sd solved ratio backdrop backdrop_sd
    local page_bg page_text contrast

    for b in "${browsers[@]}"; do
        # Back to the configured level before each one: the first capture of a
        # measurement is the one that answers the question.
        noct_glass_reset

        # Nothing that a title match could mistake for this browser's probe.
        # See noct_close_browser: the previous browser's window outliving the
        # pid that started it is how firefox once measured 0.00.
        noct_no_probe_windows || {
            info "$b: a previous probe window is still on screen -- skipped"
            continue
        }

        local mark; mark=$(noct_defer_mark)
        noct_probe_browser "$b"
        case $? in
            0) ;;
            2) info "$b: the probe window never came to rest anywhere measurable -- skipped"
               noct_unwind_to "$mark"; continue ;;
            *) info "$b: no probe window came up within 30s -- skipped"
               noct_unwind_to "$mark"; continue ;;
        esac
        addr=$NOCT_PROBE_ADDR

        three=$(noct_measure_surface "$addr" page)
        local rc=$?
        if (( rc != 0 )); then
            case $rc in
                2) info "$b: the probe page would not hold still -- skipped" ;;
                3) info "$b: the probe window would not stay put between captures -- skipped" ;;
                *) info "$b: a capture failed -- skipped" ;;
            esac
            noct_unwind_to "$mark"
            continue
        fi
        read -r seen _ own back back_sd <<<"$three"

        solved=$(noct_solve "$seen" "$own" "$back" "$back_sd")
        read -r ratio backdrop backdrop_sd <<<"$solved"

        # A page area the same brightness as the wallpaper behind it leaves
        # nothing to divide by, and any opacity computed from it is noise. It
        # should not happen with a white page over this desktop, but it is the
        # difference between a skip and a confident wrong answer.
        if awk -v o="$own" -v bd="$backdrop" 'BEGIN { d = o - bd; if (d < 0) d = -d; exit !(d < 6) }'; then
            info "$b: the page and the backdrop are the same brightness -- nothing to measure"
            noct_unwind_to "$mark"
            continue
        fi

        # What the page and its text actually land at, and the contrast between
        # them. Both fade towards the same backdrop, so this is the page's own
        # contrast scaled by the opacity -- the wallpaper cancels out of the
        # ratio, exactly as it does for a terminal.
        read -r page_bg page_text <<<"$(awk -v a="$ratio" -v b="$backdrop" -v t="$NOCT_PAGE_TEXT_GREY" 'BEGIN {
            printf "%.0f %.0f", 255 * a + b * (1 - a), t * a + b * (1 - a)
        }')"
        contrast=$(contrast_ratio "$page_text" "$page_bg")

        metric "browser.$b.effective_opacity" "$ratio"    0.04
        metric "browser.$b.page_contrast"     "$contrast" 1.5
        measured+=("$b $ratio")

        # The raw captures as well as the conclusion. Every number after this
        # is derived from them, and a derived number that looks wrong is
        # impossible to argue with otherwise -- `opaque` is the page at
        # compositor 1.00, so on a browser showing a white page it lands near
        # 255, and anything else means the capture did not photograph the page.
        info "$(printf '%-9s captures: configured %s, opaque %s, backdrop-only %s' \
                       "$b" "$seen" "$own" "$back")"
        info "$(printf '%-9s effective opacity %s over a backdrop of %s: white lands at %s, #222 text at %s, %s:1' \
                       "$b" "$ratio" "$backdrop" "$page_bg" "$page_text" "$contrast")"

        # Nothing can be MORE opaque than the compositor makes it, so anything
        # above the window level is a measurement fault rather than a finding.
        if awk -v r="$ratio" -v w="$win" 'BEGIN { exit !(r > w + 0.08) }'; then
            problems+=("$b measured $ratio, above the compositor's own $win -- that is not possible, so the measurement is wrong")
        elif awk -v r="$ratio" -v w="$win" 'BEGIN { exit !(r < w - 0.08) }'; then
            # Below the window level means something INSIDE the browser is making
            # pages translucent as well. For Zen that is the intended state and
            # the whole reason parity was retired; for the other three nothing
            # here arranges it, so it is still worth reporting.
            if [[ $b == zen ]]; then
                info "$b composites at $ratio, under the compositor's $win -- expected: the transparency mod makes its own pages translucent"
            else
                problems+=("$b composites at $ratio, well under the compositor's $win -- something in the browser is making pages translucent too, and nothing here arranges that for $b")
            fi
        fi

        awk -v c="$contrast" 'BEGIN { exit !(c < 4.5) }' \
            && problems+=("$b puts ordinary page text at ${contrast}:1, under the 4.5:1 readability floor")

        noct_unwind_to "$mark"
    done

    noct_unwind_to "$outer"

    if (( ${#measured[@]} == 0 )); then
        skip browser-glass "no browser could be measured"
        return
    fi

    # The spread, reported and not judged. Retired as an assertion 2026-08-19:
    # Zen is deliberately translucent by itself, so the four are not meant to
    # agree, and a gate here could only fail on the intended state.
    #
    # Deliberately not a `metric` either. A metric is compared against the
    # baseline within a tolerance, which is the same gate wearing a different
    # hat -- it would turn every --compare on a machine with the Zen mod
    # installed into a drift report about a decision that was made on purpose.
    local lo hi spread
    read -r lo hi <<<"$(printf '%s\n' "${measured[@]}" | awk '{ v = $2
        if (NR == 1 || v < min) min = v
        if (NR == 1 || v > max) max = v } END { printf "%.2f %.2f", min, max }')"
    spread=$(awk -v a="$lo" -v b="$hi" 'BEGIN { printf "%.2f", b - a }')

    info "$(printf 'spread across %d measured browser(s): %s to %s = %s (the focus step, for scale, is %s)' \
                   "${#measured[@]}" "$lo" "$hi" "$spread" "$BROWSER_FOCUS_STEP")"

    if awk -v s="$spread" -v m="$BROWSER_FOCUS_STEP" 'BEGIN { exit !(s > m) }'; then
        info "which is more than a focus step, so at least one of them reads as its own"
        info "material. Expected while Zen has the transparency mod on; for any other"
        info "browser it means something in that browser is fading pages too."
    fi

    if (( ${#problems[@]} == 0 )); then
        pass browser-glass "${#measured[@]} browser(s) measured, composing between ${lo} and ${hi}"
        return
    fi

    fail browser-glass "${#problems[@]} finding(s) about how the browsers composite"
    local p; for p in "${problems[@]}"; do info "$p"; done
}
