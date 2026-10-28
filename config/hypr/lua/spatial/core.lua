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

local function max_per_cell(config)
    return math.max(1, math.floor((config and config.max_per_cell) or 4))
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

-- Tegelraster binnen een cel: naast elkaar tot drie, daarna twee rijen.
local function grid_for(count)
    if count <= 3 then return math.max(count, 1), 1 end
    return math.ceil(count / 2), 2
end

local function find_open_right(state, anchor, config)
    local col = anchor.col + 1
    while #members(state, col, anchor.row) >= max_per_cell(config) do
        col = col + 1
    end
    return { col = col, row = anchor.row }
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

local function cell_metrics(area, config)
    local peek_x = clamp(config.peek_x or 0, 0, math.max(0, (area.w - 1) / 2))
    local peek_y = clamp(config.peek_y or 0, 0, math.max(0, (area.h - 1) / 2))
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
        local metrics = cell_metrics(area, config)
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
-- Is de cel vol, dan schuift de tegel op die plek naar spare (de oude plek
-- van het venster), zodat er nooit meer dan max_per_cell in een cel staan.
local function insert_at(state, id, col, row, slot, config, spare)
    local list = members(state, col, row, id)
    if #list >= max_per_cell(config) then
        local index = clamp(math.floor(slot or #list) + 1, 1, #list)
        local other = table.remove(list, index)
        local target = spare or find_open_right(state, { col = col, row = row }, config)
        state.positions[other] = { col = target.col, row = target.row }
        assign_order(state, other)
    end
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
            departed[id] = { state = state, col = position.col, row = position.row }
            state.positions[id] = nil
            state.order[id] = nil
            state.width_step_by_id[id] = nil
            state.height_step_by_id[id] = nil
        end
    end

    state.ids = unique_ids

    local added, dropped = {}, {}
    for _, id in ipairs(unique_ids) do
        local returning = not state.positions[id] and departed[id]
        if returning then departed[id] = nil end
        if returning and returning.state ~= state then returning = nil end
        if returning then
            -- Terug na slepen of zwevend: waar je het loslaat, anders op de
            -- oude plek. De camera blijft staan.
            local spot = drop and area and M.spot_at(state, area, config, drop.x, drop.y, id)
            if spot then
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
            if #members(state, target.col, target.row) >= max_per_cell(config) then
                target = find_open_right(state, target, config)
            end
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
    local cols, rows = grid_for(#list)
    local index = 0
    for i, other in ipairs(list) do
        if other == id then index = i - 1 end
    end
    local slot_col = index % cols
    local slot_row = math.floor(index / cols)
    return p.col + (slot_col + 0.5) / cols - 0.5, p.row + (slot_row + 0.5) / rows - 0.5
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
-- krijgt het als extra tegel. Is die cel vol, dan wisselen de vensters.
function M.move(state, direction, config)
    local vector = DIRECTIONS[direction]
    local focused_id = state.focused_id
    local focused = focused_id and state.positions[focused_id]
    if not vector or not focused then return false end

    local destination_col = focused.col + vector.dc
    local destination_row = focused.row + vector.dr
    local residents = members(state, destination_col, destination_row, focused_id)

    if #residents >= max_per_cell(config) then
        local other = state.positions[residents[#residents]]
        other.col, other.row = focused.col, focused.row
    end
    focused.col = destination_col
    focused.row = destination_row
    assign_order(state, focused_id)

    M.follow(state)
    return true
end

-- Kaart: sleep een venster naar een plek, op tegelplek slot (0 = eerste,
-- leeg = achteraan). Een volle plek stuurt de tegel op die plek naar de
-- oude plek van het venster.
function M.place(state, id, col, row, config, slot)
    local position = state.positions[id]
    if not position or type(col) ~= "number" or type(row) ~= "number" then return false end
    col, row = math.floor(col + 0.5), math.floor(row + 0.5)
    if position.col == col and position.row == row and slot == nil then return false end
    insert_at(state, id, col, row, slot, config, { col = position.col, row = position.row })
    return true
end

function M.pan(state, direction)
    local vector = DIRECTIONS[direction]
    if not vector then return false end
    local min_col, max_col, min_row, max_row = bounds(state)
    if not min_col then return false end
    state.camera.offset_x, state.camera.offset_y = 0, 0
    state.camera.col = clamp(state.camera.col + vector.dc, min_col - 1, max_col + 1)
    state.camera.row = clamp(state.camera.row + vector.dr, min_row - 1, max_row + 1)
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
    local metrics = cell_metrics(area, config)
    -- Hooguit anderhalve cel voorbij de buitenste vensters.
    local low_x = (min_col - 1.5 - state.camera.col) * metrics.pitch_x
    local high_x = (max_col + 1.5 - state.camera.col) * metrics.pitch_x
    local low_y = (min_row - 1.5 - state.camera.row) * metrics.pitch_y
    local high_y = (max_row + 1.5 - state.camera.row) * metrics.pitch_y
    state.camera.offset_x = clamp((state.camera.offset_x or 0) + dx, low_x, high_x)
    state.camera.offset_y = clamp((state.camera.offset_y or 0) + dy, low_y, high_y)
    state.pending_follow = false
    return true
end

-- Na vrij slepen: de camera rekent zich om naar de dichtstbijzijnde cel en
-- klikt daar alleen op vast als de rest kleiner is dan config.snap.
function M.settle(state, area, config)
    local metrics = cell_metrics(area, config)
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

function M.resize_width(state, config, delta)
    return resize_step(state, state.width_step_by_id, config.width_steps, delta)
end

function M.resize_height(state, config, delta)
    return resize_step(state, state.height_step_by_id, config.height_steps, delta)
end

function M.placements(state, area, config)
    local metrics = cell_metrics(area, config)
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

    -- Eén bezette cel, recht in beeld: die cel vult het hele werkvlak,
    -- net als gewone tegels.
    local fill = config.fill_single and #cell_list == 1
        and cell_list[1].col == state.camera.col and cell_list[1].row == state.camera.row
        and math.abs(state.camera.offset_x or 0) < 0.5 and math.abs(state.camera.offset_y or 0) < 0.5

    for _, cell in ipairs(cell_list) do
        local box
        if fill then
            box = { x = area.x, y = area.y, w = area.w, h = area.h }
        else
            box = {
                x = column_centers[cell.col] - (cell.w / 2) - (state.camera.offset_x or 0),
                y = row_centers[cell.row] - (cell.h / 2) - (state.camera.offset_y or 0),
                w = cell.w,
                h = cell.h,
            }
        end
        local list = members(state, cell.col, cell.row)
        local cols, rows = grid_for(#list)
        for index, id in ipairs(list) do
            local slot_col = (index - 1) % cols
            local slot_row = math.floor((index - 1) / cols)
            -- Een onvolle laatste rij rekt de tegels op over de hele breedte.
            local in_row = math.min(cols, #list - slot_row * cols)
            local row_w = (box.w - gap_x * (in_row - 1)) / in_row
            local tile_h = (box.h - gap_y * (rows - 1)) / rows
            placements[id] = {
                x = box.x + slot_col * (row_w + gap_x),
                y = box.y + slot_row * (tile_h + gap_y),
                w = row_w,
                h = tile_h,
            }
        end
    end

    return placements
end

-- Plek en tegelplek onder een schermpunt, alsof venster id (dat nu niet
-- meetelt) erbij komt. Nil als het punt buiten het werkvlak valt.
function M.spot_at(state, area, config, x, y, id)
    if type(x) ~= "number" or type(y) ~= "number" then return nil end
    if x < area.x or y < area.y or x > area.x + area.w or y > area.y + area.h then return nil end
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
        local metrics = cell_metrics(area, config)
        local col = state.camera.col + round((x - (area.x + area.w / 2) + (state.camera.offset_x or 0)) / metrics.pitch_x)
        local row = state.camera.row + round((y - (area.y + area.h / 2) + (state.camera.offset_y or 0)) / metrics.pitch_y)
        return { col = col, row = row, slot = 0 }
    end
    local count = #members(state, hit.col, hit.row, id)
    local cols, rows = grid_for(math.min(count + 1, max_per_cell(config)))
    local fx = clamp((x - hit.x1) / math.max(1, hit.x2 - hit.x1), 0, 0.999)
    local fy = clamp((y - hit.y1) / math.max(1, hit.y2 - hit.y1), 0, 0.999)
    local slot = math.floor(fy * rows) * cols + math.floor(fx * cols)
    return { col = hit.col, row = hit.row, slot = clamp(slot, 0, count) }
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
    if box and M.visible_fraction(box, area) < (config.follow_min_visible or 0.4) then
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
