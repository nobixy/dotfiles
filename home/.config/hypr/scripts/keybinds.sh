#!/usr/bin/env bash
# Keybind cheatsheet: every bind that has a description, searchable in rofi.
# Descriptions come from keybinds.lua via `hyprctl binds`.

hyprctl binds -j | python3 -c '
import json, sys

MODS = [(64, "SUPER"), (8, "ALT"), (4, "CTRL"), (1, "SHIFT")]
KEYS = {
    "mouse:272": "Left drag", "mouse:273": "Right drag",
    "mouse_down": "Scroll down", "mouse_up": "Scroll up",
    "left": "Left", "right": "Right", "up": "Up", "down": "Down",
    "Print": "PrtSc", "Return": "Enter",
    "backslash": "\\", "bracketleft": "[", "bracketright": "]", "grave": "`", "slash": "/",
    "XF86AudioRaiseVolume": "Volume+ key", "XF86AudioLowerVolume": "Volume- key",
    "XF86AudioMute": "Mute key", "XF86AudioMicMute": "Mic mute key",
    "XF86AudioNext": "Next key", "XF86AudioPrev": "Prev key",
    "XF86AudioPlay": "Play key", "XF86AudioPause": "Pause key",
}

def chord(b):
    mods = [name for bit, name in MODS if b["modmask"] & bit]
    key = KEYS.get(b["key"], b["key"])
    if b["key"] == "slash" and "SHIFT" in mods:
        mods.remove("SHIFT")
        key = "?"
    if "1-10" in b["description"]:
        key = "1…0"
    return " + ".join(mods + [key])

binds = json.load(sys.stdin)

# Leader groups: the opener is described "+<submap>" (see keybinds.lua), and
# the keys inside the group are listed as "<opener>, <key>". A group inside a
# group is the submap "<parent> › <name>", opened by "+<name>" in the parent.
openers = {b["description"][1:]: chord(b) for b in binds
           if not b["submap"] and b["description"].startswith("+")}
for _ in range(3):  # nesting depth
    for b in binds:
        if b["submap"] in openers and b["description"].startswith("+"):
            openers[b["submap"] + " › " + b["description"][1:]] = openers[b["submap"]] + ", " + b["key"]

rows, seen = [], set()
for b in binds:
    if not b.get("has_description"):
        continue
    if b["description"].startswith("+"):
        continue  # a group opener: listed through its keys
    if b["submap"]:
        if b["submap"] not in openers:
            continue
        keys = openers[b["submap"]] + ", " + chord(b)
        desc = b["submap"] + ": " + b["description"]
    else:
        keys, desc = chord(b), b["description"]
    if (keys, desc) not in seen:
        seen.add((keys, desc))
        rows.append((keys, desc))

width = max(len(keys) for keys, _ in rows)
for keys, desc in rows:
    print(f"{keys:<{width}}   {desc}")
' | rofi -dmenu -i -no-custom -p "Keybinds" -theme-str 'window { width: 820px; } listview { lines: 16; }' >/dev/null
