-- Super+middelmuis slepen en Super+wiel in config/hypr/lua/spatial.lua, met
-- een nagebootste Hyprland: timer, cursor en actieve layout.
local dispatched = {}
local layout_name = "lua:hyprscroll2d"
local cursor = { x = 100, y = 100 }
local timer = { enabled = false, fn = nil }
function timer:set_enabled(value) self.enabled = value end

_G.__hyprscroll2d_layout_registered = true
_G.hl = {
    layout = { register = function() end },
    dispatch = function(d) table.insert(dispatched, d) end,
    dsp = { layout = function(message) return message end },
    get_active_window = function() return { layout = { name = layout_name } } end,
    get_active_monitor = function() return { width = 2000 } end,
    get_cursor_pos = function() return { x = cursor.x, y = cursor.y } end,
    timer = function(fn, opts)
        assert(opts.type == "repeat" and opts.timeout > 0)
        timer.fn, timer.enabled = fn, true
        return timer
    end,
}
os.getenv = (function(real)
    return function(name)
        if name == "XDG_CONFIG_HOME" then return "/nonexistent" end
        return real(name)
    end
end)(os.getenv)

local spatial = assert(loadfile("config/hypr/lua/spatial.lua"))()
local function last() return dispatched[#dispatched] end

spatial.drag_start()
assert(last() == "dragstart", "drag did not start: " .. tostring(last()))
assert(timer.enabled, "timer not running")
cursor = { x = 130, y = 90 }
timer.fn()
assert(last() == "panby -30.0000 10.0000", "content should follow the hand: " .. tostring(last()))
local count = #dispatched
timer.fn()
assert(#dispatched == count, "no move means no pan")
spatial.drag_stop()
assert(last() == "dragend" and not timer.enabled, "release should settle and stop the timer")
spatial.drag_stop()
assert(last() == "dragend" and #dispatched == count + 1, "a second release is ignored")
print("ok - spatial drag pans and settles")

layout_name = "scrolling"
cursor = { x = 100, y = 100 }
spatial.drag_start()
cursor = { x = 400, y = 100 }
timer.fn()
assert(last() == "dragend", "small scrolling drag waits")
cursor = { x = 700, y = 100 }
timer.fn()
assert(last() == "move -col", "dragging right shows the column on the left: " .. tostring(last()))
spatial.drag_stop()
assert(last() == "move -col", "scrolling has no settle step")
print("ok - scrolling drag steps columns")

layout_name = "dwindle"
count = #dispatched
spatial.drag_start()
spatial.wheel("down")()
assert(#dispatched == count, "tiles ignore drag and wheel")
layout_name = "lua:hyprscroll2d"
spatial.wheel("down")()
assert(last() == "pan down")
layout_name = "scrolling"
spatial.wheel("up")()
assert(last() == "move -col")
print("ok - Super+wheel scrolls inside the workspace")
