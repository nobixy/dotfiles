"""Installer failures preserve the previous application; no real builds/downloads."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("sony_installer", ROOT / "packages/sony-device-center/install.py")
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class InstallerTests(unittest.TestCase):
    def exercise_failure(self, valid_source):
        with tempfile.TemporaryDirectory(prefix="sony-install-test-") as temporary:
            home = Path(temporary)
            target = home / ".local/opt/sony-device-center/0.1.6-native"
            target.mkdir(parents=True)
            (target / ".build-info.json").write_text("{}")
            (target / "keep").write_text("previous working install")
            archive = home / "source.tar.gz"
            source = home / ("sony-device-center-" + installer.COMMIT)
            source.mkdir()
            (source / "LICENSE").write_text("fixture")
            with tarfile.open(archive, "w:gz") as package:
                package.add(source, arcname=source.name)
            expected = hashlib.sha256(archive.read_bytes()).hexdigest() if valid_source else "0" * 64
            with patch.object(installer.Path, "home", return_value=home), \
                 patch.object(installer, "EXPECTED", expected), \
                 patch.object(installer.shutil, "which", return_value="/test/tool"), \
                 patch.object(installer.subprocess, "check_output", return_value="6.12.0\n"), \
                 patch.object(installer.subprocess, "run", side_effect=subprocess.CalledProcessError(1, "cmake")) as build, \
                 patch.dict(os.environ, {"SONY_AUDIO_ARCHIVE": str(archive)}):
                with self.assertRaises(subprocess.CalledProcessError if valid_source else SystemExit):
                    installer.main()
            self.assertEqual((target / "keep").read_text(), "previous working install")
            self.assertEqual(json.loads((target / ".build-info.json").read_text()), {})
            self.assertFalse(list(target.parent.glob(".build-*")))
            self.assertEqual(build.call_count, 1 if valid_source else 0)

    def test_checksum_failure_preserves_previous_install(self):
        self.exercise_failure(False)

    def test_configure_failure_preserves_previous_install(self):
        self.exercise_failure(True)


if __name__ == "__main__":
    unittest.main()
