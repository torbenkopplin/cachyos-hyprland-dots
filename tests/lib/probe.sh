# probe.sh -- every live measurement gets its own, brand new window.
#
# The rule, and why it is absolute
# --------------------------------
# Nothing in this suite measures a window you already had open. It always
# spawns one, measures it, and kills it.
#
# That is not tidiness. A window that has been open for a while is not evidence
# about the configuration on disk:
#
#   * kitty reads generated-glass.conf at startup and again on SIGUSR1. A
#     terminal started before the last `noct-glass apply` is sitting at a level
#     that no file on this machine describes, and measuring it reports the
#     history of the session rather than its configuration. This is not
#     hypothetical: it is why glass-visible used to print "this terminal is at
#     the compositor's level, not its configured one" as an aside -- the check
#     had noticed it was measuring the wrong window and carried on anyway.
#
#   * a Firefox-family browser reads user.js and chrome/userChrome.css exactly
#     once, at startup, and never again. A running Zen is running whatever the
#     stylesheet said the last time it was launched.
#
#   * whatever is on screen in your terminal averages into the measurement. A
#     probe is blank on purpose, so the number describes the window and not the
#     scrollback.
#
# So: a check that finds no window to measure spawns one. A check that finds
# ten does not care.
#
# Browser probes and the throwaway profile
# ----------------------------------------
# A browser probe runs a NEW PROCESS against a THROWAWAY PROFILE seeded from
# the artefacts this repo actually installs -- the repo's user.js and, for Zen,
# the chrome/userChrome.css that noct-glass generated into the managed profile.
#
# A new process, because a Firefox-family browser given a URL while it is
# already running hands it to the existing process, which re-reads nothing. The
# only way to test a stylesheet is to start a browser that has not read one yet.
#
# A throwaway profile, because the real one is locked while the browser is open
# -- so measuring the real profile would mean "close your browser and rerun",
# every time -- and because a test that writes into a profile holding live
# cookies is a test nobody will run twice.
#
# What that costs, stated plainly: a seeded profile does NOT carry Zen's
# "transparent zen" mod, so the browser probe measures our stylesheet without
# the rule it has to beat. That half is covered statically instead, by
# zen-sheet, which compares the two selectors' specificity directly. Between
# them the two checks cover what one live measurement on the real profile would
# -- and they do it without asking you to close anything.

# ---------------------------------------------------------------------------
# Windows
# ---------------------------------------------------------------------------

