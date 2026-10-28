if rawget(_G, "__hyprscroll2d_layout_registered") then return true end

local function current_dir()
    local source = debug and debug.getinfo(1, "S").source
    if type(source) ~= "string" or source:sub(1, 1) ~= "@" then
        error("hyprscroll2d: unable to resolve layout directory")
    end
    return source:sub(2):match("^(.*)/[^/]*$")
end

local function load_relative(filename)
    local chunk, err = loadfile(current_dir() .. "/" .. filename)
    if not chunk then error(err) end
    return chunk()
end

local config = load_relative("config.lua")
local core = load_relative("core.lua")
local workspaces = {}

local function safe_field(value, field)
    if value == nil then return nil end
    local ok, result = pcall(function() return value[field] end)
    if ok then return result end
end

local function target_id(target, index)
    local window = safe_field(target, "window")
    local stable_id = safe_field(window, "stable_id")
    if stable_id ~= nil then return tostring(stable_id) end
    local address = safe_field(window, "address")
    if address then return "address:" .. tostring(address) end
    return "target:" .. tostring(safe_field(target, "index") or index)
end

local function workspace_key(ctx)
    for _, target in ipairs(ctx.targets or {}) do
        local window = safe_field(target, "window")
        local workspace = safe_field(window, "workspace")
        local id = safe_field(workspace, "id")
        if id ~= nil then return "workspace:" .. tostring(id) end
        local name = safe_field(workspace, "name")
        if name then return "workspace-name:" .. tostring(name) end
    end
    return "global"
end

local function describe(ctx)
    local descriptors = {}
    local active_id = nil

    for index, target in ipairs(ctx.targets or {}) do
        local window = safe_field(target, "window")
        local id = target_id(target, index)
        descriptors[id] = {
            id = id,
            target = target,
            window = window,
            address = safe_field(window, "address"),
        }
        if safe_field(window, "active") then active_id = id end
    end

    return descriptors, active_id
end

