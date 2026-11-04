-- Versie 2 (2026-11-04). Versie 1 legde via M.watch een tweede bind op elke
-- Super-toets; Hyprland verving daarmee de echte bind en Super+Q deed niets
-- meer. Deze versie legt GEEN binds op bestaande toetsen. Alleen Super_L en
-- Super_R zelf krijgen een non_consuming bind (die hebben verder geen functie).
-- "Bezig" komt nu uit: muisbeweging, Super+wiel/slepen (binds.lua wikkelt
-- alleen die Lua-handlers in M.wrap) en wissel van venster of werkruimte.
-- Spiekbriefje: Super een moment vasthouden (zonder andere toets of klik)
-- toont de belangrijkste sneltoetsen; loslaten verbergt ze weer.
--
-- Zo blijft het betrouwbaar:
-- * binds.lua meldt elke Super-combinatie hier via M.watch(); zo'n
--   combinatie (ook Super+slepen, Super+klik en Super+wiel) breekt het
--   wachten af en verbergt een open briefje.
-- * Beweegt de muis tijdens het wachten meer dan een paar pixels, dan
--   telt dat ook als "bezig" en verschijnt er niets.
-- * Op een volledig-schermvenster (spel, film) verschijnt het nooit.
-- De shell (SuperCheatSheet.qml) leest de toestand uit één bestand.
local M = {}

local STATE_FILE = "/tmp/kingstra-superhold"
local TICK_MS = 100
local SHOW_AFTER_TICKS = 8 -- 0,8 s
local MOVE_LIMIT = 6

local state = { down = false, busy = false, shown = false, ticks = 0, pos = nil, timer = nil, seq = 0 }

local function cursor()
    local ok, pos = pcall(hl.get_cursor_pos)
    if ok and pos and pos.x and pos.y then return pos end
end

local function write(text)
    state.seq = state.seq + 1
    local line = tostring(state.seq) .. " " .. tostring(os.time()) .. " " .. text .. "\n"
    local ok = pcall(function()
        local f = assert(io.open(STATE_FILE, "w"))
        f:write(line)
        f:close()
    end)
    if not ok then
        hl.exec_cmd("printf '%s' '" .. line:gsub("'", "") .. "' > " .. STATE_FILE)
    end
end

local function stop_timer()
    if state.timer then pcall(function() state.timer:set_enabled(false) end) end
end

local function hide()
    if state.shown then
        state.shown = false
        write("hide")
    end
end

local function fullscreen_active()
    local ok, window = pcall(hl.get_active_window)
    if not ok or not window then return false end
    local fs = window.fullscreen
    return fs == true or (type(fs) == "number" and fs > 0)
end

local function tick()
    if not state.down or state.busy then stop_timer(); return end
    local pos = cursor()
    if pos and state.pos and (math.abs(pos.x - state.pos.x) > MOVE_LIMIT or math.abs(pos.y - state.pos.y) > MOVE_LIMIT) then
        state.busy = true
        stop_timer()
        return
    end
    state.ticks = state.ticks + 1
    if state.ticks < SHOW_AFTER_TICKS then return end
    stop_timer()
    if fullscreen_active() then return end
    local monitor = nil
    pcall(function() monitor = hl.get_monitor_at_cursor() end)
    state.shown = true
    write("show " .. ((monitor and monitor.name) or ""))
end

function M.down()
    state.down, state.busy, state.ticks, state.pos = true, false, 0, cursor()
    hide()
    if not hl.timer then return end
    if not state.timer then
        local ok, timer = pcall(hl.timer, tick, { timeout = TICK_MS, type = "repeat" })
        if ok then state.timer = timer end
    else
        pcall(function() state.timer:set_enabled(true) end)
    end
end

function M.up()
    state.down = false
    stop_timer()
    hide()
end

-- Een Super-combinatie is gebruikt: niet meer tonen tot de volgende druk.
function M.busy()
    state.busy = true
    stop_timer()
    hide()
end

-- Oude aanroep uit binds.lua; bewust leeg (zie bovenaan).
function M.watch() end

-- Voor Lua-handlers van Super+muis/wiel: eerst "bezig" melden, dan de
-- handler zelf. Geen extra bind, dezelfde toets houdt één bind.
function M.wrap(fn)
    if type(fn) ~= "function" then return fn end
    return function(...)
        if state.down then M.busy() end
        return fn(...)
    end
end

local function busy_if_down()
    if state.down then M.busy() end
end

function M.setup()
    for _, key in ipairs({ "Super_L", "Super_R" }) do
        pcall(hl.bind, key, M.down, { ignore_mods = true, non_consuming = true })
        pcall(hl.bind, key, M.up, { release = true, ignore_mods = true, non_consuming = true })
    end
    -- Super+1, Super+pijl, Super+Q enz. wisselen venster of werkruimte.
    pcall(hl.on, "window.active", busy_if_down)
    pcall(hl.on, "workspace.active", busy_if_down)
    -- Na een herlaadactie nooit een blijvend briefje.
    write("hide")
end

return M
