# harness.sh -- the bones of the test framework: registry, results, metrics.
#
# Sourced by bin/noct-check. Nothing in here knows anything about this desktop;
# it is the part that would be the same for any suite.
#
# Why a framework at all
# ----------------------
# The checks started as one file of ad-hoc functions and grew three problems
# that only a shared harness fixes:
#
#   * every live check hand-rolled its own `trap ... EXIT INT TERM`, and a
#     second trap silently replaces the first. Two checks that both restore
#     something meant the earlier one never ran. `defer` is a stack, so it
#     cannot happen.
#
#   * a check could only say pass/fail. "Does it pass on this machine" is a
#     much weaker question than "does it MEASURE THE SAME on this machine as on
#     the one where it looked right" -- and the second is what an appearance is
#     actually judged by. `metric` is how a check answers that one.
#
#   * results were printed and thrown away, so nothing could compare two runs.
#     Every result and every metric is now kept, which is what makes --json and
#     --record possible.
#
# The vocabulary
# --------------
#   noct_register <name> <pure|live> <fn> <description>
#       Declare a check. `live` means it opens windows or disturbs the screen,
#       and is only run under --all or by name.
#
#   pass/fail/skip <name> <message>      the verdict, exactly one per check
#   info <message>                       a line under the verdict
#   metric <key> <value> [tolerance]     a number this run measured
#   defer <command...>                   undo, run when the check ends
#   require_cmd <name> <cmd>...          skip the check unless all are present

# ---------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------

NOCT_CHECK_ORDER=()
declare -A NOCT_CHECK_FN=()
declare -A NOCT_CHECK_CLASS=()
declare -A NOCT_CHECK_DESC=()

noct_register() {  # <name> <pure|live> <function> <description>
    local name=$1 class=$2 fn=$3 desc=$4
    NOCT_CHECK_ORDER+=("$name")
    NOCT_CHECK_FN[$name]=$fn
    NOCT_CHECK_CLASS[$name]=$class
    NOCT_CHECK_DESC[$name]=$desc
}

noct_checks_of_class() {  # <pure|live|all>
    local want=$1 name
    for name in "${NOCT_CHECK_ORDER[@]}"; do
        [[ $want == all || ${NOCT_CHECK_CLASS[$name]} == "$want" ]] && printf '%s\n' "$name"
    done
    return 0
}

# ---------------------------------------------------------------------------
# Results
#
# Kept as well as printed. A verdict is recorded once per check: the runner
# enforces that, because a check that falls through its own logic and reports
# nothing used to be indistinguishable from one that passed.
# ---------------------------------------------------------------------------

PASS=0; FAIL=0; SKIP=0
NOCT_RESULTS=()      # status<TAB>name<TAB>message
NOCT_INFO=()         # name<TAB>message
NOCT_METRICS=()      # key<TAB>value<TAB>tolerance
NOCT_CURRENT=        # the check being run, for info/metric to attribute to
NOCT_VERDICT=        # set by pass/fail/skip, checked by the runner

GREEN=$'\e[32m'; RED=$'\e[31m'; YELLOW=$'\e[33m'; DIM=$'\e[2m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
[[ -t 1 ]] || { GREEN=; RED=; YELLOW=; DIM=; BOLD=; RESET=; }

# QUIET suppresses the human report, for --json. The results are still recorded.
QUIET=${QUIET:-0}

_emit() {  # <colour> <label> <name> <message>
    (( QUIET )) && return 0
    printf '%s%s%s  %-20s %s\n' "$1" "$2" "$RESET" "$3" "${4-}"
}

pass() { NOCT_VERDICT=pass; NOCT_RESULTS+=("pass	$1	${2-}"); _emit "$GREEN"  PASS "$1" "${2-}"; PASS=$((PASS+1)); }
fail() { NOCT_VERDICT=fail; NOCT_RESULTS+=("fail	$1	${2-}"); _emit "$RED"   FAIL "$1" "${2-}"; FAIL=$((FAIL+1)); }
skip() { NOCT_VERDICT=skip; NOCT_RESULTS+=("skip	$1	${2-}"); _emit "$YELLOW" SKIP "$1" "${2-}"; SKIP=$((SKIP+1)); }

