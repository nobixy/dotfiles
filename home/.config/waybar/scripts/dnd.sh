#!/usr/bin/env bash
# Waybar: dunst do-not-disturb state. Refreshed by `pkill -RTMIN+8 waybar`.
if [ "$(dunstctl is-paused 2>/dev/null)" = true ]; then
    waiting=$(dunstctl count waiting 2>/dev/null || echo 0)
    printf '{"text":"%s","tooltip":"Do not disturb (%s waiting)\\nClick to resume","class":"on"}\n' $'\U000F009B' "$waiting"
else
    printf '{"text":"%s","tooltip":"Notifications on\\nClick: do not disturb, right click: previous","class":"off"}\n' $'\U000F009A'
fi