# noct_wait_window <jq filter over clients> -- poll for a window, print its
# address. Up to <timeout> seconds, default 12.
#
# Polled rather than waited on, because there is no event that means "the
# window has painted" -- and a window that exists in `hyprctl clients` a few
# milliseconds after mapping is still 0x0 in places. The size floor below is
# what stops a capture landing on a window that has not been laid out yet.
noct_wait_window() {  # <jq select expression> [timeout seconds]
    local filter=$1 timeout=${2:-12} i addr
    for (( i = 0; i < timeout * 4; i++ )); do
        addr=$(hyprctl -j clients 2>/dev/null | jq -r "
            [ .[] | select(.size[0] > 200 and .size[1] > 150) | select($filter) ]
            | .[0].address // empty" 2>/dev/null)
        [[ -n $addr ]] && { printf '%s' "$addr"; return 0; }
        sleep 0.25
    done
    return 1
}

# noct_window_geom <address> <center|page> -- "<monitor> <crop geometry>".
#
# Two shapes, because two different things are being measured:
#
#   center  the middle 70% of the window. Borders, rounded corners and the
#           shadow all sit outside it, and every one of them would drag a mean
#           towards the wallpaper and read as extra translucency.
#
#   page    the lower-middle of the window, which for a browser is page area
#           and nothing else. A browser's top third is tab strip and URL bar --
#           chrome, which is opaque in some browsers and not others, and
#           including it would mix two materials into one number.
#
# Both are then CLAMPED to the monitor, and that is not a nicety. This is a
# scrolling layout: the tape of tiled windows is wider than the screen, so a
# perfectly healthy focused window routinely hangs off one edge. grim clamps a
# crop that starts at a negative offset to zero rather than refusing it, so an
# unclamped patch does not fail -- it quietly slides onto the window next door
# and returns a number for the wrong window. Measured: a probe painted #121212
# reported 193 of 255 that way, and nothing about the result looked wrong.
#
# Prints nothing if what is left on screen is too small to average.
noct_window_geom() {
    local addr=$1 shape=${2:-center}
    hyprctl -j clients 2>/dev/null | jq -r \
        --arg a "$addr" --arg shape "$shape" \
        --argjson mons "$(hyprctl -j monitors 2>/dev/null)" '
        .[] | select(.address == $a) as $w
        | ($mons[] | select(.id == $w.monitor)) as $m
        # The wanted rectangle, in monitor coordinates.
        | (if $shape == "page" then
             [ ($w.at[0] - $m.x + ($w.size[0]*0.25|floor)),
               ($w.at[1] - $m.y + ($w.size[1]*0.50|floor)),
               ($w.size[0]*0.5|floor), ($w.size[1]*0.4|floor) ]
           else
             [ ($w.at[0] - $m.x + ($w.size[0]*0.15|floor)),
               ($w.at[1] - $m.y + ($w.size[1]*0.15|floor)),
               ($w.size[0]*0.7|floor), ($w.size[1]*0.7|floor) ]
           end) as $r
        | ([$r[0], 0] | max) as $x
        | ([$r[1], 0] | max) as $y
        | ([$r[0] + $r[2], $m.width]  | min) as $x2
        | ([$r[1] + $r[3], $m.height] | min) as $y2
        | if ($x2 - $x) >= 200 and ($y2 - $y) >= 150
          then "\($m.name) \($x2 - $x)x\($y2 - $y)+\($x)+\($y)"
          else empty end'
}

# noct_window_settle <address> <center|page> [timeout seconds]
#
# Focus the window, wait for it to stop moving, and insist enough of it is on
# screen to measure. Every probe goes through this before anything is read off
# it.
#
# It is not paranoia, it is the layout. Under a scrolling layout a window that
# has just opened can be anywhere along the tape until focus scrolls to it, and
# the tape keeps moving for as long as the animation runs. Two consecutive
# identical geometries is what "the animation is over" looks like from the
# outside; there is no event to wait on.
#
# Overhanging an edge is allowed -- a focused window at the end of the tape does
# it routinely, and noct_window_geom clamps the patch to whatever is visible.
# What is not allowed is so little of it being visible that the patch is noise,
# which is the size floor noct_window_geom applies. Insisting instead on the
# whole window being on screen was the first version of this, and it skipped
# every run on a busy workspace.
noct_window_settle() {
    local addr=$1 shape=${2:-center} timeout=${3:-8} i prev= now=

    hyprctl dispatch "hl.dsp.window.focus({ address = \"$addr\" })" >/dev/null 2>&1

    for (( i = 0; i < timeout * 4; i++ )); do
        now=$(noct_window_geom "$addr" "$shape")
        [[ -n $now && $now == "$prev" ]] && return 0
        prev=$now
        sleep 0.25
    done
    return 1
}

# noct_window_still <address> <monitor> <geometry> -- is the window still there,
# on the same monitor, at the same place?
#
# Asked after every measurement that moved the compositor level. A window that
# vanished or was retiled between two captures leaves the second one measuring
# the wallpaper, which moves a very long way and reads as a triumphant pass.
noct_window_still() {
    local addr=$1 want_mon=$2 want_geom=$3 now
    now=$(noct_window_geom "$addr" "${4:-center}")
    [[ $now == "$want_mon $want_geom" ]]
}

# ---------------------------------------------------------------------------
# kitty probes
#
# conf/rules.lua floats and centres the noct-probe class, which is what makes a
# probe reliable to find and harmless to spawn: it never disturbs the tiling of
# whatever you were doing.
# ---------------------------------------------------------------------------

NOCT_PROBE_CLASS=noct-probe
NOCT_PROBE_TAPE_CLASS=noct-probe-tape   # deliberately NOT floated -- see binds.sh

# noct_probe_kitty [--class C] [--bg #rrggbb] [--opacity X] [--title T]
#
# Sets NOCT_PROBE_ADDR to the new window's address. Returns 0, or 1 if the
# window never appeared, or 2 if it never came to rest somewhere measurable.
#
# It sets a variable rather than printing one, and that is not a style choice.
# A function whose output is captured with $(...) runs in a SUBSHELL, and
# everything it puts on the defer stack goes into that subshell's copy and is
# thrown away when the substitution ends -- so the caller never kills the
# window. The first version of this printed its result, and a run of two checks
# left five probe terminals open on the workspace, each one narrowing the tape
# until the next probe had no room to be measured in. Nothing reported it: the
# checks skipped, with a message about the probe not settling.
#
# The default background is white, and that is a measurement decision rather
# than a cosmetic one. What every check here measures is a window moving
# between its own colour and its backdrop, and the size of that signal is the
# distance between the two. A probe left at the scheme's near-black background,
# sitting over a near-black desktop, has almost nowhere to move: measured, that
# was 5 levels out of 255, close enough to noise to be worthless. White has
# somewhere to move from whatever is behind it.
#
# Blank, too. Text would average into the patch.
NOCT_PROBE_ADDR=

noct_probe_kitty() {
    local class=$NOCT_PROBE_CLASS bg='#ffffff' opacity= title=noct-probe
    while (( $# )); do
        case $1 in
            --class)   class=$2; shift 2 ;;
            --bg)      bg=$2; shift 2 ;;
            --opacity) opacity=$2; shift 2 ;;
            --title)   title=$2; shift 2 ;;
            *) break ;;
        esac
    done

    local -a args=(--class "$class" --title "$title" -o "background=$bg")
    [[ -n $opacity ]] && args+=(-o "background_opacity=$opacity")

    kitty "${args[@]}" sh -c 'clear; sleep 120' >/dev/null 2>&1 &
    local pid=$!
    defer "kill $pid 2>/dev/null; wait $pid 2>/dev/null"

    # Matched on class AND title. The class is what conf/rules.lua keys its
    # float rule on, so it cannot be unique; the title is set per probe, and
    # without it a probe still being torn down from the previous check gets
    # picked up as this one's -- which then fails to settle, because it is busy
    # closing.
    NOCT_PROBE_ADDR=$(noct_wait_window ".class == \"$class\" and (.title // \"\") == \"$title\"") || return 1

    # The window is up, but the compositor's open animation is still running
    # and the tape may still be scrolling to it. A capture taken during either
    # measures a window that is smaller, more transparent, or somewhere else.
    noct_window_settle "$NOCT_PROBE_ADDR" center || return 2
    sleep 0.5
    return 0
}