info() {
    NOCT_INFO+=("${NOCT_CURRENT:--}	$1")
    (( QUIET )) || printf '      %s%s%s\n' "$DIM" "$1" "$RESET"
}

# ---------------------------------------------------------------------------
# Metrics
#
# The number a check measured, kept under a dotted key so a run can be compared
# with another run -- on another machine, or on this one before a change.
#
# The tolerance is the check's own statement of how much of a difference is a
# difference. It is part of the measurement, not of the comparison: only the
# code that took the number knows whether two levels of 255 is noise or a
# redesign. A metric with no tolerance is CONTEXT -- recorded, reported, never
# compared. Monitor scale and GPU go in that way: they do not fail a comparison,
# they explain one.
# ---------------------------------------------------------------------------

metric() {  # <key> <value> [tolerance]
    local key=$1 value=$2 tol=${3-}
    NOCT_METRICS+=("$key	$value	$tol")
}

noct_metric_value() {  # <key> -- the value recorded this run, or empty
    local key=$1 line
    for line in "${NOCT_METRICS[@]}"; do
        [[ ${line%%	*} == "$key" ]] && { line=${line#*	}; printf '%s' "${line%%	*}"; return 0; }
    done
    return 1
}

# ---------------------------------------------------------------------------
# Deferred cleanup
#
# A stack rather than a trap, so nesting works: a browser probe inside a glass
# override inside a check unwinds in the right order, and a check that dies
# half way through still puts back everything it had changed by then.
#
# The runner installs the only signal trap in the suite and calls
# noct_unwind after every check, pass or fail.
# ---------------------------------------------------------------------------

NOCT_DEFERRED=()

defer() { NOCT_DEFERRED+=("$*"); }

# A mark, and unwinding back to it. This is what lets a check that loops over
# four browsers open one, measure it, close it and move on -- without dropping
# the compositor level it borrowed before the loop started, which has to stay
# borrowed until the last one is done.
noct_defer_mark() { printf '%d' "${#NOCT_DEFERRED[@]}"; }

noct_unwind_to() {
    local target=$1 i
    for (( i = ${#NOCT_DEFERRED[@]} - 1; i >= target; i-- )); do
        eval "${NOCT_DEFERRED[i]}" >/dev/null 2>&1 || true
    done
    if (( target == 0 )); then
        NOCT_DEFERRED=()
    else
        NOCT_DEFERRED=("${NOCT_DEFERRED[@]:0:target}")
    fi
}

noct_unwind() { noct_unwind_to 0; }

# ---------------------------------------------------------------------------
# Requirements
#
# A missing tool is a skip, never a failure: the suite runs on machines that do
# not have every browser installed, and reporting "chromium is not transparent"
# on a machine with no chromium is worse than saying nothing.
# ---------------------------------------------------------------------------

require_cmd() {  # <check name> <cmd>...
    local name=$1 missing=() c
    shift
    # type -P for the same reason as tests/checks/20-deps.sh: command -v
    # would find this file's own pass/fail/skip/info functions first.
    for c in "$@"; do type -P "$c" >/dev/null 2>&1 || missing+=("$c"); done
    (( ${#missing[@]} == 0 )) && return 0
    skip "$name" "not installed: ${missing[*]}"
    return 1
}

require_file() {  # <check name> <path> <what to do about it>
    [[ -f $2 ]] && return 0
    skip "$1" "$2 is missing -- ${3-}"
    return 1
}

# ---------------------------------------------------------------------------
# Running
# ---------------------------------------------------------------------------

noct_run_check() {  # <name>
    local name=$1 fn
    # Split from the declaration above on purpose: an associative-array
    # subscript that names a variable being assigned in the same `local` is
    # expanded before the assignment takes effect, and under `set -u` that is
    # an unbound-variable abort rather than an empty string.
    fn=${NOCT_CHECK_FN[$name]-}
    if [[ -z $fn ]]; then
        printf 'unknown check: %s\n' "$name" >&2
        return 1
    fi
    NOCT_CURRENT=$name
    NOCT_VERDICT=
    "$fn"
    local rc=$?
    noct_unwind
    # A check that returned without a verdict is a bug in the check, and it used
    # to read as a silent pass -- which is the exact failure mode this whole
    # suite exists to eliminate.
    if [[ -z $NOCT_VERDICT ]]; then
        fail "$name" "the check returned $rc without reporting a verdict"
        info "this is a bug in the check itself, not a finding about the desktop"
    fi
    NOCT_CURRENT=
    return 0
}

noct_summary() {
    (( QUIET )) && return 0
    printf '\n%s%d passed, %d failed, %d skipped%s\n' "$BOLD" "$PASS" "$FAIL" "$SKIP" "$RESET"
}

# ---------------------------------------------------------------------------
# JSON
#
# Hand-rolled rather than piped through jq, because this has to work on a
# machine where the suite is reporting that jq is missing.
# ---------------------------------------------------------------------------

# tilde -- a path with the home directory collapsed to ~.
#
# For messages a person reads, and for anything that might be recorded: a
# baseline is committed to a public remote, so the absolute path names the
# machine's user account to everyone who clones it. ~ says the same thing.
# The ~ in the replacement MUST be backslashed. Unescaped, bash tilde-expands
# it back to $HOME and the substitution becomes a silent no-op that looks
# exactly like a working one. The guard is for a HOME that is empty or /, where
# an empty pattern would otherwise match at every position.
tilde() {
    local p=$1
    [[ -n ${HOME:-} && $HOME != / ]] || { printf '%s' "$p"; return; }
    printf '%s' "${p//$HOME/\~}"
}

_json_escape() {
    local s=$1
    # Redaction before escaping, and here rather than in each check, because
    # this is the one function every string in a baseline passes through --
    # messages, metric values, the host name. A check added later cannot leak a
    # home path into a committed file without going through this line.
    [[ -n ${HOME:-} && $HOME != / ]] && s=${s//$HOME/\~}
    s=${s//\\/\\\\}; s=${s//\"/\\\"}; s=${s//	/\\t}
    printf '%s' "$s"
}

noct_json() {  # the whole run, as one object
    local line key value value_json tol status name message first

    printf '{\n'
    printf '  "host": "%s",\n' "$(_json_escape "${NOCT_HOST:-$(hostname 2>/dev/null)}")"
    printf '  "recorded": "%s",\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '  "summary": { "pass": %d, "fail": %d, "skip": %d },\n' "$PASS" "$FAIL" "$SKIP"

    printf '  "results": [\n'
    first=1
    for line in "${NOCT_RESULTS[@]}"; do
        IFS=$'\t' read -r status name message <<<"$line"
        (( first )) || printf ',\n'; first=0
        printf '    { "check": "%s", "status": "%s", "message": "%s" }' \
               "$(_json_escape "$name")" "$status" "$(_json_escape "$message")"
    done
    printf '\n  ],\n'

    printf '  "metrics": {\n'
    first=1
    for line in "${NOCT_METRICS[@]}"; do
        IFS=$'\t' read -r key value tol <<<"$line"
        (( first )) || printf ',\n'; first=0
        # A metric is usually a number, but the context ones are not: a GPU
        # name or a compositor version is exactly the kind of thing that
        # explains why two machines measure differently, so it is recorded the
        # same way and quoted here rather than kept somewhere else.
        if [[ $value =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
            value_json=$value
        else
            value_json="\"$(_json_escape "$value")\""
        fi
        if [[ -n $tol ]]; then
            printf '    "%s": { "value": %s, "tolerance": %s }' "$(_json_escape "$key")" "$value_json" "$tol"
        else
            printf '    "%s": { "value": %s }' "$(_json_escape "$key")" "$value_json"
        fi
    done
    printf '\n  }\n'
    printf '}\n'
}
