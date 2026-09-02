#!/usr/bin/env python3
from __future__ import annotations

import json
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"
MOBILE = ROOT / "mobile"
MACOS = ROOT / "macos"

DARK = (17, 24, 39, 255)
YELLOW = (255, 204, 0, 255)
TRANSPARENT = (0, 0, 0, 0)


def _inside_round_rect(x: float, y: float, size: int, radius: float) -> bool:
    if radius <= x <= size - radius or radius <= y <= size - radius:
        return 0 <= x <= size and 0 <= y <= size
    cx = radius if x < radius else size - radius
    cy = radius if y < radius else size - radius
    return (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2


def _inside_circle(x: float, y: float, cx: float, cy: float, radius: float) -> bool:
    return (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2


def _inside_capsule(x: float, y: float, x0: float, y0: float, x1: float, y1: float, radius: float) -> bool:
    if y0 + radius <= y <= y1 - radius and x0 <= x <= x1:
        return True
    cx = (x0 + x1) / 2
    return _inside_circle(x, y, cx, y0 + radius, radius) or _inside_circle(x, y, cx, y1 - radius, radius)


def render_rgba(size: int, *, rounded: bool = True, transparent_outside: bool = True) -> bytes:
    samples = 3 if size <= 256 else 2
    total = samples * samples
    out = bytearray(size * size * 4)

    rr = size * 0.215
    circle_cx = size * 0.5
    circle_cy = size * 0.42
    circle_r = size * 0.31
    bar_x0 = size * 0.455
    bar_x1 = size * 0.545
    bar_y0 = size * 0.20
    bar_y1 = size * 0.525
    bar_r = (bar_x1 - bar_x0) / 2
    dot_cx = size * 0.5
    dot_cy = size * 0.625
    dot_r = size * 0.052

    i = 0
    for py in range(size):
        for px in range(size):
            acc = [0, 0, 0, 0]
            for sy in range(samples):
                for sx in range(samples):
                    x = px + (sx + 0.5) / samples
                    y = py + (sy + 0.5) / samples

                    in_base = True
                    if rounded:
                        in_base = _inside_round_rect(x, y, size, rr)

                    if not in_base:
                        color = TRANSPARENT if transparent_outside else DARK
                    else:
                        color = DARK
                        if _inside_circle(x, y, circle_cx, circle_cy, circle_r):
                            color = YELLOW
                        if _inside_capsule(x, y, bar_x0, bar_y0, bar_x1, bar_y1, bar_r):
                            color = DARK
                        if _inside_circle(x, y, dot_cx, dot_cy, dot_r):
                            color = DARK

                    for c in range(4):
                        acc[c] += color[c]

            for c in range(4):
                out[i + c] = acc[c] // total
            i += 4

    return bytes(out)


def png_bytes(width: int, height: int, rgba: bytes) -> bytes:
    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)
        raw.extend(rgba[y * stride : (y + 1) * stride])

    return b"".join(
        (
            b"\x89PNG\r\n\x1a\n",
            chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)),
            chunk(b"IDAT", zlib.compress(bytes(raw), 9)),
            chunk(b"IEND", b""),
        )
    )


def write_png(path: Path, size: int, *, rounded: bool, transparent_outside: bool = True) -> bytes:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = png_bytes(size, size, render_rgba(size, rounded=rounded, transparent_outside=transparent_outside))
    path.write_bytes(payload)
    return payload


def write_ico(path: Path, sizes: list[int]) -> None:
    images = [write_png(path.parent / f"trayvoha-{size}.png", size, rounded=True) for size in sizes]
    header = struct.pack("<HHH", 0, 1, len(images))
    entries = bytearray()
    offset = 6 + 16 * len(images)
    for size, image in zip(sizes, images):
        dim = 0 if size >= 256 else size
        entries.extend(struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(image), offset))
        offset += len(image)
    path.write_bytes(header + bytes(entries) + b"".join(images))


def write_icns(path: Path) -> None:
    mapping = [
        ("icp4", 16),
        ("icp5", 32),
        ("icp6", 64),
        ("ic07", 128),
        ("ic08", 256),
        ("ic09", 512),
        ("ic10", 1024),
    ]
    chunks = []
    for code, size in mapping:
        png = write_png(path.parent / f"trayvoha-{size}.png", size, rounded=False, transparent_outside=False)
        chunks.append(code.encode("ascii") + struct.pack(">I", 8 + len(png)) + png)
    body = b"".join(chunks)
    path.write_bytes(b"icns" + struct.pack(">I", 8 + len(body)) + body)


