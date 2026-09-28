#!/usr/bin/env bash
# Rename the current workspace (the desktop's <leader>rn).
# An empty name gives it back its number.
ws=$(hyprctl activeworkspace -j | python3 -c 'import json, sys; print(json.load(sys.stdin)["id"])') || exit 1
name=$(rofi -dmenu -p "Rename workspace $ws" -theme-str 'listview { enabled: false; }' </dev/null) || exit 0

# Quote the name as a Lua string (JSON strings are valid Lua once control
# characters are gone). Empty -> the workspace number again.
lua_name=$(python3 -c '
import json, sys
name = "".join(c for c in sys.argv[1] if c.isprintable()).strip() or sys.argv[2]
print(json.dumps(name, ensure_ascii=False))' "$name" "$ws")
hyprctl dispatch "hl.dsp.workspace.rename({ workspace = $ws, name = $lua_name })" >/dev/null
