#!/usr/bin/env bash
# Recently used files in rofi (the desktop's <leader>fr). The list is GTK's
# recently-used.xbel, filled by file pickers and apps. Enter opens the file
# or folder with its default app.
choice=$(python3 -c '
import os, urllib.parse, xml.etree.ElementTree as ET

home = os.path.expanduser("~")
try:
    root = ET.parse(home + "/.local/share/recently-used.xbel").getroot()
except (OSError, ET.ParseError):
    raise SystemExit

newest_first = sorted(root.iter("bookmark"),
                      key=lambda b: b.get("visited") or b.get("modified") or "", reverse=True)
seen = set()
for b in newest_first:
    href = b.get("href", "")
    if not href.startswith("file://"):
        continue
    path = urllib.parse.unquote(href[len("file://"):])
    if path in seen or not os.path.exists(path):
        continue
    seen.add(path)
    print(path.replace(home, "~", 1))
' | rofi -dmenu -i -no-custom -p "Recent") || exit 0

xdg-open "${choice/#\~/$HOME}"
