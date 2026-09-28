-- Shared settings used by the other modules: programs, palette and helpers.

local M = {}

M.mainMod = "ALT"

M.terminal    = "kitty"
M.fileManager = "kitty -e yazi" -- GUI alternative: "dolphin"
M.browser     = "google-chrome-stable"
M.menu        = "rofi -show drun"

M.home    = os.getenv("HOME")
M.scripts = M.home .. "/.config/hypr/scripts"
M.font    = "FiraCode Nerd Font"

-- Catppuccin Mocha surfaces + the cyan -> green accent used across the rice
-- (Waybar, rofi, dunst, kitty, hyprlock and starship all use the same values)
M.color = {
    crust    = "11111b",
    mantle   = "181825",
    base     = "1e1e2e",
    surface0 = "313244",
    surface1 = "45475a",
    overlay0 = "6c7086",
    text     = "cdd6f4",
    red      = "f38ba8",
    yellow   = "f9e2af",
    cyan     = "33ccff",
    green    = "00ff99",
}

-- rgba("33ccff", 0.5) -> "rgba(33ccff80)"
function M.rgba(hex, alpha)
    return string.format("rgba(%s%02x)", hex, math.floor((alpha or 1) * 255 + 0.5))
end

M.accent = { colors = { M.rgba(M.color.cyan, 0.93), M.rgba(M.color.green, 0.93) }, angle = 45 }

-- True if `bin` is an executable on PATH. Only opens files, so it is safe to
-- call at config load without blocking the compositor.
function M.have(bin)
    for dir in (os.getenv("PATH") or "/usr/bin"):gmatch("[^:]+") do
        local f = io.open(dir .. "/" .. bin, "r")
        if f then
            f:close()
            return true
        end
    end
    return false
end

function M.exists(path)
    local f = io.open(path, "r")
    if f then f:close() end
    return f ~= nil
end

return M
