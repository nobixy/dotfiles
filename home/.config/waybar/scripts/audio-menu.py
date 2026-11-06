#!/usr/bin/env python3
"""Waybar audio controls. Sony writes use the shared daemon, never direct Bluetooth."""
import argparse
import fcntl
import html
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import sys
import tempfile
import time

VERSION = "0.1.6-native"
APP = Path.home() / ".local/opt/sony-device-center" / VERSION / "bin/sony-device-center"
RUNTIME = Path(os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}"))
SOCKET = RUNTIME / "sony-device-center.sock"
BOOST_STATE = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "waybar/headphone-volume-boost"
PRESETS = {
    "punch": (5, [-2, 0, 2, 1, 1]),
    "bass": (8, [-2, 0, 2, 1, 1]),
    "original": (8, [-1, 1, 0, 3, 5]),
}


class AudioError(Exception):
    pass


def run(args, **kwargs):
    return subprocess.run(args, text=True, capture_output=True, check=True,
                          timeout=kwargs.pop("timeout", 5), **kwargs)


def notify(message, error=False):
    subprocess.run(["notify-send", "-a", "Audio", "-h", "string:x-dunst-stack-tag:sony-audio",
                    "-u", "normal" if error else "low",
                    "-t", "3500", "Audio", message], check=False,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def sinks():
    return json.loads(run(["pactl", "-f", "json", "list", "sinks"]).stdout)


def default_sink():
    name = run(["pactl", "get-default-sink"]).stdout.strip()
    return next((s for s in sinks() if s["name"] == name), None)


def is_xm5(sink):
    props = sink.get("properties", {})
    return (props.get("device.bus") == "bluetooth" and
            (props.get("device.product.id") == "0x0df0" or
             "WH-1000XM5" in sink.get("description", "")))


def display_name(text):
    # Rofi uses one row per line. Device names must never create extra choices.
    return " ".join(str(text).replace("\0", "").split())


def boost_enabled():
    try:
        return BOOST_STATE.read_text().strip() != "off"
    except FileNotFoundError:
        return True  # Requested default: allow amplification for quiet media.


def set_boost(enabled):
    if not enabled:
        for sink in sinks():
            if is_xm5(sink):
                volumes = [str(min(65536, v["value"])) for v in sink["volume"].values()]
                run(["pactl", "set-sink-volume", sink["name"], *volumes])
    BOOST_STATE.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile("w", dir=BOOST_STATE.parent, delete=False) as saved:
        saved.write("on\n" if enabled else "off\n")
    os.replace(saved.name, BOOST_STATE)
    notify("Volume boost enabled — turn up to 150%" if enabled else "Normal headphone volume — maximum 100%")


def volume_up():
    sink = default_sink()
    if sink is None:
        raise AudioError("No audio output is connected.")
    # Target the inspected device, even if the default changes during the command.
    limit = 65536 if is_xm5(sink) and not boost_enabled() else 98304
    volumes = [str(min(limit, v["value"] + 3277)) for v in sink["volume"].values()]
    run(["pactl", "set-sink-volume", sink["name"], *volumes])
    run(["pactl", "set-sink-mute", sink["name"], "0"])


def ipc(method="snapshot", params=None, timeout=5):
    request = {"version": 1, "id": "waybar", "method": method, "params": params or {}}
    with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as client:
        client.settimeout(timeout)
        client.connect(str(SOCKET))
        _, uid, _ = struct.unpack("3i", client.getsockopt(socket.SOL_SOCKET, socket.SO_PEERCRED, 12))
        if uid != os.geteuid():
            raise AudioError("The headphone controller has an unexpected owner.")
        client.sendall(json.dumps(request).encode() + b"\n")
        data = bytearray()
        deadline = time.monotonic() + timeout
        while b"\n" not in data:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                raise AudioError("Headphone controls took too long to respond.")
            client.settimeout(remaining)
            part = client.recv(4096)
            if not part:
                raise AudioError("Headphone controls disconnected. Please try again.")
            data.extend(part)
            if len(data) > 262144:
                raise AudioError("Invalid response from headphone controls.")
    reply = json.loads(data.split(b"\n", 1)[0])
    if not isinstance(reply, dict) or reply.get("version") != 1 or reply.get("id") != request["id"]:
        raise AudioError("The headphone controller needs updating.")
    if not reply.get("ok"):
        error = reply.get("error", {})
        raise AudioError(error.get("message", "The change could not be applied.") if isinstance(error, dict)
                         else "The change could not be applied.")
    if not isinstance(reply.get("data"), dict):
        raise AudioError("Invalid response from headphone controls.")
    return reply["data"]


def ensure_daemon():
    if not APP.is_file():
        raise AudioError("Sony controls are not installed. Run the audio setup in your dotfiles.")
    run(["systemctl", "--user", "start", "sonyd.service"])
    deadline = time.monotonic() + 8
    while True:
        try:
            return ipc(timeout=0.6)
        except (OSError, ValueError, AudioError):
            if time.monotonic() >= deadline:
                raise AudioError("Headphone controls are unavailable. Close other Sony control apps and try again.") from None
            time.sleep(0.15)


def connected_xm5(feature=None):
    notify("Connecting headphone controls…")
    state = ensure_daemon()
    # The daemon discovers connected Sony devices; do not write a different model.
    deadline = time.monotonic() + 7
    while not state.get("connected") and time.monotonic() < deadline:
        time.sleep(0.2)
        state = ipc(timeout=1)
    if not state.get("connected"):
        raise AudioError("Connect your WH-1000XM5 headphones in Bluetooth settings first.")
    if state.get("name") != "WH-1000XM5":
        raise AudioError("These music presets are for WH-1000XM5 headphones. Use Headphone controls for this device.")
    if feature and not state.get("capabilities", {}).get(feature):
        raise AudioError("This setting is unavailable on the connected headphones.")
    return state


def sony_action(action, preset=None):
    connected_xm5("equalizer" if action == "preset" else "anc" if action == "nc" else "ambient")
    if action == "nc":
        state = ipc("anc", {"enabled": True})
        notify("Noise cancelling on")
    elif action == "ambient":
        state = ipc("ambient", {"level": 20, "focusOnVoice": False})
        notify("Ambient Sound on — hear your surroundings")
    else:
        bass, bands = PRESETS[preset]
        state = ipc("eqCustom", {"clearBass": bass, "bands": bands})
        label = {"punch": "Punch and detail", "bass": "More bass", "original": "Previous sound"}[preset]
        notify(f"{label} applied")
    return state


def headphones():
    # The Qt app decides between IPC and direct access at launch. Gate on an
    # actual daemon response rather than systemd's Type=simple start completion.
    gui_lock = (RUNTIME / "sony-headphone-gui.lock").open("w")
    try:
        fcntl.flock(gui_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        gui_lock.close()
        try:
            windows = json.loads(run(["hyprctl", "-j", "clients"]).stdout)
            for window in windows:
                if "sony" in window.get("class", "").lower() or "Sony Device Center" in window.get("title", ""):
                    run(["hyprctl", "dispatch", "focuswindow", "address:" + window["address"]])
                    return
        except (ValueError, OSError, subprocess.SubprocessError):
            pass
        notify("Headphone controls are already open.")
        return
    try:
        notify("Opening headphone controls…")
        ensure_daemon()
        state_dir = Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state"))) / "sony-device-center"
        state_dir.mkdir(parents=True, exist_ok=True)
        with (state_dir / "gui.log").open("a") as log:
            subprocess.Popen([str(APP)], stdout=log, stderr=log, start_new_session=True,
                             pass_fds=(gui_lock.fileno(),))
    finally:
        gui_lock.close()  # The child retains the lock until its window exits.


def choose(title, labels, message=""):
    result = subprocess.run(
        ["rofi", "-dmenu", "-i", "-no-custom", "-no-sort", "-format", "i",
         "-p", title, "-mesg", html.escape(message),
         "-theme-str", 'listview { lines: 7; } entry { placeholder: "Search or choose"; }'],
        input="\n".join(labels) + "\n", text=True, capture_output=True, check=False)
    if result.returncode:
        return None
    value = result.stdout.strip()
    return int(value) if value.isdigit() and int(value) < len(labels) else None


def choose_output():
    available = sinks()
    current = run(["pactl", "get-default-sink"]).stdout.strip()
    labels = [("✓  " if s["name"] == current else "   ") + display_name(s.get("description", s["name"]))
              for s in available]
    selection = choose("Audio output", [*labels, "←  Back"], "Choose where music and app audio play")
    if selection is None or selection == len(available):
        return
    # Recheck the device before changing defaults; Bluetooth may disconnect.
    name = available[selection]["name"]
    if not any(s["name"] == name for s in sinks()):
        raise AudioError("That audio output disconnected. Please choose again.")
    run(["pactl", "set-default-sink", name])
    failed = set()
    for stream in json.loads(run(["pactl", "-f", "json", "list", "sink-inputs"]).stdout):
        try:
            run(["pactl", "move-sink-input", str(stream["index"]), name])
        except subprocess.CalledProcessError:
            failed.add(stream["index"])
    if failed:
        alive = {s["index"] for s in json.loads(run(["pactl", "-f", "json", "list", "sink-inputs"]).stdout)}
        if failed & alive:
            notify("Output changed. Some apps need reopening or adjusting in App volumes.", error=True)
            return
    notify("Audio output: " + available[selection].get("description", name))


def mixer():
    subprocess.Popen(["pavucontrol"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                     start_new_session=True)


def menu():
    with (RUNTIME / "waybar-audio-menu.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        while True:
            sink = default_sink()
            if sink:
                level = max((v["value"] for v in sink["volume"].values()), default=0)
                header = f'{sink.get("description", "Audio")} · {round(level / 655.36)}%'
                if sink.get("mute"):
                    header += " · muted"
            else:
                header = "No audio output connected"
            boost_label = "󰓅  Headphone boost · on (150%)" if boost_enabled() else "󰓅  Headphone boost · off (100%)"
            choice = choose("Audio", ["󰋋  Headphone controls", "󰂚  Noise control",
                "󰎆  Music presets", boost_label, "󰕾  Choose audio output", "󰍬  App volumes and microphone",
                "󰝟  Unmute" if sink and sink.get("mute") else "󰝟  Mute"], header)
            if choice is None:
                return
            try:
                if choice == 0:
                    headphones()
                    return
                if choice == 1:
                    sub = choose("Noise control", ["Noise cancelling — block outside noise",
                        "Ambient Sound — hear surroundings", "←  Back"], "For your WH-1000XM5 headphones")
                    if sub in (0, 1):
                        sony_action("nc" if sub == 0 else "ambient")
                elif choice == 2:
                    sub = choose("Music sound", ["Punch and detail · recommended", "More bass",
                        "Previous sound", "←  Back"], "Presets keep your current noise-control mode")
                    if sub in (0, 1, 2):
                        sony_action("preset", ("punch", "bass", "original")[sub])
                elif choice == 3:
                    sub = choose("Headphone boost", ["Allow up to 150% · for quiet media",
                        "Normal headphones · return to 100% maximum", "←  Back"],
                        "Amplification may distort louder recordings. Turn up gradually.")
                    if sub in (0, 1):
                        set_boost(sub == 0)
                elif choice == 4:
                    choose_output()
                elif choice == 5:
                    mixer()
                    return
                elif choice == 6:
                    run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
            except (AudioError, OSError, ValueError, subprocess.SubprocessError) as exc:
                notify(str(exc), error=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", nargs="?", default="menu",
                        choices=["menu", "headphones", "volume-up", "outputs", "nc", "ambient", "preset", "status"])
    parser.add_argument("preset", nargs="?", choices=PRESETS)
    args = parser.parse_args()
    try:
        if args.action == "menu":
            menu()
        elif args.action == "headphones":
            headphones()
        elif args.action == "volume-up":
            volume_up()
        elif args.action == "outputs":
            choose_output()
        elif args.action == "status":
            print(json.dumps(ipc(), indent=2))
        elif args.action == "preset":
            if args.preset is None:
                parser.error("choose a preset: punch, bass, or original")
            sony_action("preset", args.preset)
        else:
            sony_action(args.action)
    except (AudioError, OSError, ValueError, subprocess.SubprocessError) as exc:
        notify(str(exc), error=True)
        print(str(exc), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