local function context(ctx)
    local key = workspace_key(ctx)
    local state = workspaces[key]
    if not state then
        state = core.new_state()
        workspaces[key] = state
    end

    local descriptors, active_id = describe(ctx)
    local ids = {}
    for _, target in ipairs(ctx.targets or {}) do
        table.insert(ids, target_id(target, #ids + 1))
    end
    core.sync(state, ids, active_id, config)

    return state, descriptors
end

local function focus_descriptor(descriptor)
    if not descriptor or not descriptor.address then return end
    hl.dispatch(hl.dsp.focus({ window = "address:" .. descriptor.address }))
end


local function json_string(value)
    local escapes = { ['"'] = '\\"', ['\\'] = '\\\\', ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t' }
    return '"' .. tostring(value or ""):gsub('[%z\1-\31\\"]', function(c)
        return escapes[c] or string.format("\\u%04x", string.byte(c))
    end) .. '"'
end

local snapshot_cache = {}
local function publish(ctx, state, descriptors, placements)
    local runtime = os.getenv("XDG_RUNTIME_DIR")
    if not runtime then return end
    local key = workspace_key(ctx):match("^workspace:(%d+)$")
    if not key then return end
    local rows = {}
    for _, id in ipairs(state.ids) do
        local d, p = descriptors[id], placements[id]
        if d and p then
            local pos = state.positions[id]
            rows[#rows + 1] = string.format(
                '{"address":%s,"title":%s,"x":%.3f,"y":%.3f,"w":%.3f,"h":%.3f,"col":%d,"row":%d}',
                json_string(d.address), json_string(safe_field(d.window, "title")),
                p.x, p.y, p.w, p.h, pos.col, pos.row)
        end
    end
    local a = ctx.area
    local raw = string.format(
        '{"workspace":%s,"area":{"x":%.3f,"y":%.3f,"w":%.3f,"h":%.3f},"windows":[%s]}',
        key, a.x, a.y, a.w, a.h, table.concat(rows, ","))
    if snapshot_cache[key] == raw then return end
    local path = runtime .. "/kingstra-spatial-" .. key .. ".json"
    local file = io.open(path .. ".tmp", "w")
    if not file then return end
    file:write(raw)
    file:close()
    if os.rename(path .. ".tmp", path) then snapshot_cache[key] = raw end
end

-- Kingstra: meld cameraverschuivingen als Hyprland-IPC-event
-- (custom>>kingstra-pan,<werkruimte>,<dx>,<dy>, in schermbreedtes), zodat
-- de shell een klein wallpaper-effect kan tonen. Puur informatief.
local last_camera = {}
local function announce_pan(ctx, state)
    local key = workspace_key(ctx):match("^workspace:(%d+)$")
    local c = state.camera
    if not key or not c then return end
    local w, h = math.max(ctx.area.w or 1, 1), math.max(ctx.area.h or 1, 1)
    local x = (c.col or 0) + (c.offset_x or 0) / w
    local y = (c.row or 0) + (c.offset_y or 0) / h
    local previous = last_camera[key]
    last_camera[key] = { x = x, y = y }
    if not previous then return end
    local dx, dy = x - previous.x, y - previous.y
    if math.abs(dx) < 0.001 and math.abs(dy) < 0.001 then return end
    pcall(function()
        hl.dispatch(hl.dsp.event(string.format("kingstra-pan,%s,%.4f,%.4f", key, dx, dy)))
    end)
end

local function recalculate(ctx)
    local state, descriptors = context(ctx)
    local placements = core.placements(state, ctx.area, config)
    publish(ctx, state, descriptors, placements)
    announce_pan(ctx, state)

    for id, descriptor in pairs(descriptors) do
        local placement = placements[id]
        if placement then descriptor.target:place(placement) end
    end
end

local function layout_msg(ctx, message)
    local state, descriptors = context(ctx)
    local command, argument, extra = message:match("^(%S+)%s*(%S*)%s*(%S*)$")

    if command == "panby" then
        local dx, dy = tonumber(argument), tonumber(extra)
        if not dx or not dy then return "hyprscroll2d: panby expects two numbers" end
        core.pan_by(state, dx, dy, ctx.area, config)
    elseif command == "focus" then
        local id = core.focus(state, argument)
        focus_descriptor(id and descriptors[id])
    elseif command == "move" then
        core.move(state, argument)
    elseif command == "pan" then
        core.pan(state, argument)
    elseif command == "follow" or command == "center" then
        core.follow(state)
    elseif command == "resize" and argument == "width" then
        if extra ~= "grow" and extra ~= "shrink" then
            return "hyprscroll2d: resize width expects grow or shrink"
        end
        core.resize_width(state, config, extra == "grow" and 1 or -1)
    elseif command == "resize" and argument == "height" then
        if extra ~= "grow" and extra ~= "shrink" then
            return "hyprscroll2d: resize height expects grow or shrink"
        end
        core.resize_height(state, config, extra == "grow" and 1 or -1)
    else
        return "hyprscroll2d: expected focus/move/pan <direction>, resize width/height grow/shrink, or center"
    end

    return true
end

local function window_layout_name(window)
    local layout = safe_field(window, "layout")
    return safe_field(layout, "name")
end

if not rawget(_G, "__hyprscroll2d_focus_subscription") then
    local ok, subscription = pcall(function()
        return hl.on("window.active", function(window)
            if window_layout_name(window) == "lua:hyprscroll2d" then
                hl.dispatch(hl.dsp.layout("follow"))
            end
        end)
    end)
    if ok then _G.__hyprscroll2d_focus_subscription = subscription or true end
end

hl.layout.register("hyprscroll2d", {
    recalculate = recalculate,
    layout_msg = layout_msg,
})

_G.__hyprscroll2d_layout_registered = true
return true
