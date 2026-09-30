#!/usr/bin/env bash
# Client for the which-key overlay (whichkey-overlay.py); starts it if needed.
# usage: whichkey.sh show <view> <monitor-x> <monitor-y> [<window-class> <window-title>]
#        whichkey.sh hide
# Fields travel tab-separated, so views and titles may contain spaces.
fifo="${XDG_RUNTIME_DIR:-/tmp}/hypr-whichkey.fifo"

send() {
    local IFS=$'\t'
    # A FIFO with no reader would block forever; give up after 0.3 s
    [ -p "$fifo" ] && timeout 0.3 sh -c 'printf "%s\n" "$1" > "$2"' _ "$*" "$fifo"
}

send "$@" && exit 0
[ "${1:-}" = hide ] && exit 0 # not running, nothing to hide

setsid -f "$(dirname "$0")/whichkey-overlay.py" >/dev/null 2>&1
for _ in 1 2 3 4 5 6 7 8 9 10; do
    sleep 0.1
    send "$@" && exit 0
done
