#!/usr/bin/env python3
"""Generate a pixel-style QueueMonitor app icon for Android and iOS."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
BASE_SIZE = 128

ANDROID_SIZES = {
    ROOT / "android/app/src/main/res/mipmap-mdpi/ic_launcher.png": 48,
    ROOT / "android/app/src/main/res/mipmap-hdpi/ic_launcher.png": 72,
    ROOT / "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png": 96,
    ROOT / "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png": 144,
    ROOT / "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png": 192,
}

PALETTE = {
    "bg": "#08111f",
    "bg2": "#0c1527",
    "frame": "#17304c",
    "frame_hi": "#2d5b7f",
    "screen": "#0e1726",
    "screen_hi": "#16263b",
    "cyan": "#58d7ff",
    "green": "#35d07f",
    "lime": "#b8f34a",
    "amber": "#f0b54b",
    "white": "#e6f1ff",
}


def _rect(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], color: str) -> None:
    draw.rectangle(box, fill=color)


def _pixel(draw: ImageDraw.ImageDraw, x: int, y: int, color: str, size: int = 1) -> None:
    draw.rectangle((x, y, x + size - 1, y + size - 1), fill=color)


def build_base_icon() -> Image.Image:
    image = Image.new("RGBA", (BASE_SIZE, BASE_SIZE), PALETTE["bg"])
    draw = ImageDraw.Draw(image)

    # Background texture.
    _rect(draw, (0, 0, BASE_SIZE - 1, BASE_SIZE - 1), PALETTE["bg"])
    _rect(draw, (0, 0, BASE_SIZE - 1, 2), PALETTE["bg2"])
    _rect(draw, (0, 0, 2, BASE_SIZE - 1), PALETTE["bg2"])
    _rect(draw, (BASE_SIZE - 3, 0, BASE_SIZE - 1, BASE_SIZE - 1), PALETTE["bg2"])
    _rect(draw, (0, BASE_SIZE - 3, BASE_SIZE - 1, BASE_SIZE - 1), PALETTE["bg2"])

    # Main body.
    body = (14, 14, 113, 113)
    _rect(draw, body, PALETTE["frame"])
    _rect(draw, (14, 14, 113, 20), PALETTE["frame_hi"])
    _rect(draw, (14, 14, 20, 113), PALETTE["frame_hi"])
    _rect(draw, (107, 14, 113, 113), "#102238")
    _rect(draw, (14, 107, 113, 113), "#102238")

    # Inner screen.
    screen = (24, 28, 103, 102)
    _rect(draw, screen, PALETTE["screen"])
    _rect(draw, (24, 28, 103, 35), PALETTE["screen_hi"])
    _rect(draw, (24, 28, 29, 102), "#132033")
    _rect(draw, (98, 28, 103, 102), "#132033")
    _rect(draw, (24, 96, 103, 102), "#111d2d")

    # Top bar lights.
    _pixel(draw, 30, 31, PALETTE["green"], 3)
    _pixel(draw, 36, 31, PALETTE["amber"], 3)
    _pixel(draw, 42, 31, PALETTE["cyan"], 3)
    _pixel(draw, 92, 31, PALETTE["green"], 3)
    _pixel(draw, 98, 31, PALETTE["white"], 2)

    # Left queue bars.
    queue_rows = [
        (34, 44, 28, PALETTE["green"]),
        (34, 53, 36, PALETTE["lime"]),
        (34, 62, 22, PALETTE["green"]),
        (34, 71, 42, PALETTE["amber"]),
        (34, 80, 18, PALETTE["cyan"]),
    ]
    for x, y, width, color in queue_rows:
        _rect(draw, (x, y, x + width, y + 5), color)
        _rect(draw, (x, y, x + 2, y + 5), PALETTE["white"])

    # Right-side status bars.
    cpu_bars = [(74, 88, 6), (82, 80, 6), (90, 70, 6), (98, 76, 6)]
    gpu_bars = [(74, 95, 6), (82, 90, 6), (90, 84, 6), (98, 92, 6)]
    for x, top, width in cpu_bars:
        _rect(draw, (x, top, x + width, 92), PALETTE["cyan"])
        _rect(draw, (x, top, x + 1, 92), PALETTE["white"])
    for x, top, width in gpu_bars:
        _rect(draw, (x, top, x + width, 99), PALETTE["green"])
        _rect(draw, (x, top, x + 1, 99), PALETTE["white"])

    # Bottom queue indicator and prompt blocks.
    _pixel(draw, 32, 92, PALETTE["amber"], 4)
    _pixel(draw, 38, 92, PALETTE["amber"], 4)
    _pixel(draw, 44, 92, PALETTE["amber"], 4)
    _pixel(draw, 54, 92, PALETTE["cyan"], 4)
    _pixel(draw, 60, 92, PALETTE["cyan"], 4)
    _pixel(draw, 66, 92, PALETTE["cyan"], 4)
    _pixel(draw, 94, 92, PALETTE["green"], 4)
    _pixel(draw, 100, 92, PALETTE["green"], 4)

    # Small terminal cursor.
    _pixel(draw, 29, 86, PALETTE["white"], 3)
    _pixel(draw, 33, 84, PALETTE["white"], 2)
    _pixel(draw, 33, 88, PALETTE["white"], 2)

    return image


def resize_icon(base: Image.Image, size: int) -> Image.Image:
    return base.resize((size, size), Image.Resampling.NEAREST)


def write_android_icons(base: Image.Image) -> None:
    for path, size in ANDROID_SIZES.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        resize_icon(base, size).save(path)


def write_ios_icons(base: Image.Image) -> None:
    iconset = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((iconset / "Contents.json").read_text())

    for image_entry in contents["images"]:
        filename = image_entry.get("filename")
        size_spec = image_entry.get("size")
        scale = image_entry.get("scale")
        if not filename or not size_spec or not scale:
            continue
        point_size = float(size_spec.split("x", 1)[0])
        pixel_size = int(round(point_size * float(scale.rstrip("x"))))
        resize_icon(base, pixel_size).save(iconset / filename)


def main() -> None:
    base = build_base_icon()
    write_android_icons(base)
    write_ios_icons(base)


if __name__ == "__main__":
    main()
