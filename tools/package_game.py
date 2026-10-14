"""Cross-platform Godot packaging. Python 3.9+, standard library only."""
import argparse
import configparser
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time
import zipfile
from contextlib import contextmanager

ROOT = Path(__file__).resolve().parents[1]
GAME = ROOT / "game"
PRESETS = GAME / "export_presets.cfg"
ENGINE_VERSION = "4.7.2.stable"
TARGETS = {"pc": ("PC", "RichMan6.exe"), "android": ("Android", "RichMan6.apk"),
           "ios": ("iOS", "RichMan6.zip"), "pack": ("PC", "RichMan6.pck")}


def engine_path(explicit=None):
    candidates = [explicit, os.environ.get("GODOT_BIN"),
                  "D:/Godot/Godot_v4.7.2-stable_win64_console.exe",
                  "/Applications/Godot.app/Contents/MacOS/Godot", shutil.which("godot")]
    for folder in (ROOT / "Godot", ROOT / ".tools"):
        candidates.extend(sorted(folder.glob("*console.exe")))
    for item in candidates:
        if item and Path(item).is_file() and Path(item).stat().st_size:
            return str(Path(item).resolve())
    raise RuntimeError("Godot not found. Set GODOT_BIN or pass --godot PATH.")


def template_dir():
    if os.environ.get("GODOT_TEMPLATE_DIR"):
        return Path(os.environ["GODOT_TEMPLATE_DIR"])
    if sys.platform == "win32":
        base = Path(os.environ["APPDATA"]) / "Godot"
    elif sys.platform == "darwin":
        base = Path.home() / "Library/Application Support/Godot"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "godot"
    return base / "export_templates" / ENGINE_VERSION


def read_config(path):
    if not path.is_file():
        return {}
    return json.loads(path.read_text(encoding="utf-8-sig"))


def android_editor_paths():
    if sys.platform == "win32":
        base = Path(os.environ["APPDATA"]) / "Godot"
    elif sys.platform == "darwin":
        base = Path.home() / "Library/Application Support/Godot"
    else:
        base = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "godot"
    settings = base / "editor_settings-4.7.tres"
    text = settings.read_text(encoding="utf-8") if settings.is_file() else ""
    values = []
    for name in ("android_sdk_path", "java_sdk_path"):
        match = re.search(r'^export/android/' + name + r'\s*=\s*(".*")$', text, re.MULTILINE)
        values.append(Path(json.loads(match[1])) if match and json.loads(match[1]) else None)
    return values


def check(target, engine, cfg, release=False):
    problems = []
    version = subprocess.check_output([engine, "--version"], text=True).strip()
    if not version.startswith(ENGINE_VERSION + "."):
        problems.append(f"Expected Godot {ENGINE_VERSION}; found {version}")
    if not (GAME / "assets/fonts/r6_16.fnt").is_file():
        problems.append("Runtime assets missing: prepare game/assets before exporting.")
    templates = template_dir()
    expected = {"pc": ["windows_release_x86_64.exe" if release else "windows_debug_x86_64.exe"],
                "android": ["android_release.apk" if release else "android_debug.apk"],
                "ios": ["ios.zip"], "pack": []}[target]
    for name in expected:
        if not (templates / name).is_file():
            problems.append(f"Missing export template: {templates / name}")
    if target == "android":
        # The exporter reads these two paths from Godot Editor Settings.
        sdk, java = android_editor_paths()
        suffix = ".exe" if sys.platform == "win32" else ""
        if not sdk or not (sdk / ("platform-tools/adb" + suffix)).is_file():
            problems.append("Configure Android SDK Path (with platform-tools/adb) in Godot Editor Settings.")
        if not java or not (java / ("bin/java" + suffix)).is_file():
            problems.append("Configure Java SDK Path in Godot Editor Settings (JDK 17 recommended).")
        if release:
            for key in ("PATH", "USER", "PASSWORD"):
                if not os.environ.get("GODOT_ANDROID_KEYSTORE_RELEASE_" + key):
                    problems.append("Set GODOT_ANDROID_KEYSTORE_RELEASE_" + key + " for signed release APK.")
    if target == "ios":
        if sys.platform != "darwin":
            problems.append("iOS export requires macOS and Xcode; run this same script on your Mac.")
        elif not shutil.which("xcodebuild"):
            problems.append("Xcode command-line tools not found.")
        if not re.fullmatch(r"[A-Z0-9]{10}", cfg.get("ios_team_id", "")):
            problems.append("Set your 10-character ios_team_id in build-config.local.json.")
    if release and cfg.get("application_id", "org.richman.replica") == "org.richman.replica" and target in ("android", "ios"):
        problems.append("Set your own application_id before a release mobile build.")
    return version, problems


