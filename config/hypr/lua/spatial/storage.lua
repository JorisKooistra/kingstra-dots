-- Sessie-eigen data, nooit Lua-code laden uit een statusbestand.
local M = {}
local cache = {}

local function path(key)
    local runtime = os.getenv("XDG_RUNTIME_DIR")
    local id = key:match("^workspace:(%d+)$")
    if runtime and id then return runtime .. "/kingstra-spatial-state-" .. id end
end

local function read(file)
    local f = file and io.open(file, "r")
    if not f then return nil end
    local raw = f:read(1024 * 1024)
    f:close()
    return raw
end

function M.save(key, state, descriptors)
    local file = path(key)
    if not file or (state.restore_positions and next(state.restore_positions)) then return end
    local c = state.camera
    local rows = {"version\t1", string.format("camera\t%d\t%d\t%.6f\t%.6f",c.col,c.row,c.offset_x or 0,c.offset_y or 0)}
    if state.focused_id then rows[#rows+1] = "focus\t" .. state.focused_id end
    for _, id in ipairs(state.ids) do
        local p, d = state.positions[id], descriptors[id]
        if p and d and d.address then
            rows[#rows+1] = string.format("window\t%s\t%s\t%d\t%d\t%d\t%d\t%d",id,d.address,p.col,p.row,
                state.order[id] or 0,state.width_step_by_id[id] or 4,state.height_step_by_id[id] or 4)
        end
    end
    local function tree(key, node, route)
        if not node then return end
        if node.id then rows[#rows+1] = "leaf\t"..key.."\t"..route.."\t"..node.id
        else
            rows[#rows+1] = string.format("split\t%s\t%s\t%s\t%.6f",key,route,node.axis,node.ratio)
            tree(key,node.a,route.."a"); tree(key,node.b,route.."b")
        end
    end
    local keys = {}
    for key in pairs(state.cell_trees or {}) do keys[#keys+1]=key end
    table.sort(keys)
    for _, key in ipairs(keys) do tree(key,state.cell_trees[key],"-") end
    local raw = table.concat(rows,"\n").."\n"
    if cache[file] == raw then return end
    local f = io.open(file..".tmp","w")
    if not f then return end
    local ok = f:write(raw)
    f:close()
    if ok and os.rename(file..".tmp",file) then cache[file]=raw end
end

function M.restore(key, state, available, config)
    local file = path(key)
    if not file then return false end
    local by_address = {}
    for id, d in pairs(available) do by_address[tostring(d.address):lower()]=id end
    local raw = read(file)
    local mapping, nodes = {}, {}
    state.restore_positions = {}
    if raw and raw:match("^version\t1\n") then
        for line in raw:gmatch("[^\n]+") do
            local id,address,col,row,order,w,h = line:match("^window\t([^\t]+)\t([^\t]+)\t(%-?%d+)\t(%-?%d+)\t(%d+)\t(%d+)\t(%d+)$")
            local current = address and by_address[address:lower()]
            if current then
                mapping[id]=current
                state.restore_positions[current]={col=tonumber(col),row=tonumber(row)}
                state.order[current]=tonumber(order)
                state.next_order=math.max(state.next_order,tonumber(order)+1)
                state.width_step_by_id[current]=math.max(1,math.min(#config.width_steps,tonumber(w)))
                state.height_step_by_id[current]=math.max(1,math.min(#config.height_steps,tonumber(h)))
            end
        end
        for line in raw:gmatch("[^\n]+") do
            local kind,cell,route,value,ratio = line:match("^(%w+)\t([%-:%d]+)\t(%-[ab]*)\t([^\t]+)\t?(.*)$")
            if (kind=="split" or kind=="leaf") and #route<=256 then
                nodes[cell]=nodes[cell] or {}
                nodes[cell][route]=kind=="leaf" and {id=mapping[value]} or {axis=value,ratio=tonumber(ratio)}
            end
        end
        local function build(records,route)
            local n=records[route]
            if not n then return nil end
            if n.id then return {id=n.id} end
            if n.axis~="x" and n.axis~="y" then return nil end
            local a,b=build(records,route.."a"),build(records,route.."b")
            if not a then return b end
            if not b then return a end
            return {axis=n.axis,ratio=math.max(0.15,math.min(0.85,n.ratio or 0.5)),a=a,b=b}
        end
        state.cell_trees={}
        for cell,records in pairs(nodes) do state.cell_trees[cell]=build(records,"-") end
        local col,row,x,y=raw:match("\ncamera\t(%-?%d+)\t(%-?%d+)\t([%-%.%d]+)\t([%-%.%d]+)")
        if col then state.camera={col=tonumber(col),row=tonumber(row),offset_x=tonumber(x),offset_y=tonumber(y)} end
        local focused=raw:match("\nfocus\t([^\n]+)")
        state.focused_id=mapping[focused]
    else
        -- Eerste update vanuit de oude versie: ook die bestaande kaart bewaren.
        local snapshot=read(file:gsub("state%-", "")..".json") or ""
        for address,_,col,row in snapshot:gmatch('"address":"([^"]+)"(.-)"col":(%-?%d+),"row":(%-?%d+)') do
            local id=by_address[address:lower()]
            if id then
                state.restore_positions[id]={col=tonumber(col),row=tonumber(row)}
                state.order[id]=state.next_order; state.next_order=state.next_order+1
                state.width_step_by_id[id],state.height_step_by_id[id]=config.default_width_step,config.default_height_step
            end
        end
        local col,row,x,y=snapshot:match('"camera":{"col":(%-?%d+),"row":(%-?%d+),"x":([%-%.%d]+),"y":([%-%.%d]+)')
        if col then state.camera={col=tonumber(col),row=tonumber(row),offset_x=tonumber(x),offset_y=tonumber(y)} end
    end
    state.observed_active_id=state.focused_id
    return next(state.restore_positions)~=nil
end

return M
