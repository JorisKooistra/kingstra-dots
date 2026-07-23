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
// <<< kingstra performance profile <<<
