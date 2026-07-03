#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import shutil
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
SCREENSHOT_DIR = ROOT / "fastlane/screenshots/en-US"
ASSET_DIR = ROOT / "fastlane/assets"
APP_ICON_SOURCE = ROOT / "QuickBasic/Assets.xcassets/AppIcon.appiconset/AppIcon-1024@1x.png"
SVG_ICON_SOURCE = ROOT / "Artwork/TabletBasicIcon.svg"

CAPTURE_TEST = "TabletBasicUITests/TabletBasicUITests/testCaptureAppStoreScreenshots"
DEVICE_GROUPS = [
    (
        "IPHONE_69",
        [
            "iPhone 17 Pro Max",
            "iPhone 16 Pro Max",
            "iPhone 15 Pro Max",
        ],
    ),
    (
        "IPAD_PRO_3GEN_129",
        [
            "iPad Pro 13-inch (M5)",
            "iPad Pro 13-inch (M4)",
            "iPad Pro (12.9-inch) (6th generation)",
            "iPad Pro (12.9-inch) (5th generation)",
        ],
    ),
]


def clean_output() -> None:
    SCREENSHOT_DIR.mkdir(parents=True, exist_ok=True)
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    for path in SCREENSHOT_DIR.glob("*.png"):
        path.unlink()


def developer_env() -> dict[str, str]:
    env = os.environ.copy()

    default_xcode = Path("/Applications/Xcode.app/Contents/Developer")
    if "DEVELOPER_DIR" not in env and default_xcode.exists():
        env["DEVELOPER_DIR"] = str(default_xcode)

    return env


def xcode_env(prefix: str) -> dict[str, str]:
    env = developer_env()
    env["APP_STORE_SCREENSHOT_DIR"] = str(SCREENSHOT_DIR)
    env["APP_STORE_SCREENSHOT_PREFIX"] = prefix
    return env


def available_device_names() -> set[str]:
    result = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available"],
        cwd=ROOT,
        env=developer_env(),
        check=True,
        text=True,
        capture_output=True,
    )
    pattern = re.compile(r"^\s+(.+?) \([0-9A-F-]{36}\) \((?:Booted|Shutdown)\)")
    return {
        match.group(1)
        for line in result.stdout.splitlines()
        if (match := pattern.match(line))
    }


def choose_device(prefix: str, candidates: list[str], available: set[str]) -> str:
    for candidate in candidates:
        if candidate in available:
            return candidate
    raise SystemExit(
        f"No simulator found for {prefix}. Tried: {', '.join(candidates)}"
    )


def capture_device(device_name: str, prefix: str) -> None:
    command = [
        "xcodebuild",
        "-project",
        "TabletBasic.xcodeproj",
        "-scheme",
        "TabletBasic",
        "-destination",
        f"platform=iOS Simulator,name={device_name}",
        "-only-testing:" + CAPTURE_TEST,
        "test",
        "CODE_SIGNING_ALLOWED=NO",
    ]
    print(f"Capturing {prefix} screenshots on {device_name}...")
    subprocess.run(command, cwd=ROOT, env=xcode_env(prefix), check=True)


def copy_assets() -> None:
    if APP_ICON_SOURCE.exists():
        shutil.copyfile(APP_ICON_SOURCE, ASSET_DIR / "app-icon-1024.png")
    if SVG_ICON_SOURCE.exists():
        shutil.copyfile(SVG_ICON_SOURCE, ASSET_DIR / "tabletbasic-icon.svg")


def main() -> None:
    clean_output()
    available = available_device_names()
    for prefix, candidates in DEVICE_GROUPS:
        device_name = choose_device(prefix, candidates, available)
        capture_device(device_name, prefix)
    copy_assets()

    screenshots = sorted(SCREENSHOT_DIR.glob("*.png"))
    print(f"Wrote {len(screenshots)} simulator screenshots to {SCREENSHOT_DIR}")
    print(f"Wrote marketing assets to {ASSET_DIR}")


if __name__ == "__main__":
    main()
