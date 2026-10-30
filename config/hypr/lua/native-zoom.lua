-- Native rendering/input zoom. The existing Lua layout keeps ownership of tiles.
local M = { ready = false }
local home = os.getenv("HOME") or ""
local base = os.getenv("XDG_CONFIG_HOME") or (home .. "/.config")
local override = os.getenv("KINGSTRA_NATIVE_ZOOM_PLUGIN")
local path = override or (base .. "/hypr/native-zoom/kingstra-native-zoom.so")
-- A package upgrade can replace Hyprland while this repo remains unchanged.
-- Only load the locally built ABI; the installer rebuilds it on updates.
if not override then
    local running = (os.getenv("HYPRLAND_INSTANCE_SIGNATURE") or ""):match("^([a-fA-F0-9]+)_")
    -- Keep the running session's build when package headers already belong to
    -- the next Hyprland version. A reboot selects that version's own entry.
    local stamp = running and io.open(path .. "." .. running .. ".abi", "r")
    stamp = stamp or io.open(path .. ".abi", "r")
    local abi = stamp and stamp:read("l")
    local binary = stamp and stamp:read("l")
    if stamp then stamp:close() end
    if not abi or (running and running ~= abi) then return M end
    if binary and binary ~= "" then path = binary end
end
local file = io.open(path,"rb")
if not file then return M end
file:close()

local function loaded()
    for _, plugin in ipairs(hl.get_loaded_plugins()) do
        if plugin.name == "spatialoverview" then return true end
    end
    return false
end
-- This declares the plugin for *every* config pass, including reloads.
-- Omitting it when already loaded causes Hyprland to unload/reload it forever.
hl.plugin.load(path)
local ok, err = pcall(function()
    assert(loaded(), "native zoom plugin did not load")
    if type(hl.plugin.spatialoverview._backend)=="function" and hl.plugin.spatialoverview._backend()=="kingstra-0.57" then
        hl.config({plugin={spatialoverview={canvas={hover_focus=true}}}})
        return
    end
    hl.config({plugin={spatialoverview={
        layout="grid", scale=1.0,
        animation={enabled=true,speed=8.0},
        distortion={enabled=false},
        chrome_animation={enabled=false},
        workspace_outline={enabled=false},
        navigator={enabled=false,pointer=false},
        canvas={
            enabled=true,desktop_mode=true,persistent=true,linked_screens=false,
            initial_zoom=1.0,min_zoom=0.25,max_zoom=1.0,zoom_step=0.12,
            auto_float=false,auto_place=false,remember_layout=false,
            direct_input=true,hover_focus=true,space_pan=false,
            grid_enabled=false,minimap_enabled=false,viewport_enabled=false,
            background_dim=0.0,float_on_drag=false,snap_enabled=false,
            snap_viewport_on_pan=false,commit_viewport_on_close=false,
        },
    }}})
end)
if not ok then M.error=tostring(err); return M end
M.ready = true
_G.__kingstra_native_zoom_workspaces = {}
local zooms = _G.__kingstra_native_zoom_workspaces
local monitors = {}
-- Plugin factories execute immediately inside a Lua keybind and return nil.
-- Passing that result to hl.dispatch causes "expected a dispatcher".
local function dispatch(action, argument)
    hl.plugin.spatialoverview._dispatch(action, argument)
end
local function publish()
    local runtime = os.getenv("XDG_RUNTIME_DIR")
    if not runtime then return end
    local native = hl.plugin and hl.plugin.spatialoverview
    local body
    -- Aanraken schrijft de zoom in de plugin. Die blijft de bron voor de knop,
    -- ook als Lua het gebaar niet zelf heeft bijgehouden.
    if native and type(native._state_json) == "function" then
        local read_ok, raw = pcall(native._state_json)
        if read_ok and type(raw) == "string" then body = raw end
    end
    if not body then
        local rows = {}
        for name, id in pairs(monitors) do
            if zooms[id] and name:match("^[%w_:%.%-]+$") then
                rows[#rows+1] = string.format('"%s":%.6f', name, zooms[id])
            end
        end
        body = "{" .. table.concat(rows, ",") .. "}"
    end
    if body:sub(-1) ~= "\n" then body = body .. "\n" end
    local path = runtime .. "/kingstra-native-zoom.json"
    local file = io.open(path .. ".tmp", "w")
    if not file then return end
    file:write(body); file:close()
    os.rename(path .. ".tmp", path)
end

local function plugin_factor()
    local native = hl.plugin and hl.plugin.spatialoverview
    if not native or type(native._zoom) ~= "function" then return nil end
    local read_ok, value = pcall(native._zoom)
    if read_ok and type(value) == "number" and value > 0 and value == value then return value end
end

-- steps = 2 voor een wielstap (ongeveer 25%), 1 voor een knijpstap (ongeveer 12%).
-- Openen zet de plugin terug op 100%, dus een al uitgezoomd scherm niet opnieuw openen.
local function change_zoom(direction, steps)
    if not M.ready or hl.get_active_special_workspace() then return end
    local monitor = hl.get_monitor_at_cursor() or hl.get_active_monitor()
    local workspace = monitor and monitor.active_workspace or hl.get_active_workspace()
    if not monitor or not workspace or workspace.tiled_layout ~= "lua:hyprscroll2d" then return end
    if (monitor.width and monitor.width<=0) or (monitor.height and monitor.height<=0) then return end
    local id = tostring(workspace.id)
    local current = plugin_factor() or zooms[id] or 1.0
    if direction == "in" and current >= 0.999 then return M.reset() end
    if direction == "out" and current <= 0.251 then return end
    local factor = 1.12 ^ steps
    local next_zoom = math.max(0.25, math.min(1.0, current * (direction == "in" and factor or 1 / factor)))
    if next_zoom >= 0.999 then return M.reset() end
    if current >= 0.999 then dispatch("overview", "open " .. monitor.name) end
    monitors[monitor.name] = id
    zooms[id] = next_zoom
    for _ = 1, steps do dispatch("canvas", "zoom " .. direction) end
    publish()
end

function M.reset(name)
    if not M.ready then return end
    local monitor = type(name)=="string" and hl.get_monitor(name) or hl.get_monitor_at_cursor() or hl.get_active_monitor()
    if not monitor then return end
    local previous = monitors[monitor.name]
    if previous then zooms[previous] = nil end
    monitors[monitor.name] = nil
    dispatch("overview", "close " .. monitor.name)
    publish()
end

function M.zoom(direction) change_zoom(direction, 2) end
function M.nudge(direction) change_zoom(direction, 1) end

-- A reload or workspace switch returns to the ordinary desktop.
local function reset_all()
    dispatch("overview", "close all")
    for id in pairs(zooms) do zooms[id]=nil end
    for name in pairs(monitors) do monitors[name]=nil end
    publish()
end
hl.on("config.reloaded", reset_all)
hl.on("workspace.active", function()
    -- Merely focusing another monitor must preserve its neighbour's zoom.
    for name, id in pairs(monitors) do
        local monitor = hl.get_monitor(name)
        local workspace = monitor and monitor.active_workspace
        if not workspace or tostring(workspace.id) ~= id then
            dispatch("overview", "close " .. name)
            zooms[id], monitors[name] = nil, nil
        end
    end
    publish()
end)
return M
