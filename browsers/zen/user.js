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
//   * Zen. The "transparent zen" mod (sameerasw) plus its companion site styles
//     make the browser surface AND most page backgrounds fully transparent, so
//     reddit and youtube showed ~100% wallpaper -- much lighter in shade than
//     every other window on screen, which is the mismatch these prefs address.
//
// The two multiply: what you see is Zen's own alpha times the compositor's. So a
// tint of 0.75 lands at 0.75 x 0.90 = ~0.67, about a third of the wallpaper
// showing. The terminal meets it from the other side at 0.85 (`terminal` in
// glass.conf), and the two then read as one material at slightly different
// depths instead of as an opaque window beside a hole in the desktop.
//
// Hyprland's own window opacity is not the knob to reach for on either side: the
// compositor cannot separate a window's text from its background, so fading
// windows further fades their text with them. kitty and the browser both draw
// their own translucency and keep their text opaque, which is why all the room to
// meet is in the apps.
//
// #121212 is the palette surface (noirblaze); any near-black reads the same
// under a dark scheme. Unlike the rest of the theming this cannot follow the
// palette automatically -- a profile path is random per install, so there is
// nowhere for a Noctalia template to render to.
user_pref("browser.tabs.allow_transparent_browser", true);
user_pref("zen.widget.linux.transparency", true);
user_pref("zen.view.grey-out-inactive-windows", false);

// This tints Zen's *chrome*, and its alpha is one of the two knobs. (The mod
// writes the pref as 8-digit hex itself -- #121212bf is the same colour -- and
// its placeholder text accepts either; rgba() is the form you can tune by eye.)
user_pref("mod.sameerasw.zen_bg_color_enabled", true);
user_pref("mod.sameerasw.zen_transparency_color", "rgba(18, 18, 18, 0.75)");

// The page area behind a transparent site is a different element, and the mod's
// only control for it is a two-position switch -- so its alpha is set from
// userChrome.css in this directory, installed alongside this file and loaded
// because of the legacyUserProfileCustomizations pref above. Keep the two equal
// or the window is two materials.
//
// That switch is "light website tint": 1 = Flip, a 10% dark wash behind the page
// under a dark scheme; 2 = Remove, the fully transparent default that made pages
// read so much lighter than everything else. Flip is the closer of the two to
// start from, and userChrome.css overrides the result either way.
user_pref("mod.sameerasw_zen_light_tint", "1");
