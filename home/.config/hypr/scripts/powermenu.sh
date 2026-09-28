#!/usr/bin/env bash
# Power menu in rofi. Bound to mod+Escape and Waybar's power button.

lock=$'\U000F033E  Lock'
logout=$'\U000F0343  Log out'
suspend=$'\U000F0904  Suspend'
reboot=$'\U000F0709  Reboot'
shutdown=$'\U000F0425  Shut down'

choice=$(printf '%s\n' "$lock" "$logout" "$suspend" "$reboot" "$shutdown" |
    rofi -dmenu -i -no-custom -p "Power" -theme-str 'window { width: 300px; } listview { lines: 5; }')

# hyprshutdown closes apps gracefully (saving Chrome sessions etc.) first
leave() {
    if command -v hyprshutdown >/dev/null; then
        hyprshutdown ${1:+--post-cmd "$1"}
    elif [ -n "${1:-}" ]; then
        $1
    else
        hyprctl dispatch 'hl.dsp.exit()'
    fi
}

case "$choice" in
    "$lock")     ~/.config/hypr/scripts/lock.sh ;;
    "$logout")   leave ;;
    "$suspend")  systemctl suspend ;;
    "$reboot")   leave "systemctl reboot" ;;
    "$shutdown") leave "systemctl poweroff" ;;
esac
