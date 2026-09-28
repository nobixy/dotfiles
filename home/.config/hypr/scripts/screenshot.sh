#!/usr/bin/env bash
# Screenshots, saved to ~/Pictures/Screenshots and copied to the clipboard.
# usage: screenshot.sh region|window|monitor|all|edit
#   edit = pick a region and annotate it in satty (if installed)
set -uo pipefail

dir="$HOME/Pictures/Screenshots"
file="$dir/$(date +%F_%H-%M-%S).png"
mkdir -p "$dir"

# Region picker in the rice colours; Esc cancels without touching the clipboard
pick_region() {
    slurp -d -b 1e1e2e66 -c 33ccffee -s 33ccff22 -w 2
}

args=()
case "${1:-region}" in
    region | edit)
        geometry=$(pick_region) || exit 0
        args=(-g "$geometry")
        ;;
    window)
        geometry=$(hyprctl activewindow -j | python3 -c '
import json, sys
w = json.load(sys.stdin)
if not w:
    sys.exit(1)
print("%d,%d %dx%d" % (*w["at"], *w["size"]))') || exit 1
        args=(-g "$geometry")
        ;;
    monitor)
        output=$(hyprctl monitors -j | python3 -c '
import json, sys
print(next(m["name"] for m in json.load(sys.stdin) if m["focused"]))') || exit 1
        args=(-o "$output")
        ;;
    all) ;;
    *)
        echo "usage: $0 region|window|monitor|all|edit" >&2
        exit 2
        ;;
esac

if [ "${1:-}" = edit ]; then
    if command -v satty >/dev/null; then
        grim "${args[@]}" - | satty --filename - --output-filename "$file" \
            --copy-command wl-copy --early-exit --initial-tool arrow
        exit 0
    fi
    notify-send -u low "satty is not installed" "Saving without annotation (sudo pacman -S satty)"
fi

grim "${args[@]}" "$file" || { notify-send -u critical "Screenshot failed"; exit 1; }
wl-copy --type image/png < "$file"

action=$(notify-send -a screenshot -i "$file" -A open=Open -A folder="Show in folder" \
    "Screenshot saved" "$(basename "$file") · copied to clipboard")
case "$action" in
    open)   xdg-open "$file" ;;
    folder) xdg-open "$dir" ;;
esac
