#!/usr/bin/env bash
# Notification history in rofi (the desktop's Telescope diagnostics).
# Enter shows the picked notification again.
choice=$(dunstctl history | python3 -c '
import json, sys

for n in json.load(sys.stdin)["data"][0]:
    get = lambda key: n[key]["data"]
    body = " ".join(get("body").split())
    line = get("appname") + ": " + get("summary") + ("  —  " + body if body else "")
    print(str(get("id")) + "\t" + line)
' | rofi -dmenu -i -no-custom -p "Notifications" -display-columns 2 -display-column-separator $'\t') || exit 0

dunstctl history-pop "${choice%%$'\t'*}"