# ---------------------------------------------------------------------------
# Browser probes
# ---------------------------------------------------------------------------

# The four browsers this repo configures, and how to give each one a fresh
# process on a profile of our choosing.
#
#   zen, firefox        Firefox-family. --profile takes a directory, --no-remote
#                       forces a new process instead of handing the URL to a
#                       running one. The profile is seeded, because everything
#                       this repo does to a Firefox-family browser is a file in
#                       the profile.
#
#   brave, chromium     Chromium-family. --user-data-dir is both the fresh
#                       profile and the fresh process; nothing needs seeding
#                       because everything this repo does to them is a policy
#                       file under /etc, which is read whatever profile is in
#                       use. The extra flags are all "do not show me the
#                       first-run experience", which would otherwise be the
#                       thing on screen when the capture happens.
noct_browser_binary() {  # <browser>
    case $1 in
        zen)      printf 'zen-browser' ;;
        firefox)  printf 'firefox' ;;
        brave)    printf 'brave' ;;
        chromium) printf 'chromium' ;;
        *) return 1 ;;
    esac
}

NOCT_BROWSERS=(zen firefox brave chromium)

# noct_browsers_present -- the subset installed on this machine.
noct_browsers_present() {
    local b bin
    for b in "${NOCT_BROWSERS[@]}"; do
        bin=$(noct_browser_binary "$b")
        command -v "$bin" >/dev/null 2>&1 && printf '%s\n' "$b"
    done
    return 0
}

