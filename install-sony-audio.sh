#!/usr/bin/env bash
# Build the pinned upstream source against this machine's Qt.
set -euo pipefail
if (( EUID == 0 )); then
    printf 'Run this as your normal user.\n' >&2
    exit 1
fi
audio_setup=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/packages/sony-device-center/install.py
python3 "$audio_setup"
systemctl --user daemon-reload
if systemctl --user is-active --quiet sonyd.service; then
    systemctl --user restart sonyd.service
fi
printf 'Ready: click the Waybar audio button or open Sony Device Center.\n'
