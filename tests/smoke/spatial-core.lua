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

test("first window starts at origin", function()
    local state = fresh({ "A" }, "A")
    equal(core.position_of(state, "A").col, 0)
    equal(core.position_of(state, "A").row, 0)
end)

test("new windows extend to the right", function()
    local state = fresh({ "A", "B", "C" }, "A")
    equal(core.position_of(state, "B").col, 1)
    equal(core.position_of(state, "C").col, 2)
end)

test("moving down creates a second row", function()
    local state = fresh({ "A", "B" }, "B")
    assert(core.move(state, "down"))
    equal(core.position_of(state, "B").col, 1)
    equal(core.position_of(state, "B").row, 1)
    equal(state.camera.row, 1)
end)

test("moving into an occupied cell swaps windows", function()
    local state = fresh({ "A", "B" }, "B")
    assert(core.move(state, "left"))
    equal(core.position_of(state, "B").col, 0)
    equal(core.position_of(state, "A").col, 1)
end)

test("focus prefers a window aligned on the requested axis", function()
    local state = fresh({ "A", "B", "C" }, "A")
    core.move(state, "down")
    state.focused_id = "A"
    core.follow(state)
    equal(core.focus(state, "right"), "B")
end)

test("focus moves vertically", function()
    local state = fresh({ "A", "B" }, "B")
    core.move(state, "down")
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

test("maximum cell leaves horizontal and vertical peeks", function()
    local state = fresh({ "A", "B" }, "A")
    state.width_step_by_id.A = #config.width_steps
    state.height_step_by_id.A = #config.height_steps
    state.width_step_by_id.B = #config.width_steps
    state.height_step_by_id.B = #config.height_steps
    state.focused_id = "B"
    core.move(state, "down")
    state.focused_id = "A"
    core.follow(state)
    local placements = core.placements(state, { x = 0, y = 0, w = 1000, h = 800 }, config)
    equal(placements.A.x, config.peek_x)
    equal(placements.A.y, config.peek_y)
    equal(placements.A.w, 1000 - 2 * config.peek_x)
    equal(placements.A.h, 800 - 2 * config.peek_y)
    equal(placements.B.y, 800 - config.peek_y + config.gap_y)
end)

test("smaller presets keep neighboring rows visible", function()
    local state = fresh({ "A", "B" }, "A")
    state.focused_id = "B"
    core.move(state, "down")
    state.focused_id = "A"
    core.follow(state)
    local placements = core.placements(state, { x = 0, y = 0, w = 1000, h = 800 }, config)
    assert(placements.B.y < 800, "the next row should peek into the viewport")
    assert(placements.B.y > placements.A.y, "the next row should remain below the focused row")
end)

test("camera follows focus in both dimensions", function()
    local state = fresh({ "A", "B" }, "B")
    core.move(state, "down")
    equal(state.camera.col, 1)
    equal(state.camera.row, 1)
end)

test("manual camera pan survives ordinary synchronization", function()
    local state = fresh({ "A", "B" }, "A")
    core.pan(state, "down")
    core.sync(state, { "A", "B" }, "A", config)
    equal(state.camera.row, 1)
end)

test("closed windows are removed without disturbing survivors", function()
    local state = fresh({ "A", "B", "C" }, "B")
    local original = core.position_of(state, "C").col
    core.sync(state, { "A", "C" }, "C", config)
    assert(not core.has_id(state, "B"))
    equal(core.position_of(state, "C").col, original)
end)


test("diagonal pan changes both axes in one operation", function()
    local state = fresh({ "A", "B" }, "A")
    local area = { x = 0, y = 0, w = 1000, h = 800 }
    local before = core.placements(state, area, config)
    assert(core.pan_by(state, 125, -70, area, config))
    local after = core.placements(state, area, config)
    equal(after.A.x, before.A.x - 125)
    equal(after.A.y, before.A.y + 70)
    core.sync(state, { "A", "B" }, "A", config)
    equal(state.camera.offset_x, 125)
    equal(state.camera.offset_y, -70)
    core.focus(state, "right")
    equal(state.camera.offset_x, 0)
    equal(state.camera.offset_y, 0)
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
    local area = { x = 0, y = 0, w = 1000, h = 800 }
    assert(not core.pan_by(fresh({}, nil), 10, 10, area, config))
    assert(not core.pan_by(fresh({ "A", "B" }, "A"), math.huge, 0, area, config))
end)

test("keyboard pan stays near occupied cells", function()
    local state = fresh({ "A", "B" }, "A")
    for _ = 1, 100 do core.pan(state, "down"); core.pan(state, "left") end
    equal(state.camera.row, 1)
    equal(state.camera.col, -1)
end)

print(string.format("Kingstra spatial: %d tests passed", passed))
