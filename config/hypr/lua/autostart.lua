hl.on("hyprland.start", function()
    -- An already-running legacy session may recreate this file while it still
    -- uses the old parser. Once this Lua session is active it is safe to remove
    -- the obsolete entrypoint permanently.
    local home = os.getenv("HOME")
    if home then
        hl.exec_cmd("rm -f " .. home .. "/.config/hypr/hyprland.conf")
    end
    hl.exec_cmd("~/.local/bin/kingstra-session-start")
end)
