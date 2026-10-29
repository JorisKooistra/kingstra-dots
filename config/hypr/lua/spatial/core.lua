local M = {}

-- Kingstra-variant van de Hyprscroll2D-kern. Een cel op het werkvlak kan
-- meerdere vensters als tegels bevatten; nieuwe vensters komen in de cel
-- waar je naar kijkt (een lege plek of de huidige tegels) en pas als die
-- vol is ernaast. De camera kan vrij bewegen (panby) en klikt bij loslaten
-- alleen op een cel vast als je er dichtbij bent (settle).

local DIRECTIONS = {
    left = { dc = -1, dr = 0 },
    right = { dc = 1, dr = 0 },
    up = { dc = 0, dr = -1 },
    down = { dc = 0, dr = 1 },
}

local EPSILON = 1e-6

local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
end

local function round(value)
    return value >= 0 and math.floor(value + 0.5) or -math.floor(-value + 0.5)
end

local function contains(values, wanted)
    for _, value in ipairs(values or {}) do
        if value == wanted then
            return true
        end
    end
    return false
end

local function position_key(col, row)
    return tostring(col) .. ":" .. tostring(row)
end

-- Leden van een cel, in volgorde van binnenkomst.
local function members(state, col, row, except_id)
    local list = {}
    for id, position in pairs(state.positions) do
        if id ~= except_id and position.col == col and position.row == row then
            table.insert(list, id)
        end
    end
    table.sort(list, function(a, b)
        local oa, ob = state.order[a] or 0, state.order[b] or 0
        if oa ~= ob then return oa < ob end
        return tostring(a) < tostring(b)
    end)
    return list
end
M.members = members

-- Elke pagina heeft een eigen splitsboom. Bestaande splits en verhoudingen
-- blijven behouden wanneer je vensters toevoegt, sluit of verplaatst.
local function tree_has(node, id)
    if not node or id == nil then return false end
    return node.id == id or tree_has(node.a, id) or tree_has(node.b, id)
end

local function clone_tree(node)
    if not node then return nil end
    if node.id then return {id=node.id} end
    return {axis=node.axis,ratio=node.ratio,a=clone_tree(node.a),b=clone_tree(node.b)}
end

local function replace_leaf(node, from, to)
    if not node then return end
    if node.id == from then node.id = to
    elseif not node.id then replace_leaf(node.a, from, to); replace_leaf(node.b, from, to) end
end

local function prune_tree(node, present)
    if not node then return nil end
    if node.id then return present[node.id] and node or nil end
    node.a, node.b = prune_tree(node.a, present), prune_tree(node.b, present)
    if not node.a then return node.b end
    if not node.b then return node.a end
    return node
end

local function split_box(node, box, config)
    local horizontal = node.axis == "x"
    local gap = math.min(horizontal and (config.gap_x or 0) or (config.gap_y or 0),
        math.max(0, (horizontal and box.w or box.h) - 2))
    local length = math.max(2, (horizontal and box.w or box.h) - gap)
    local first = length * (node.ratio or 0.5)
    if horizontal then
        return {x=box.x,y=box.y,w=first,h=box.h},
            {x=box.x+first+gap,y=box.y,w=length-first,h=box.h}
    end
    return {x=box.x,y=box.y,w=box.w,h=first},
        {x=box.x,y=box.y+first+gap,w=box.w,h=length-first}
end

local function insert_leaf(node, anchor, id, box, config)
    if node.id then
        if node.id ~= anchor then return false end
        node.a, node.b = {id=node.id}, {id=id}
        node.id, node.axis, node.ratio = nil, box.w >= box.h and "x" or "y", 0.5
        return true
    end
    local a, b = split_box(node, box, config)
    return insert_leaf(node.a, anchor, id, a, config) or insert_leaf(node.b, anchor, id, b, config)
end

