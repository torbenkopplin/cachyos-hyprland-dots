# 019 — Mail credentials live in `pass`, and `accounts.conf` holds only the lookup

**Measured 2026-08-22** on aerc 0.21.0. Status: in force.

aerc needs a password. The mail server is Dovecot and, verified against the live
service, it offers `AUTH PLAIN` and `AUTH LOGIN` over implicit TLS and nothing
else — 993 and 465 are the only mail ports open, 143, 587 and 25 are all
filtered. So there is no OAuth path to hide behind and no token to store instead:
something on this machine has to be able to produce a password.

`accounts.conf` is the file aerc reads it from, and that file cannot be tracked.
It names mail addresses and server names, and whatever it says about the password
is either a secret in git or a machine-local reference. That is the same shape as
[014](014-two-machine-local-files.md), and it is settled the same way: the repo
tracks `config/aerc/accounts.conf.example` and the linker skips `*.example` by
rule, so the real file is copied once per machine and never committed.

What was left was where the password itself lives.

## `pass`, not the keyring

`source-cred-cmd` and `outgoing-cred-cmd` run a command and read the password off
its stdout, so the tracked example can say `pass show mail/<account>` and the
secret stays in the password store. aerc caches the result until it exits, so the
GPG agent asks once per session rather than once per sync.

The keyring route was the obvious alternative and it is not available here.
`secret-tool` is already on PATH — libsecret pulls it in — which makes it look
present. It is not: nothing owns `org.freedesktop.secrets`. `busctl --user list`
shows exactly one candidate, `org.kde.secretservicecompat`, marked activatable,
and activating it fails:

```
$ secret-tool search --all service aerc
secret-tool: The name is not activatable
```

Making that work means installing `gnome-keyring` **and** unlocking it at login,
which greetd does not do on its own, so it also means PAM wiring in a stack this
repo configures ([016](016-greetd-instead-of-plasmalogin.md)). Three moving parts
on each of two machines, for the same outcome that one GPG key buys. `gpg` is
already installed; `pass` is a shell script around it.

The third option — the password inline in the `source` URL — was rejected for
being a readable secret on disk, not for being hard. It is the fallback if the
GPG key is ever unavailable, and it is written down in the example for that case,
including the fact that an inline password must be URL-encoded like every other
field in the URL.

## The bug this found

Adding `pass` to `tests/deps.tsv` made `noct-check deps-installed` report it
present on a machine that had never had it. The check tested `command -v "$cmd"`,
and `command -v` **resolves shell functions before it looks at PATH** —
`tests/lib/harness.sh` defines `pass`, `fail`, `skip`, `info` and `metric`, so
any dependency named after one of them could never be reported missing.

`pass` is the first collision that was ever plausible, and it is a good one: the
check that exists to catch a tool missing from a fresh machine was silently
incapable of catching this one. Fixed by testing `type -P`, which searches PATH
and nothing else, in `20-deps.sh` and in the harness's own `need`. Verified the
way this repo asks for — against the broken version first, which reported 47 of
48 present, then against the fix, which reports 46 and names both gaps.

## What else this settled

`w3m` is a dependency of aerc's *configuration*, not of its package. The default
filter list maps `text/html` to a filter script that wraps w3m, so without it the
most common kind of mail renders as an empty body with nothing anywhere saying
why. It is in the manifest and in `deps.tsv` now, and it is the same shape as the
`tree-sitter-cli` gap that made `deps.tsv` exist at all.

`config/aerc/aerc.conf` therefore carries the shipped filter list verbatim, which
would otherwise look like tracked defaults: aerc uses the **first** `aerc.conf`
it finds rather than merging, so the moment this repo ships one it displaces
`/usr/share/aerc/aerc.conf` entirely and anything that file set is gone.
