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

-- Schaal van de echte desktopzoom, zodat een vingerbeweging even ver
-- schuift als wat je op het scherm ziet. Zonder zoom blijft dat 1.
local function zoom_scale()
    local native = hl.plugin and hl.plugin.spatialoverview
    if native and type(native._zoom) == "function" then
        local read_ok, value = pcall(native._zoom)
        if read_ok and type(value) == "number" and value > 0 and value == value then return value end
    end
    local zooms = rawget(_G, "__kingstra_native_zoom_workspaces")
    if zooms and hl.get_active_workspace then
        local read_ok, workspace = pcall(hl.get_active_workspace)
        local scale = read_ok and workspace and zooms[tostring(workspace.id)]
        if type(scale) == "number" and scale > 0 and scale == scale then return scale end
    end
    return 1
end

-- Inhoud volgt de hand: een beweging naar rechts schuift het beeld mee.
local function pan_pixels(dx, dy)
    if type(dx) ~= "number" or type(dy) ~= "number" or dx ~= dx or dy ~= dy then return end
    local scale = zoom_scale()
    hl.dispatch(hl.dsp.layout(string.format("panby %.4f %.4f", -dx / scale, -dy / scale)))
end

-- Knijpen zoomt in stappen van ongeveer 12%. De schaal van het gebaar is
-- absoluut vanaf het begin (1 = start), niet een stap per update.
local pinch_base = 1
local function follow_pinch(scale)
    if type(scale) ~= "number" or scale ~= scale or scale <= 0.2 or scale >= 5 then return end
    local zoom = package.loaded["lua.native-zoom"]
    if not zoom or type(zoom.nudge) ~= "function" then return end
    local target = math.max(0.25, math.min(1, pinch_base * scale))
    for _ = 1, 6 do
        local current = zoom_scale()
        local before = current
        if current < target / 1.06 then zoom.nudge("in")
        elseif current > target * 1.06 then zoom.nudge("out")
        else break end
        if math.abs(zoom_scale() - before) < 0.001 then break end
    end
end

-- Gewone tweevingerscroll blijft bij de app. Drie vingers blijven werkruimte,
-- overzicht en controlecentrum. Het ruimtelijk werkvlak gebruikt daarom
-- vier vingers om te schuiven en knijpen om te zoomen, plus Super+drie vingers
-- als de vierde vinger niet past. Zonder live Lua-gebaren blijven toetsen,
-- wiel en de kaart werken.
if hl.gesture then
    local swiping = false
    pcall(hl.gesture, {
        fingers = 3, direction = "swipe", mods = "SUPER",
        action = {
            start = function(e)
                swiping = active()
                if not swiping then return end
                hl.dispatch(hl.dsp.layout("dragstart"))
                if e.delta then pan_pixels(e.delta.x, e.delta.y) end
            end,
            update = function(e)
                if swiping and active() and e.delta then pan_pixels(e.delta.x, e.delta.y) end
            end,
            finish = function()
                if swiping then hl.dispatch(hl.dsp.layout("dragend")) end
                swiping = false
            end,
        },
    })
    local pinching = false
    pcall(hl.gesture, {
        fingers = 2, direction = "pinch",
        action = {
            start = function(e)
                pinching = active()
                if not pinching then return end
                pinch_base = zoom_scale()
                hl.dispatch(hl.dsp.layout("dragstart"))
                if e.delta then pan_pixels(e.delta.x, e.delta.y) end
                follow_pinch(e.scale)
            end,
            update = function(e)
                if not pinching or not active() then return end
                if e.delta then pan_pixels(e.delta.x, e.delta.y) end
                follow_pinch(e.scale)
            end,
            finish = function()
                if pinching then hl.dispatch(hl.dsp.layout("dragend")) end
                pinching = false
            end,
        },
    })
    -- Vier vingers schuiven het ruimtelijk werkvlak. Buiten die indeling blijft
    -- een verticale veeg de magische werkruimte togglen, zoals voorheen.
    local hand = { on = false, x = 0, y = 0 }
    pcall(hl.gesture, {
        fingers = 4, direction = "swipe",
        action = {
            start = function(e)
                hand.on, hand.x, hand.y = active(), 0, 0
                if e.delta then hand.x, hand.y = e.delta.x or 0, e.delta.y or 0 end
                if not hand.on then return end
                hl.dispatch(hl.dsp.layout("dragstart"))
                if e.delta then pan_pixels(e.delta.x, e.delta.y) end
            end,
            update = function(e)
                if not e.delta then return end
                hand.x, hand.y = hand.x + (e.delta.x or 0), hand.y + (e.delta.y or 0)
                if hand.on and active() then pan_pixels(e.delta.x, e.delta.y) end
            end,
            finish = function(e)
                local panned = hand.on
                hand.on = false
                if panned then
                    hl.dispatch(hl.dsp.layout("dragend"))
                    return
                end
                if e and e.cancelled then return end
                if math.abs(hand.y) >= math.abs(hand.x) and math.abs(hand.y) >= 24 then
                    hl.dispatch(hl.dsp.workspace.toggle_special("magic"))
                end
            end,
        },
    })
end
-- Vrij slepen met Super+Ctrl+linkermuis. Hyprland kent geen muisbeweging als
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
    -- Hyprland 0.57 arms release binds differently. The native observer sees
    -- every button event, even when a consuming press bind owns the gesture.
    local native = hl.plugin and hl.plugin.spatialoverview
    if native and type(native._button_down)=="function" and not native._button_down(272) then
        return drag_stop()
    end
    -- Vangnet als het loslaten gemist wordt.
    if os.time() - drag.started > 60 then return drag_stop() end
    local pos = cursor()
    if not pos or not drag.last then return end
    local dx, dy = pos.x - drag.last.x, pos.y - drag.last.y
    drag.last = pos
    if dx == 0 and dy == 0 then return end
    if drag.kind == "spatial" then
        pan_pixels(dx, dy)
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
    local native = hl.plugin and hl.plugin.spatialoverview
    if native and type(native._button_down)=="function" and not native._button_down(273) then
        return M.resize_stop()
    end
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
