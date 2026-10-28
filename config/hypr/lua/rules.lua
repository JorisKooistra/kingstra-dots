local function rule(name, match, properties)
    properties.name = name
    properties.match = match
    hl.window_rule(properties)
end

rule("pavucontrol", { class = "^pavucontrol$" }, { float = true, size = "800 600", center = true })
rule("blueman", { class = "^blueman-manager$" }, { float = true, size = "900 700", center = true })
rule("network-editor", { class = "^nm-connection-editor$" }, { float = true })
rule("polkit", { class = "^polkit-gnome-authentication-agent-1$" }, { float = true })
rule("portal-gtk", { class = "^xdg-desktop-portal-gtk$" }, { float = true })
rule("nautilus-properties", { class = "^org\\.gnome\\.Nautilus$", title = "(Bestandseigenschappen|File Properties)" }, { float = true })
rule("file-dialogs", { title = "^(Open File|Open Folder|Save File|Save As|Confirm)$" }, { float = true })
rule("picture-in-picture", { title = "^Picture-in-Picture$" }, { float = true, pin = true, move = "monitor_w*0.69 monitor_h*0.04", size = "monitor_w*0.25 monitor_h*0.25", keep_aspect_ratio = true })
rule("media-viewer", { title = "^Media viewer$" }, { float = true })
rule("kitty-opacity", { class = "^kitty$" }, { opacity = "0.95 0.88" })
rule("hyprland-opacity", { class = "^Hyprland$" }, { opacity = "1.0 1.0" })
rule("fullscreen-opacity", { fullscreen = true }, { opacity = "1.0" })
rule("ghostty-no-blur", { class = "^com\\.mitchellh\\.ghostty$" }, { no_blur = true })
rule("youtube-no-blur", { title = "YouTube" }, { no_blur = true })
rule("spotify", { class = "^(Spotify|spotify)$" }, { workspace = "special:spotify" })
rule("discord", { class = "^(discord|vesktop)$" }, { workspace = "special:discord" })
rule("quickshell", { class = "^org\\.quickshell$" }, { float = true, no_blur = true, no_shadow = true, border_size = 0, no_initial_focus = true })
-- Instellingen is een echt Quickshell-venster: zwevend, gecentreerd en wel
-- focus, schaduw en rand, anders dan de overige quickshell-oppervlakken.
-- Komt na de algemene quickshell-regel, zodat deze waarden winnen.
pcall(rule, "kingstra-settings", { class = "^org\\.quickshell$", title = "^Kingstra Instellingen$" }, { float = true, size = "1120 740", center = true, no_initial_focus = false, no_shadow = false, no_blur = false })
rule("qs-master", { title = "^qs-master$" }, { float = true, no_blur = true, no_shadow = true, border_size = 0, no_initial_focus = true, workspace = "special:qs-master" })

-- Super+T remembers per app class whether it floats (togglefloating-safe.sh
-- keeps the list). Registered after the static rules, so a remembered choice
-- wins on the next launch.
local function regex_escape(text)
    return (text:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?%{%}|\\]", "\\%0"))
end

local function rule_slug(class)
    return (class:gsub("[^%w]", "-"))
end

local state_home = os.getenv("XDG_STATE_HOME") or ((os.getenv("HOME") or "") .. "/.local/state")
local ok_file, float_file = pcall(io.open, state_home .. "/kingstra/floating-apps", "r")
if ok_file and float_file then
    for line in float_file:lines() do
        -- class<TAB>width height<TAB>x% y%; the geometry is optional.
        local class, size, move = line:match("^([^\t]*)\t?([^\t]*)\t?([^\t]*)")
        class = class and class:match("^%s*(.-)%s*$") or ""
        if class ~= "" and not class:match("^#") then
            local props = { float = true }
            -- Hyprland takes no percentages here: size and move are pixels or
            -- expressions, and move is relative to the monitor it opens on.
            if size and size:match("^%d+ %d+$") then
                props.size = size
                local x, y = (move or ""):match("^(%d+)%% (%d+)%%$")
                if x then
                    props.move = string.format("monitor_w*%.2f monitor_h*%.2f", tonumber(x) / 100, tonumber(y) / 100)
                end
            else
                -- No remembered size yet: a calm default instead of the size
                -- the app asks for itself.
                props.size = "monitor_w*0.6 monitor_h*0.65"
                props.center = true
            end
            pcall(rule, "remember-float-" .. rule_slug(class), { class = "^" .. regex_escape(class) .. "$" }, props)
        end
    end
    float_file:close()
end

-- Indeling per werkruimte (Super+Z, `kingstra indeling`). layout-tool.sh
-- schrijft "werkruimte layout" per regel; zo overleeft de keuze een herstart.
local ok_layouts, layouts_file = pcall(io.open, state_home .. "/kingstra/workspace-layouts", "r")
if ok_layouts and layouts_file then
    local known = { dwindle = true, master = true, scrolling = true, monocle = true, ["lua:hyprscroll2d"] = rawget(_G, "__hyprscroll2d_layout_registered") == true }
    for line in layouts_file:lines() do
        local ws, layout = line:match("^(%S+)%s+(%S+)$")
        if ws and known[layout] then
            pcall(hl.workspace_rule, { workspace = ws, layout = layout })
        end
    end
    layouts_file:close()
end

-- Subtle border cue for every floating window; colors follow Matugen.
local ok_colors, colors = pcall(require, "lua.colors")
local floating_border = (ok_colors and type(colors) == "table" and colors.floating_border)
    or "rgba(90d6a8ee) rgba(98cbff77)"
rule("floating-border", { float = true }, { border_color = floating_border })

local function layer(name, namespace, properties)
    properties.name = name
    properties.match = { namespace = "^" .. namespace .. "$" }
    hl.layer_rule(properties)
end

layer("walker", "walker", { blur = true })
layer("selection", "selection", { no_anim = true })
layer("skwd-paper", "skwd-paper", { no_anim = true })
layer("skwd-paper-transition", "skwd-paper-transition", { no_anim = true })
layer("wallpaper-selector", "wallpaper-selector-parallel", { no_anim = true })
layer("quickshell", "quickshell", { no_anim = true })
