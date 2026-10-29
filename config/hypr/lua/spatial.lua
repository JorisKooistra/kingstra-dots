-- Register before workspace rules; never change a workspace on load.
local M = {}
local function active()
    local ok, window = pcall(hl.get_active_window)
    return ok and window and window.layout and window.layout.name == "lua:hyprscroll2d"
end
M.active = active
function M.route(message, fallback)
    return function()
        if active() then hl.dispatch(hl.dsp.layout(message))
        elseif fallback then fallback() end
    end
end
local ok = pcall(function()
    assert(hl.layout and hl.layout.register, "custom layouts are unavailable")
    local base = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/lua/spatial/"
    assert(loadfile(base .. "init.lua"))()
end)
M.available = ok

-- Ordinary app scroll and unmodified gestures remain available.
-- Versions without live Lua gestures retain keyboard and overview-drag control.
if ok and hl.gesture then
    local swiping = false
    pcall(hl.gesture, {
        fingers = 3, direction = "swipe", mods = "SUPER",
        action = {
            start = function(e)
                swiping = active()
                if swiping and e.delta then
                    hl.dispatch(hl.dsp.layout(string.format("panby %.4f %.4f", -e.delta.x, -e.delta.y)))
                end
            end,
            update = function(e)
                if swiping and active() and e.delta then
                    hl.dispatch(hl.dsp.layout(string.format("panby %.4f %.4f", -e.delta.x, -e.delta.y)))
                end
            end,
            finish = function() swiping = false end,
        },
    })
end
-- Vrij slepen met Super+Alt+linkermuis. Hyprland kent geen muisbeweging als
-- Lua-gebeurtenis, dus een korte timer leest de cursor en schuift de camera
-- mee (ruimtelijk) of stapt per kolom (scrollstrook). Bij loslaten klikt het
-- ruimtelijk werkvlak alleen op een plek vast als je er dichtbij bent.
local function layout_of_active()
    if hl.get_active_workspace then
        local ok, workspace = pcall(hl.get_active_workspace)
        if ok and workspace and workspace.tiled_layout then return workspace.tiled_layout end
    end
    local ok, window = pcall(hl.get_active_window)
    local layout = ok and window and window.layout
    return layout and layout.name or ""
end

local drag = { on = false, kind = nil, last = nil, carry = 0, started = 0, timer = nil }

local function cursor()
    local ok, pos = pcall(hl.get_cursor_pos)
    if ok and pos and pos.x and pos.y then return pos end
end

local function drag_stop()
    if not drag.on then return end
    drag.on = false
    if drag.timer then pcall(function() drag.timer:set_enabled(false) end) end
    if drag.kind == "spatial" then hl.dispatch(hl.dsp.layout("dragend")) end
    drag.kind = nil
end

local function drag_tick()
    if not drag.on then return end
    -- Vangnet als het loslaten gemist wordt.
    if os.time() - drag.started > 60 then return drag_stop() end
    local pos = cursor()
    if not pos or not drag.last then return end
    local dx, dy = pos.x - drag.last.x, pos.y - drag.last.y
    drag.last = pos
    if dx == 0 and dy == 0 then return end
    if drag.kind == "spatial" then
        local zooms = rawget(_G, "__kingstra_native_zoom_workspaces")
        local workspace = zooms and hl.get_active_workspace()
        local scale = workspace and zooms[tostring(workspace.id)] or 1
        hl.dispatch(hl.dsp.layout(string.format("panby %.4f %.4f", -dx / scale, -dy / scale)))
    elseif drag.kind == "scrolling" then
        drag.carry = drag.carry + dx
        local ok, monitor = pcall(hl.get_active_monitor)
        local step = (ok and monitor and monitor.width or 1920) / 4
        if math.abs(drag.carry) >= step then
            hl.dispatch(hl.dsp.layout(drag.carry > 0 and "move -col" or "move +col"))
            drag.carry = 0
        end
    end
end

local function drag_start()
    if drag.on or not hl.timer then return end
    local layout = layout_of_active()
    local kind = layout == "lua:hyprscroll2d" and "spatial" or layout == "scrolling" and "scrolling" or nil
    local pos = cursor()
    if not kind or not pos then return end
    drag.on, drag.kind, drag.last, drag.carry, drag.started = true, kind, pos, 0, os.time()
    if kind == "spatial" then hl.dispatch(hl.dsp.layout("dragstart")) end
    if not drag.timer then
        local ok, timer = pcall(hl.timer, drag_tick, { timeout = 16, type = "repeat" })
        if not ok then drag.on = false; return end
        drag.timer = timer
    else
        pcall(function() drag.timer:set_enabled(true) end)
    end
end

-- Super+wiel binnen de werkruimte: ruimtelijk één pagina, op een
-- scrollstrook één kolom. Tegels hebben niets om te scrollen.
function M.wheel(direction)
    return function()
        local layout = layout_of_active()
        if layout == "lua:hyprscroll2d" then
            hl.dispatch(hl.dsp.layout("pan " .. direction))
        elseif layout == "scrolling" then
            hl.dispatch(hl.dsp.layout((direction == "up" or direction == "left") and "move -col" or "move +col"))
        end
    end
end

M.drag_start = drag_start
M.drag_stop = drag_stop

-- De Lua-layout-API van Hyprland 0.56 geeft geen resize-delta door.
-- Lees daarom tijdens Super+rechtermuis dezelfde cursor als bij camera-slepen.
local resize = { on = false, last = nil, timer = nil, started = 0 }
function M.resize_stop()
    if not resize.on then return end
    resize.on = false
    if resize.timer then resize.timer:set_enabled(false) end
    hl.dispatch(hl.dsp.layout("resizeend"))
end
local function resize_tick()
    if not resize.on then return end
    if os.time() - resize.started > 60 or not active() then return M.resize_stop() end
    local pos = cursor()
    if not pos then return end
    local dx, dy = pos.x - resize.last.x, pos.y - resize.last.y
    resize.last = pos
    if dx ~= 0 or dy ~= 0 then
        hl.dispatch(hl.dsp.layout(string.format("resizeby %.4f %.4f", dx, dy)))
    end
end
function M.resize_start()
    local pos = cursor()
    if resize.on or not active() or not pos or not hl.timer then return end
    resize.on, resize.last, resize.started = true, pos, os.time()
    hl.dispatch(hl.dsp.layout("resizestart"))
    if resize.timer then resize.timer:set_enabled(true)
    else
        local ok, timer = pcall(hl.timer, resize_tick, {timeout=16,type="repeat"})
        if not ok then return M.resize_stop() end
        resize.timer = timer
    end
end
return M
