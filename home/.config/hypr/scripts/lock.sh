#!/bin/sh
# Lock the session with hyprlock, never starting a second instance.
# Used by SUPER+L, the power menu and hypridle.
if command -v hyprlock >/dev/null 2>&1; then
    pidof hyprlock >/dev/null || exec hyprlock
else
    notify-send -u critical "Screen lock unavailable" "Install it with: sudo pacman -S hyprlock hypridle"
fi
