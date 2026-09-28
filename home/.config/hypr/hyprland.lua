-- Hyprland config (Lua, Hyprland 0.55+). Wiki: https://wiki.hypr.land/Configuring/Start/
--
-- Each module is loaded in its own scope, so an error in one of them does not
-- stop the others from loading. Shared values (programs, palette, helpers)
-- live in modules/vars.lua.
--
-- Check changes before saving:  Hyprland --verify-config -c ~/.config/hypr/hyprland.lua
-- Editor completion:            /usr/share/hypr/stubs/ (see .luarc.json)

require("modules.monitors")
require("modules.env")
require("modules.looknfeel")
require("modules.input")
require("modules.keybinds")
require("modules.rules")
require("modules.autostart")
