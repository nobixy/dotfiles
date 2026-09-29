-- Keybindings, laid out like the Neovim config: ALT is the leader.
--
--   Neovim                      Hyprland
--   <leader>\  file explorer    ALT+\          app launcher (rofi)
--   <leader>f… find group       ALT+F, then f  files, a apps, b windows, ...
--   <leader>s… splits           ALT+S, then v  split right, h below, e equal, x close
--   <leader>b… buffers          ALT+B, then d  close window, o others, p pin
--   <leader>t… toggles          ALT+T, then f  floating, g game mode, n night light, ...
--   <leader>r… rename/restart   ALT+R, then n  rename workspace, s restart bar
--   <leader>[ ] prev/next       ALT+[ ]        previous/next workspace (this monitor)
--   <leader>p  paste            ALT+P          clipboard history
--   <leader>?  keymaps          ALT+?          keybind cheatsheet
--   <C-w>h/j/k/l, H/J/K/L       ALT+h/j/k/l, ALT+SHIFT+h/j/k/l   focus / move window
--   <C-w>c, <C-w>o              ALT+C close, ALT+O fullscreen ("only")
--
-- Hold ALT on its own for a moment and a which-key overlay lists all of this
-- (modules/whichkey.lua). Every bind has a description; ALT+? lists them from
-- `hyprctl binds` in a searchable rofi menu.
-- See https://wiki.hypr.land/Configuring/Basics/Binds/

local v   = require("modules.vars")
local wk  = require("modules.whichkey")
local mod = v.mainMod

-- Binds with a description show up in the which-key overlay (under the last
-- wk.section) and the cheatsheet. opts.wk = false keeps one out of the overlay
-- only, e.g. when a wk.add summary line covers a whole family of binds.
local function bind(keys, action, description, opts)
    opts = opts or {}
    if opts.wk ~= false then
        wk.record(keys, description)
    end
    opts.wk = nil
    opts.description = description
    return hl.bind(keys, action, opts)
end

local function exec(cmd)
    return hl.dsp.exec_cmd(cmd)
end

local function script(name, args)
    return exec(v.scripts .. "/" .. name .. (args and (" " .. args) or ""))
end

-- Run an optional tool, or say which package provides it
local function optional(bin, cmd, pkg)
    return exec(string.format(
        [[if command -v %s >/dev/null; then %s; else notify-send -u low "%s is not installed" "sudo pacman -S %s"; fi]],
        bin, cmd, bin, pkg or bin))
end

local function notify(text)
    hl.exec_cmd(string.format("notify-send -a osd -u low -t 2000 %q", text))
end

---------------------
---- LEADER KEYS ----
---------------------

-- Like Neovim's <leader>f, <leader>s, ...: mod+<key> opens a group and the
-- next key picks the action (keep holding mod or let go, both work). Esc or
-- any other key cancels, and so does waiting 5 s. While a group is open the
-- which-key overlay lists its keys and Waybar shows its name.

-- Keysyms of the leader modifier. Pressing it again inside a group (ALT+F,
-- then ALT+F as a second chord) must not count as "any other key".
local modkeys = ({
    ALT   = { "Alt_L", "Alt_R" },
    SUPER = { "Super_L", "Super_R" },
    CTRL  = { "Control_L", "Control_R" },
})[mod] or {}

local function group(key, name, items)
    wk.group(key, name, items)
    bind(mod .. " + " .. key, hl.dsp.submap(name), "+" .. name, { wk = false })

    hl.define_submap(name, function()
        for _, item in ipairs(items) do
            local k, action, desc = item[1], item[2], item[3]
            local function run()
                hl.dispatch(hl.dsp.submap("reset"))
                if type(action) == "function" then
                    action()
                else
                    hl.dispatch(action)
                end
            end
            hl.bind(k, run, { description = desc })
            hl.bind(mod .. " + " .. k, run) -- mod still held
        end
        for _, modkey in ipairs(modkeys) do
            hl.bind(modkey, hl.dsp.no_op()) -- must come before catchall
        end
        hl.bind("escape", hl.dsp.submap("reset"))
        hl.bind("catchall", hl.dsp.submap("reset"))
    end)
