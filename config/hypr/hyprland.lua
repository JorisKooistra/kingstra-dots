-- Kingstra Hyprland configuration (Lua API, Hyprland 0.55+).
-- Legacy .conf files remain on disk only as an emergency rollback; this is
-- the sole entrypoint loaded by Hyprland.

require("lua.config")
require("lua.monitors")
require("lua.rules")
require("lua.binds")
require("lua.autostart")
