// Zen user.js -- installed into every profile under ~/.zen/.
//
// Zen is a Firefox fork, so the same pref names apply. It is deliberately
// shorter than the Firefox one: Zen already ships a compact, chrome-light UI
// and its own workspace model, so re-imposing Firefox's layout prefs here
// would fight the browser rather than configure it.
//
// Zen has no /etc policies directory of its own, so unlike Firefox the
// telemetry and sponsored-content settings have to live here.

// --- Startup ---------------------------------------------------------------
user_pref("browser.startup.page", 3);
user_pref("browser.aboutConfig.showWarning", false);

// --- Telemetry (policies.json equivalent) ----------------------------------
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("browser.discovery.enabled", false);

// --- Quieter browsing ------------------------------------------------------
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("extensions.getAddons.showPane", false);
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);

// --- Wayland ---------------------------------------------------------------
user_pref("apz.gtk.touchpad_pinch.enabled", true);
user_pref("widget.dmabuf.force-enabled", true);

// --- Downloads -------------------------------------------------------------
user_pref("browser.download.useDownloadDir", false);

// --- Transparency: deliberately off ----------------------------------------
//
// Zen can draw its own window and page backgrounds transparent -- that is what
// the "transparent zen" mod (sameerasw) and the "Zen Internet" extension are
// for -- and this repo used to switch it on and then tint what it left
// transparent, from a `browser` level in ~/.config/noctalia/glass.conf written
// into a generated chrome/userChrome.css. That was given up on 2026-08-19; the
// reasoning is in docs/theming.md. A browser now gets exactly what every other
// window gets from the compositor and nothing else.
//
// Both are set to `false` rather than simply left out, and the difference
// matters: user.js only ever *sets* prefs. Deleting a line does not restore the
// default -- it leaves whatever prefs.js already recorded, so a profile that had
// transparency switched on would silently keep it forever.
//
// This does not uninstall the mod or the extension. Nothing a file can do will:
// see docs/theming.md for the two things to turn off by hand.
user_pref("browser.tabs.allow_transparent_browser", false);
user_pref("zen.widget.linux.transparency", false);

// Not part of that, and staying: Hyprland already dims an unfocused window
// (inactive_opacity, 0.06 below the active level), so Zen greying itself out on
// top of that is the same cue applied twice.
user_pref("zen.view.grey-out-inactive-windows", false);
