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
return M
