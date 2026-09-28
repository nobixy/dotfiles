-- which-key for Hyprland, like the Neovim plugin:
--   * hold the leader (ALT) on its own for a moment and an overlay lists
--     everything it can do; it closes when you let go or press a key
--   * open a leader group (ALT+F, ALT+S, ...) and it lists that group's keys
--
-- keybinds.lua registers what to show through section()/add()/record()/group().
-- The overlay itself is scripts/whichkey-overlay.py (never takes keyboard
-- focus), driven through scripts/whichkey.sh.

local v = require("modules.vars")

local M = {}

M.delay_ms = 500 -- hold the leader this long before the overlay appears
M.group_timeout_ms = 5000 -- an open group gives up after this long

local mod = v.mainMod
local sections = {}
local groups, group_order = {}, {}

---------------------------------------------------------------------------
-- Labels: "ALT + SHIFT + h" -> "H" (vim style: capital = shift),
-- "ALT + CTRL + h" -> "⌃h", "ALT + backslash" -> "\"

local SYMBOLS = { SHIFT = "⇧", CTRL = "⌃", SUPER = "❖", ALT = "⌥" }
local KEYS = {
    backslash = "\\", bracketleft = "[", bracketright = "]", grave = "`", slash = "/",
    Return = "⏎", Tab = "⇥", Escape = "esc", Print = "prt",
    ["mouse:272"] = "left drag", ["mouse:273"] = "right drag",
}

function M.label(chord)
    local mods, key = {}, nil
    for part in chord:gmatch("[^+%s]+") do
        if SYMBOLS[part] then
            mods[part] = true
        else
            key = part
        end
    end
    if not key or not mods[mod] then
        return nil -- not reachable from the leader
    end
    mods[mod] = nil

    if mods.SHIFT and key == "slash" then
        mods.SHIFT, key = nil, "?"
    elseif mods.SHIFT and #key == 1 and key:match("%a") then
        mods.SHIFT, key = nil, key:upper()
    elseif #key == 1 then
        key = key:lower()
    else
        key = KEYS[key] or key
    end

    local prefix = ""
    for _, m in ipairs({ "SUPER", "CTRL", "SHIFT" }) do
        if mods[m] then
            prefix = prefix .. SYMBOLS[m]
        end
    end
    return prefix .. key
end

---------------------------------------------------------------------------
-- Registration (called from keybinds.lua)

function M.section(name)
    table.insert(sections, { name = name, entries = {} })
end

function M.add(keys, desc)
    if #sections == 0 then
        M.section("General")
    end
    local entries = sections[#sections].entries
    local last = entries[#entries]
    if last and last[2] == desc then
        last[1] = last[1] .. " " .. keys -- same action on several keys
    else
        table.insert(entries, { keys, desc })
    end
end

-- A bind: shown if it's reachable from the leader and has a description
function M.record(chord, desc)
    local keys = desc and M.label(chord)
    if keys then
        M.add(keys, desc)
    end
end

function M.group(key, name, items)
    groups[name] = { key = key, items = items }
    table.insert(group_order, name)
end

function M.is_group(name)
    return groups[name] ~= nil
end

local function write()
    local path = (os.getenv("XDG_RUNTIME_DIR") or "/tmp") .. "/hypr-whichkey.tsv"
    local f = io.open(path, "w")
    if not f then
        return
    end
    local function line(...)
        f:write(table.concat({ ... }, "\t"), "\n")
    end

    line("section", "Leader groups")
    for _, name in ipairs(group_order) do
        line("entry", M.label(mod .. " + " .. groups[name].key), "+" .. name)
    end
    for _, s in ipairs(sections) do
        line("section", s.name)
        for _, e in ipairs(s.entries) do
            line("entry", e[1], e[2])
        end
    end
    for _, name in ipairs(group_order) do
        local g = groups[name]
        line("group", name, mod .. "+" .. g.key .. "  " .. name)
        for _, item in ipairs(g.items) do
            line("item", name, item[1], item[3])
        end
    end
    f:close()
end

---------------------------------------------------------------------------
-- Triggers

-- XKB keycodes (evdev + 8), as passed by the input.keyboard.key event
local MOD_KEYCODES = {
    ALT = { 64, 108 },
    SUPER = { 133, 134 },
    CTRL = { 37, 105 },
}
local MODIFIER = { [50] = true, [62] = true, [37] = true, [105] = true, [133] = true, [134] = true, [64] = true, [108] = true }

local leader = {}
for _, code in ipairs(MOD_KEYCODES[mod] or {}) do
    leader[code] = true
end

local held, arm_timer, group_timer = false, nil, nil
local visible -- "root", a group name, or nil

local function send(args)
    hl.exec_cmd(v.scripts .. "/whichkey.sh " .. args)
end

local function show(view)
    local m = hl.get_active_monitor()
    send(string.format("show %s %d %d", view, m and m.x or 0, m and m.y or 0))
    visible = view
end

local function hide()
    if visible then
        send("hide")
        visible = nil
    end
end

local function stop(timer)
    if timer then
        timer:set_enabled(false)
    end
end

local function in_game()
    local w = hl.get_active_window()
    return w ~= nil and (w.content_type == "game" or w.class:match("^steam_app_") ~= nil)
end

-- input.keyboard.key handler. Runs for every key press/release, so it only
-- does cheap work. Public so the logic can be exercised from `hyprctl repl`.
function M.on_key(keycode, _, state)
    if state == 2 then
        return -- key repeat
    end

    if leader[keycode] then
        if state == 1 and not held then
            held = true
            if hl.get_current_submap() == "" and not in_game() then
                stop(arm_timer)
                arm_timer = hl.timer(function()
                    arm_timer = nil
                    if held and hl.get_current_submap() == "" then
                        show("root")
                    end
                end, { timeout = M.delay_ms, type = "oneshot" })
            end
        elseif state == 0 then
            held = false
            stop(arm_timer)
            arm_timer = nil
            if visible == "root" then
                hide()
            end
        end
    elseif state == 1 and not MODIFIER[keycode] then
        -- A chord is being typed: cancel/close the overview. Closing waits a
        -- moment, so a group opened by this key can take over instead.
        stop(arm_timer)
        arm_timer = nil
        if visible == "root" then
            hl.timer(function()
                if visible == "root" then
                    hide()
                end
            end, { timeout = 40, type = "oneshot" })
        end
    end
end

-- keybinds.submap handler: a leader group opened or closed
function M.on_submap(name)
    stop(group_timer)
    group_timer = nil
    if groups[name] then
        show(name)
        group_timer = hl.timer(function()
            if hl.get_current_submap() == name then
                hl.dispatch(hl.dsp.submap("reset"))
            end
        end, { timeout = M.group_timeout_ms, type = "oneshot" })
    elseif visible and visible ~= "root" then
        hide()
    end
end

function M.visible()
    return visible
end

function M.start()
    write()
    hl.on("input.keyboard.key", M.on_key)
    hl.on("keybinds.submap", M.on_submap)
end

return M