end

-- <leader>f: find
group("F", "find", {
    { "f", exec("rofi -show recursivebrowser"), "files (under ~)" },
    { "r", script("recent.sh"),                 "recent files" },
    { "a", exec(v.menu),                        "apps" },
    { "b", exec("rofi -show window"),           "windows (all workspaces)" },
    { "c", exec("rofi -show run"),              "run a command" },
    { "d", script("notifications.sh"),          "notification history" },
    { "k", script("keybinds.sh"),               "keybinds" },
})

-- <leader>s: splits (dwindle). v/h choose where the NEXT window opens.
group("S", "split", {
    { "v", hl.dsp.layout("preselect r"),        "next window opens right" },
    { "h", hl.dsp.layout("preselect d"),        "next window opens below" },
    { "e", hl.dsp.layout("splitratio 1 exact"), "equal size" },
    { "t", hl.dsp.layout("togglesplit"),        "toggle split direction" },
    { "s", hl.dsp.layout("swapsplit"),          "swap the two halves" },
    { "x", hl.dsp.window.close(),               "close window" },
})

-- <leader>b: buffers -> windows
group("B", "buffer", {
    { "d", hl.dsp.window.close(), "close window" },
    { "o", function()
        local active = hl.get_active_window()
        if not active or not active.workspace then return end
        for _, w in ipairs(hl.get_workspace_windows(active.workspace)) do
            if w.address ~= active.address then
                hl.dispatch(hl.dsp.window.close({ window = w }))
            end
        end
    end, "close other windows here" },
    { "p", function()
        local w = hl.get_active_window()
        if w and not w.pinned and not w.floating then
            hl.dispatch(hl.dsp.window.float({ action = "set" }))
        end
        hl.dispatch(hl.dsp.window.pin())
    end, "pin to all workspaces (floats it)" },
})

-- <leader>t: toggles
group("T", "toggle", {
    { "f", hl.dsp.window.float({ action = "toggle" }), "floating" },
    { "p", hl.dsp.window.pseudo(),                     "pseudotile" },
    { "b", exec("pkill -SIGUSR1 -x waybar"),           "bar (hide/show)" },
    { "d", exec("dunstctl set-paused toggle; pkill -RTMIN+8 waybar"), "do not disturb" },
    { "n", optional("hyprsunset",
        [[f="$XDG_RUNTIME_DIR/nightlight-forced"; if [ -e "$f" ]; then hyprctl hyprsunset reset; rm -f "$f"; else hyprctl hyprsunset temperature 4000; touch "$f"; fi]]),
        "night light (on / back to schedule)" },
    -- Game mode: no animations, blur, shadows or gaps; again to restore
    { "g", function()
        if hl.get_config("animations.enabled") == false then
            hl.exec_cmd("hyprctl reload config-only")
            notify("Game mode off")
            return
        end
        hl.config({
            general    = { gaps_in = 0, gaps_out = 0, border_size = 1 },
            animations = { enabled = false },
            decoration = { rounding = 0, shadow = { enabled = false }, blur = { enabled = false } },
        })
        notify("Game mode on")
    end, "game mode" },
})

-- <leader>r: rename / restart
group("R", "rename/restart", {
    { "n", script("rename-workspace.sh"), "rename workspace" },
    { "s", exec("pkill -x waybar; systemctl --user restart dunst; waybar"), "restart bar and notifications" },
    { "h", exec("hyprctl reload"), "reload Hyprland config" },
})

-- <leader>i: study. The agent buttons run in the background and report back
-- through a notification (~/.local/bin/eecs-agent).
local agent = v.home .. "/.local/bin/eecs-agent"
group("I", "study", {
    { "p", exec(agent .. " plan"),         "plan my day" },
    { "w", exec(agent .. " shifts"),       "sync work shifts" },
    { "i", exec(agent .. " shifts-paste"), "type in shifts" },
    { "c", exec(agent .. " coach"),        "coach: rebuild the week" },
    { "a", exec(agent .. " menu"),         "all agents" },
})

