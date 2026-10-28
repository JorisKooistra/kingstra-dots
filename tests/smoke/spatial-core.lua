local core = assert(loadfile("config/hypr/lua/spatial/core.lua"))()
local config = assert(loadfile("config/hypr/lua/spatial/config.lua"))()
local passed = 0

local function test(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        io.stderr:write("FAIL: " .. name .. "\n" .. tostring(err) .. "\n")
        os.exit(1)
    end
    passed = passed + 1
    print("ok - " .. name)
end

local function equal(actual, expected, label)
    if actual ~= expected then
        error((label or "value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

local function fresh(ids, active)
    local state = core.new_state()
    core.sync(state, ids, active, config)
    return state
end

local AREA = { x = 0, y = 0, w = 1000, h = 800 }

-- Zet B via een zet omlaag in een eigen cel onder A.
local function two_rows()
    local state = fresh({ "A", "B" }, "B")
    assert(core.move(state, "down", config))
    return state
end

test("first window starts at origin", function()
    local state = fresh({ "A" }, "A")
    equal(core.position_of(state, "A").col, 0)
    equal(core.position_of(state, "A").row, 0)
end)

test("new windows tile into the viewed cell until it is full", function()
    local state = fresh({ "A", "B", "C", "D" }, "A")
    for _, id in ipairs({ "B", "C", "D" }) do
        equal(core.position_of(state, id).col, 0, id .. " col")
        equal(core.position_of(state, id).row, 0, id .. " row")
    end
    core.sync(state, { "A", "B", "C", "D", "E" }, "A", config)
    equal(core.position_of(state, "E").col, 1, "fifth window moves right")
end)

test("a new window opens on the empty spot the camera looks at", function()
    local state = fresh({ "A" }, "A")
    core.sync(state, { "A" }, "A", config, AREA)
    assert(core.pan(state, "up"))
    core.sync(state, { "A", "B" }, "B", config, AREA)
    equal(core.position_of(state, "B").col, 0)
    equal(core.position_of(state, "B").row, -1)
    equal(state.camera.row, -1, "camera stays on the new window")
end)

test("a new window lands where free dragging stopped", function()
    local state = fresh({ "A" }, "A")
    core.sync(state, { "A" }, "A", config, AREA)
    assert(core.pan_by(state, 990, 0, AREA, config))
    core.settle(state, AREA, config)
    core.sync(state, { "A", "B" }, "B", config, AREA)
    equal(core.position_of(state, "B").col, 1)
    equal(core.position_of(state, "B").row, 0)
end)

test("moving down creates a second row", function()
    local state = two_rows()
    equal(core.position_of(state, "B").col, 0)
    equal(core.position_of(state, "B").row, 1)
    equal(state.camera.row, 1)
end)

test("moving into an occupied cell adds a tile", function()
    local state = two_rows()
    assert(core.move(state, "up", config))
    equal(core.position_of(state, "B").row, 0)
    equal(core.position_of(state, "A").row, 0)
    local placements = core.placements(state, AREA, config)
    assert(placements.A.x < placements.B.x, "tiles sit side by side")
end)

test("moving into a full cell swaps with its last tile", function()
    local state = fresh({ "A", "B", "C", "D" }, "D")
    core.move(state, "right", config)
    state.focused_id = "D"
    core.sync(state, { "A", "B", "C", "D", "E" }, "E", config)
    state.focused_id = "D"
    -- D zit rechts, E erbij; terug naar links: die cel (A,B,C + ?) is vol?
    core.sync(state, { "A", "B", "C", "D", "E", "F" }, "A", config)
    equal(#core.members(state, 0, 0), 4)
    state.focused_id = "D"
    local before = #core.members(state, 1, 0)
    assert(core.move(state, "left", config))
    equal(#core.members(state, 0, 0), 4, "full cell stays full")
    equal(#core.members(state, 1, 0), before, "one tile came back in return")
end)

test("focus walks through tiles before leaving the cell", function()
    local state = fresh({ "A", "B" }, "A")
    equal(core.focus(state, "right"), "B")
    equal(core.focus(state, "left"), "A")
end)

test("focus moves vertically between cells", function()
    local state = two_rows()
    state.focused_id = "A"
    core.follow(state)
    equal(core.focus(state, "down"), "B")
end)

test("width and height presets are independent", function()
    local state = fresh({ "A" }, "A")
    core.resize_width(state, config, 1)
    core.resize_height(state, config, -1)
    local width_step, height_step = core.size_steps_of(state, "A")
    equal(width_step, math.min(config.default_width_step + 1, #config.width_steps))
    equal(height_step, config.default_height_step - 1)
end)

test("resize clamps at preset boundaries", function()
    local state = fresh({ "A" }, "A")
    for _ = 1, 10 do core.resize_width(state, config, -1) end
    local width_step = core.size_steps_of(state, "A")
    equal(width_step, 1)
    for _ = 1, 10 do core.resize_width(state, config, 1) end
    width_step = core.size_steps_of(state, "A")
    equal(width_step, #config.width_steps)
end)

test("with two cells the focused cell leaves peeks", function()
    local state = two_rows()
    state.focused_id = "A"
    core.follow(state)
    local placements = core.placements(state, AREA, config)
    equal(placements.A.x, config.peek_x)
    equal(placements.A.y, config.peek_y)
    equal(placements.A.w, 1000 - 2 * config.peek_x)
    equal(placements.A.h, 800 - 2 * config.peek_y)
    equal(placements.B.y, 800 - config.peek_y + config.gap_y)
end)

test("one occupied cell fills the work area with tiles", function()
    local state = fresh({ "A", "B" }, "A")
    local placements = core.placements(state, AREA, config)
    equal(placements.A.x, 0)
    equal(placements.A.y, 0)
    equal(placements.A.h, 800)
    equal(placements.B.x + placements.B.w, 1000)
    equal(placements.A.w, (1000 - config.gap_x) / 2)
end)

test("camera follows focus in both dimensions", function()
    local state = two_rows()
    equal(state.camera.col, 0)
    equal(state.camera.row, 1)
end)

test("a lone window can still be panned", function()
    local state = fresh({ "A" }, "A")
    assert(core.pan(state, "right"))
    equal(state.camera.col, 1)
    assert(core.pan_by(state, 30, 40, AREA, config))
end)

test("manual camera pan survives ordinary synchronization", function()
    local state = fresh({ "A", "B" }, "A")
    core.pan(state, "down")
    core.sync(state, { "A", "B" }, "A", config)
    equal(state.camera.row, 1)
end)

test("closed windows are removed without disturbing survivors", function()
    local state = fresh({ "A", "B", "C", "D", "E" }, "B")
    local original = core.position_of(state, "E").col
    core.sync(state, { "A", "C", "D", "E" }, "E", config)
    assert(not core.has_id(state, "B"))
    equal(core.position_of(state, "E").col, original)
end)

test("diagonal pan changes both axes in one operation", function()
    local state = two_rows()
    local before = core.placements(state, AREA, config)
    assert(core.pan_by(state, 125, -70, AREA, config))
    local after = core.placements(state, AREA, config)
    equal(after.A.x, before.A.x - 125)
    equal(after.A.y, before.A.y + 70)
    core.sync(state, { "A", "B" }, "B", config)
    equal(state.camera.offset_x, 125)
    equal(state.camera.offset_y, -70)
    core.focus(state, "up")
    equal(state.camera.offset_x, 0)
    equal(state.camera.offset_y, 0)
end)

test("settle snaps only when close to a cell", function()
    local state = fresh({ "A" }, "A")
    core.pan_by(state, 40, 0, AREA, config)
    core.settle(state, AREA, config)
    equal(state.camera.offset_x, 0, "small drag snaps back")
    equal(state.camera.col, 0)
    core.pan_by(state, 400, 0, AREA, config)
    core.settle(state, AREA, config)
    equal(state.camera.col, 0)
    equal(state.camera.offset_x, 400, "a real drag keeps its free position")
    core.pan_by(state, 500, 0, AREA, config)
    core.settle(state, AREA, config)
    equal(state.camera.col, 1, "past halfway counts as the next cell")
end)

test("mouse focus does not move a visible window's camera", function()
    local state = two_rows()
    core.sync(state, { "A", "B" }, "B", config, AREA)
    core.pan_by(state, 0, -400, AREA, config)
    core.sync(state, { "A", "B" }, "A", config, AREA)
    assert(not core.resolve_follow(state, AREA, config), "A is half in view, camera stays")
    equal(state.camera.offset_y, -400)
end)

test("mouse focus on a window out of view follows it", function()
    local state = two_rows()
    core.sync(state, { "A", "B" }, "B", config, AREA)
    core.sync(state, { "A", "B" }, "A", config, AREA)
    assert(core.resolve_follow(state, AREA, config))
    equal(state.camera.row, 0)
end)

test("no follow while dragging", function()
    local state = two_rows()
    core.sync(state, { "A", "B" }, "B", config, AREA)
    state.dragging = true
    core.sync(state, { "A", "B" }, "A", config, AREA)
    assert(not core.resolve_follow(state, AREA, config))
    equal(state.camera.row, 1)
end)

test("a lone window fills a scaled work area", function()
    local state = fresh({ "A" }, "A")
    local area = { x = 50, y = 32, w = 1280, h = 688 }
    local box = core.placements(state, area, config).A
    equal(box.x, 50)
    equal(box.y, 32)
    equal(box.w, 1280)
    equal(box.h, 688)
end)

test("empty panning and nonfinite input are ignored", function()
    assert(not core.pan_by(fresh({}, nil), 10, 10, AREA, config))
    assert(not core.pan_by(fresh({ "A", "B" }, "A"), math.huge, 0, AREA, config))
    assert(not core.pan(fresh({}, nil), "left"))
end)

test("keyboard pan stays near occupied cells", function()
    local state = two_rows()
    for _ = 1, 100 do core.pan(state, "down"); core.pan(state, "left") end
    equal(state.camera.row, 2)
    equal(state.camera.col, -1)
end)

print(string.format("Kingstra spatial: %d tests passed", passed))
