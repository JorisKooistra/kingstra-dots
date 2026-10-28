local mod = "SUPER"
local scripts = "~/.config/hypr/scripts"
local function exec(keys, command, options)
    hl.bind(keys, hl.dsp.exec_cmd(command), options)
end
local function bind(keys, dispatcher, options)
    hl.bind(keys, dispatcher, options)
end

-- Focus and movement
bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))
bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))
bind(mod .. " + K", hl.dsp.focus({ direction = "up" }))
bind(mod .. " + J", hl.dsp.focus({ direction = "down" }))
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    exec(mod .. " + " .. direction, scripts .. "/focus-direction-safe.sh " .. direction)
end
bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))
bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    bind(mod .. " + SHIFT + " .. direction, hl.dsp.window.move({ direction = direction }))
end
bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
-- Duimknop van de Logitech M720: logid (config/system/logid.cfg) laat hem
-- BTN_TASK sturen, zodat vensters zonder Super te slepen zijn. Dubbelklikken
-- opent het overzicht (zelfde als Super+Tab).
bind("mouse:279", hl.dsp.window.drag(), { mouse = true })
exec("mouse:279", scripts .. "/thumb-double-click.sh")
bind(mod .. " + CTRL + right", hl.dsp.window.resize({ x = 60, y = 0 }), { repeating = true })
bind(mod .. " + CTRL + left", hl.dsp.window.resize({ x = -60, y = 0 }), { repeating = true })
bind(mod .. " + CTRL + up", hl.dsp.window.resize({ x = 0, y = -60 }), { repeating = true })
bind(mod .. " + CTRL + down", hl.dsp.window.resize({ x = 0, y = 60 }), { repeating = true })

bind(mod .. " + Q", hl.dsp.window.close())
bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = 0 }))
bind(mod .. " + M", hl.dsp.window.fullscreen({ mode = 1 }))
exec(mod .. " + T", scripts .. "/togglefloating-safe.sh")
exec(mod .. " + SHIFT + T", scripts .. "/theme-next-safe.sh")
bind(mod .. " + ALT + T", hl.dsp.window.pin())
bind(mod .. " + P", hl.dsp.window.pseudo())
bind(mod .. " + backslash", hl.dsp.layout("togglesplit"))
bind(mod .. " + SHIFT + Space", hl.dsp.window.center())
bind(mod .. " + G", hl.dsp.group.toggle())
bind(mod .. " + ALT + right", hl.dsp.group.next())
bind(mod .. " + ALT + left", hl.dsp.group.prev())
bind(mod .. " + CTRL + SHIFT + G", hl.dsp.group.lock_active({ action = "toggle" }))
bind(mod .. " + SHIFT + G", hl.dsp.group.move_window({ action = "out" }))

for workspace = 1, 10 do
    local key = workspace % 10
    exec(mod .. " + " .. key, scripts .. "/workspace-action.sh workspace " .. workspace)
    exec(mod .. " + SHIFT + " .. key, scripts .. "/workspace-action.sh movetoworkspace " .. workspace)
    exec(mod .. " + ALT + " .. key, scripts .. "/workspace-action.sh movetoworkspacesilent " .. workspace)
end
exec(mod .. " + mouse_down", scripts .. "/workspace-scroll.sh next")
exec(mod .. " + mouse_up", scripts .. "/workspace-scroll.sh prev")
exec(mod .. " + Tab", scripts .. "/overview-toggle.sh")
bind("ALT + Tab", hl.dsp.focus({ workspace = "previous" }))

exec(mod .. " + CTRL + L", "bash " .. scripts .. "/lock.sh")
exec(mod .. " + CTRL + R", "hyprctl reload")
bind(mod .. " + CTRL + backspace", hl.dsp.exit())

-- Applications and shell panels
exec(mod .. " + Return", "kitty")
exec(mod .. " + CTRL + Return", scripts .. "/qs_manager.sh toggle launcher")
exec(mod .. " + B", "xdg-open https://")
exec(mod .. " + E", "nautilus")
exec(mod .. " + SHIFT + E", "kitty --title=yazi yazi")
exec(mod .. " + V", scripts .. "/qs_manager.sh toggle clipboard")
exec(mod .. " + SHIFT + Return", "kitty --title=btop btop")
exec(mod .. " + SHIFT + C", "kitty --title=cava cava")
exec(mod .. " + ALT + I", "kitty --title=Network nmtui")
exec(mod .. " + ALT + B", "blueman-manager")
exec(mod .. " + SHIFT + W", scripts .. "/wallpaper-random-safe.sh")
exec(mod .. " + CTRL + W", scripts .. "/wallpaper-picker-safe.sh")
exec(mod .. " + W", scripts .. "/qs_manager.sh toggle windows")
exec(mod .. " + CTRL + B", "hyprctl reload && notify-send 'Hyprland' 'Config herladen'")

exec(mod .. " + N", "~/.config/quickshell/notifications/notification_control.sh toggle")
exec(mod .. " + SHIFT + N", "~/.config/quickshell/notifications/notification_control.sh clear")
exec(mod .. " + ALT + N", "~/.config/quickshell/notifications/notification_control.sh dnd")
exec(mod .. " + SHIFT + M", scripts .. "/qs_manager.sh toggle music")
exec(mod .. " + CTRL + C", scripts .. "/qs_manager.sh toggle calendar")
exec(mod .. " + A", scripts .. "/qs_manager.sh toggle tophover")
exec(mod .. " + O", scripts .. "/qs_manager.sh toggle monitors")
exec(mod .. " + X", scripts .. "/qs_manager.sh toggle focustime")
exec(mod .. " + CTRL + I", scripts .. "/qs_manager.sh toggle settings")
exec(mod .. " + comma", scripts .. "/qs_manager.sh toggle settings")
exec(mod .. " + ALT + Space", scripts .. "/qs_manager.sh toggle menu")
exec(mod .. " + CTRL + T", scripts .. "/qs_manager.sh toggle theme")
exec(mod .. " + CTRL + M", scripts .. "/qs_manager.sh toggle mode")
exec(mod .. " + CTRL + G", "quickshell-game")
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
exec(mod .. " + ALT + S", scripts .. "/layout-tool.sh scroll")
exec(mod .. " + grave", scripts .. "/scratchpad.sh toggle")
exec(mod .. " + SHIFT + grave", scripts .. "/scratchpad.sh send")
-- In een scrollende werkruimte: Super+Shift+wiel schuift de strook een
-- kolom op, Super+Ctrl+, en . maken de kolom smaller of breder. Op andere
-- layouts doen deze toetsen niets.
bind(mod .. " + SHIFT + mouse_down", hl.dsp.layout("move +col"))
bind(mod .. " + SHIFT + mouse_up", hl.dsp.layout("move -col"))
bind(mod .. " + CTRL + period", hl.dsp.layout("colresize +conf"))
bind(mod .. " + CTRL + comma", hl.dsp.layout("colresize -conf"))

hl.define_submap("passthrough", function()
    bind(mod .. " + Escape", hl.dsp.submap("reset"))
end)
bind(mod .. " + Escape", hl.dsp.submap("passthrough"))
