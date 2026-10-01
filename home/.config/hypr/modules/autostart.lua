-- Daemons and the startup layout, run once when Hyprland starts.
-- See https://wiki.hypr.land/Configuring/Basics/Autostart/

local v       = require("modules.vars")
local session = require("modules.session")

hl.on("hyprland.start", function()
    hl.exec_cmd("waybar > /tmp/waybar.log 2>&1")                -- log kept so a dead bar can be diagnosed
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")   -- password prompts for GUI apps
    hl.exec_cmd("wl-paste --watch cliphist store")               -- clipboard history
    hl.exec_cmd(v.scripts .. "/whichkey-overlay.py")             -- which-key overlay (hold ALT)

    -- Wallpaper, idle/lock, night light; skipped until the packages are installed
    if v.have("hyprpaper")  then hl.exec_cmd("hyprpaper")  end
    if v.have("hypridle")   then hl.exec_cmd("hypridle")   end
    if v.have("hyprsunset") then hl.exec_cmd("hyprsunset") end

    -- ActivityWatch (window + AFK log on :5600); the guy's activity worker reads it
    if v.have("awatcher")   then hl.exec_cmd("awatcher --no-tray") end
    hl.exec_cmd(v.home .. "/.local/bin/guy eyes start")          -- camera presence, unless paused (ALT+A p)

    session.restore()
end)
