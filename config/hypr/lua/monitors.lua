-- Local monitor and workspace assignments are written to lua/monitors-local.lua
-- and lua/workspaces.lua by the display settings helpers. A universal fallback
-- keeps new machines usable before any local state has been saved.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

local function apply_optional(module)
    local ok, value = pcall(require, module)
    if ok and type(value) == "table" and type(value.apply) == "function" then
        value.apply()
    end
end

apply_optional("lua.monitors-local")
apply_optional("lua.workspaces")
