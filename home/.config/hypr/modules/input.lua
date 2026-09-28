-- Keyboard, mouse and cursor.
-- See https://wiki.hypr.land/Configuring/Basics/Variables/#input

hl.config({
    input = {
        kb_layout = "us",

        numlock_by_default = true,

        -- Snappier key repeat than the 600 ms / 25 Hz default
        repeat_delay = 300,
        repeat_rate  = 40,

        follow_mouse = 1,
        sensitivity  = 0, -- -1.0 - 1.0, 0 means no modification
    },

    cursor = {
        -- NVIDIA: hardware cursors glitch, draw them in software
        no_hardware_cursors = true,
    },
})
