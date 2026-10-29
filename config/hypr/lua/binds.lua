local mod = "SUPER"
local scripts = "~/.config/hypr/scripts"
local ok_spatial, spatial = pcall(require, "lua.spatial")
local ok_zoom, zoom = pcall(require, "lua.native-zoom")
if not ok_zoom then zoom = {ready=false} end
if not ok_spatial then
    spatial = { route = function(_, fallback)
        return function() if fallback then fallback() end end
    end }
end
local noop = function() end
local function exec(keys, command, options)
    hl.bind(keys, hl.dsp.exec_cmd(command), options)
end
local function bind(keys, dispatcher, options)
    return hl.bind(keys, dispatcher, options)
end

-- Focus and movement
-- Opgeschoond 2026-10-28 op Joris' aanvinklijst: alleen de pijltoetsen.
-- Weggehaalde functies staan in het toetsenbordmenu (Super+Alt+Space).
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    bind(mod .. " + " .. direction, spatial.route("focus " .. direction, function()
        hl.exec_cmd(scripts .. "/focus-direction-safe.sh " .. direction)
    end))
end
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    bind(mod .. " + SHIFT + " .. direction, spatial.route("move " .. direction, function()
        hl.dispatch(hl.dsp.window.move({ direction = direction }))
    end))
    -- Zicht verschuiven: ruimtelijk in alle richtingen; op een scrollstrook
    -- schuift links/rechts één kolom, zodat dezelfde toets overal "verder kijken" is.
    bind(mod .. " + CTRL + ALT + " .. direction, spatial.route("pan " .. direction, function()
        if direction == "left" or direction == "right" then
            hl.exec_cmd(scripts .. "/layout-tool.sh wheel " .. direction)
        end
    end))
end
local window_drag = bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
local window_resize = bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
local tile_resize = bind(mod .. " + mouse:273", spatial.resize_start or noop)
local camera_drag = bind(mod .. " + CTRL + mouse:272", spatial.drag_start or noop)
bind("mouse:272", spatial.drag_stop or noop, { release = true, ignore_mods = true, non_consuming = true })
bind("mouse:273", spatial.resize_stop or noop, { release = true, ignore_mods = true, non_consuming = true })
local function update_mouse_binds(window)
    local map = window and window.title == "Kingstra Werkvlak"
    local tiled = spatial.active and spatial.active()
    -- Het overzicht ontvangt Super+klik zelf: nooit het overzichtvenster slepen.
    window_drag:set_enabled(not map)
    window_resize:set_enabled(not map and not tiled)
    tile_resize:set_enabled(not map and tiled or false)
    camera_drag:set_enabled(not map)
end
hl.on("window.active", update_mouse_binds)
update_mouse_binds(hl.get_active_window())
-- Duimknop van de Logitech M720: logid (config/system/logid.cfg) laat hem
-- BTN_TASK sturen, zodat vensters zonder Super te slepen zijn. Dubbelklikken
-- opent het overzicht (zelfde als Super+Tab).
bind("mouse:279", hl.dsp.window.drag(), { mouse = true })
exec("mouse:279", scripts .. "/thumb-double-click.sh")

bind(mod .. " + Q", hl.dsp.window.close())
-- Echt afsluiten: het proces van het venster stoppen, ook als de app naar de
-- tray zou gaan. Apps op de lijst "echt sluiten" (Instellingen › Sessie)
-- stoppen al bij een gewone Super+Q.
exec(mod .. " + SHIFT + Q", scripts .. "/app-quit.sh active")
bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = 0 }))
bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = 1 }))
exec(mod .. " + T", scripts .. "/togglefloating-safe.sh")
exec(mod .. " + SHIFT + T", scripts .. "/theme-next-safe.sh")
bind(mod .. " + P", hl.dsp.window.pseudo())
bind(mod .. " + backslash", hl.dsp.layout("togglesplit"))
bind(mod .. " + SHIFT + Space", hl.dsp.window.center())
bind(mod .. " + G", hl.dsp.group.toggle())
bind(mod .. " + ALT + right", hl.dsp.group.next())
bind(mod .. " + ALT + left", hl.dsp.group.prev())

