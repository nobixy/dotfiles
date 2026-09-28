-- Startup layout: opens each app in turn and, as soon as its window appears,
-- moves it to its workspace. Apps are started one at a time so the tiling
-- order on each workspace is always the same.
--
-- Windows are matched by class instead of exec rules because Chrome hands new
-- windows to its already-running process, so the PID never matches.
-- A step may still carry `rules` (exec rules, e.g. { float = true }).

local M = {}

M.layout = {
    -- BenQ
    { ws = 1, class = "google-chrome", cmd = "google-chrome-stable --new-window https://calendar.google.com" },
    { ws = 2, class = "antigravity",   cmd = "antigravity" },
    { ws = 2, class = "kitty",         cmd = [[kitty --directory "$HOME" sh -c 'claude; exec zsh']] },

    -- Asus
    { ws = 3, class = "google-chrome", cmd = "google-chrome-stable --new-window" },
    { ws = 4, class = "google-chrome", cmd = "google-chrome-stable --new-window" },

    -- LG
    { ws = 6, class = "google-chrome",              cmd = "google-chrome-stable --new-window" },
    { ws = 7, class = "org.pulseaudio.pavucontrol", cmd = "pavucontrol" },
    { ws = 7, class = "kitty",                      cmd = "kitty" },
    { ws = 7, class = "kitty",                      cmd = "kitty -e btop" },
}

-- Show each monitor's first workspace, finishing on the LG
M.focus_after = { 1, 3, 6 }

M.step_timeout_ms = 30000
-- Extra windows from the same launch (e.g. a restored Chrome session) that
-- arrive within this window go to the same workspace
M.grace_ms = 400

function M.restore(steps, focus_after)
    steps       = steps or M.layout
    focus_after = focus_after or M.focus_after

    local index, current = 0, nil
    local timeout, grace
    local placed = {}
    local subs = {}

    local function finish()
        for _, s in ipairs(subs) do s:remove() end
        for _, ws in ipairs(focus_after) do
            hl.dispatch(hl.dsp.focus({ workspace = ws }))
        end
    end

    local function advance()
        grace = nil
        index = index + 1
        current = steps[index]
        if not current then
            return finish()
        end

        local step = index
        hl.exec_cmd(current.cmd, current.rules)
        timeout = hl.timer(function()
            if index ~= step then return end
            hl.notification.create({ text = "startup: timed out waiting for " .. current.class, timeout = 5000 })
            advance()
        end, { timeout = M.step_timeout_ms, type = "oneshot" })
    end

    local function place(w)
        -- window.class also fires before the window is mapped; moving it then
        -- has no effect, so wait for window.open (or a later class change)
        if not current or w == nil or not w.mapped or w.class ~= current.class or placed[w.address] then
            return
        end
        placed[w.address] = true
        hl.dispatch(hl.dsp.window.move({ window = w, workspace = current.ws, follow = false }))

        if not grace then
            timeout:set_enabled(false)
            grace = hl.timer(advance, { timeout = M.grace_ms, type = "oneshot" })
        end
    end

    -- Electron apps sometimes set their class only after mapping
    subs[1] = hl.on("window.open", place)
    subs[2] = hl.on("window.class", place)

    advance()
end

return M