def write_linux() -> None:
    out = ASSETS / "linux"
    for size in [16, 24, 32, 48, 64, 128, 256, 512]:
        write_png(out / f"trayvoha-{size}.png", size, rounded=True)


def write_android() -> None:
    res = MOBILE / "android" / "app" / "src" / "main" / "res"
    densities = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for directory, size in densities.items():
        write_png(res / directory / "ic_launcher.png", size, rounded=True, transparent_outside=False)
        write_png(res / directory / "ic_launcher_round.png", size, rounded=True, transparent_outside=False)

    drawable = res / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    (drawable / "ic_launcher_foreground.xml").write_text(
        """<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<vector xmlns:android=\"http://schemas.android.com/apk/res/android\"\n    android:width=\"108dp\"\n    android:height=\"108dp\"\n    android:viewportWidth=\"108\"\n    android:viewportHeight=\"108\">\n    <path android:fillColor=\"#FFCC00\" android:pathData=\"M54,20a34,34 0,1 0,0.01,0\"/>\n    <path android:fillColor=\"#111827\" android:pathData=\"M49,28h10v36a5,5 0,0 1,-10,0z\"/>\n    <path android:fillColor=\"#111827\" android:pathData=\"M54,76m-5,0a5,5 0,1 0,10,0a5,5 0,1 0,-10,0\"/>\n</vector>\n""",
        encoding="utf-8",
    )

    values = res / "values"
    values.mkdir(parents=True, exist_ok=True)
    (values / "colors.xml").write_text(
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<resources>\n    <color name=\"trayvoha_icon_background\">#111827</color>\n</resources>\n",
        encoding="utf-8",
    )

    anydpi = res / "mipmap-anydpi-v26"
    anydpi.mkdir(parents=True, exist_ok=True)
    adaptive = """<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<adaptive-icon xmlns:android=\"http://schemas.android.com/apk/res/android\">\n    <background android:drawable=\"@color/trayvoha_icon_background\"/>\n    <foreground android:drawable=\"@drawable/ic_launcher_foreground\"/>\n</adaptive-icon>\n"""
    (anydpi / "ic_launcher.xml").write_text(adaptive, encoding="utf-8")
    (anydpi / "ic_launcher_round.xml").write_text(adaptive, encoding="utf-8")


def write_ios() -> None:
    out = MOBILE / "ios" / "Assets.xcassets" / "AppIcon.appiconset"
    out.mkdir(parents=True, exist_ok=True)
    specs = [
        ("iphone", "20x20", "2x", 40),
        ("iphone", "20x20", "3x", 60),
        ("iphone", "29x29", "2x", 58),
        ("iphone", "29x29", "3x", 87),
        ("iphone", "40x40", "2x", 80),
        ("iphone", "40x40", "3x", 120),
        ("iphone", "60x60", "2x", 120),
        ("iphone", "60x60", "3x", 180),
        ("ios-marketing", "1024x1024", "1x", 1024),
    ]
    images = []
    for idiom, logical, scale, pixels in specs:
        filename = f"trayvoha-{pixels}.png"
        write_png(out / filename, pixels, rounded=False, transparent_outside=False)
        images.append({"idiom": idiom, "size": logical, "scale": scale, "filename": filename})
    (out / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def write_macos() -> None:
    out = MACOS / "Assets.xcassets" / "AppIcon.appiconset"
    out.mkdir(parents=True, exist_ok=True)
    specs = [
        ("16x16", "1x", 16),
        ("16x16", "2x", 32),
        ("32x32", "1x", 32),
        ("32x32", "2x", 64),
        ("128x128", "1x", 128),
        ("128x128", "2x", 256),
        ("256x256", "1x", 256),
        ("256x256", "2x", 512),
        ("512x512", "1x", 512),
        ("512x512", "2x", 1024),
    ]
    images = []
    for logical, scale, pixels in specs:
        filename = f"trayvoha-{pixels}.png"
        write_png(out / filename, pixels, rounded=False, transparent_outside=False)
        images.append({"idiom": "mac", "size": logical, "scale": scale, "filename": filename})
    (out / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    write_icns(ASSETS / "macos" / "trayvoha.icns")


def main() -> int:
    write_ico(ASSETS / "windows" / "trayvoha.ico", [16, 24, 32, 48, 64, 128, 256])
    write_linux()
    write_android()
    write_ios()
    write_macos()
    print("Готово: іконки TrayVoha згенеровано для Windows, Linux, macOS, Android та iOS.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