for workspace = 1, 10 do
    local key = workspace % 10
    exec(mod .. " + " .. key, scripts .. "/workspace-action.sh workspace " .. workspace)
    exec(mod .. " + SHIFT + " .. key, scripts .. "/workspace-action.sh movetoworkspace " .. workspace)
    exec(mod .. " + ALT + " .. key, scripts .. "/workspace-action.sh movetoworkspacesilent " .. workspace)
end
-- Super+wiel scrolt binnen de werkruimte (ruimtelijk: omhoog/omlaag,
-- scrollstrook: kolommen), Super+Alt+wiel opzij, Super+Shift+wiel wisselt
-- van werkruimte. Super+Ctrl+linkermuis sleept het werkvlak vrij.
local wheel = spatial.wheel or function() return noop end
bind(mod .. " + mouse_down", wheel("down"))
bind(mod .. " + mouse_up", wheel("up"))
bind(mod .. " + mouse_left", wheel("left"))
bind(mod .. " + mouse_right", wheel("right"))
bind(mod .. " + ALT + mouse_down", wheel("right"))
bind(mod .. " + ALT + mouse_up", wheel("left"))
if zoom.ready then
    bind(mod .. " + CTRL + mouse_down", function() zoom.zoom("out") end)
    bind(mod .. " + CTRL + mouse_up", function() zoom.zoom("in") end)
    bind(mod .. " + CTRL + mouse:274", zoom.reset)
end
exec(mod .. " + SHIFT + mouse_down", scripts .. "/workspace-scroll.sh next")
exec(mod .. " + SHIFT + mouse_up", scripts .. "/workspace-scroll.sh prev")
bind(mod .. " + Tab", function()
    if zoom.ready then zoom.reset() end
    hl.exec_cmd(scripts .. "/overview-toggle.sh")
end)
bind("ALT + Tab", hl.dsp.focus({ workspace = "previous" }))

exec(mod .. " + CTRL + L", "bash " .. scripts .. "/lock.sh")
exec(mod .. " + CTRL + R", "hyprctl reload")
bind(mod .. " + CTRL + backspace", hl.dsp.exit())

-- Applications and shell panels
exec(mod .. " + Return", "kitty")
exec(mod .. " + CTRL + Return", scripts .. "/qs_manager.sh toggle launcher")
exec(mod .. " + B", "xdg-open https://")
exec(mod .. " + E", "nautilus")
exec(mod .. " + V", scripts .. "/qs_manager.sh toggle clipboard")
exec(mod .. " + SHIFT + Return", "kitty --title=btop btop")
exec(mod .. " + SHIFT + C", "kitty --title=cava cava")
exec(mod .. " + SHIFT + W", scripts .. "/wallpaper-random-safe.sh")
exec(mod .. " + CTRL + W", scripts .. "/wallpaper-picker-safe.sh")
exec(mod .. " + W", scripts .. "/qs_manager.sh toggle windows")
exec(mod .. " + CTRL + B", "hyprctl reload && notify-send 'Hyprland' 'Config herladen'")

exec(mod .. " + N", "~/.config/quickshell/notifications/notification_control.sh toggle")
exec(mod .. " + SHIFT + N", "~/.config/quickshell/notifications/notification_control.sh clear")
exec(mod .. " + SHIFT + M", scripts .. "/qs_manager.sh toggle music")
exec(mod .. " + CTRL + I", scripts .. "/qs_manager.sh toggle settings")
exec(mod .. " + ALT + Space", scripts .. "/qs_manager.sh toggle menu")
exec(mod .. " + CTRL + T", scripts .. "/qs_manager.sh toggle theme")
exec(mod .. " + CTRL + M", scripts .. "/qs_manager.sh toggle mode")
exec(mod .. " + F1", scripts .. "/qs_manager.sh toggle help")

