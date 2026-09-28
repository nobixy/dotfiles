-- Environment variables for everything launched from Hyprland.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/

local v = require("modules.vars")

-- Cursor
hl.env("XCURSOR_THEME", "Adwaita")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- Toolkits: native Wayland first, X11 as a fallback
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")   -- Antigravity/Obsidian/Electron run native Wayland

-- Qt theming (dark palette + icons for Dolphin etc.), once qt6ct is installed
if v.have("qt6ct") then
    hl.env("QT_QPA_PLATFORMTHEME", "qt6ct")
end

-- Dolphin's "Open With" menu needs an applications.menu outside of Plasma
if v.exists("/etc/xdg/menus/arch-applications.menu") then
    hl.env("XDG_MENU_PREFIX", "arch-")
end

-- NVIDIA (see https://wiki.hypr.land/Nvidia/). Only when its driver is
-- loaded: on AMD/Intel graphics these would break video decoding and GL.
if v.exists("/proc/driver/nvidia/version") then
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
end
