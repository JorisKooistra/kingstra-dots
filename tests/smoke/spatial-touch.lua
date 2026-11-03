-- Touchpad gestures: three fingers (no Super) pan the spatial workspace and
-- switch workspace elsewhere; pinch zooms; four fingers do nothing.
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
    exec_cmd = function(cmd) dispatched[#dispatched + 1] = "exec " .. cmd end,
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

local three = find(3, "swipe", nil)
for _, g in ipairs(gestures) do
    assert(g.fingers ~= 4, "four-finger gestures are gone")
    assert(not (g.fingers == 3 and g.mods), "three fingers need no Super")
end

three.start({ delta = { x = 12, y = -4 } })
assert(dispatched[1] == "dragstart" and last() == "panby -12.0000 4.0000", "three fingers pan with the hand")
three.update({ delta = { x = 0, y = 8 } })
assert(last() == "panby 0.0000 -8.0000" or last() == "panby -0.0000 -8.0000")
three.finish({})
assert(last() == "dragend", "lifting the fingers settles the camera")

_G.__kingstra_native_zoom_workspaces = { ["1"] = 0.5 }
three.start({ delta = { x = 10, y = 0 } })
assert(last() == "panby -20.0000 0.0000" or last() == "panby -20.0000 -0.0000", "pan follows the zoomed desktop")
three.finish({})
_G.__kingstra_native_zoom_workspaces = nil

local nudged = {}
package.loaded["lua.native-zoom"] = {
    nudge = function(direction) nudged[#nudged + 1] = direction end,
}
local pinch = find(2, "pinch", nil)
pinch.start({ delta = { x = 3, y = 0 }, scale = 1 })
pinch.update({ delta = { x = 0, y = 0 }, scale = 0.8 })
assert(nudged[1] == "out", "pinching fingers together zooms the workspace out")
pinch.finish({})
assert(last() == "dragend")

-- Elders wisselen drie vingers opzij van werkruimte, en verder niets.
layout_name = "dwindle"
local before = #dispatched
three.start({ delta = { x = -30, y = 2 } })
three.update({ delta = { x = -70, y = 3 } })
assert(#dispatched == before, "no panning outside the spatial workspace")
three.finish({})
assert(last():match("workspace%-scroll%.sh next$"), "fingers to the left go to the next workspace")
three.start({ delta = { x = 60, y = 0 } })
three.update({ delta = { x = 60, y = 0 } })
three.finish({})
assert(last():match("workspace%-scroll%.sh prev$"), "fingers to the right go back")
before = #dispatched
three.start({ delta = { x = 5, y = 60 } })
three.update({ delta = { x = 0, y = 120 } })
three.finish({})
assert(#dispatched == before, "three fingers up or down open nothing")
three.start({ delta = { x = 30, y = 0 } })
three.finish({})
assert(#dispatched == before, "a short swipe does not switch")
three.start({ delta = { x = -200, y = 0 } })
three.finish({ cancelled = true })
assert(#dispatched == before, "a cancelled swipe does nothing")

layout_name = "dwindle"
pinch.start({ scale = 0.5, delta = { x = 30, y = 0 } })
assert(#nudged == 1, "pinch does nothing outside the spatial layout")
pinch.finish({})

-- Op een leeg ruimtelijk werkvlak (geen actief venster) schuift het ook.
hl.get_active_window = function() return nil end
hl.get_active_workspace = function() return { id = 1, tiled_layout = "lua:hyprscroll2d" } end
three.start({ delta = { x = 7, y = 0 } })
assert(last() == "panby -7.0000 0.0000" or last() == "panby -7.0000 -0.0000", "three fingers pan an empty spatial workspace")
three.finish({})
assert(last() == "dragend")
print("ok - three fingers pan the werkvlak or switch workspace, pinch zooms, no four-finger gestures")