local function tile_tree(state, list, box, config)
    state.cell_trees = state.cell_trees or {}
    local p = state.positions[list[1]]
    local key = position_key(p.col, p.row)
    local present = {}
    for _, id in ipairs(list) do present[id] = true end
    for id, position in pairs(state.restore_positions or {}) do
        if position.col == p.col and position.row == p.row then present[id] = true end
    end
    local tree = prune_tree(state.cell_trees[key], present)
    for index, id in ipairs(list) do
        if not tree then tree = {id=id}
        elseif not tree_has(tree, id) then
            local anchor = state.split_anchor and state.split_anchor[id]
            if not tree_has(tree, anchor) then anchor = list[math.max(1, index - 1)] end
            if not tree_has(tree, anchor) then anchor = list[1] end
            insert_leaf(tree, anchor, id, box, config)
        end
    end
    -- De volgorde van een expliciete drop moet ook in de boom terugkomen.
    local leaves = {}
    local function collect(node)
        if node.id then leaves[#leaves+1] = node else collect(node.a); collect(node.b) end
    end
    collect(tree)
    if state.reorder_cells and state.reorder_cells[key] then
        for i, leaf in ipairs(leaves) do leaf.id = list[i] end
        state.reorder_cells[key] = nil
    end
    state.cell_trees[key] = tree
    return tree
end

local function tree_placements(node, box, config, result)
    if node.id then result[node.id] = box; return end
    local a, b = split_box(node, box, config)
    tree_placements(node.a, a, config, result)
    tree_placements(node.b, b, config, result)
end

local function bounds(state)
    local min_col, max_col, min_row, max_row
    for _, p in pairs(state.positions) do
        min_col = min_col and math.min(min_col, p.col) or p.col
        max_col = max_col and math.max(max_col, p.col) or p.col
        min_row = min_row and math.min(min_row, p.row) or p.row
        max_row = max_row and math.max(max_row, p.row) or p.row
    end
    return min_col, max_col, min_row, max_row
end

local function cell_metrics(area, config, state)
    local peek_x = clamp(config.peek_x or 0, 0, math.max(0, (area.w - 1) / 2))
    local peek_y = clamp(config.peek_y or 0, 0, math.max(0, (area.h - 1) / 2))
    if state and config.fill_single then
        local col, row, single
        single = true
        for _, p in pairs(state.positions) do
            if col == nil then col, row = p.col, p.row
            elseif col ~= p.col or row ~= p.row then single = false; break end
        end
        if single then peek_x, peek_y = 0, 0 end
    end
    local maximum_width = math.max(1, area.w - (peek_x * 2))
    local maximum_height = math.max(1, area.h - (peek_y * 2))
    return {
        peek_x = peek_x,
        peek_y = peek_y,
        maximum_width = maximum_width,
        maximum_height = maximum_height,
        pitch_x = maximum_width * config.width_steps[config.default_width_step] + math.max(0, config.gap_x or 0),
        pitch_y = maximum_height * config.height_steps[config.default_height_step] + math.max(0, config.gap_y or 0),
    }
end

M.cell_metrics = cell_metrics

-- De cel waar de camera nu (ongeveer) op staat, inclusief vrije verschuiving.
function M.view_cell(state, area, config)
    local col, row = state.camera.col, state.camera.row
    if area and area.w and area.h then
        local metrics = cell_metrics(area, config, state)
        col = col + round((state.camera.offset_x or 0) / metrics.pitch_x)
        row = row + round((state.camera.offset_y or 0) / metrics.pitch_y)
    end
    return { col = col, row = row }
end

function M.new_state()
    return {
        ids = {},
        positions = {},
        order = {},
        next_order = 1,
        width_step_by_id = {},
        height_step_by_id = {},
        focused_id = nil,
        observed_active_id = nil,
        pending_follow = false,
        force_follow = false,
        dragging = false,
        camera = { col = 0, row = 0, offset_x = 0, offset_y = 0 },
    }
end

-- Vensters die net uit een werkruimte verdwenen (gesloten, verplaatst of
-- opgepakt om te slepen). Alleen een terugkeer in dezelfde werkruimte telt.
local departed = {}

local function assign_order(state, id)
    state.order[id] = state.next_order or 1
    state.next_order = (state.next_order or 1) + 1
end

-- Zet een venster op een bepaalde tegelplek (0 = eerste) in een cel.
local function insert_at(state, id, col, row, slot, config, spare)
    local list = members(state, col, row, id)
    local index = clamp(math.floor(slot or #list) + 1, 1, #list + 1)
    table.insert(list, index, id)
    state.positions[id] = { col = col, row = row }
    for _, member in ipairs(list) do
        assign_order(state, member)
    end
end

function M.follow(state)
    local focused = state.focused_id and state.positions[state.focused_id]
    if not focused then return false end
    state.camera.col = focused.col
    state.camera.row = focused.row
    state.camera.offset_x, state.camera.offset_y = 0, 0
    state.pending_follow = false
    state.force_follow = false
    return true
end

-- area is optioneel: zonder area komt een nieuw venster bij het actieve.
-- drop is de cursor ({x, y}); die bepaalt waar een teruggezet venster landt.
function M.sync(state, ids, active_id, config, area, drop)
    state.order = state.order or {}
    local present = {}
    local unique_ids = {}

    for _, id in ipairs(ids or {}) do
        if not present[id] then
            present[id] = true
            table.insert(unique_ids, id)
        end
    end

    for id, position in pairs(state.positions) do
        if not present[id] then
            -- Onthouden: een venster dat je met Super+slepen oppakt, wordt
            -- even zwevend en komt bij loslaten terug (zie drop hieronder).
            departed[id] = { state = state, col = position.col, row = position.row,
                order = state.order[id], width = state.width_step_by_id[id], height = state.height_step_by_id[id],
                tree = clone_tree(state.cell_trees and state.cell_trees[position_key(position.col, position.row)]) }
            state.positions[id] = nil
            state.order[id] = nil
            state.width_step_by_id[id] = nil
            state.height_step_by_id[id] = nil
        end
    end

    state.ids = unique_ids

    local added, dropped = {}, {}
    for _, id in ipairs(unique_ids) do
        local restored = state.restore_positions and state.restore_positions[id]
        if not state.positions[id] and restored then
            state.positions[id] = restored
            state.restore_positions[id] = nil
            dropped[id] = true
        end
        local returning = not state.positions[id] and departed[id]
        if returning then departed[id] = nil end
        if returning and returning.state ~= state then returning = nil end
        if returning then
            -- Terug na slepen of zwevend: waar je het loslaat, anders op de
            -- oude plek. De camera blijft staan.
            local spot = drop and area and M.spot_at(state, area, config, drop.x, drop.y, id)
            if spot and spot.target then
                state.positions[id] = {col=returning.col,row=returning.row}
                state.order[id] = returning.order
                state.width_step_by_id[id] = returning.width or config.default_width_step
                state.height_step_by_id[id] = returning.height or config.default_height_step
                if returning.tree then
                    state.cell_trees = state.cell_trees or {}
                    state.cell_trees[position_key(returning.col, returning.row)] = returning.tree
                end
                M.tile_place(state, id, spot.target, spot.edge, area, config)
            elseif spot then
                insert_at(state, id, spot.col, spot.row, spot.slot, config, returning)
            else
                insert_at(state, id, returning.col, returning.row, nil, config)
            end
            state.width_step_by_id[id] = state.width_step_by_id[id] or config.default_width_step
            state.height_step_by_id[id] = state.height_step_by_id[id] or config.default_height_step
            dropped[id] = true
        elseif not state.positions[id] then
            local target
            if area then
                target = M.view_cell(state, area, config)
            else
                local anchor_id = active_id and state.positions[active_id] and active_id
                    or state.focused_id and state.positions[state.focused_id] and state.focused_id
                local anchor = anchor_id and state.positions[anchor_id]
                target = anchor and { col = anchor.col, row = anchor.row } or { col = 0, row = 0 }
            end
            state.split_anchor = state.split_anchor or {}
            state.split_anchor[id] = state.focused_id
            state.positions[id] = target
            assign_order(state, id)
            state.width_step_by_id[id] = config.default_width_step
            state.height_step_by_id[id] = config.default_height_step
            added[id] = true
        end
    end

    local focus_changed = false
    if active_id and present[active_id] then
        focus_changed = state.observed_active_id ~= active_id
        state.observed_active_id = active_id
        state.focused_id = active_id
    elseif not state.focused_id or not present[state.focused_id] then
        -- Het actieve venster is (even) weg, bijvoorbeeld omdat je het
        -- versleept: kies een ander, maar laat de camera staan.
        state.focused_id = unique_ids[1]
        state.observed_active_id = state.focused_id
        focus_changed = state.focused_id ~= nil and not area
    end

    if focus_changed and state.focused_id and state.positions[state.focused_id] then
        if dropped[state.focused_id] then
            state.pending_follow = false
        elseif added[state.focused_id] or not area then
            -- Een nieuw venster krijgt altijd beeld; zonder area (tests,
            -- oude aanroepen) volgt de camera zoals vroeger direct.
            M.follow(state)
        elseif not state.dragging then
            -- Focus via de muis: alleen meebewegen als het venster
            -- grotendeels buiten beeld staat (zie resolve_follow).
            state.pending_follow = true
        end
    end
end

-- Effectieve plek van een venster, met tegels als fracties binnen de cel.
local function effective(state, id)
    local p = state.positions[id]
    local list = members(state, p.col, p.row)
    local boxes = {}
    tree_placements(tile_tree(state, list, {x=0,y=0,w=1,h=0.8}, {gap_x=0,gap_y=0}),
        {x=0,y=0,w=1,h=0.8}, {gap_x=0,gap_y=0}, boxes)
    local box = boxes[id]
    return p.col + box.x + box.w / 2 - 0.5, p.row + (box.y + box.h / 2) / 0.8 - 0.5
end

local function directional_metrics(ox, oy, cx, cy, direction)
    local dc = cx - ox
    local dr = cy - oy

    if direction == "left" and dc >= -EPSILON then return nil end
    if direction == "right" and dc <= EPSILON then return nil end
    if direction == "up" and dr >= -EPSILON then return nil end
    if direction == "down" and dr <= EPSILON then return nil end

    local along = (direction == "left" or direction == "right") and math.abs(dc) or math.abs(dr)
    local across = (direction == "left" or direction == "right") and math.abs(dr) or math.abs(dc)

    return {
        aligned = across < 0.5 and 0 or 1,
        across = across,
        along = along,
        distance = math.abs(dc) + math.abs(dr),
    }
end

local function metrics_less(a, b)
    if a.aligned ~= b.aligned then return a.aligned < b.aligned end
    if math.abs(a.along - b.along) > EPSILON then return a.along < b.along end
    if math.abs(a.across - b.across) > EPSILON then return a.across < b.across end
    if math.abs(a.distance - b.distance) > EPSILON then return a.distance < b.distance end
    return tostring(a.id) < tostring(b.id)
end

function M.focus(state, direction)
    if not DIRECTIONS[direction] or not state.focused_id then
        return nil
    end

    if not state.positions[state.focused_id] then return nil end
    local ox, oy = effective(state, state.focused_id)

    local candidates = {}
    for id in pairs(state.positions) do
        if id ~= state.focused_id then
            local cx, cy = effective(state, id)
            local metrics = directional_metrics(ox, oy, cx, cy, direction)
            if metrics then
                metrics.id = id
                table.insert(candidates, metrics)
            end
        end
    end

    table.sort(candidates, metrics_less)
    local target = candidates[1]
    if not target then return nil end

    state.focused_id = target.id
    M.follow(state)
    return target.id
end

-- Naar de buurcel: een lege cel neemt het venster over, een bezette cel
-- krijgt het als extra Dwindle-tegel, zonder limiet per pagina.
function M.move(state, direction, config)
    local vector = DIRECTIONS[direction]
    local focused_id = state.focused_id
    local focused = focused_id and state.positions[focused_id]
    if not vector or not focused then return false end

    local destination_col = focused.col + vector.dc
    local destination_row = focused.row + vector.dr
    focused.col = destination_col
    focused.row = destination_row
    assign_order(state, focused_id)

    M.follow(state)
    return true
end

-- Kaart: sleep een venster naar een plek, op tegelplek slot (0 = eerste,
-- leeg = achteraan). Alleen een expliciete middendrop wisselt vlakken.
function M.place(state, id, col, row, config, slot)
    local position = state.positions[id]
    if not position or type(col) ~= "number" or type(row) ~= "number" then return false end
    col, row = math.floor(col + 0.5), math.floor(row + 0.5)
    if position.col == col and position.row == row and slot == nil then return false end
    insert_at(state, id, col, row, slot, config, { col = position.col, row = position.row })
    state.reorder_cells = state.reorder_cells or {}
    state.reorder_cells[position_key(col, row)] = true
    return true
end

-- Midden: de volledige vlakken ruilen. Rand: alleen dat vlak splitsen.
-- De rest van de boom en de camera blijven precies staan.
function M.tile_place(state, id, target, edge, area, config)
    local source, dest = state.positions[id], state.positions[target]
    if not source or not dest or id == target then return false end
    if edge ~= "center" and not DIRECTIONS[edge] then return false end
    M.placements(state, area, config)
    local skey, dkey = position_key(source.col, source.row), position_key(dest.col, dest.row)
    if edge == "center" then
        if skey == dkey then
            local marker = {}
            replace_leaf(state.cell_trees[skey], id, marker)
            replace_leaf(state.cell_trees[skey], target, id)
            replace_leaf(state.cell_trees[skey], marker, target)
        else
            replace_leaf(state.cell_trees[skey], id, target)
            replace_leaf(state.cell_trees[dkey], target, id)
        end
        state.positions[id], state.positions[target] = {col=dest.col,row=dest.row}, {col=source.col,row=source.row}
        state.order[id], state.order[target] = state.order[target], state.order[id]
    else
        local present = {}
        for other in pairs(state.positions) do if other ~= id then present[other] = true end end
        state.cell_trees[skey] = prune_tree(state.cell_trees[skey], present)
        local list = members(state, dest.col, dest.row, id)
        local before = edge == "left" or edge == "up"
        local slot = #list
        for i, other in ipairs(list) do if other == target then slot = i - (before and 1 or 0); break end end
        insert_at(state, id, dest.col, dest.row, slot, config)
        local function insert(node)
            if node.id == target then
                node.id, node.axis, node.ratio = nil, (edge == "left" or edge == "right") and "x" or "y", 0.5
                node.a, node.b = {id=before and id or target}, {id=before and target or id}
            elseif not node.id then insert(node.a); insert(node.b) end
        end
        insert(state.cell_trees[dkey])
    end
    if state.reorder_cells then state.reorder_cells[skey], state.reorder_cells[dkey] = nil, nil end
    state.pending_follow = false
    return true
end

function M.drop_edge(box, x, y)
    local fx, fy = (x-box.x)/math.max(1,box.w), (y-box.y)/math.max(1,box.h)
    local edge, distance = "center", 0.25
    for _, candidate in ipairs({{"left",fx},{"right",1-fx},{"up",fy},{"down",1-fy}}) do
        if candidate[2] < distance then edge, distance = candidate[1], candidate[2] end
    end
    return edge
end

function M.pan(state, direction)
    local vector = DIRECTIONS[direction]
    if not vector then return false end
    local min_col, max_col, min_row, max_row = bounds(state)
    if not min_col then return false end
    state.camera.offset_x, state.camera.offset_y = 0, 0
    state.camera.col = state.camera.col + vector.dc
    state.camera.row = state.camera.row + vector.dr
    state.pending_follow = false
    return true
end

-- Kingstra: both deltas are applied together, without locking to an axis.
function M.pan_by(state, dx, dy, area, config)
    if #state.ids < 1 then return false end
    if type(dx) ~= "number" or type(dy) ~= "number"
        or dx ~= dx or dy ~= dy or math.abs(dx) == math.huge or math.abs(dy) == math.huge then
        return false
    end
    local min_col, max_col, min_row, max_row = bounds(state)
    local metrics = cell_metrics(area, config, state)
    -- Hooguit anderhalve cel voorbij de buitenste vensters.
    local low_x = math.min(-1.5, min_col - 1.5 - state.camera.col) * metrics.pitch_x
    local high_x = math.max(1.5, max_col + 1.5 - state.camera.col) * metrics.pitch_x
    local low_y = math.min(-1.5, min_row - 1.5 - state.camera.row) * metrics.pitch_y
    local high_y = math.max(1.5, max_row + 1.5 - state.camera.row) * metrics.pitch_y
    state.camera.offset_x = clamp((state.camera.offset_x or 0) + dx, low_x, high_x)
    state.camera.offset_y = clamp((state.camera.offset_y or 0) + dy, low_y, high_y)
    state.pending_follow = false
    return true
end

-- Na vrij slepen: de camera rekent zich om naar de dichtstbijzijnde cel en
-- klikt daar alleen op vast als de rest kleiner is dan config.snap.
function M.settle(state, area, config)
    local metrics = cell_metrics(area, config, state)
    local snap = clamp(config.snap or 0.2, 0, 0.5)
    local function axis(offset, pitch)
        local cells = round(offset / pitch)
        local rest = offset - cells * pitch
        if math.abs(rest) < snap * pitch then rest = 0 end
        return cells, rest
    end
    local dc, rest_x = axis(state.camera.offset_x or 0, metrics.pitch_x)
    local dr, rest_y = axis(state.camera.offset_y or 0, metrics.pitch_y)
    state.camera.col = state.camera.col + dc
    state.camera.row = state.camera.row + dr
    state.camera.offset_x, state.camera.offset_y = rest_x, rest_y
    state.dragging = false
    state.pending_follow = false
    return true
end

local function resize_step(state, map, steps, delta)
    local id = state.focused_id
    if not id or not state.positions[id] then return false end
    local current = map[id] or #steps
    local next_step = clamp(current + delta, 1, #steps)
    map[id] = next_step
    return next_step ~= current
end

-- Het pad naar een tegel bevat de splits die je met de muis kunt verzetten.
local function split_path(state, area, config, id)
    id = id or state.focused_id
    local p = state.positions[id]
    if not p then return {} end
    local boxes = M.placements(state, area, config)
    local tree = state.cell_trees[position_key(p.col, p.row)]
    local box
    for _, other in ipairs(members(state, p.col, p.row)) do
        local b = boxes[other]
        if not box then box = {x=b.x,y=b.y,w=b.w,h=b.h}
        else
            local right, bottom = math.max(box.x+box.w,b.x+b.w), math.max(box.y+box.h,b.y+b.h)
            box.x, box.y = math.min(box.x,b.x), math.min(box.y,b.y)
            box.w, box.h = right-box.x, bottom-box.y
        end
    end
    local path = {}
    while tree and not tree.id do
        local side = tree_has(tree.a, id) and "a" or "b"
        path[#path+1] = {node=tree,box=box,side=side}
        local a, b = split_box(tree, box, config)
        box, tree = side == "a" and a or b, tree[side]
    end
    return path
end

function M.resize_by(state, dx, dy, area, config, id)
    local path, changed = split_path(state, area, config, id), false
    for _, axis in ipairs({"x", "y"}) do
        local delta = axis == "x" and dx or dy
        for i = #path, 1, -1 do
            local entry = path[i]
            if entry.node.axis == axis and delta ~= 0 then
                local length = axis == "x" and entry.box.w or entry.box.h
                entry.node.ratio = clamp(entry.node.ratio + delta / math.max(1, length), 0.15, 0.85)
                changed = true
                break
            end
        end
    end
    return changed
end

function M.toggle_split(state, area, config)
    local path = split_path(state, area, config)
    local entry = path[#path]
    if not entry then return false end
    entry.node.axis = entry.node.axis == "x" and "y" or "x"
    return true
end

local function resize_tiled_step(state, config, delta, area, axis)
    if not area then return false end
    local path = split_path(state, area, config)
    for i = #path, 1, -1 do
        local entry = path[i]
        if entry.node.axis == axis then
            entry.node.ratio = clamp(entry.node.ratio + delta * 0.05 * (entry.side == "a" and 1 or -1), 0.15, 0.85)
            return true
        end
    end
    return false
end

function M.resize_width(state, config, delta, area)
    if resize_tiled_step(state, config, delta, area, "x") then return true end
    return resize_step(state, state.width_step_by_id, config.width_steps, delta)
end

function M.resize_height(state, config, delta, area)
    if resize_tiled_step(state, config, delta, area, "y") then return true end
    return resize_step(state, state.height_step_by_id, config.height_steps, delta)
end

function M.placements(state, area, config)
    local metrics = cell_metrics(area, config, state)
    local maximum_width = metrics.maximum_width
    local maximum_height = metrics.maximum_height
    local gap_x = math.max(0, config.gap_x or 0)
    local gap_y = math.max(0, config.gap_y or 0)
    local center_x = area.x + (area.w / 2)
    local center_y = area.y + (area.h / 2)
    local placements = {}
    local cells = {}
    local cell_list = {}
    local column_widths = {}
    local row_heights = {}
    local min_col, max_col = state.camera.col, state.camera.col
    local min_row, max_row = state.camera.row, state.camera.row

    for id, position in pairs(state.positions) do
        local key = position_key(position.col, position.row)
        local cell = cells[key]
        if not cell then
            cell = { col = position.col, row = position.row, w = 0, h = 0 }
            cells[key] = cell
            table.insert(cell_list, cell)
        end
        local width_step = clamp(state.width_step_by_id[id] or config.default_width_step, 1, #config.width_steps)
        local height_step = clamp(state.height_step_by_id[id] or config.default_height_step, 1, #config.height_steps)
        cell.w = math.max(cell.w, maximum_width * config.width_steps[width_step])
        cell.h = math.max(cell.h, maximum_height * config.height_steps[height_step])
        min_col = math.min(min_col, position.col)
        max_col = math.max(max_col, position.col)
        min_row = math.min(min_row, position.row)
        max_row = math.max(max_row, position.row)
    end

    for _, cell in ipairs(cell_list) do
        column_widths[cell.col] = math.max(column_widths[cell.col] or 0, cell.w)
        row_heights[cell.row] = math.max(row_heights[cell.row] or 0, cell.h)
    end

    local default_width = maximum_width * config.width_steps[config.default_width_step]
    local default_height = maximum_height * config.height_steps[config.default_height_step]
    for col = min_col, max_col do
        column_widths[col] = column_widths[col] or default_width
    end
    for row = min_row, max_row do
        row_heights[row] = row_heights[row] or default_height
    end

    local column_centers = { [state.camera.col] = center_x }
    for col = state.camera.col + 1, max_col do
        column_centers[col] = column_centers[col - 1]
            + (column_widths[col - 1] / 2) + gap_x + (column_widths[col] / 2)
    end
    for col = state.camera.col - 1, min_col, -1 do
        column_centers[col] = column_centers[col + 1]
            - (column_widths[col + 1] / 2) - gap_x - (column_widths[col] / 2)
    end

    local row_centers = { [state.camera.row] = center_y }
    for row = state.camera.row + 1, max_row do
        row_centers[row] = row_centers[row - 1]
            + (row_heights[row - 1] / 2) + gap_y + (row_heights[row] / 2)
    end
    for row = state.camera.row - 1, min_row, -1 do
        row_centers[row] = row_centers[row + 1]
            - (row_heights[row + 1] / 2) - gap_y - (row_heights[row] / 2)
    end

    for _, cell in ipairs(cell_list) do
        local box = {
            x = column_centers[cell.col] - cell.w / 2 - (state.camera.offset_x or 0),
            y = row_centers[cell.row] - cell.h / 2 - (state.camera.offset_y or 0),
            w = cell.w, h = cell.h,
        }
        local list = members(state, cell.col, cell.row)
        tree_placements(tile_tree(state, list, box, config), box, config, placements)
    end

    return placements
end

-- Plek en tegelplek onder een schermpunt, alsof venster id (dat nu niet
-- meetelt) erbij komt. Nil als het punt buiten het werkvlak valt.
function M.spot_at(state, area, config, x, y, id, allow_outside)
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    if not allow_outside and (x < area.x or y < area.y or x > area.x + area.w or y > area.y + area.h) then return nil end
    local placements = M.placements(state, area, config)
    local boxes = {}
    for other, box in pairs(placements) do
        if other ~= id then
            local p = state.positions[other]
            local key = position_key(p.col, p.row)
            local cell = boxes[key]
            if not cell then
                boxes[key] = { col = p.col, row = p.row, x1 = box.x, y1 = box.y, x2 = box.x + box.w, y2 = box.y + box.h }
            else
                cell.x1, cell.y1 = math.min(cell.x1, box.x), math.min(cell.y1, box.y)
                cell.x2, cell.y2 = math.max(cell.x2, box.x + box.w), math.max(cell.y2, box.y + box.h)
            end
        end
    end
    local hit
    for _, cell in pairs(boxes) do
        if x >= cell.x1 and x <= cell.x2 and y >= cell.y1 and y <= cell.y2 then hit = cell end
    end
    if not hit then
        local metrics = cell_metrics(area, config, state)
        local col = state.camera.col + round((x - (area.x + area.w / 2) + (state.camera.offset_x or 0)) / metrics.pitch_x)
        local row = state.camera.row + round((y - (area.y + area.h / 2) + (state.camera.offset_y or 0)) / metrics.pitch_y)
        return { col = col, row = row, slot = 0 }
    end
    local list = members(state, hit.col, hit.row, id)
    local slot, target, edge = #list, nil, nil
    for index, other in ipairs(list) do
        local box = placements[other]
        if box and x >= box.x and x <= box.x + box.w and y >= box.y and y <= box.y + box.h then
            local after = hit.x2 - hit.x1 >= hit.y2 - hit.y1 and x >= box.x + box.w / 2
                or hit.x2 - hit.x1 < hit.y2 - hit.y1 and y >= box.y + box.h / 2
            slot = index - (after and 0 or 1)
            target, edge = other, M.drop_edge(box, x, y)
            break
        end
    end
    return { col = hit.col, row = hit.row, slot = clamp(slot, 0, #list), target=target, edge=edge }
end

-- Deel van een venster dat binnen het werkvlak valt (0..1).
function M.visible_fraction(box, area)
    if not box or box.w <= 0 or box.h <= 0 then return 0 end
    local w = math.max(0, math.min(box.x + box.w, area.x + area.w) - math.max(box.x, area.x))
    local h = math.max(0, math.min(box.y + box.h, area.y + area.h) - math.max(box.y, area.y))
    return (w * h) / (box.w * box.h)
end

-- Voert een uitgestelde focus-volging uit: alleen als het gefocuste venster
-- grotendeels buiten beeld staat. Zo springt de camera niet weg als de muis
-- over een buurvenster beweegt.
function M.resolve_follow(state, area, config)
    if state.dragging then
        state.pending_follow = false
        return false
    end
    if not state.pending_follow then return false end
    state.pending_follow = false
    local placements = M.placements(state, area, config)
    local box = state.focused_id and placements[state.focused_id]
    if box and M.visible_fraction(box, area) <= (config.follow_min_visible or 0) then
        return M.follow(state)
    end
    return false
end

function M.position_of(state, id)
    return state.positions[id]
end

function M.size_steps_of(state, id)
    return state.width_step_by_id[id], state.height_step_by_id[id]
end

function M.has_id(state, id)
    return contains(state.ids, id)
end

return M
