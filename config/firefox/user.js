// >>> kingstra performance profile >>>
// Conservative Firefox defaults focused on smoother day-to-day performance.
user_pref("browser.cache.disk.enable", true);
user_pref("browser.cache.disk.smart_size.enabled", true);
user_pref("browser.cache.memory.enable", true);
user_pref("browser.sessionstore.interval", 60000);
user_pref("browser.sessionstore.max_tabs_undo", 10);
user_pref("browser.tabs.unloadOnLowMemory", true);
user_pref("gfx.webrender.compositor", true);
user_pref("layers.gpu-process.enabled", true);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// De nieuwe-tabbladpagina krijgt het thema (userContent.css); zonder
// advertenties en nieuwsfeed blijft alleen de zoekbalk en je snelkoppelingen.
user_pref("browser.newtabpage.activity-stream.showSponsored", false);
user_pref("browser.newtabpage.activity-stream.showSponsoredTopSites", false);
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.topsites", true);
// Pdf's: Firefox opent ze niet meer zelf (ook niet vanzelf na downloaden).
// Een gedownloade pdf blijft in Downloads; klik je erop, dan opent Papers
// (de standaard-app). kingstra-firefox-optimize zet handlers.json op opslaan.
user_pref("pdfjs.disabled", true);
user_pref("browser.download.open_pdf_attachments_inline", false);
// <<< kingstra performance profile <<<
