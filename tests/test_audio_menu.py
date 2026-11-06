"""Audio controls regression checks. No real audio or Bluetooth commands."""
import importlib.util
import fcntl
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("audio_menu", ROOT / "home/.config/waybar/scripts/audio-menu.py")
audio = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audio)


def completed(stdout=""):
    return subprocess.CompletedProcess([], 0, stdout=stdout, stderr="")


def sink(name="sony", level=64225, bluetooth=True):
    return {"name": name, "description": "WH-1000XM5" if bluetooth else "Speakers",
            "properties": {"device.bus": "bluetooth" if bluetooth else "pci"},
            "volume": {"left": {"value": level}, "right": {"value": level}}, "mute": False}


class AudioTests(unittest.TestCase):
    def setUp(self):
        notification = patch.object(audio, "notify")
        notification.start()
        self.addCleanup(notification.stop)
        temporary = tempfile.TemporaryDirectory(prefix="audio-boost-")
        self.addCleanup(temporary.cleanup)
        state = patch.object(audio, "BOOST_STATE", Path(temporary.name) / "boost")
        state.start()
        self.addCleanup(state.stop)

    def test_sony_caps_both_channels_at_100_without_default_device_race(self):
        audio.BOOST_STATE.write_text("off\n")
        with patch.object(audio, "default_sink", return_value=sink()), patch.object(audio, "run") as run:
            audio.volume_up()
        self.assertEqual(run.call_args_list[0].args[0],
                         ["pactl", "set-sink-volume", "sony", "65536", "65536"])
        self.assertEqual(run.call_args_list[1].args[0], ["pactl", "set-sink-mute", "sony", "0"])

    def test_boost_defaults_on_and_allows_150_for_quiet_media(self):
        self.assertTrue(audio.boost_enabled())
        with patch.object(audio, "default_sink", return_value=sink(level=98000)), patch.object(audio, "run") as run:
            audio.volume_up()
        self.assertEqual(run.call_args_list[0].args[0][-2:], ["98304", "98304"])

    def test_enabling_boost_persists_without_changing_volume(self):
        with patch.object(audio, "run") as run:
            audio.set_boost(True)
        self.assertTrue(audio.boost_enabled())
        run.assert_not_called()

    def test_normal_mode_clamps_before_disabling_boost(self):
        with patch.object(audio, "sinks", return_value=[sink(level=81725), sink("speakers", 90000, False)]), \
             patch.object(audio, "run") as run:
            audio.set_boost(False)
        self.assertFalse(audio.boost_enabled())
        run.assert_called_once_with(["pactl", "set-sink-volume", "sony", "65536", "65536"])

    def test_other_outputs_keep_existing_150_percent_limit(self):
        with patch.object(audio, "default_sink", return_value=sink("speakers", 98000, False)), patch.object(audio, "run") as run:
            audio.volume_up()
        self.assertEqual(run.call_args_list[0].args[0][-2:], ["98304", "98304"])

    def test_failed_volume_change_never_unmutes(self):
        with patch.object(audio, "default_sink", return_value=sink()), \
             patch.object(audio, "run", side_effect=subprocess.CalledProcessError(1, [])) as run:
            with self.assertRaises(subprocess.CalledProcessError):
                audio.volume_up()
        self.assertEqual(run.call_count, 1)

    def test_cancel_menu_never_starts_bluetooth_or_changes_audio(self):
        with tempfile.TemporaryDirectory() as temporary, patch.object(audio, "RUNTIME", Path(temporary)), \
             patch.object(audio, "default_sink", return_value=sink()), patch.object(audio, "choose", return_value=None), \
             patch.object(audio, "run") as run, patch.object(audio, "ensure_daemon") as daemon:
            audio.menu()
        run.assert_not_called()
        daemon.assert_not_called()

    def test_cancel_output_selection_does_not_change_default_or_move_apps(self):
        with patch.object(audio, "sinks", return_value=[sink()]), patch.object(audio, "choose", return_value=None), \
             patch.object(audio, "run", return_value=completed("sony\n")) as run:
            audio.choose_output()
        self.assertEqual(run.call_count, 1)

    def test_disappearing_output_is_not_selected(self):
        with patch.object(audio, "sinks", side_effect=[[sink()], []]), patch.object(audio, "choose", return_value=0), \
             patch.object(audio, "run", return_value=completed("sony\n")) as run:
            with self.assertRaises(audio.AudioError):
                audio.choose_output()
        self.assertEqual(run.call_count, 1)

    def test_output_selection_moves_playing_apps(self):
        def run(args, **kwargs):
            if args == ["pactl", "get-default-sink"]:
                return completed("other\n")
            if args[-1] == "sink-inputs":
                return completed('[{"index":7}]')
            return completed()
        with patch.object(audio, "sinks", return_value=[sink()]), patch.object(audio, "choose", return_value=0), \
             patch.object(audio, "run", side_effect=run) as calls, patch.object(audio, "notify"):
            audio.choose_output()
        self.assertIn(unittest.mock.call(["pactl", "set-default-sink", "sony"]), calls.call_args_list)
        self.assertIn(unittest.mock.call(["pactl", "move-sink-input", "7", "sony"]), calls.call_args_list)

    def test_other_headphone_model_cannot_receive_xm5_preset(self):
        with patch.object(audio, "ensure_daemon", return_value={"connected": True, "name": "WH-1000XM6"}), \
             patch.object(audio, "ipc") as ipc:
            with self.assertRaises(audio.AudioError):
                audio.sony_action("preset", "punch")
        ipc.assert_not_called()

    def test_persistent_stream_move_error_is_reported(self):
        def run(args, **kwargs):
            if args == ["pactl", "get-default-sink"]:
                return completed("other\n")
            if args[-1] == "sink-inputs":
                return completed('[{"index":7}]')
            if "move-sink-input" in args:
                raise subprocess.CalledProcessError(1, args)
            return completed()
        with patch.object(audio, "sinks", return_value=[sink()]), patch.object(audio, "choose", return_value=0), \
             patch.object(audio, "run", side_effect=run), patch.object(audio, "notify") as notify:
            audio.choose_output()
        self.assertTrue(notify.call_args.kwargs["error"])

    def test_failed_setting_is_not_retried_or_reported_as_success(self):
        with patch.object(audio, "connected_xm5"), patch.object(audio, "ipc", side_effect=socket.timeout()) as ipc, \
             patch.object(audio, "notify") as notify:
            with self.assertRaises(socket.timeout):
                audio.sony_action("preset", "punch")
        ipc.assert_called_once_with("eqCustom", {"clearBass": 5, "bands": [-2, 0, 2, 1, 1]})
        notify.assert_not_called()

    def test_rofi_uses_indices_and_rejects_custom_input(self):
        with patch.object(audio.subprocess, "run", return_value=completed("$(touch bad)")) as run:
            self.assertIsNone(audio.choose("Audio", ["Mute"]))
        argv = run.call_args.args[0]
        self.assertIn("-no-custom", argv)
        self.assertIn("-no-sort", argv)

    def test_device_names_cannot_create_extra_menu_rows(self):
        self.assertEqual(audio.display_name("Sony\r\nSpeakers\0"), "Sony Speakers")

    def test_launcher_does_not_need_local_bin_on_path(self):
        with tempfile.TemporaryDirectory(prefix="audio-launch-") as temporary:
            home = Path(temporary)
            binary = home / ".local/bin/sony-device-center"
            binary.parent.mkdir(parents=True)
            binary.write_text('#!/bin/sh\nprintf launched > "$HOME/launched"\n')
            binary.chmod(0o755)
            entry = ROOT / "home/.local/share/applications/sony-device-center.desktop"
            result = subprocess.run(["gio", "launch", str(entry)], text=True, capture_output=True,
                                    timeout=5, env={**os.environ, "HOME": str(home), "PATH": "/usr/bin:/bin"})
            self.assertEqual(result.returncode, 0, result.stderr)
            for _ in range(30):
                if (home / "launched").exists():
                    break
                time.sleep(0.05)
            self.assertTrue((home / "launched").exists())

    def test_gui_child_retains_single_instance_lock(self):
        with tempfile.TemporaryDirectory(prefix="audio-gui-") as temporary:
            root = Path(temporary)
            binary = root / "fake-gui"
            binary.write_text('#!/bin/sh\nexec sleep 30\n')
            binary.chmod(0o755)
            processes = []
            real_popen = subprocess.Popen
            def spawn(*args, **kwargs):
                process = real_popen(*args, **kwargs)
                processes.append(process)
                return process
            try:
                with patch.object(audio, "APP", binary), patch.object(audio, "RUNTIME", root), \
                     patch.dict(os.environ, {"XDG_STATE_HOME": str(root / "state")}), \
                     patch.object(audio, "ensure_daemon", return_value={}), \
                     patch.object(audio.subprocess, "Popen", side_effect=spawn), \
                     patch.object(audio, "run", return_value=completed("[]")):
                    audio.headphones()
                    with (root / "sony-headphone-gui.lock").open("w") as lock:
                        with self.assertRaises(BlockingIOError):
                            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
                    audio.headphones()
                    self.assertEqual(len(processes), 1)
            finally:
                for process in processes:
                    process.terminate()
                    process.wait(timeout=3)
            with (root / "sony-headphone-gui.lock").open("w") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)

    def test_directly_invoked_scripts_are_executable(self):
        for name in ["install-sony-audio.sh", "home/.local/bin/sony-device-center",
                     "home/.config/hypr/scripts/volume.sh"]:
            self.assertTrue(os.access(ROOT / name, os.X_OK), name)

    def exchange(self, reply):
        with tempfile.TemporaryDirectory() as temporary:
            endpoint = Path(temporary) / "controller.sock"
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as server:
                server.bind(str(endpoint))
                server.listen(1)
                received = []
                def serve():
                    connection, _ = server.accept()
                    with connection:
                        received.append(json.loads(connection.recv(16384)))
                        payload = json.dumps(reply).encode() + b"\n"
                        connection.sendall(payload[:8])
                        connection.sendall(payload[8:])
                worker = threading.Thread(target=serve)
                worker.start()
                try:
                    with patch.object(audio, "SOCKET", endpoint):
                        result = audio.ipc(timeout=1)
                    return result, received
                finally:
                    worker.join(timeout=2)

    def test_real_local_ipc_handles_split_response(self):
        result, requests = self.exchange({"version": 1, "id": "waybar", "ok": True,
                                          "data": {"connected": True}})
        self.assertTrue(result["connected"])
        self.assertEqual(requests[0]["method"], "snapshot")

    def test_ipc_rejects_mismatched_response(self):
        with self.assertRaises(audio.AudioError):
            self.exchange({"version": 1, "id": "somebody-else", "ok": True, "data": {}})

    def test_ipc_rejects_malformed_data(self):
        with self.assertRaises(audio.AudioError):
            self.exchange({"version": 1, "id": "waybar", "ok": True, "data": []})


if __name__ == "__main__":
    unittest.main()
