-- Kingstra Hyprland configuration (Lua API, Hyprland 0.55+).
-- Legacy .conf files remain on disk only as an emergency rollback; this is
-- the sole entrypoint loaded by Hyprland.

require("lua.config")
require("lua.monitors")
require("lua.rules")
require("lua.binds")
require("lua.autostart")

-- Personal additions last, so they can override anything above. lua/user.lua
-- is not tracked by git and survives every update; see lua/user.lua.default.
-- A mistake in it never takes the rest of the config down.
local ok_user, user = pcall(require, "lua.user")
if ok_user and type(user) == "table" and type(user.apply) == "function" then
    pcall(user.apply)
end
