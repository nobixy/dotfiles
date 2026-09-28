-- Gaps, borders, blur, animations and layouts.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/

local v = require("modules.vars")
local c, rgba = v.color, v.rgba

-- hyprpaper draws the wallpaper; until it is installed keep Hyprland's own
local haveWallpaper = v.have("hyprpaper")

hl.config({
    general = {
        gaps_in  = 5,
        gaps_out = 10,

        border_size = 2,

        col = {
            active_border   = v.accent,
            inactive_border = rgba(c.surface1, 0.67),
        },

        -- Drag borders/gaps to resize; floating windows snap to edges
        resize_on_border = true,
        snap = { enabled = true },

        -- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before turning this on
        allow_tearing = false,

        layout = "dwindle",
    },

    decoration = {
        rounding       = 10,
        rounding_power = 2,

        active_opacity   = 1.0,
        inactive_opacity = 1.0,

        shadow = {
            enabled      = true,
            range        = 12,
            render_power = 3,
            color        = rgba(c.crust, 0.6),
        },

        blur = {
            enabled  = true,
            size     = 6,
            passes   = 2,
            vibrancy = 0.1696,
            popups   = true,
        },
    },

    group = {
        col = {
            border_active          = v.accent,
            border_inactive        = rgba(c.surface1, 0.67),
            border_locked_active   = rgba(c.yellow, 0.93),
            border_locked_inactive = rgba(c.surface1, 0.67),
        },
        groupbar = {
            font_family         = v.font,
            font_size           = 11,
            height              = 18,
            gradients           = true,
            rounding            = 6,
            text_color          = rgba(c.crust),
            text_color_inactive = rgba(c.text),
            col = {
                active          = rgba(c.cyan, 0.9),
                inactive        = rgba(c.surface0, 0.9),
                locked_active   = rgba(c.yellow, 0.9),
                locked_inactive = rgba(c.surface0, 0.9),
            },
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    master = {
        new_status = "master",
    },

    scrolling = {
        fullscreen_on_one_column = true,
    },

    misc = {
        force_default_wallpaper = haveWallpaper and 0 or -1,
        disable_hyprland_logo   = haveWallpaper,
        background_color        = rgba(c.crust),
        font_family             = v.font,

        -- Adaptive sync only for fullscreen games/video (rules.lua tags games)
        vrr = 3,

        -- Wake the monitors after hypridle turns them off
        mouse_move_enables_dpms = true,
        key_press_enables_dpms  = true,
    },

    ecosystem = {
        no_donation_nag = true,
    },
})

-- Default curves and animations, see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("easeOutQuint",   { type = "bezier", points = { {0.23, 1},    {0.32, 1} } })
hl.curve("easeInOutCubic", { type = "bezier", points = { {0.65, 0.05}, {0.36, 1} } })
hl.curve("linear",         { type = "bezier", points = { {0, 0},       {1, 1}    } })
hl.curve("almostLinear",   { type = "bezier", points = { {0.5, 0.5},   {0.75, 1} } })
hl.curve("quick",          { type = "bezier", points = { {0.15, 0},    {0.1, 1}  } })

hl.curve("easy",           { type = "spring", mass = 1, stiffness = 238.1191, dampening = 24.21279333 })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, spring = "easy" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  spring = "easy",         style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "linear",       style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "layersIn",      enabled = true, speed = 4,    bezier = "easeOutQuint", style = "fade" })
hl.animation({ leaf = "layersOut",     enabled = true, speed = 1.5,  bezier = "linear",       style = "fade" })
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 1.79, bezier = "almostLinear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.39, bezier = "almostLinear" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesIn",  enabled = true, speed = 1.21, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })
hl.animation({ leaf = "zoomFactor",    enabled = true, speed = 7,    bezier = "quick" })