---------------------------
---- PROGRAMS (direct) ----
---------------------------

wk.section("Apps")

bind(mod .. " + backslash",       exec(v.menu),        "App launcher")
bind(mod .. " + Return",          exec(v.terminal),    "Terminal")
bind(mod .. " + Q",               exec(v.terminal),    "Terminal")
bind(mod .. " + E",               exec(v.fileManager), "File manager")
bind(mod .. " + W",               exec(v.browser),     "Browser (web)")
bind(mod .. " + P",               exec("cliphist list | rofi -dmenu -p clipboard -display-columns 2 | cliphist decode | wl-copy"),
    "Clipboard history (paste)")
bind(mod .. " + SHIFT + C",       optional("hyprpicker", "hyprpicker -a"), "Colour picker (copies hex)")
bind(mod .. " + SHIFT + slash",   script("keybinds.sh"), "Keybind cheatsheet")

-----------------
---- WINDOWS ----
-----------------

wk.section("Windows")

bind(mod .. " + C",         hl.dsp.window.close(),                             "Close window")
bind(mod .. " + O",         hl.dsp.window.fullscreen({ mode = "fullscreen" }), "Fullscreen (only this window)")
bind(mod .. " + SHIFT + O", hl.dsp.window.fullscreen({ mode = "maximized" }),  "Maximize (keep gaps and bar)")
bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }),        "Toggle floating")
bind(mod .. " + G",         hl.dsp.group.toggle(),                             "Toggle tab group")

bind(mod .. " + Tab", function()
    local w = hl.get_active_window()
    if w and w.group and w.group.size > 1 then
        hl.dispatch(hl.dsp.group.next())
    else
        hl.dispatch(hl.dsp.window.cycle_next())
        hl.dispatch(hl.dsp.window.bring_to_top())
    end
end, "Next window (next tab inside a group)")

-- Vim directions, with the arrow keys as aliases (one overlay line each)
wk.add("h j k l", "Focus")
wk.add("H J K L", "Move window")
wk.add("⌃h j k l", "Resize")
local directions = {
    { vim = "h", arrow = "left",  name = "left",  dx = -1, dy = 0 },
    { vim = "j", arrow = "down",  name = "down",  dx = 0,  dy = 1 },
    { vim = "k", arrow = "up",    name = "up",    dx = 0,  dy = -1 },
    { vim = "l", arrow = "right", name = "right", dx = 1,  dy = 0 },
}
local step = 40
for _, d in ipairs(directions) do
    for _, key in ipairs({ d.vim, d.arrow }) do
        local first = key == d.vim
        bind(mod .. " + " .. key,           hl.dsp.focus({ direction = d.name }),
            first and ("Focus " .. d.name) or nil, { wk = false })
        bind(mod .. " + SHIFT + " .. key,   hl.dsp.window.move({ direction = d.name }),
            first and ("Move window " .. d.name) or nil, { wk = false })
        bind(mod .. " + CTRL + " .. key,
            hl.dsp.window.resize({ x = d.dx * step, y = d.dy * step, relative = true }),
            first and ("Resize window " .. d.name) or nil, { repeating = true, wk = false })
    end
end

bind(mod .. " + mouse:272", hl.dsp.window.drag(),   "Drag window",   { mouse = true })
bind(mod .. " + mouse:273", hl.dsp.window.resize(), "Resize window", { mouse = true })

--------------------
---- WORKSPACES ----
--------------------

wk.section("Workspaces")

