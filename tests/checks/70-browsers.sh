# browsers.sh -- all four of them, and one question about each.
#
# The complaint this was built around: "all browsers have some level of
# transparency which is ok, but not always pretty."
#
# Every browser IS translucent, because bin/noct-glass fades every window
# through the compositor and a browser is a window. Nothing in a browser has to
# agree to that and nothing can opt out of it.
#
# Nothing should be translucent BEYOND that any more, and that is the change
# this check is now written around. Zen can make its own page area transparent
# -- the "transparent zen" mod plus zen.widget.linux.transparency -- and until
# 2026-08-19 this repo switched that on and tinted the result from a `browser`
# level in glass.conf. It was given up on: see docs/theming.md. So a browser
# measuring well under the compositor's own level is now a finding rather than
# the expected case, and the static zen-sheet check that guarded the generated
# stylesheet went with the stylesheet.
#
# Every measurement here is taken on a browser this suite started itself,
# against a throwaway profile. See tests/lib/probe.sh for why -- the short
# version is that a Firefox-family browser reads its configuration exactly once,
# at startup, so a running one is evidence about the past.

noct_register browser-glass  live check_browser_glass \
    "every installed browser is translucent to the degree the config intends"

# Two surfaces further apart than this read as two materials rather than one.
#
# The number is not taste. The compositor dims an UNFOCUSED window by 0.06
# (write_hypr in bin/noct-glass), so any two windows more than 0.06 apart look
# exactly like the same window in two different focus states -- which is
# precisely the "zen when active looks like kitty when inactive" report that
# started all of this.
BROWSER_SPREAD_MAX=${BROWSER_SPREAD_MAX:-0.06}

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
# And then the assertion that matters: do they all read as the same material?
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
            # Below the window level means something INSIDE the browser is
            # making pages translucent as well. Nothing in this repo does that
            # any more, so it is a leftover: for Zen, the "transparent zen" mod
            # or the "Zen Internet" extension still enabled in the real profile,
            # or zen.widget.linux.transparency still true in prefs.js.
            problems+=("$b composites at $ratio, well under the compositor's $win -- something in the browser is making pages translucent too")
            [[ $b == zen ]] && problems+=("  for Zen that is the transparency mod or the Zen Internet extension -- see docs/theming.md")
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

    # Parity. This is the assertion the complaint is actually about.
    local lo hi spread
    read -r lo hi <<<"$(printf '%s\n' "${measured[@]}" | awk '{ v = $2
        if (NR == 1 || v < min) min = v
        if (NR == 1 || v > max) max = v } END { printf "%.2f %.2f", min, max }')"
    spread=$(awk -v a="$lo" -v b="$hi" 'BEGIN { printf "%.2f", b - a }')
    metric browser.spread "$spread" 0.03

    info "$(printf 'spread across %d measured browser(s): %s to %s = %s (want <= %s)' \
                   "${#measured[@]}" "$lo" "$hi" "$spread" "$BROWSER_SPREAD_MAX")"

    local wide=0
    awk -v s="$spread" -v m="$BROWSER_SPREAD_MAX" 'BEGIN { exit !(s > m) }' && wide=1

    if (( ${#problems[@]} == 0 && ! wide )); then
        pass browser-glass "${#measured[@]} browser(s) composite within $BROWSER_SPREAD_MAX of each other, at ${lo}-${hi}"
        return
    fi

    if (( wide )); then
        fail browser-glass "the browsers are $spread apart -- more than the $BROWSER_SPREAD_MAX that reads as one material"
    else
        fail browser-glass "${#problems[@]} finding(s) about how the browsers composite"
    fi
    local p; for p in "${problems[@]}"; do info "$p"; done

    (( wide )) || return
    info ""
    info "A browser that paints an opaque page can only be as translucent as the"
    info "compositor makes it, and the compositor has one level for every window. So a"
    info "spread means one browser is ALSO translucent by itself. Nothing in this repo"
    info "arranges that any more, so it is something left on inside the browser:"
    info ""
    info "  Zen   the \"transparent zen\" mod, the \"Zen Internet\" extension, or"
    info "        zen.widget.linux.transparency still true from before 2026-08-19."
    info "        browsers/zen/user.js sets it false at every startup, so a Zen that"
    info "        has been restarted since should not be able to show this."
}
