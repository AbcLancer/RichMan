"""Packaging guards: rollback, concurrency, false success and bundled data."""
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
import zipfile

spec = importlib.util.spec_from_file_location("package_game", Path(__file__).with_name("package_game.py"))
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class PackagingTests(unittest.TestCase):
    def test_presets_restore_after_failure(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            presets = root / "export_presets.cfg"
            original = package.PRESETS.read_bytes()
            presets.write_bytes(original)
            with patch.object(package, "ROOT", root), patch.object(package, "PRESETS", presets):
                with self.assertRaisesRegex(RuntimeError, "simulated"):
                    with package.configured_presets({"version": "2.3.4", "version_code": 12}):
                        self.assertIn('version/name="2.3.4"', presets.read_text())
                        raise RuntimeError("simulated exporter failure")
                self.assertEqual(presets.read_bytes(), original)
                self.assertFalse((root / "exports/.package.lock").exists())

    def test_active_build_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "exports").mkdir()
            (root / "exports/.package.lock").write_text("already running")
            with patch.object(package, "ROOT", root):
                with self.assertRaises(FileExistsError):
                    with package.configured_presets({}):
                        pass
            self.assertEqual((root / "exports/.package.lock").read_text(), "already running")

    def test_pc_requires_companion_pack(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            exe = root / "RichMan6.exe"
            exe.write_bytes(b"MZ")
            with self.assertRaisesRegex(RuntimeError, "nonempty"):
                package.validate_artifacts("pc", exe, root)
            exe.with_suffix(".pck").write_bytes(b"GDPC")
            self.assertEqual(len(package.validate_artifacts("pc", exe, root)), 2)

    def test_android_rejects_wrong_zip(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            apk = root / "bad.apk"
            with zipfile.ZipFile(apk, "w") as archive:
                archive.writestr("wrong.txt", "not an APK")
            with self.assertRaisesRegex(RuntimeError, "AndroidManifest"):
                package.validate_artifacts("android", apk, root)

    def test_custom_assets_are_included_in_every_preset(self):
        parser = package.configparser.ConfigParser(interpolation=None)
        parser.read(package.PRESETS)
        for index in range(3):
            includes = parser[f"preset.{index}"]["include_filter"]
            for extension in ("*.json", "*.r6m", "*.r6v"):
                self.assertIn(extension, includes)

    def test_runtime_exit_zero_is_not_enough(self):
        with tempfile.TemporaryDirectory() as directory:
            log = Path(directory) / "validation.log"
            log.write_text("通过 531 / 失败 2", encoding="utf-8")
            with patch.object(package, "run"):
                with self.assertRaisesRegex(RuntimeError, "did not pass"):
                    package.validate_pc_runtime(Path("game.exe"), log)
                log.write_text("through normal boot, no tests ran", encoding="utf-8")
                with self.assertRaisesRegex(RuntimeError, "did not pass"):
                    package.validate_pc_runtime(Path("game.exe"), log)
                log.write_text("通过 533 / 失败 0", encoding="utf-8")
                self.assertEqual(package.validate_pc_runtime(Path("game.exe"), log), 533)


if __name__ == "__main__":
    unittest.main()
