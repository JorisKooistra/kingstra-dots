-- Local monitor and workspace assignments are written to lua/monitors-local.lua
-- and lua/workspaces.lua by the display settings helpers. A universal fallback
-- keeps new machines usable before any local state has been saved.
-- Houd dezelfde compacte 100%-standaard als vóór de Lua-migratie. Automatische
-- HiDPI-detectie koos op sommige 1080p-laptops 150%, waardoor de effectieve
-- werkruimte tot ongeveer 1280x720 kromp. Lokale monitorregels hieronder
-- kunnen per scherm nog steeds bewust een andere schaal instellen.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1.0 })

local function apply_optional(module)
    local ok, value = pcall(require, module)
    if ok and type(value) == "table" and type(value.apply) == "function" then
        value.apply()
    end
end

apply_optional("lua.monitors-local")
apply_optional("lua.workspaces")
