-- Touchpad gestures for the spatial workspace: four-finger pan, pinch zoom,
-- Super+three-finger pan, and the magic-workspace fallback outside that layout.
local gestures, dispatched = {}, {}
local layout_name = "lua:hyprscroll2d"
local real_getenv = os.getenv
os.getenv = function(name)
    if name == "XDG_CONFIG_HOME" then return "/nonexistent" end
    return real_getenv(name)
end
_G.__hyprscroll2d_layout_registered = true
_G.hl = {
    layout = { register = function() end },
    dispatch = function(value) dispatched[#dispatched + 1] = value end,
    dsp = {
        layout = function(message) return message end,
        workspace = { toggle_special = function(name) return "special:" .. name end },
    },
    get_active_window = function() return { layout = { name = layout_name } } end,
    get_active_workspace = function() return { id = 1 } end,
    gesture = function(spec) gestures[#gestures + 1] = spec end,
}
assert(loadfile("config/hypr/lua/spatial.lua"))()

local function find(fingers, direction, mods)
    for _, gesture in ipairs(gestures) do
        if gesture.fingers == fingers and gesture.direction == direction and gesture.mods == mods then
            return gesture.action
        end
    end
    error("missing gesture " .. fingers .. " " .. direction .. " " .. tostring(mods))
end
local function last() return dispatched[#dispatched] end

local three = find(3, "swipe", "SUPER")
three.start({ delta = { x = 12, y = -4 } })
assert(dispatched[1] == "dragstart" and last() == "panby -12.0000 4.0000", "Super+three fingers pans with the hand")
three.update({ delta = { x = 0, y = 8 } })
assert(last() == "panby 0.0000 -8.0000")
three.finish({})
assert(last() == "dragend", "releasing the gesture settles the camera")

_G.__kingstra_native_zoom_workspaces = { ["1"] = 0.5 }
three.start({ delta = { x = 10, y = 0 } })
assert(last() == "panby -20.0000 0.0000", "trackpad pan follows the zoomed desktop")
three.finish({})
_G.__kingstra_native_zoom_workspaces = nil

local nudged = {}
package.loaded["lua.native-zoom"] = {
    nudge = function(direction) nudged[#nudged + 1] = direction end,
}
local pinch = find(2, "pinch", nil)
pinch.start({ delta = { x = 3, y = 0 }, scale = 1 })
assert(dispatched[#dispatched - 1] == "dragstart" or last() == "panby -3.0000 -0.0000")
pinch.update({ delta = { x = 0, y = 0 }, scale = 0.8 })
assert(nudged[1] == "out", "pinching fingers together zooms the workspace out")
pinch.finish({})
assert(last() == "dragend")

layout_name = "dwindle"
local before = #dispatched
local four = find(4, "swipe", nil)
four.start({ delta = { x = 5, y = 40 } })
four.update({ delta = { x = 0, y = 30 } })
four.finish({})
assert(#dispatched == before + 1 and last() == "special:magic", "a vertical four-finger swipe still toggles magic outside the spatial layout")
four.start({ delta = { x = 80, y = 4 } })
four.finish({})
assert(last() == "special:magic", "a horizontal four-finger swipe does not toggle magic")

layout_name = "lua:hyprscroll2d"
four.start({ delta = { x = 15, y = 6 } })
assert(last() == "panby -15.0000 -6.0000", "four fingers pan the spatial workspace in both directions")
four.update({ delta = { x = 0, y = 90 } })
four.finish({})
assert(last() == "dragend", "spatial four-finger pan does not toggle the magic workspace")

layout_name = "dwindle"
pinch.start({ scale = 0.5, delta = { x = 30, y = 0 } })
assert(#nudged == 1, "pinch does nothing outside the spatial layout")
pinch.finish({})
print("ok - touchpad pans, pinches and keeps the magic workspace outside the spatial layout")