-- mod + [0-9] switches, + SHIFT moves the window along, + CTRL sends it silently
wk.add("1…0", "Go to workspace")
wk.add("⇧1…0", "Move window there")
wk.add("⌃1…0", "Send window there (stay here)")
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    local first = i == 1
    bind(mod .. " + " .. key,           hl.dsp.focus({ workspace = i }),
        first and "Go to workspace 1-10" or nil, { wk = false })
    bind(mod .. " + SHIFT + " .. key,   hl.dsp.window.move({ workspace = i }),
        first and "Move window to workspace 1-10" or nil, { wk = false })
    bind(mod .. " + CTRL + " .. key,    hl.dsp.window.move({ workspace = i, follow = false }),
        first and "Send window to workspace 1-10 (stay here)" or nil, { wk = false })
end

-- Like <leader>[ / <leader>]: step through this monitor's workspaces
bind(mod .. " + bracketleft",          hl.dsp.focus({ workspace = "m-1" }),        "Previous workspace (this monitor)")
bind(mod .. " + bracketright",         hl.dsp.focus({ workspace = "m+1" }),        "Next workspace (this monitor)")
bind(mod .. " + SHIFT + bracketleft",  hl.dsp.window.move({ workspace = "m-1" }),  "Move window to previous workspace")
bind(mod .. " + SHIFT + bracketright", hl.dsp.window.move({ workspace = "m+1" }),  "Move window to next workspace")
bind(mod .. " + mouse_down",           hl.dsp.focus({ workspace = "m+1" }),        "Next workspace (this monitor)", { wk = false })
bind(mod .. " + mouse_up",             hl.dsp.focus({ workspace = "m-1" }),        "Previous workspace (this monitor)", { wk = false })

-- Scratchpad (a hidden workspace you can pull over anything)
bind(mod .. " + grave",         hl.dsp.workspace.toggle_special("magic"),            "Toggle scratchpad")
bind(mod .. " + SHIFT + grave", hl.dsp.window.move({ workspace = "special:magic" }), "Move window to scratchpad")

---------------------
---- SCREENSHOTS ----
---------------------

wk.section("Screenshots")

-- All of them are saved to ~/Pictures/Screenshots and copied to the clipboard
bind("Print",                   script("screenshot.sh", "region"),  "Screenshot a region")
bind(mod .. " + Print",         script("screenshot.sh", "window"),  "Screenshot the active window")
bind("CTRL + Print",            script("screenshot.sh", "monitor"), "Screenshot this monitor")
bind("SHIFT + Print",           script("screenshot.sh", "all"),     "Screenshot all monitors")
bind(mod .. " + SHIFT + Print", script("screenshot.sh", "edit"),    "Screenshot a region and annotate it")

-----------------------
---- NOTIFICATIONS ----
-----------------------

wk.section("Notifications")

-- ALT+D stays free: zsh uses Alt-D for fuzzy cd
bind(mod .. " + N",         exec("dunstctl history-pop"), "Show previous notification")
bind(mod .. " + SHIFT + N", exec("dunstctl close-all"),   "Dismiss all notifications")

----------------
---- SYSTEM ----
----------------

wk.section("System")

bind("SUPER + L",           script("lock.sh"),      "Lock screen")
bind(mod .. " + Escape",    script("powermenu.sh"), "Power menu")
bind(mod .. " + SHIFT + M", exec("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'"),
    "Exit Hyprland")

-- Media keys, also active on the lock screen
bind("XF86AudioRaiseVolume", script("volume.sh", "up"),   "Volume up",       { locked = true, repeating = true })
bind("XF86AudioLowerVolume", script("volume.sh", "down"), "Volume down",     { locked = true, repeating = true })
bind("XF86AudioMute",        script("volume.sh", "mute"), "Mute",            { locked = true })
bind("XF86AudioMicMute",     script("volume.sh", "mic"),  "Mute microphone", { locked = true })

bind("XF86AudioNext",  exec("playerctl next"),       "Next track",     { locked = true })
bind("XF86AudioPause", exec("playerctl play-pause"), "Play/pause",     { locked = true })
bind("XF86AudioPlay",  exec("playerctl play-pause"), "Play/pause",     { locked = true })
bind("XF86AudioPrev",  exec("playerctl previous"),   "Previous track", { locked = true })

wk.start()
