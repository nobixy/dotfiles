-- Monitors, left to right, and the workspaces that live on each one.
-- See https://wiki.hypr.land/Configuring/Basics/Monitors/

-- BenQ GL2460, 60 Hz
hl.monitor({ output = "HDMI-A-1", mode = "1920x1080@60",     position = "0x0",    scale = 1 })
-- Asus VG248, 144 Hz
hl.monitor({ output = "DP-2",     mode = "1920x1080@144",    position = "1920x0", scale = 1 })
-- LG UltraGear (main), 1440p at its full 180 Hz
hl.monitor({ output = "DP-1",     mode = "2560x1440@179.96", position = "3840x0", scale = 1 })

-- Anything else that gets plugged in (TV, projector) goes to the right
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- BenQ 1-2, Asus 3-4, LG 6-7. Persistent, so Waybar always shows each
-- monitor's pair even when a workspace is empty.
local workspaces = {
    { monitor = "HDMI-A-1", ids = { 1, 2 } },
    { monitor = "DP-2",     ids = { 3, 4 } },
    { monitor = "DP-1",     ids = { 6, 7 } },
}

for _, m in ipairs(workspaces) do
    for i, id in ipairs(m.ids) do
        hl.workspace_rule({ workspace = tostring(id), monitor = m.monitor, default = i == 1, persistent = true })
    end
end