@contextmanager
def configured_presets(cfg):
    """Keep tracked configuration intact even when the exporter fails."""
    lock = ROOT / "exports/.package.lock"
    lock.parent.mkdir(parents=True, exist_ok=True)
    with lock.open("x", encoding="utf-8") as stream:
        stream.write(str(os.getpid()))
    try:
        original = PRESETS.read_bytes()
        parser = configparser.ConfigParser(interpolation=None)
        parser.optionxform = str
        parser.read_string(original.decode("utf-8"))
        app_id = cfg.get("application_id", "org.richman.replica")
        version = cfg.get("version", "0.1.0")
        code = int(cfg.get("version_code", 1))
        if code < 1 or not re.fullmatch(r"[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z][A-Za-z0-9_]*)+", app_id):
            raise RuntimeError("Invalid application_id or version_code in local config.")
        values = {
            "preset.1.options": {"package/unique_name": app_id, "version/name": version},
            "preset.2.options": {"application/bundle_identifier": app_id,
                                 "application/short_version": version,
                                 "application/version": str(code),
                                 "application/app_store_team_id": cfg.get("ios_team_id", "")}}
        for section, mapping in values.items():
            for key, value in mapping.items():
                parser[section][key] = json.dumps(value)
        parser["preset.1.options"]["version/code"] = str(code)
        with PRESETS.open("w", encoding="utf-8", newline="\n") as stream:
            parser.write(stream, space_around_delimiters=False)
        yield
    finally:
        if "original" in locals():
            PRESETS.write_bytes(original)
        lock.unlink()


def run(command, log, allow_test_cleanup=False):
    with log.open("a", encoding="utf-8") as stream:
        result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
    if result.returncode:
        raise RuntimeError(f"Build step failed ({result.returncode}); see {log}")
    errors = re.findall(r"^(?:SCRIPT ERROR|ERROR):.*$", log.read_text(encoding="utf-8", errors="replace"), re.MULTILINE)
    if allow_test_cleanup:
        # Existing test harness retains test resources until process shutdown.
        # Only its exact shutdown diagnostic is allowed; script/load errors still fail.
        errors = [line for line in errors if not re.fullmatch(r"ERROR: \d+ resources still in use at exit \(run with --verbose for details\)\.", line.strip())]
    if errors:
        raise RuntimeError(f"Godot reported errors; see {log}")


def ios_ipa(dest, cfg, options):
    if not options or not options.is_file():
        raise RuntimeError("--ios-ipa requires --export-options pointing to your ExportOptions.plist")
    projects = list(dest.glob("*.xcodeproj"))
    if not projects:
        with zipfile.ZipFile(dest / "RichMan6.zip") as archive:
            for name in archive.namelist():
                resolved = (dest / name).resolve()
                if not resolved.is_relative_to(dest.resolve()):
                    raise RuntimeError("Unsafe path in iOS export ZIP")
            archive.extractall(dest)
        projects = list(dest.rglob("*.xcodeproj"))
    if len(projects) != 1:
        raise RuntimeError("Expected exactly one exported Xcode project")
    project = projects[0]
    listing = json.loads(subprocess.check_output(["xcodebuild", "-list", "-json", "-project", str(project)], text=True))
    schemes = listing["project"].get("schemes", [])
    scheme = cfg.get("ios_scheme") or (schemes[0] if len(schemes) == 1 else "")
    if scheme not in schemes:
        raise RuntimeError("Set ios_scheme in local config; available schemes: " + ", ".join(schemes))
    archive = dest / "RichMan6.xcarchive"
    log = dest / "xcode.log"
    run(["xcodebuild", "-project", str(project), "-scheme", scheme, "-configuration", "Release",
         "-destination", "generic/platform=iOS", "-archivePath", str(archive), "-allowProvisioningUpdates", "archive"], log)
    run(["xcodebuild", "-exportArchive", "-archivePath", str(archive), "-exportPath", str(dest / "ipa"),
         "-exportOptionsPlist", str(options.resolve()), "-allowProvisioningUpdates"], log)
    if not list((dest / "ipa").glob("*.ipa")):
        raise RuntimeError("Xcode completed without an IPA")


