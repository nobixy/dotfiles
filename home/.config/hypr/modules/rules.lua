-- Window and layer rules.
-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/

---------------
---- APPS  ----
---------------

hl.window_rule({
    -- Ignore maximize requests from all apps
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    -- Don't dim or lock the screen while anything is fullscreen (video, games)
    name  = "idle-inhibit-fullscreen",
    match = { class = ".*" },

    idle_inhibit = "fullscreen",
})

hl.window_rule({
    -- Fix some dragging issues with XWayland
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },

    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },

    move  = "20 monitor_h-120",
    float = true,
})

-- The guy's chat (ALT+A g): a floating terminal on the right
hl.window_rule({
    name  = "float-guy",
    match = { class = "^guy$" },

    float = true,
    size  = { "monitor_w*0.35", "monitor_h*0.7" },
    move  = { "monitor_w*0.65-20", "monitor_h*0.15" },
})

-- Browser picture-in-picture: small, pinned to all workspaces, bottom right
hl.window_rule({
    name  = "pip",
    match = { title = "^(Picture.in.[Pp]icture)$" },

    float             = true,
    pin               = true,
    keep_aspect_ratio = true,
    size              = { "monitor_w*0.25", "monitor_h*0.25" },
    move              = { "monitor_w*0.75-20", "monitor_h*0.75-20" },
})

-- File pickers and password prompts: float, centred, with the rest dimmed
hl.window_rule({
    name  = "float-file-pickers",
    match = { class = "^(xdg-desktop-portal-gtk|org.freedesktop.impl.portal.desktop.kde)$" },

    float  = true,
    center = true,
    size   = { "monitor_w*0.5", "monitor_h*0.6" },
})

hl.window_rule({
    name  = "polkit-prompt",
    match = { class = "^(org.kde.polkit-kde-authentication-agent-1|hyprpolkitagent)$" },

    float      = true,
    center     = true,
    pin        = true,
    dim_around = true,
})

hl.window_rule({
    name  = "float-file-progress",
    match = {
        class = "^(org.kde.dolphin|thunar)$",
        title = "^(File Operation Progress|Copying.*|Moving.*|Deleting.*)$",
    },

    float = true,
})

-- Screenshot annotation (mod+SHIFT+Print)
hl.window_rule({
    name  = "satty",
    match = { class = "^com.gabm.satty$" },

    float  = true,
    center = true,
    size   = { "monitor_w*0.8", "monitor_h*0.8" },
})

-- Steam: keep the friends list and settings out of the tiling layout
hl.window_rule({
    name  = "steam-popups",
    match = { class = "^steam$", title = "^(Friends List|Steam Settings|Steam - News.*)$" },

    float = true,
})

-- Games: flag as game content so VRR (misc.vrr = 3) kicks in when fullscreen
hl.window_rule({
    name  = "games",
    match = { class = "^(steam_app_.*|gamescope)$" },

    content = "game",
})

----------------
---- LAYERS ----
----------------

-- Blur behind the translucent bar, launcher, notifications and which-key overlay
for _, ns in ipairs({ "waybar", "rofi", "notifications", "whichkey" }) do
    hl.layer_rule({
        name         = "blur-" .. ns,
        match        = { namespace = "^" .. ns .. "$" },
        blur         = true,
        ignore_alpha = 0.3,
    })
end

-- No fade on the screenshot region selector and colour picker overlays
hl.layer_rule({
    name    = "no-anim-overlays",
    match   = { namespace = "^(selection|hyprpicker)$" },
    no_anim = true,
})
