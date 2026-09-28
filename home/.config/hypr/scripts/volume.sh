#!/usr/bin/env bash
# Volume / microphone control with an on-screen progress notification (dunst).
# usage: volume.sh up|down|mute|mic
set -euo pipefail

sink=@DEFAULT_AUDIO_SINK@
source=@DEFAULT_AUDIO_SOURCE@

case "${1:-}" in
    up)   wpctl set-mute "$sink" 0; wpctl set-volume -l 1.5 "$sink" 5%+ ;;
    down) wpctl set-volume "$sink" 5%- ;;
    mute) wpctl set-mute "$sink" toggle ;;
    mic)  wpctl set-mute "$source" toggle ;;
    *)    echo "usage: $0 up|down|mute|mic" >&2; exit 2 ;;
esac

osd() { # osd <stack-tag> <icon> <title> [percent]
    notify-send -a osd -u low -t 1500 -i "$2" -h "string:x-dunst-stack-tag:$1" \
        ${4:+-h "int:value:$4"} "$3" "${4:+$4%}"
}

if [ "$1" = mic ]; then
    if wpctl get-volume "$source" | grep -q MUTED; then
        osd mic microphone-sensitivity-muted-symbolic "Microphone muted"
    else
        osd mic audio-input-microphone-symbolic "Microphone on"
    fi
    exit 0
fi

# "Volume: 0.45" or "Volume: 0.45 [MUTED]"
read -r _ level muted < <(wpctl get-volume "$sink")
percent=$(awk -v l="$level" 'BEGIN { printf "%d", l * 100 + 0.5 }')

if [ -n "${muted:-}" ]; then
    osd volume audio-volume-muted-symbolic "Muted" "$percent"
elif [ "$percent" -ge 66 ]; then
    osd volume audio-volume-high-symbolic "Volume" "$percent"
elif [ "$percent" -ge 33 ]; then
    osd volume audio-volume-medium-symbolic "Volume" "$percent"
else
    osd volume audio-volume-low-symbolic "Volume" "$percent"
fi
