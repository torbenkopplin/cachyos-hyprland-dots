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
// The two multiply: what you see is Zen's own alpha times the compositor's. So
// a tint of 0.6 lands at 0.6 x 0.90 = 0.54, i.e. roughly half the wallpaper
// showing where the rest of the desktop shows a tenth of it. That is the
// deliberate meeting point -- clearly glassier than a terminal, clearly the same
// material. Raise it towards 1.0 to converge on the rest of the desktop, lower
// it for more wallpaper.
//
// The desktop side is not the one to move: the compositor cannot separate a
// window's text from its background, so fading windows further fades their text
// with them. The browser draws its own translucency and keeps its text opaque,
// which is why the room to meet is on this side.
//
// #121212 is the palette surface (noirblaze); any near-black reads the same
// under a dark scheme. Unlike the rest of the theming this cannot follow the
// palette automatically -- a profile path is random per install, so there is
// nowhere for a Noctalia template to render to.
user_pref("browser.tabs.allow_transparent_browser", true);
user_pref("zen.widget.linux.transparency", true);
user_pref("zen.view.grey-out-inactive-windows", false);

// The alpha in this string IS the knob -- it is the only number here worth
// touching. (The mod writes this pref as 8-digit hex itself, #12121299 being the
// same colour; its own placeholder text accepts either, and rgba() is the form
// you can actually tune by eye.)
user_pref("mod.sameerasw.zen_bg_color_enabled", true);
user_pref("mod.sameerasw.zen_transparency_color", "rgba(18, 18, 18, 0.6)");

// The mod's own "light website tint": 1 = Flip, which puts a 10% dark wash
// behind the page under a dark scheme, 2 = Remove, which is the fully
// transparent default that made pages read so much lighter than everything else.
user_pref("mod.sameerasw_zen_light_tint", "1");

// If the page area still reads lighter than the chrome around it, the pref above
// is reaching the browser background but not the content stack. Add this to
// <profile>/chrome/userChrome.css, which the pref at the top of this section
// already enables, and restart:
//
//   .browserStack > browser { background-color: rgba(18, 18, 18, 0.6) !important; }
