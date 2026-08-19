# baseline.sh -- "does this machine look like the one where it looked right?"
#
# The question this exists for
# ----------------------------
# Every check in the suite is a threshold: is the lift above 12, is the
# contrast above 4.5. Thresholds catch a setup that is broken. They do not
# catch a setup that is WORKING BUT DIFFERENT -- and "these kitty windows don't
# look on par with what I tested on my other machine" is exactly that. Both
# machines pass every check. One of them looks better.
#
# So a run records the numbers as well as the verdicts, and a recorded run can
# be compared against a later one:
#
#   noct-check --record            on the machine that looks right
#   git add tests/baselines/*.json
#   noct-check --compare <that>    on the machine that does not
#
# and the answer is a list of exactly which measurements moved, by how much,
# and which ones are inside the tolerance the check that took them declared.
#
# What a baseline is not
# ----------------------
# It is not a golden screenshot. Two machines differ in resolution, scale,
# wallpaper and GPU, so pixels never match and a pixel comparison would be
# noise on the first run. What is comparable is the DERIVED numbers -- the
# effective opacity of a terminal, the lift, the contrast the text lands at --
# because those are ratios, and a ratio is the same on a 1080p laptop as on a
# 4K desk.
#
# Metrics recorded without a tolerance are context: monitor scale, GPU,
# compositor version, the wallpaper's mean luma. They are reported when they
# differ and they never fail a comparison. They are there because they are
# usually the ANSWER -- a terminal that measures 6 levels of lift less on one
# machine, next to a line saying the wallpaper's mean luma is 40 lower, is not
# a mystery any more.

# ---------------------------------------------------------------------------
# Reading a recorded run
#
# Parsed with sed rather than jq. The suite has to be able to report that jq is
# missing, which it cannot do if comparing two of its own files needs jq -- and
# this only ever reads files noct_json wrote, whose shape is known exactly.
# ---------------------------------------------------------------------------

# noct_baseline_metrics <file> -- "<key> <value> <tolerance>" per line,
# tolerance empty when the metric is context.
noct_baseline_metrics() {
    sed -n 's/^[[:space:]]*"\([^"]*\)":[[:space:]]*{[[:space:]]*"value":[[:space:]]*\("[^"]*"\|[^,}]*\)\(,[[:space:]]*"tolerance":[[:space:]]*\([^[:space:]}]*\)\)\?[[:space:]]*}.*/\1 \2 \4/p' "$1" \
        | sed 's/"//g'
}

noct_baseline_host() {
    sed -n 's/^[[:space:]]*"host":[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -1
}

noct_baseline_recorded() {
    sed -n 's/^[[:space:]]*"recorded":[[:space:]]*"\([^"]*\)".*/\1/p' "$1" | head -1
}

# ---------------------------------------------------------------------------
# Writing one
# ---------------------------------------------------------------------------

noct_baseline_default_path() {
    printf '%s/tests/baselines/%s.json' "$NOCT_REPO" "${NOCT_HOST:-$(hostname 2>/dev/null || echo unknown)}"
}

# noct_baseline_clash <file> -- what says the file was recorded somewhere else.
# Prints one line per differing hardware fact; prints nothing when it looks like
# the same machine.
#
# The baseline is named after the hostname, and on this distro that is a trap
# rather than an identity: a stock CachyOS install is called cachyos-x8664 on
# EVERY machine. So two machines write the same file, each --record silently
# replaces the other's numbers, and every --compare afterwards reads the other
# machine's monitor as drift -- which is precisely the confusion the whole
# baseline mechanism exists to remove.
#
# Compared on geometry rather than on anything clever. Two machines that differ
# in resolution or refresh rate are two machines, and geometry is recorded as
# plain integers with no spaces to parse around.
noct_baseline_clash() {  # <file>
    local file=$1 key was now
    for key in monitor.width monitor.height monitor.refresh; do
        was=$(noct_baseline_metrics "$file" | awk -v k="$key" '$1 == k { print $2; exit }')
        now=$(noct_metric_value "$key") || continue
        [[ -n $was && -n $now && $was != "$now" ]] && printf '%s: %s in the file, %s here\n' "$key" "$was" "$now"
    done
    return 0
}