# noct_managed_profiles <zen|firefox> -- profile directories this repo has
# installed a user.js into. That is also how noct-glass decides where to write,
# so it is the same set on both sides.
noct_managed_profiles() {
    local roots=()
    case $1 in
        zen)     roots=("$CONFIG_HOME/zen" "$HOME/.zen") ;;
        firefox) roots=("$HOME/.mozilla/firefox") ;;
        *) return 1 ;;
    esac
    local root
    for root in "${roots[@]}"; do
        [[ -d $root ]] || continue
        find "$root" -mindepth 2 -maxdepth 2 -name user.js -printf '%h\n' 2>/dev/null
    done
    return 0
}

# The page every browser probe loads: an ORDINARY page, painting an opaque
# background, because that is what every page you actually look at does.
#
# This was a transparent page first, on the theory that the generated Zen
# stylesheet only shows where the page paints nothing. It measured nothing.
# Firefox honours `background: transparent` on the root too, so its page area
# came out at the same brightness as the wallpaper behind it, the solve had
# nothing to divide by, and the check reported a browser with no opacity at all.
# Which is true of that page and true of no page anybody visits.
#
# So: white, opaque, and the number that comes out is how much of the wallpaper
# reaches your eye through a web page. That is the thing the complaint is
# about, it is the same question for all four browsers, and it is comparable
# between them and between machines.
#
# What this page CANNOT see is the generated Zen stylesheet, which only shows
# through where the page itself paints nothing. That half is checked statically
# instead, by zen-sheet, which compares its alpha and its specificity directly.
#
# The title, and why it changes
# -----------------------------
# The probe window is found by its title, because a browser's window class is
# its own business and differs between the four (`zen`, `firefox`,
# `brave-browser`, `chromium`) in ways that also differ between versions. A
# page title is set by the page.
#
# It starts as noct-probe and becomes noct-probe-ready once the page has
# actually been painted, and waiting for the second one is what makes this
# reliable. A browser maps its window before it paints the page, and on Wayland
# an unpainted content area is TRANSPARENT -- so a capture taken in that gap
# photographs the wallpaper and reports a browser with no opacity at all. It is
# also perfectly stable while it lasts, so capturing twice and comparing does
# not catch it. Measured: firefox came out at 0.00 that way, but only on the
# runs where something else had just been busy, which is the worst kind of
# flake to chase.
#
# Two nested requestAnimationFrames after load, because the first one is
# scheduled BEFORE the frame that contains the page and the second one runs
# after it has been composited.
NOCT_PROBE_TITLE=noct-probe
NOCT_PROBE_READY=noct-probe-ready

