# Browser configuration

Only declarative, secret-free configuration lives here. **No profile data.**

A browser profile (`~/.config/BraveSoftware/.../Default`,
`~/.mozilla/firefox/<profile>`) holds live session cookies, saved passwords and
full history. Committing one to git would put working credentials into every
clone and every remote, permanently — `git rm` afterwards does not remove them
from history. So this directory carries only the parts that describe *how the
browser should behave*, which are safe to publish and reproducible anywhere.

Bookmarks, extensions and logins come from each browser's own sync account.
Nothing in these files disables sync — that is deliberate, since sync is how
you get that data onto the new machine.

## What goes where

| File | Installed to | Applies to |
|---|---|---|
| `brave/policies.json` | `/etc/brave/policies/managed/` | Brave |
| `chromium/policies.json` | `/etc/chromium/policies/managed/` | Chromium |
| `firefox/policies.json` | `/etc/firefox/policies/` | Firefox |
| `firefox/user.js` | every profile in `~/.mozilla/firefox/` | Firefox |
| `zen/user.js` | every profile in `~/.config/zen/` (or `~/.zen/`) | Zen |

Chromium-family policy files need root and take effect on next launch.
Firefox-family `user.js` is read at startup and re-applies its values every
time, so a setting changed in the UI reverts on restart — that is the point,
but it is also why anything you want to be able to change by hand should *not*
be listed there.

Zen's profile root is **`~/.config/zen`** on `zen-browser-bin` 1.21, not `~/.zen`
as its Firefox ancestry suggests — which is why `install.sh` tries both, and why
the Zen half of `--browsers` had quietly never landed anything before. `find` the
profile if you need it by hand; the directory name is random per install:

```sh
ls -d ~/.config/zen/*.*        # e.g. "yemhuyco.Default (release)"
```

Install with:

```sh
./install.sh --browsers        # needs sudo for the policy directories
```

## Why these keys

The JSON files carry no `_comment` entries on purpose. Chromium and Firefox
both surface unrecognised keys as errors on their policy pages, so a comment
key would produce exactly the noise those pages exist to help you spot. The
rationale lives here instead.

**Brave.** Rewards, Wallet, VPN, Leo (AI chat) and Tor are all switched off:
they are product surfaces, not browser features, and each one adds UI to a
window you are trying to keep quiet. Telemetry and the survey/promo prompts go
with them. `RestoreOnStartup: 1` reopens your previous tabs, which on a work
machine is the difference between resuming and rebuilding your context.

**Chromium.** Deliberately thinner — this is the "check it in a clean engine"
browser rather than a daily driver, so it gets telemetry off and no first-run
nagging, and nothing else opinionated.

**Firefox.** This is the "pure" part of Firefox-pure: Pocket, sponsored
shortcuts, sponsored stories, snippets, the onboarding tour and the
"More from Mozilla" panel are all things Mozilla ships enabled, and none of
them is the browser you asked for. Search and top sites stay on because they
are actually useful; `Locked: false` means you can still change them in the UI.

**Zen — transparency, on but unmatched.** No browser here knows about the
desktop. `bin/noct-glass` sets one opacity for every window through the
compositor and blurs the wallpaper behind it, and a browser gets that and nothing
more — the same as a GTK app, and for the same reason: it paints its own
background.

Zen is the one browser that *can* do more, with the "transparent zen" mod and the
"Zen Internet" extension, and `zen/user.js` switches on the two prefs those need:
`browser.tabs.allow_transparent_browser` and `zen.widget.linux.transparency`.
They are what give the window an alpha channel at all, and without them the mod
paints against Zen's own opaque backdrop and looks like it is not installed.

What `zen/user.js` no longer does is *tint* what the mod leaves transparent. That
was a `browser` level in `glass.conf` written into a generated
`chrome/userChrome.css`, and it was dropped on 2026-08-19 — see
[theming](../docs/theming.md#what-was-tried-with-zen-and-dropped). So Zen is
translucent at whatever the mod paints, matched to nothing, and it will not read
as the same material as a terminal. Installing and enabling the mod is yours to
do; no file here can.

**Zen is the only one, and that is a rule rather than an accident.** Brave,
Chromium and Firefox get no effect of their own — no transparency prefs, no
stylesheet, nothing in their policy files that touches how they paint. At the
shipped `window = 1.0` the compositor is not fading them either, so what they get
is nothing at all. `noct-check browser-glass` is what enforces it: any browser
*other* than Zen measuring under the compositor's level is a finding, because
nothing here arranges that and nothing should.

Both prefs are stated rather than omitted, and that is not the same thing:
`user.js` only *sets* prefs, so a deleted line leaves whatever `prefs.js` already
recorded rather than restoring the default.

`user.js` is read at startup, so changing it needs Zen restarted — and because it
re-applies at *every* startup, a pref changed by hand in `about:config` reverts on
the next launch. That is the point of the file, and it is also the trap: it makes
a reinstalled mod look broken until the pref here agrees with it.

**Not set anywhere:** default search engine, homepage, password manager
behaviour beyond leaving it enabled, and extension allow/block lists. Those are
personal choices, and a policy does not merely set a default — it removes your
ability to change it from the UI at all.

**Not disabled anywhere:** sync, in any browser. That is the deliberate
consequence of keeping profiles out of git — sync is how bookmarks, extensions
and logins reach the new machine.

## Editing policy

The full key reference:

- Chromium/Brave: <https://chromeenterprise.google/policies/>
- Brave-specific: <https://support.brave.com/hc/en-us/articles/360039248271>
- Firefox: <https://mozilla.github.io/policy-templates/>

Verify what actually applied at `brave://policy`, `chrome://policy`, and
`about:policies` — a key that was rejected silently shows up as an error there.