def validate_artifacts(target, output, destination):
    required = [output]
    if target == "pc":
        required.append(output.with_suffix(".pck"))
    for item in required:
        if not item.is_file() or not item.stat().st_size:
            raise RuntimeError(f"Exporter did not produce a nonempty artifact: {item}")
    if target in ("android", "ios"):
        with zipfile.ZipFile(output) as archive:
            names = archive.namelist()
            if target == "android" and "AndroidManifest.xml" not in names:
                raise RuntimeError("APK missing AndroidManifest.xml")
            if target == "ios" and not any(".xcodeproj/" in name for name in names):
                # Some engine versions export the Xcode project beside the ZIP.
                if not list(destination.glob("*.xcodeproj")):
                    raise RuntimeError("iOS export missing Xcode project")
    return required


def validate_pc_runtime(executable, log):
    # No --path / --main-pack: this must boot from its own companion PCK.
    run([str(executable), "--headless", "--", "--selftest"], log, allow_test_cleanup=True)
    result = re.search(r"通过\s+(\d+)\s*/\s*失败\s+(\d+)", log.read_text(encoding="utf-8", errors="replace"))
    if not result or int(result[1]) == 0 or int(result[2]) != 0:
        raise RuntimeError(f"Packaged runtime self-test did not pass; see {log}")
    return int(result[1])


def build(target, engine, cfg, release, ipa=False, options=None):
    stamp = time.strftime("%Y%m%d-%H%M%S") + "-" + str(time.time_ns() % 1000000)
    dest = ROOT / "exports" / target / stamp
    dest.mkdir(parents=True, exist_ok=False)
    output = dest / TARGETS[target][1]
    log = dest / "build.log"
    with configured_presets(cfg):
        print("Importing resources...", flush=True)
        run([engine, "--headless", "--path", str(GAME), "--editor", "--import"], log)
        print("Exporting " + target + "...", flush=True)
        mode = "--export-pack" if target == "pack" else ("--export-release" if release else "--export-debug")
        run([engine, "--headless", "--path", str(GAME), mode, TARGETS[target][0], str(output)], log)
    artifacts = validate_artifacts(target, output, dest)
    passed = None
    if target == "pc":
        print("Testing standalone PC runtime...", flush=True)
        passed = validate_pc_runtime(output, dest / "validation.log")
    if ipa:
        ios_ipa(dest, cfg, options)
    if target == "pc":
        archive = dest / "RichMan6-Windows.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED) as z:
            for item in artifacts:
                z.write(item, item.name)
        artifacts.append(archive)
    # Include every iOS project file in the manifest, even if exported beside ZIP.
    if target == "ios":
        artifacts = [p for p in dest.rglob("*") if p.is_file() and p != log]
    manifest = {"target": target, "mode": "release" if release else "debug",
                "engine": ENGINE_VERSION, "version": cfg.get("version", "0.1.0"),
                "artifacts": []}
    if passed is not None:
        manifest["runtime_selftest"] = {"passed": passed, "failed": 0}
    for item in artifacts:
        digest = hashlib.sha256()
        with item.open("rb") as stream:
            for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                digest.update(chunk)
        manifest["artifacts"].append({"file": str(item.relative_to(dest)), "bytes": item.stat().st_size,
                                       "sha256": digest.hexdigest()})
    (dest / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    print("SUCCESS: " + str(dest))
    return dest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=["check", "build"])
    parser.add_argument("target", choices=[*TARGETS, "all"])
    parser.add_argument("--release", action="store_true")
    parser.add_argument("--godot")
    parser.add_argument("--ios-ipa", action="store_true", help="Archive and sign the exported iOS project using Xcode")
    parser.add_argument("--export-options", type=Path, help="Your Xcode ExportOptions.plist")
    parser.add_argument("--config", type=Path, default=ROOT / "build-config.local.json")
    args = parser.parse_args()
    try:
        if args.ios_ipa and (args.target != "ios" or not args.release or not args.export_options or not args.export_options.is_file()):
            raise RuntimeError("Use --ios-ipa only with build ios --release --export-options FILE")
        cfg = read_config(args.config)
        engine = engine_path(args.godot or cfg.get("godot"))
        targets = ["pc", "android", "ios"] if args.target == "all" else [args.target]
        checks = []
        for target in targets:
            version, problems = check(target, engine, cfg, args.release)
            print(f"[{target}] Godot {version}")
            for problem in problems:
                print("  MISSING: " + problem)
            if not problems:
                print("  Base requirements found; exporter will validate platform SDK/signing settings.")
            checks.extend(problems)
        if checks:
            return 1
        if args.command == "build":
            for target in targets:
                build(target, engine, cfg, args.release, args.ios_ipa, args.export_options)
        return 0
    except (OSError, ValueError, RuntimeError, subprocess.SubprocessError, zipfile.BadZipFile) as error:
        print("FAILED: " + str(error), file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
