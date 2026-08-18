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

// --- Customisation ---------------------------------------------------------
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// --- Transparency, matched to the desktop's frosted glass -------------------
//
// Two independent things are at work here, and they were landing at very
// different shades:
//
//   * The desktop. bin/noct-glass sets Hyprland's window opacity for EVERY
//     window -- 0.90 by default, per scheme in ~/.config/noctalia/glass.conf,
//     and `noct-glass show` says which is in force -- and the compositor blurs
//     the wallpaper behind whatever is left. A terminal or a GTK app therefore
//     shows about a tenth of the wallpaper: a dark surface with a hint of the
//     image in it.
//
//   * Zen. The "transparent zen" mod (sameerasw) plus the "Zen Internet"
//     extension make the browser surface AND most page backgrounds transparent,
//     so reddit and youtube showed nearly all of the wallpaper -- much lighter
//     than every window beside them.
//
// The prefs below only *enable* that. The shade itself is the `browser` level in
// glass.conf, which noct-glass divides by the window opacity and writes into
// chrome/noct-glass.css in this profile -- so the browser and the rest of the
// desktop are two numbers in one file rather than a value copied by hand into a
// browser config. noct-glass writes the whole of that file; nothing in this repo
// tracks it, because its only content is a number derived from glass.conf.
//
// Both are read at startup, so a change here or there needs Zen restarted.
user_pref("browser.tabs.allow_transparent_browser", true);
user_pref("zen.widget.linux.transparency", true);
user_pref("zen.view.grey-out-inactive-windows", false);

// Deliberately OFF, and not a leftover. With it on, the mod defines
// --zen-main-browser-background on an element below :root, and a variable set
// further down the tree cannot be reached by inheritance from above -- so the
// generated stylesheet would lose to it. Off, the mod leaves the variable alone
// and the generated value applies.
user_pref("mod.sameerasw.zen_bg_color_enabled", false);

// The mod's own page tint, left on Flip (1) rather than Remove (2). The generated
// stylesheet overrides it, so this is purely the fallback for a profile where that
// file is missing: a 10% dark wash under a dark scheme is a far better failure
// mode than a fully transparent page.
user_pref("mod.sameerasw_zen_light_tint", "1");
