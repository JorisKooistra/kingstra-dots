-- Core appearance and input. Runtime color/theme modules are generated
-- atomically by Kingstra and intentionally kept out of git.

local function load_optional(module)
    local ok, value = pcall(require, module)
    if ok and type(value) == "table" and type(value.apply) == "function" then
        value.apply()
    end
end

hl.config({
    general = {
        gaps_in = 4,
        gaps_out = 8,
        border_size = 2,
        col = {
            active_border = { colors = { "rgba(98cbffee)", "rgba(a5eb6eee)", "rgba(90d6a8ee)" }, angle = 55 },
            inactive_border = "rgba(89919d44)",
        },
        resize_on_border = true,
        extend_border_grab_area = 20,
        hover_icon_on_border = true,
        layout = "dwindle",
        allow_tearing = false,
    },
    decoration = {
        rounding = 10,
        active_opacity = 1.0,
        inactive_opacity = 0.94,
        fullscreen_opacity = 1.0,
        blur = {
            enabled = true, size = 8, passes = 2, xray = false,
            ignore_opacity = false, popups = true, popups_ignorealpha = 0.2,
            brightness = 0.9, contrast = 0.9, noise = 0.02,
            vibrancy = 0.18, vibrancy_darkness = 0.0,
        },
        shadow = {
            enabled = true, range = 12, render_power = 3,
            color = "rgba(000000cc)", color_inactive = "rgba(00000055)",
            offset = { 0, 4 }, scale = 1.0,
        },
        dim_inactive = false, dim_strength = 0.1, dim_special = 0.2, dim_around = 0.4,
    },
    dwindle = {
        preserve_split = true, smart_split = false, smart_resizing = true,
        force_split = 0, split_width_multiplier = 1.0,
    },
    master = { new_status = "slave", new_on_top = false, mfact = 0.55, orientation = "left" },
    misc = {
        disable_hyprland_logo = true, disable_splash_rendering = true,
        force_default_wallpaper = 0, vrr = 0, key_press_enables_dpms = true,
        mouse_move_enables_dpms = true, font_family = "Fira Sans",
        focus_on_activate = false, animate_manual_resizes = false, enable_swallow = false,
    },
    debug = { vfr = true },
    input = {
        kb_layout = "us", kb_variant = "intl", kb_options = "",
        follow_mouse = 1, mouse_refocus = true, sensitivity = 0,
        accel_profile = "flat", scroll_factor = 1.35,
        touchpad = {
            natural_scroll = true, disable_while_typing = true, tap_to_click = true,
            tap_and_drag = true, scroll_factor = 0.45, clickfinger_behavior = false,
            middle_button_emulation = false,
        },
    },
    gestures = {
        workspace_swipe_distance = 320, workspace_swipe_invert = true,
        workspace_swipe_cancel_ratio = 0.45, workspace_swipe_min_speed_to_force = 25,
        workspace_swipe_direction_lock = true, workspace_swipe_direction_lock_threshold = 12,
        workspace_swipe_create_new = true, workspace_swipe_forever = false,
        workspace_swipe_use_r = false, workspace_swipe_touch = true,
        workspace_swipe_touch_invert = true,
    },
    cursor = { no_warps = true, inactive_timeout = 10, hide_on_key_press = false },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "up", action = "special", workspace_name = "magic" })
hl.gesture({ fingers = 4, direction = "down", action = "special", workspace_name = "magic" })

hl.curve("easeOut", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })
hl.curve("easeIn", { type = "bezier", points = { { 0.5, 0 }, { 1, 0.5 } } })
hl.curve("easeInOut", { type = "bezier", points = { { 0.42, 0 }, { 0.58, 1 } } })
hl.curve("overshot", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
hl.curve("snap", { type = "bezier", points = { { 0.19, 1 }, { 0.22, 1 } } })
hl.animation({ leaf = "windows", enabled = true, speed = 4, bezier = "overshot" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "overshot", style = "popin 80%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "easeIn", style = "popin 80%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 4, bezier = "snap" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 60, bezier = "linear", style = "loop" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fadeDim", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "fadeLayers", enabled = true, speed = 5, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "snap", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "snap", style = "slidevert" })
hl.animation({ leaf = "layers", enabled = true, speed = 4, bezier = "overshot", style = "slide" })

-- Load generated overrides last, so the selected theme always wins.
load_optional("lua.hardware")
load_optional("lua.colors")
load_optional("lua.theme")
load_optional("lua.input-overrides")
