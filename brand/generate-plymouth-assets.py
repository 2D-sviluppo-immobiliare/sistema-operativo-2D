#!/usr/bin/env python3
"""
Generatore degli asset PNG del tema Plymouth di 2D OS.

Usa solo la libreria standard (zlib + struct): nessuna dipendenza esterna,
cosi' il repository resta riproducibile su qualsiasi macchina.

Uso:
    python3 brand/generate-plymouth-assets.py
"""

from __future__ import annotations

import struct
import zlib
from pathlib import Path

GOLD = (230, 196, 120)
OUT_DIR = Path(__file__).resolve().parent / "plymouth"


def write_png(path: Path, width: int, height: int, pixels: bytearray) -> None:
    """Scrive un PNG RGBA (8 bit per canale) senza dipendenze esterne."""
    raw = bytearray()
    stride = width * 4
    for y in range(height):
        raw.append(0)  # filtro "None"
        raw += pixels[y * stride:(y + 1) * stride]

    def chunk(kind: bytes, data: bytes) -> bytes:
        return (
            struct.pack(">I", len(data))
            + kind
            + data
            + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
        )

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    path.write_bytes(png)


def coverage(inside) -> int:
    """Anti-aliasing: 4x4 campioni per pixel."""
    hits = 0
    for i in range(4):
        for j in range(4):
            if inside((i + 0.5) / 4, (j + 0.5) / 4):
                hits += 1
    return int(255 * hits / 16)


def make_ring(size: int = 160, outer: float = 70.0, thickness: float = 5.0) -> bytearray:
    pixels = bytearray(size * size * 4)
    c = size / 2.0
    inner = outer - thickness
    for y in range(size):
        for x in range(size):
            def inside(fx: float, fy: float, x=x, y=y) -> bool:
                dx = (x + fx) - c
                dy = (y + fy) - c
                d = (dx * dx + dy * dy) ** 0.5
                return inner <= d <= outer

            a = coverage(inside)
            i = (y * size + x) * 4
            pixels[i:i + 4] = bytes((GOLD[0], GOLD[1], GOLD[2], a))
    return pixels


def make_dot(size: int = 12, radius: float = 4.6) -> bytearray:
    pixels = bytearray(size * size * 4)
    c = size / 2.0
    for y in range(size):
        for x in range(size):
            def inside(fx: float, fy: float, x=x, y=y) -> bool:
                dx = (x + fx) - c
                dy = (y + fy) - c
                return (dx * dx + dy * dy) ** 0.5 <= radius

            a = coverage(inside)
            i = (y * size + x) * 4
            pixels[i:i + 4] = bytes((GOLD[0], GOLD[1], GOLD[2], a))
    return pixels


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    write_png(OUT_DIR / "ring.png", 160, 160, make_ring())
    write_png(OUT_DIR / "dot.png", 12, 12, make_dot())
    for f in sorted(OUT_DIR.glob("*.png")):
        print(f"{f.relative_to(OUT_DIR.parent.parent)}  {f.stat().st_size} byte")


if __name__ == "__main__":
    main()
