"""Build pinned upstream Sony controls; validate before replacing an installation."""
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import socket
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request

COMMIT = "897022b041b7b312f6ccbd6956e5f0c6e6e76b57"  # upstream v0.1.6
EXPECTED = "733c8b02635bc3cb47d553dadec0e7b7a85b757324d1701c855603191d5876b6"
URL = f"https://codeload.github.com/marconvcm/sony-device-center/tar.gz/{COMMIT}"
BINARIES = {"sony-device-center": "device-center", "sonyd": "sonyd", "sonyctl": "sonyctl"}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def stop(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)


def smoke_test(staged, temporary):
    # Fake headset, isolated from real Bluetooth, live IPC, and user settings.
    runtime = temporary / "runtime"
    runtime.mkdir(mode=0o700)
    env = {**os.environ, "XDG_RUNTIME_DIR": str(runtime), "XDG_CONFIG_HOME": str(temporary / "config"),
           "XDG_CACHE_HOME": str(temporary / "cache"), "XDG_STATE_HOME": str(temporary / "state"),
           "DBUS_SYSTEM_BUS_ADDRESS": "unix:path=" + str(temporary / "no-system-bus"),
           "QT_QPA_PLATFORM": "offscreen", "QT_QUICK_BACKEND": "software"}
    log_path = temporary / "smoke.log"
    with log_path.open("w+") as log:
        daemon = subprocess.Popen([str(staged / "bin/sonyd"), "--simulated"], env=env, stdout=log, stderr=log)
        gui = None
        try:
            for _ in range(40):
                if (runtime / "sony-device-center.sock").exists():
                    break
                if daemon.poll() is not None:
                    raise RuntimeError("The simulated controller failed to start.")
                time.sleep(0.1)
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as control:
                control.settimeout(3)
                control.connect(str(runtime / "sony-device-center.sock"))
                control.sendall(b'{"version":1,"id":"smoke","method":"snapshot","params":{}}\n')
                response = bytearray()
                deadline = time.monotonic() + 4
                while b"\n" not in response:
                    remaining = deadline - time.monotonic()
                    if remaining <= 0:
                        raise RuntimeError("Simulated controller timed out.")
                    control.settimeout(remaining)
                    part = control.recv(4096)
                    if not part or len(response) + len(part) > 262144:
                        raise RuntimeError("Invalid simulated controller response.")
                    response.extend(part)
                reply = json.loads(response.split(b"\n", 1)[0])
                if reply.get("version") != 1 or reply.get("id") != "smoke" or not reply.get("ok"):
                    raise RuntimeError("The simulated controller did not become ready.")
            gui = subprocess.Popen([str(staged / "bin/sony-device-center")], env=env, stdout=log, stderr=log)
            time.sleep(2)
            if gui.poll() is not None:
                log.flush()
                raise RuntimeError("Sony GUI smoke test failed: " + log_path.read_text()[-1600:])
        finally:
            if gui is not None:
                stop(gui)
            stop(daemon)


def main():
    if platform.system() != "Linux" or platform.machine() != "x86_64":
        raise SystemExit("This Sony audio setup targets x86_64 Linux.")
    for executable in ["cmake", "ninja", "c++", "pkg-config"]:
        if not shutil.which(executable):
            raise SystemExit(f"Missing {executable}; install the dotfiles package list first.")
    qt = subprocess.check_output(["pkg-config", "--modversion", "Qt6Core"], text=True).strip()
    recipe = Path(__file__).with_name("CMakeLists.txt")
    identity = {"commit": COMMIT, "source_sha256": EXPECTED, "qt": qt,
                "recipe_sha256": digest(recipe), "installer_sha256": digest(Path(__file__))}
    base = Path.home() / ".local/opt/sony-device-center"
    target = base / "0.1.6-native"
    marker = target / ".build-info.json"
    previous = json.loads(marker.read_text()) if marker.exists() else {}
    current = (all(previous.get(k) == v for k, v in identity.items()) and
               all((target / "bin" / name).is_file() and os.access(target / "bin" / name, os.X_OK)
                   and digest(target / "bin" / name) == previous.get("binaries", {}).get(name)
                   for name in BINARIES))
    if current:
        print("Sony controls already match this Qt version and verified source.")
        return
    if target.exists() and not marker.exists():
        raise SystemExit("Existing unrecognized native installation was preserved.")
    base.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".build-", dir=base) as temporary:
        temporary = Path(temporary)
        archive = temporary / "source.tar.gz"
        local = os.environ.get("SONY_AUDIO_ARCHIVE")
        if local:
            archive.write_bytes(Path(local).read_bytes())
        else:
            with urllib.request.urlopen(URL, timeout=40) as response:
                archive.write_bytes(response.read())
        if digest(archive) != EXPECTED:
            raise SystemExit("Source checksum mismatch; existing installation was preserved.")
        with tarfile.open(archive) as package:
            package.extractall(temporary / "source", filter="data")
        source = temporary / "source" / f"sony-device-center-{COMMIT}"
        wrapper = temporary / "recipe"
        wrapper.mkdir()
        shutil.copy2(recipe, wrapper / "CMakeLists.txt")
        build = temporary / "build"
        subprocess.run(["cmake", "-S", str(wrapper), "-B", str(build), "-G", "Ninja",
                        "-DCMAKE_BUILD_TYPE=Release", "-DSONY_SOURCE=" + str(source)], check=True)
        subprocess.run(["cmake", "--build", str(build), "--target", *BINARIES,
                        "--parallel", str(min(os.cpu_count() or 2, 6))], check=True)
        staged = temporary / "installed"
        (staged / "bin").mkdir(parents=True)
        for name, folder in BINARIES.items():
            shutil.copy2(build / folder / name, staged / "bin" / name)
        shutil.copy2(source / "LICENSE", staged / "LICENSE")
        smoke_test(staged, temporary)
        metadata = {**identity, "source": URL,
                    "binaries": {name: digest(staged / "bin" / name) for name in BINARIES}}
        (staged / ".build-info.json").write_text(json.dumps(metadata, indent=2) + "\n")
        old = temporary / "previous"
        if target.exists():
            target.rename(old)
        try:
            staged.rename(target)
        except OSError:
            if old.exists():
                old.rename(target)
            raise
    print(f"Verified source, built and smoke-tested Sony controls for Qt {qt}.")


if __name__ == "__main__":
    main()
