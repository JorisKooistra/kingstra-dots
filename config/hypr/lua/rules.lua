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
rule("picture-in-picture", { title = "^Picture-in-Picture$" }, { float = true, pin = true, move = "69% 4%", size = "25% 25%", keep_aspect_ratio = true })
rule("media-viewer", { title = "^Media viewer$" }, { float = true })
rule("kitty-opacity", { class = "^kitty$" }, { opacity = "0.95 0.88" })
rule("hyprland-opacity", { class = "^Hyprland$" }, { opacity = "1.0 1.0" })
rule("fullscreen-opacity", { fullscreen = true }, { opacity = "1.0" })
rule("ghostty-no-blur", { class = "^com\\.mitchellh\\.ghostty$" }, { no_blur = true })
rule("youtube-no-blur", { title = "YouTube" }, { no_blur = true })
rule("spotify", { class = "^(Spotify|spotify)$" }, { workspace = "special:spotify" })
rule("discord", { class = "^(discord|vesktop)$" }, { workspace = "special:discord" })
rule("quickshell", { class = "^org\\.quickshell$" }, { float = true, no_blur = true, no_shadow = true, border_size = 0, no_initial_focus = true })
rule("qs-master", { title = "^qs-master$" }, { float = true, no_blur = true, no_shadow = true, border_size = 0, no_initial_focus = true, workspace = "special:qs-master" })

local function layer(name, namespace, properties)
    properties.name = name
    properties.match = { namespace = "^" .. namespace .. "$" }
    hl.layer_rule(properties)
end

layer("swaync-control", "swaync-control-center", { no_anim = true })
layer("swaync-notifications", "swaync-notification-window", { no_anim = true })
layer("walker", "walker", { blur = true })
layer("selection", "selection", { no_anim = true })
layer("skwd-paper", "skwd-paper", { no_anim = true })
layer("skwd-paper-transition", "skwd-paper-transition", { no_anim = true })
layer("wallpaper-selector", "wallpaper-selector-parallel", { no_anim = true })
layer("quickshell", "quickshell", { no_anim = true })