-- Screenshots
-- Print is bewust als gewone sleutel gebonden: de helper verzorgt selectie,
-- opslag, klembord en optionele Satty-annotatie.
exec("Print", scripts .. "/screenshot.sh")
exec(mod .. " + Print", scripts .. "/screenshot.sh --clipboard")
exec("SHIFT + Print", scripts .. "/screenshot.sh --annotate")
exec(mod .. " + SHIFT + P", scripts .. "/screenshot.sh --full")

-- Media and brightness keys remain available while locked.
local repeat_locked = { locked = true, repeating = true }
-- osd.sh toont de waarde in het Kingstra-eiland; staat dat uit, dan swayosd.
exec("XF86AudioRaiseVolume", scripts .. "/osd.sh volume up", repeat_locked)
exec("XF86AudioLowerVolume", scripts .. "/osd.sh volume down", repeat_locked)
exec("XF86AudioMute", scripts .. "/osd.sh volume mute", { locked = true })
exec("XF86AudioMicMute", scripts .. "/osd.sh mic mute", { locked = true })
exec("XF86MonBrightnessUp", scripts .. "/osd.sh brightness up", repeat_locked)
exec("XF86MonBrightnessDown", scripts .. "/osd.sh brightness down", repeat_locked)
exec("XF86AudioPlay", "playerctl play-pause", { locked = true })
exec("XF86AudioPause", "playerctl play-pause", { locked = true })
exec("XF86AudioNext", "playerctl next", { locked = true })
exec("XF86AudioPrev", "playerctl previous", { locked = true })
exec("XF86AudioStop", "playerctl stop", { locked = true })
exec(mod .. " + ALT + P", "playerctl play-pause")
exec(mod .. " + ALT + period", "playerctl next")
exec(mod .. " + ALT + comma", "playerctl previous")

bind(mod .. " + S", hl.dsp.workspace.toggle_special("spotify"))
bind(mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:spotify" }))
bind(mod .. " + D", hl.dsp.workspace.toggle_special("discord"))
bind(mod .. " + SHIFT + D", hl.dsp.window.move({ workspace = "special:discord" }))

-- Indelingen en kladblok. Super+Z kiest een snap-indeling voor deze
-- werkruimte; Super+Alt+S zet scrollende kolommen aan of uit. Super+`
-- toont het kladblok, Super+Shift+` stuurt het actieve venster erheen
-- (of haalt het terug).
exec(mod .. " + Z", scripts .. "/qs_manager.sh toggle snap")
exec(mod .. " + ALT + Z", scripts .. "/zen.sh toggle")
exec(mod .. " + ALT + S", scripts .. "/layout-tool.sh scroll")
exec(mod .. " + grave", scripts .. "/scratchpad.sh toggle")
exec(mod .. " + SHIFT + grave", scripts .. "/scratchpad.sh send")
-- Parkeren (minimaliseren): Super+- zet het actieve venster weg, Super+Shift+-
-- haalt het laatst geparkeerde terug; Super+W toont ze allemaal.
exec(mod .. " + minus", "python3 " .. scripts .. "/park-window.py park")
exec(mod .. " + SHIFT + minus", "python3 " .. scripts .. "/park-window.py last")
-- In een scrollende werkruimte maken Super+Ctrl+, en . de kolom smaller
-- of breder. Op andere layouts doen deze toetsen niets.
exec(mod .. " + CTRL + period", scripts .. "/layout-tool.sh resize grow")
exec(mod .. " + CTRL + comma", scripts .. "/layout-tool.sh resize shrink")

hl.define_submap("passthrough", function()
    bind(mod .. " + Escape", hl.dsp.submap("reset"))
end)
bind(mod .. " + Escape", hl.dsp.submap("passthrough"))
