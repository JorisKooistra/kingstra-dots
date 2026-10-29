local close = assert(loadfile("config/hypr/lua/window-close.lua"))()
local monitor, active, dispatched
_G.hl = {
    get_monitor_at_cursor = function() return monitor end,
    get_active_window = function() return active end,
    dsp = { window = { close = function(options) return options end } },
    dispatch = function(options) dispatched = options end,
}
local function window(address, output, workspace)
    return { address=address, monitor=output, workspace=workspace,
        mapped=true, visible=true, hidden=false }
end
local function expect(target)
    assert(close.target() == target, "wrong close target")
    dispatched = nil
    close.close()
    if target then
        assert(dispatched and dispatched.window == "address:" .. target.address,
            "close must use the selected address, never global focus")
    else
        assert(not dispatched, "no local target must mean no close")
    end
end

local workspace = {id=1}
monitor = {id=2, active_workspace=workspace} -- monitor 0 is also a valid ID
local other = {id=0}
local local_window = window("0xaaa", monitor, workspace)
workspace.last_window = local_window
active = local_window
expect(local_window)

-- Focus bleef op een ander scherm; kies alleen het lokale venster.
active = window("0xbbb", other, {id=2})
local foreign = active
expect(local_window)
active = nil
expect(local_window)
workspace.last_window = nil
expect(nil)
workspace.last_window = foreign
expect(nil)

-- Geen vensters uit verborgen werkruimtes of gesloten/verborgen groep-tabs.
workspace.last_window = local_window
local_window.workspace = {id=3}
expect(nil)
local_window.workspace = workspace
for _, field in ipairs({"mapped", "visible", "hidden"}) do
    local original = local_window[field]
    local_window[field] = not original
    expect(nil)
    local_window[field] = original
end
active = window("0xccc", monitor, workspace)
expect(active) -- actieve lokale app gaat voor de werkruimte-cache

-- Een open speciale werkruimte mag geen onderliggend venster sluiten.
local special = {id=-99}
monitor.active_special_workspace = special
expect(nil)
local popup = window("0xddd", monitor, special)
special.last_window = popup
expect(popup)
special.last_window = nil
expect(nil)
monitor.active_special_workspace = nil

-- Vastgepinde vensters zijn lokaal zichtbaar buiten hun originele werkruimte.
active.workspace, active.pinned = {id=5}, true
expect(active)
active.monitor = other
expect(local_window)
monitor.id, other.id = 0, 2
expect(local_window)
monitor = nil
expect(nil)
print("ok - Super+Q stays on the cursor monitor, including empty and special workspaces")
