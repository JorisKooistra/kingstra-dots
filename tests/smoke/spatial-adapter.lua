local root = "config/hypr/lua/spatial"
local registered = nil
local dispatched = {}
local floating = {address="0xF",title="Floating app",floating=true,mapped=true,workspace={id=9},at={x=120,y=80},size={x=400,y=300}}

_G.__hyprscroll2d_focus_subscription = nil
_G.hl = {
    get_windows = function() return {floating} end,
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
        event = function(data)
            return { kind = "event", data = data }
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

-- Camerabeweging wordt als custom IPC-event gemeld (wallpaper-effect).
registered.provider.recalculate(ctx)
local before = #dispatched
assert(registered.provider.layout_msg(ctx, "pan down") == true, "pan was rejected")
registered.provider.recalculate(ctx)
local pan = dispatched[#dispatched]
assert(#dispatched == before + 1 and pan.kind == "event", "camera move did not announce a pan event")
assert(pan.data:match("^kingstra%-pan,9,[-%d.]+,[-%d.]+$"), "unexpected pan event: " .. tostring(pan.data))
local dy = tonumber(pan.data:match(",([-%d.]+)$"))
assert(dy and dy > 0, "panning down should report a positive dy")
registered.provider.recalculate(ctx)
assert(#dispatched == before + 1, "an unchanged camera must not announce again")

-- Werkvlakkaart: venster op een plek zetten via zijn adres.
assert(registered.provider.layout_msg(ctx, "place 0xB 3 -2") == true, "place was rejected")
registered.provider.recalculate(ctx)
assert(type(registered.provider.layout_msg(ctx, "place 0xZZ 0 0")) == "string", "unknown window should error")

assert(registered.provider.layout_msg(ctx, "place 0xA 3 -2 0") == true, "place with a tile spot was rejected")
assert(registered.provider.layout_msg(ctx,"tileplace 0xA 0xB center") == true)
assert(registered.provider.layout_msg(ctx,"tileplace 0xA 0xB left") == true)
assert(type(registered.provider.layout_msg(ctx,"tileplace 0xA 0xB invalid"))=="string")

-- Expliciete kaartselectie centreert ook een buurpagina waarvan nog een rand
-- zichtbaar is. Muisfocus alleen mag dat juist niet doen.
assert(registered.provider.layout_msg(ctx,"place 0xA 0 -1")==true)
assert(registered.provider.layout_msg(ctx,"place 0xB 1 -1")==true)
assert(registered.provider.layout_msg(ctx,"select 0xA")==true)
registered.provider.recalculate(ctx)
assert(a.placed.x >= ctx.area.x and a.placed.x+a.placed.w <= ctx.area.x+ctx.area.w)
assert(a.placed.y >= ctx.area.y and a.placed.y+a.placed.h <= ctx.area.y+ctx.area.h)
assert(registered.provider.layout_msg(ctx,"select 0xB")==true)
registered.provider.recalculate(ctx)
assert(b.placed.x >= ctx.area.x and b.placed.x+b.placed.w <= ctx.area.x+ctx.area.w)
assert(b.placed.y >= ctx.area.y and b.placed.y+b.placed.h <= ctx.area.y+ctx.area.h)
print('ok - overview selects adjacent pages above and beside the current view')

-- Miniaturen: een venster dat helemaal in beeld staat krijgt na een korte
-- pauze een plaatje via werkvlak-thumb.sh.
local timer_fn, commands = nil, {}
hl.timer = function(fn) timer_fn = fn; return { set_enabled = function() end } end
hl.exec_cmd = function(command) table.insert(commands, command) end
hl.get_active_window = function() return a.window end
local solo = target("C", true)
solo.window.address = "0xC"
solo.window.mapped = true
solo.window.workspace = { id = 10, visible = true }
solo.window.at = { x = 0, y = 0 }
solo.window.size = { x = 1000, y = 800 }
registered.provider.recalculate({ area = { x = 0, y = 0, w = 1000, h = 800 }, targets = { solo } })
assert(timer_fn, "no thumbnail timer was scheduled")
timer_fn()
assert(#commands == 1 and commands[1]:match("werkvlak%-thumb%.sh c '0,0 1000x800'$"),
    "unexpected thumbnail command: " .. tostring(commands[1]))

print("ok - mocked Hyprland adapter")

floating.workspace.id=11
hl.get_active_workspace=function() return {id=11} end
assert(registered.provider.layout_msg({area=ctx.area,targets={}},"snapshot")==true)
print('ok - floating-only workspaces can publish an overview without tiled targets')
