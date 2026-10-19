#!/usr/bin/env python3
"""Render the vector tray marks into size-aware Windows ICO files.

Windows commonly displays a tray icon at 16 or 20 pixels. A single 64-pixel
frame gives it thin, broken strokes after scaling, so these frames are rendered
at their final sizes with a stronger small-size outline.
"""

from pathlib import Path
import shutil
import struct
import subprocess


ROOT = Path(__file__).resolve().parents[1] / "assets" / "tray"
SIZES = (16, 20, 24, 32, 48, 64, 128, 256)


def render(svg: bytes, size: int) -> bytes:
    return subprocess.check_output(
        ["rsvg-convert", "-w", str(size), "-h", str(size)], input=svg
    )


def small_mark(name: str) -> bytes:
    # The two terminal badges overlap the letter at tray size. Keep the Povad
    # stroke and move a simple state shape into its own lower-right space.
    status = {
        "stopped": '<rect x="11.4" y="11.6" width="2.9" height="2.9" rx="0.6" fill="white" stroke="white" stroke-width="1.1"/><rect x="11.7" y="11.9" width="2.3" height="2.3" rx="0.4" fill="none" stroke="#18181b" stroke-width="1.1"/>',
        "listening": '<circle cx="12.9" cy="13" r="2.1" fill="white" stroke="white" stroke-width="1.2"/><circle cx="12.9" cy="13" r="1.7" fill="none" stroke="#18181b" stroke-width="1.2"/>',
        "connected": '<circle cx="12.9" cy="13" r="2.5" fill="white"/><circle cx="12.9" cy="13" r="1.7" fill="#18181b"/>',
        "error": '<path d="M11.4 11.5l3 3m0-3l-3 3" stroke="white" stroke-width="3.2" stroke-linecap="round"/><path d="M11.4 11.5l3 3m0-3l-3 3" stroke="#18181b" stroke-width="1.6" stroke-linecap="round"/>',
    }[name]
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16">'
        '<path d="M3.8 13.7V6.7c0-2.6 2-4.2 4.7-4.2h.7c2.8 0 4.6 1.7 4.6 4s-1.8 3.9-4.6 3.9H6.8" fill="none" stroke="white" stroke-width="4" stroke-linecap="round" stroke-linejoin="round"/>'
        '<path d="M3.8 13.7V6.7c0-2.6 2-4.2 4.7-4.2h.7c2.8 0 4.6 1.7 4.6 4s-1.8 3.9-4.6 3.9H6.8" fill="none" stroke="#18181b" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>'
        f'{status}</svg>'
    ).encode("utf-8")


def write_ico(path: Path, frames: list[tuple[int, bytes]]) -> None:
    offset = 6 + 16 * len(frames)
    entries = []
    images = []
    for size, png in frames:
        dimension = 0 if size == 256 else size
        entries.append(struct.pack("<BBBBHHII", dimension, dimension, 0, 0, 1, 32, len(png), offset))
        images.append(png)
        offset += len(png)
    path.write_bytes(struct.pack("<HHH", 0, 1, len(frames)) + b"".join(entries + images))


def main() -> None:
    if shutil.which("rsvg-convert") is None:
        raise SystemExit("rsvg-convert is required to build tray icons")
    for name in ("stopped", "listening", "connected", "error"):
        svg = (ROOT / f"{name}.svg").read_bytes()
        small = small_mark(name)
        frames = [(size, render(small if size <= 20 else svg, size)) for size in SIZES]
        write_ico(ROOT / f"{name}.ico", frames)


if __name__ == "__main__":
    main()
