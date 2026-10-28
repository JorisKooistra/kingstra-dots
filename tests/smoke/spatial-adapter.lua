local root = "config/hypr/lua/spatial"
local registered = nil
local dispatched = {}

_G.__hyprscroll2d_focus_subscription = nil
_G.hl = {
    layout = {
        register = function(name, provider)
            registered = { name = name, provider = provider }
        end,
    },
    on = function()
        return true
    end,
    dispatch = function(dispatcher)
        table.insert(dispatched, dispatcher)
    end,
    dsp = {
        layout = function(message)
            return { kind = "layout", message = message }
        end,
        focus = function(options)
            return { kind = "focus", window = options.window }
        end,
    },
}

assert(loadfile(root .. "/init.lua"))()
assert(registered and registered.name == "hyprscroll2d", "layout did not register")

local function target(id, active)
    return {
        window = {
            stable_id = id,
            address = "0x" .. id,
            title = "Quoted \"title\"\nsecond line",
            active = active,
            workspace = { id = 9 },
            layout = { name = "lua:hyprscroll2d" },
        },
        place = function(self, box)
            self.placed = box
        end,
    }
end

local a = target("A", true)
local b = target("B", false)
local ctx = {
    area = { x = 0, y = 0, w = 1000, h = 800 },
    targets = { a, b },
}

registered.provider.recalculate(ctx)
assert(a.placed and b.placed, "recalculate did not place every target")
assert(a.placed.x < b.placed.x, "new targets should initially extend right")

local response = registered.provider.layout_msg(ctx, "focus right")
assert(response == true, "focus command was rejected")
assert(dispatched[#dispatched].kind == "focus", "focus command did not dispatch")
assert(dispatched[#dispatched].window == "address:0xB", "focus targeted the wrong window")

response = registered.provider.layout_msg(ctx, "resize height shrink")
assert(response == true, "height resize command was rejected")

response = registered.provider.layout_msg(ctx, "resize height sideways")
assert(type(response) == "string", "invalid resize command should return an error")

print("ok - mocked Hyprland adapter")