noct_baseline_record() {  # <file>
    local out=$1 clash=""

    [[ -f $out ]] && clash=$(noct_baseline_clash "$out")
    if [[ -n $clash ]]; then
        printf '\n%s!! not overwriting %s%s\n' "$RED" "${out#"$NOCT_REPO"/}" "$RESET"
        printf '   it was recorded on hardware this is not:\n'
        printf '%s\n' "$clash" | sed 's/^/     /'
        printf '\n   Both of your machines are called %s, so both want this one file and\n' "$(hostname 2>/dev/null)"
        printf '   each --record would replace the other. Name this one for the suite:\n\n'
        printf '     NOCT_HOST=work noct-check --all --record\n\n'
        printf '   or name it for real, which fixes it everywhere and not just here:\n'
        printf '     sudo hostnamectl hostname work\n\n'
        printf '   Nothing was written.\n'
        NOCT_BASELINE_FAIL=1
        return 1
    fi

    mkdir -p "$(dirname "$out")"
    QUIET=1 noct_json >"$out"
    printf 'recorded %d metrics to %s\n' "${#NOCT_METRICS[@]}" "$out"
    printf '\n%sCommit it.%s A baseline that is not in git is a number on one machine,\n' "$BOLD" "$RESET"
    printf 'which is the situation it exists to get you out of.\n'
}

# ---------------------------------------------------------------------------
# Comparing
# ---------------------------------------------------------------------------

NOCT_BASELINE_FAIL=0

noct_baseline_report() {  # <file>
    local file=$1
    if [[ ! -f $file ]]; then
        printf '%sno such baseline: %s%s\n' "$RED" "$file" "$RESET" >&2
        printf 'record one with: noct-check --all --record\n' >&2
        NOCT_BASELINE_FAIL=1
        return 1
    fi

    local host recorded
    host=$(noct_baseline_host "$file")
    recorded=$(noct_baseline_recorded "$file")

    printf '\n%s── against %s, recorded %s ──%s\n\n' "$BOLD" "${host:-?}" "${recorded:-?}" "$RESET"

    local key was tol now line drift=() context=() missing=() gained=()
    local -A seen=()

    while read -r key was tol; do
        [[ -n $key ]] || continue
        seen[$key]=1
        if ! now=$(noct_metric_value "$key"); then
            missing+=("$key was $was there, and this run did not measure it")
            continue
        fi

        # Context metrics -- no tolerance -- are compared as text and only ever
        # reported. A different GPU is not a regression.
        if [[ -z $tol ]]; then
            [[ $was == "$now" ]] || context+=("$(printf '%-34s %s -> %s' "$key" "$was" "$now")")
            continue
        fi

        local verdict
        verdict=$(awk -v a="$was" -v b="$now" -v t="$tol" 'BEGIN {
            d = b - a; ad = (d < 0) ? -d : d
            printf "%+.2f %d", d, (ad <= t)
        }')
        local delta ok
        read -r delta ok <<<"$verdict"
        if (( ! ok )); then
            drift+=("$(printf '%-34s %8s -> %-8s %s%+8s%s  (tolerance %s)' \
                              "$key" "$was" "$now" "$RED" "$delta" "$RESET" "$tol")")
            NOCT_BASELINE_FAIL=$((NOCT_BASELINE_FAIL + 1))
        fi
    done < <(noct_baseline_metrics "$file")

    for line in "${NOCT_METRICS[@]}"; do
        key=${line%%	*}
        [[ -n ${seen[$key]-} ]] || gained+=("$key is new since that baseline")
    done

    if (( ${#drift[@]} )); then
        printf '%sout of tolerance%s\n' "$BOLD" "$RESET"
        printf '  %s\n' "${drift[@]}"
        printf '\n'
    fi
    if (( ${#context[@]} )); then
        # Deliberately after the drift and deliberately not a failure: this is
        # the section you read to find out WHY the section above moved.
        printf '%sdifferent, but context rather than regression%s\n' "$BOLD" "$RESET"
        printf '  %s\n' "${context[@]}"
        printf '\n'
    fi
    if (( ${#missing[@]} || ${#gained[@]} )); then
        printf '%snot comparable%s\n' "$BOLD" "$RESET"
        (( ${#missing[@]} )) && printf '  %s\n' "${missing[@]}"
        (( ${#gained[@]} )) && printf '  %s\n' "${gained[@]}"
        printf '\n'
    fi

    if (( NOCT_BASELINE_FAIL == 0 )); then
        printf '%severy comparable measurement is within tolerance of %s%s\n' "$GREEN" "${host:-the baseline}" "$RESET"
    else
        printf '%s%d measurement(s) drifted from %s%s\n' "$RED" "$NOCT_BASELINE_FAIL" "${host:-the baseline}" "$RESET"
    fi
    return 0
}
