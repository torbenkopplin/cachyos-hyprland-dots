// Firefox user.js -- installed into every profile under ~/.mozilla/firefox/.
//
// user.js is re-applied on every startup, so anything set here cannot be
// changed persistently from the UI: change it in the browser and it reverts on
// restart. That makes it right for settings you have decided once, and wrong
// for anything you want to toggle. Preferences that belong in the UI are
// deliberately absent.
//
// Telemetry, Pocket and sponsored content are handled by policies.json
// instead, which is the stronger mechanism. This file covers what policy
// cannot reach.

// --- Startup ---------------------------------------------------------------
// 3 = restore the previous session. On a work machine that is the difference
// between resuming and rebuilding your context.
user_pref("browser.startup.page", 3);
user_pref("browser.aboutConfig.showWarning", false);

// --- Chrome ----------------------------------------------------------------
// 1 = compact density. Reclaims vertical space, which matters more than usual
// on a scrolling layout where a browser column is often only half the screen.
user_pref("browser.uidensity", 1);
user_pref("browser.tabs.firefox-view", false);
user_pref("browser.tabs.tabmanager.enabled", false);

// Allow a chrome/userChrome.css in the profile to take effect. None ships
// here; this only removes the barrier to dropping one in later.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// --- Quieter browsing ------------------------------------------------------
user_pref("browser.urlbar.suggest.quicksuggest.sponsored", false);
user_pref("browser.urlbar.suggest.quicksuggest.nonsponsored", false);
user_pref("browser.urlbar.trending.featureGate", false);
user_pref("browser.urlbar.suggest.weather", false);
user_pref("extensions.getAddons.showPane", false);
user_pref("extensions.htmlaboutaddons.recommendations.enabled", false);

// --- Wayland ---------------------------------------------------------------
// Touchpad pinch-zoom and smooth scrolling behave correctly under Wayland
// only with this on. MOZ_ENABLE_WAYLAND itself is set in conf/env.lua.
user_pref("apz.gtk.touchpad_pinch.enabled", true);
user_pref("widget.dmabuf.force-enabled", true);

// --- Downloads -------------------------------------------------------------
// Ask where each file goes rather than silently filling ~/Downloads.
user_pref("browser.download.useDownloadDir", false);
