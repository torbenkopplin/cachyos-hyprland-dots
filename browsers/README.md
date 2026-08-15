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
| `zen/user.js` | every profile in `~/.zen/` | Zen |

Chromium-family policy files need root and take effect on next launch.
Firefox-family `user.js` is read at startup and re-applies its values every
time, so a setting changed in the UI reverts on restart — that is the point,
but it is also why anything you want to be able to change by hand should *not*
be listed there.

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
