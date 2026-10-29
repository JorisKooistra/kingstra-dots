-- Super+Q is lokaal aan het scherm onder de muis. Toetsenbordfocus kan nog
-- op een ander scherm staan, bijvoorbeeld als de muis op de shell-rail staat.
local M = {}

function M.target()
    local monitor = hl.get_monitor_at_cursor()
    if not monitor then return nil end
    local special = monitor.active_special_workspace
    local workspace = special or monitor.active_workspace
    if not workspace then return nil end

    local function eligible(window)
        return window and window.mapped and window.visible and not window.hidden
            and window.monitor and window.monitor.id == monitor.id
            and ((window.workspace and window.workspace.id == workspace.id)
                or (window.pinned and not special))
    end

    local active = hl.get_active_window()
    if eligible(active) then return active end
    local last = workspace.last_window
    if eligible(last) then return last end
    -- Geen globale fallback: op een leeg scherm nooit elders iets sluiten.
    return nil
end

function M.close()
    local window = M.target()
    if window then
        hl.dispatch(hl.dsp.window.close({ window = "address:" .. window.address }))
    end
end

return M