noct_probe_page() {  # <path>
    cat >"$1" <<'HTML'
<!doctype html>
<meta charset="utf-8">
<title>noct-probe</title>
<style>html, body { background: #ffffff; margin: 0; height: 100%; }</style>
<script>
  addEventListener("load", function () {
    requestAnimationFrame(function () {
      requestAnimationFrame(function () { document.title = "noct-probe-ready"; });
    });
  });
</script>
HTML
}

# What an ordinary page paints its text in, as a grey level. Not measured --
# the probe page is deliberately blank, because glyphs are 1% of the pixels and
# a percentile over them measures the content rather than the desktop. It is
# the constant the readability number below is computed against, and #222 is
# what a typical light page uses.
NOCT_PAGE_TEXT_GREY=34

# noct_seed_profile <browser> <dir> -- put this repo's configuration into a
# throwaway Firefox-family profile.
#
# Both halves matter and they come from different places: the user.js is the
# repo's, because that is the artefact under test, and the userChrome.css is
# the managed profile's, because it is GENERATED by noct-glass from the levels
# in force and does not exist in the repo at all.
noct_seed_profile() {
    local browser=$1 dir=$2 src real
    mkdir -p "$dir/chrome"

    src=$NOCT_REPO/browsers/$browser/user.js
    [[ -f $src ]] && cp "$src" "$dir/user.js"

    real=$(noct_managed_profiles "$browser" | head -1)
    if [[ -n $real && -f $real/chrome/userChrome.css ]]; then
        cp "$real/chrome/userChrome.css" "$dir/chrome/userChrome.css"
    fi

    # A profile that has never been started shows its first-run tour, and the
    # tour covers the whole window -- so the capture photographs the welcome
    # screen and reports its colour as the colour of a web page. Zen's is the
    # worst of them: "Welcome to a calmer internet" over a full-bleed image,
    # which measured 41 of 255 where a white page should have measured 255.
    #
    # None of this is configuration under test. It is the difference between
    # photographing the probe page and photographing an advertisement for the
    # browser.
    cat >>"$dir/user.js" <<PREFS
// Added by the test suite, for this throwaway profile only.
user_pref("browser.startup.page", 0);
user_pref("browser.aboutwelcome.enabled", false);
user_pref("browser.startup.homepage_override.mstone", "ignore");
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("datareporting.policy.firstRunURL", "");
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.shell.didSkipDefaultBrowserCheckOnFirstRun", true);
user_pref("app.normandy.first_run", false);
user_pref("doh-rollout.doneFirstRun", true);
user_pref("nimbus.firstUpdateComplete", true);
user_pref("zen.welcome-screen.seen", true);
PREFS
}

# noct_close_browser <address> <pid> -- shut a probe browser down the way a
# person would, and do not come back until its window is actually gone.
#
# Closing the window rather than signalling the process, because a browser that
# is SIGTERMed thinks it crashed. Measured: killing the probe left Firefox
# offering "Open Firefox in Troubleshoot Mode?" on its next launch and Zen
# restarting in safe mode -- a test that makes the thing it tested worse.
#
# Waiting on the WINDOW rather than on the pid, and this is the part that
# matters. The command on PATH is usually a wrapper that execs the real binary,
# so the pid this suite holds is often already gone while the browser it
# started is still on screen. Waiting on that pid returns instantly and the
# next browser's probe then finds the PREVIOUS browser's window, which is by
# then in the middle of closing -- so the patch lands on wallpaper and the
# browser is reported as having no opacity at all. That is exactly what
# happened: firefox measured 0.00 on a run where zen had not finished closing.
noct_close_browser() {
    local addr=$1 pid=$2 i
    [[ -n $addr ]] && hyprctl dispatch "hl.dsp.window.close({ window = \"address:$addr\" })" >/dev/null 2>&1
    for (( i = 0; i < 40; i++ )); do
        if ! hyprctl -j clients 2>/dev/null | jq -e --arg a "$addr" \
               'any(.[]; .address == $a)' >/dev/null 2>&1; then
            kill -0 "$pid" 2>/dev/null && { kill "$pid" 2>/dev/null; wait "$pid" 2>/dev/null; }
            return 0
        fi
        sleep 0.25
    done
    kill "$pid" 2>/dev/null
    wait "$pid" 2>/dev/null
    return 0
}

# noct_no_probe_windows [timeout] -- wait until nothing titled like a probe is
# left on screen. Called between browsers, because "the window I asked to close
# has gone" and "no window that a title match could confuse for mine is left"
# are different statements, and only the second one makes the next probe safe.
noct_no_probe_windows() {
    local timeout=${1:-10} i n
    for (( i = 0; i < timeout * 4; i++ )); do
        n=$(hyprctl -j clients 2>/dev/null \
            | jq -r --arg t "$NOCT_PROBE_TITLE" '[ .[] | select((.title // "") | test($t)) ] | length')
        [[ ${n:-0} == 0 ]] && return 0
        sleep 0.25
    done
    return 1
}

# noct_probe_browser <browser>
#
# Sets NOCT_PROBE_ADDR to the new browser window, framed on its PAGE area.
# Returns 0, 1 if it never appeared, 2 if it never came to rest.
#
# Registers teardown of the process and of the profile it was given -- see the
# note on noct_probe_kitty for why this sets a variable rather than printing
# one.
#
# A throwaway profile, for both families
# --------------------------------------
#   Chromium-family   nothing this repo does to Brave or Chromium lives in a
#                     profile: the configuration is a policy file under /etc,
#                     read whatever profile is in use. A throwaway profile is
#                     exactly as faithful as the real one.
#
#   Firefox-family    seeded with the repo's user.js and the userChrome.css
#                     noct-glass generated into the managed profile, which is
#                     everything this repo installs into one.
#
# The real profile was tried, on the argument that a Zen without its
# "transparent zen" mod is not the Zen you run. It measured the same number --
# the probe page paints an opaque background, so what comes back is the
# compositor's level either way, and the mod does not transparentise a local
# file:// page. What it cost was real: the browser cannot be launched at all
# while you have it open, the new process restores your whole session first,
# and shutting it down again is not reliably clean.
#
# So the live measurement is taken hermetically, and the one thing it cannot
# see -- whether the generated stylesheet beats the mod's rule -- is checked
# statically by zen-sheet, which compares the two selectors directly.
noct_probe_browser() {
    local browser=$1 bin
    bin=$(noct_browser_binary "$browser") || return 1
    command -v "$bin" >/dev/null 2>&1 || return 1

    local tmp; tmp=$(mktemp -d)
    noct_probe_page "$tmp/probe.html"

    local -a cmd
    case $browser in
        zen|firefox)
            noct_seed_profile "$browser" "$tmp/profile"
            # --no-remote or the URL is handed to a browser you already have
            # open, which then opens a tab in it and never starts a process of
            # its own -- so nothing new reads the configuration under test.
            cmd=("$bin" --profile "$tmp/profile" --no-remote --new-window "file://$tmp/probe.html")
            ;;
        brave|chromium)
            cmd=("$bin" --user-data-dir="$tmp/profile"
                 --no-first-run --no-default-browser-check --disable-sync
                 --password-store=basic --new-window "file://$tmp/probe.html")
            ;;
    esac

    # MOZ_ENABLE_WAYLAND is set in conf/env.lua for the session, but a probe
    # must not depend on having inherited it: under XWayland a Firefox window
    # gets no translucency at all and the check would report a configuration
    # problem that is really an environment one.
    MOZ_ENABLE_WAYLAND=1 "${cmd[@]}" >/dev/null 2>&1 &
    local pid=$!

    # The profile is removed AFTER the browser is gone -- deferred first, so it
    # unwinds last. Pulling a live profile out from under a running browser is
    # how a clean shutdown turns back into a crash.
    defer "rm -rf '$tmp'"

    # 30 seconds, not 12. A browser starting cold on a profile it has never
    # seen builds caches, and on a slow disk that is comfortably past the point
    # where a kitty probe would have been up ten times over.
    # The READY title, not the plain one: the page says when it has been
    # painted, and until it has, the content area is transparent and a capture
    # of it is a photograph of the wallpaper.
    NOCT_PROBE_ADDR=$(noct_wait_window "(.title // \"\") | test(\"$NOCT_PROBE_READY\")" 40) || {
        # Still worth finding the window, so it can be closed rather than
        # signalled -- a SIGTERMed browser offers troubleshoot mode next time.
        local stray
        stray=$(noct_wait_window "(.title // \"\") | test(\"$NOCT_PROBE_TITLE\")" 1) || stray=
        defer "noct_close_browser '$stray' $pid"
        return 1
    }
    defer "noct_close_browser '$NOCT_PROBE_ADDR' $pid"

    noct_window_settle "$NOCT_PROBE_ADDR" page 20 || return 2
    sleep 0.5
    return 0
}
