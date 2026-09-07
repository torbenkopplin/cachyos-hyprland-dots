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

// --- Transparency: on ------------------------------------------------------
//
// These two prefs decide whether Zen's window has an alpha channel at all, and
// they are what the "transparent zen" mod (sameerasw) and the "Zen Internet"
// extension need in order to do anything. Both are CSS, and an rgba() background
// needs something behind it to show through -- so with these false the mod paints
// against Zen's own opaque backdrop and looks like it is not installed.
//
// That is the trap worth knowing: reinstalling the mod does not help while these
// are false, because user.js re-applies its values at every startup, so each
// restart undoes the reinstall.
//
// Switched off on 2026-08-19 along with the `browser` glass level, and back on
// the same day. What was dropped and stays dropped is the *tint*: nothing
// generates a chrome/userChrome.css any more, so what reaches the screen is
// whatever the mod and the extension paint, not a level matched to the
// desktop's. The reasoning for giving up that match is in docs/theming.md and it
// still holds -- this turns the transparency back on, not the attempt to make a
// page and a terminal read as one material.
//
// Stated explicitly rather than left out, and that matters in both directions:
// user.js only ever *sets* prefs, so a deleted line leaves whatever prefs.js
// already recorded rather than restoring the default.
user_pref("browser.tabs.allow_transparent_browser", true);
user_pref("zen.widget.linux.transparency", true);

// --- Transparency: how much ------------------------------------------------
//
// The two prefs above decide whether Zen CAN be transparent. These decide how
// transparent it ends up, and they are the mod's own settings rather than
// anything this repo invents -- `mod.sameerasw.*` is declared in the transparent
// zen mod's preferences.json and read by its own stylesheet:
//
//     .zen-browser-generic-background {
//       @media -moz-pref("mod.sameerasw.zen_bg_color_enabled") {
//         --zen-main-browser-background: var(
//           --mod-sameerasw-zen_transparency_color, #00000000) !important;
//       }
//     }
//
// With the checkbox off it falls through to #00000000 -- fully transparent --
// which is why a page reads as the wallpaper rather than as a browser. Measured
// 2026-09-07: Zen's page background came out at luma 89 over a local backdrop of
// 124, an effective opacity of about 0.32, while a terminal at the adaptive
// level was at 22 and 0.90. Warm brown against near-black, and the reason the
// two windows stopped looking like the same desktop.
//
// This is NOT the `browser` glass level coming back (see docs/theming.md and
// decision 013). That was a third number in glass.conf and a generated
// chrome/userChrome.css that had to win a specificity fight with somebody else's
// stylesheet. This is one pref the mod itself documents, set to the palette's own
// background. Nothing here generates CSS and nothing overrides the mod.
//
// 0.90 rather than 0.75, because the terminal level is adaptive and Zen's cannot
// be: measured across the 41 ultrawide wallpapers, the terminal lands between
// 0.66 and 0.91, and 0.90 is the fixed number closest to it across that range --
// within 5 levels of 255 at the median wallpaper and 2 at the brightest. 0.85 is
// the runner-up and reads slightly lighter.
//
// THE TRAP, and it is the same one as above: user.js re-applies at every
// startup, so changing this in the mod's settings panel lasts until the next
// restart and then silently reverts. Change it HERE. To hand the setting back to
// the panel, delete the two lines -- and note that deleting them leaves whatever
// prefs.js last recorded rather than restoring a default.
user_pref("mod.sameerasw.zen_bg_color_enabled", true);
user_pref("mod.sameerasw.zen_transparency_color", "rgba(18, 18, 18, 0.90)");

// Not part of that, and staying off: the focus cue here is the border -- a
// gradient on the focused window against a hairline on everything else, drawn by
// conf/look.lua. Hyprland's own focus dim went with `window = 1.0`
// (inactive_opacity is 1.0 too), so Zen greying itself out would be the only dim
// on the desktop, applied by one app and by nothing else on screen.
user_pref("zen.view.grey-out-inactive-windows", false);
