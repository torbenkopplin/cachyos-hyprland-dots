# The test suite

Run it with `noct-check`. Everything below is about how it is built and how to
add to it; `noct-check --list` is the index of what it currently checks.

```sh
noct-check                    # everything that does not disturb the screen
noct-check --all              # also the ones that open windows
noct-check glass-visible      # just this one, live or not
noct-check --list             # what each check asserts
noct-check --json             # results and measurements, for a script
```

## What it is for

[`TESTING.md`](../TESTING.md) is the checklist for things only a person can
judge — does the animation feel right, did the prompt window appear. This is
the opposite: facts about the running session that are easy to measure and easy
to be wrong about by eye.

Every check here exists because something was broken in a way that looked
fine. The launcher answered "No results found", which is also what a working
provider with nothing to report looks like. The frosted glass was
mathematically present and visually absent — seven levels out of 255.
`hyprctl keyword` is silently a no-op under the Lua parser, so an A/B test
written with it measures nothing and reports success. `tree-sitter-cli` was
never in `install.sh`, on a machine that already had it.

## Two rules that shape the whole thing

**Every live measurement gets a brand new window.** Nothing here measures a
terminal or a browser you already had open. kitty reads its opacity at startup
and on SIGUSR1; a Firefox-family browser reads `user.js` and
`chrome/userChrome.css` exactly once, at startup. So a window that has been
open for a while is evidence about the past, not about the files on disk. It
also carries your scrollback and your tabs, which average into any measurement
taken off it. See [`lib/probe.sh`](lib/probe.sh).

**Every check records numbers, not just a verdict.** A threshold catches a
setup that is broken. It cannot catch a setup that is working but *different* —
and "both machines pass and one of them looks better" is the question that
actually gets asked. So a run can be saved and diffed:

```sh
noct-check --all --record                       # on the machine that looks right
git add tests/baselines/*.json && git commit

noct-check --all --compare tests/baselines/<host>.json   # on the one that does not
```

which answers with the measurements that moved and by how much:

```
out of tolerance
  glass.terminal          0.78 -> 0.55   -0.23  (tolerance 0.01)
  kitty.cell_width       11.40 -> 10.10   -1.30 (tolerance 0.6)
```

Metrics recorded *without* a tolerance are context — monitor scale, GPU,
compositor version, the wallpaper's mean luma. They are reported when they
differ and never fail a comparison, because they are usually the answer rather
than the problem. See [`lib/baseline.sh`](lib/baseline.sh).

## Layout

| | |
|---|---|
| `lib/harness.sh` | registry, verdicts, metrics, deferred cleanup |
| `lib/measure.sh` | reading numbers off the screen, and the compositing arithmetic |
| `lib/probe.sh` | spawning and tearing down fresh windows |
| `lib/baseline.sh` | recording a run, and diffing two of them |
| `checks/*.sh` | the checks themselves, grouped by what they are about |
| `deps.tsv` | every external command this setup needs, and what installs it |
| `baselines/*.json` | recorded runs, one per machine, committed |

`bin/noct-check` is the runner and holds no assertions of its own.

## Adding a check

One function and one registration:

```sh
noct_register my-check pure check_my_thing "one line on what it asserts"

check_my_thing() {
    require_cmd my-check hyprctl jq || return

    local measured
    measured=$(...)
    metric my.thing "$measured" 0.05      # 0.05 is what counts as a difference

    if [[ ... ]]; then
        pass my-check "what is true"
    else
        fail my-check "what is not"
        info "and what to do about it"
    fi
}
```

- `pure` runs by default; `live` opens windows and only runs under `--all` or
  by name.
- Exactly one `pass`/`fail`/`skip` per check. A check that returns without one
  is reported as a bug in the check — silence used to read as success, which is
  the failure mode this suite exists to eliminate.
- `skip` for "cannot answer here" (a tool is missing, one monitor, no profile).
  Never `fail` for that: a machine without chromium is not a broken machine.
- `defer <command>` for anything that has to be put back. It is a stack, it
  unwinds after the check whatever happens, and it nests — `noct_defer_mark`
  and `noct_unwind_to` are how a loop over four browsers closes each one
  without dropping the compositor level it borrowed before the loop.
- `metric <key> <value> [tolerance]` for anything a person might compare
  between two machines. Leave the tolerance off for context.

### If it needs a window

```sh
noct_probe_kitty --title noct-probe-mine --bg '#ffffff' || { skip my-check "no probe"; return; }
noct_glass_borrow                                   # and it will be given back
three=$(noct_measure_surface "$NOCT_PROBE_ADDR" center)
read -r seen _ own back back_sd <<<"$three"
read -r alpha backdrop backdrop_sd <<<"$(noct_solve "$seen" "$own" "$back" "$back_sd")"
```

`noct_probe_kitty` sets `NOCT_PROBE_ADDR` rather than printing it, and that is
load-bearing: a function whose output is captured with `$(...)` runs in a
subshell, and everything it puts on the defer stack is thrown away with that
subshell. The first version printed its result, and a run of two checks left
five probe terminals open — each one narrowing the tape until the next probe
had nowhere measurable to be, so the suite went quiet instead of red.

Read the comment on `noct_solve` before trusting what it returns. What the
ratio it prints *means* depends on whether the window re-read its own
configuration while the level was being moved, and the two cases give different
answers to the same three captures.

### If it needs a new tool

Add it to `deps.tsv`, with the package, the `install.sh` list that installs it,
and one line on why. `deps-declared` fails until you do — that is the check
that stops the manifest rotting, and the manifest is what stops another
`tree-sitter-cli`.
