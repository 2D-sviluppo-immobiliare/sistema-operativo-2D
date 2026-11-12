#!/usr/bin/env python3
"""
2D OS - prepara lo sfondo del desktop a partire dall'immagine del cliente.

Converte il PNG originale in JPEG (molto piu' leggero da caricare a ogni
avvio), ritaglia al formato dello schermo e salva l'asset usato dalla shell.

Uso:
    python3 scripts/prepare-wallpaper.py <sorgente> <destinazione.jpg>
"""

from __future__ import annotations

import sys

from PySide6.QtCore import Qt
from PySide6.QtGui import QImage

# Formato di destinazione: 1920x1080 copre qualunque schermo comune.
TARGET_W = 1920
TARGET_H = 1080
QUALITY = 90


def build(source: str, target: str) -> int:
    image = QImage(source)
    if image.isNull():
        print(f"impossibile aprire {source}", file=sys.stderr)
        return 1

    image = image.convertToFormat(QImage.Format.Format_RGB32)

    # Ritaglio centrale al rapporto 16:9, poi scala alla risoluzione target.
    src_ratio = image.width() / image.height()
    dst_ratio = TARGET_W / TARGET_H

    if src_ratio > dst_ratio:
        crop_w = int(image.height() * dst_ratio)
        crop_h = image.height()
    else:
        crop_w = image.width()
        crop_h = int(image.width() / dst_ratio)

    cropped = image.copy(
        (image.width() - crop_w) // 2,
        (image.height() - crop_h) // 2,
        crop_w,
        crop_h,
    )

    scaled = cropped.scaled(
        TARGET_W, TARGET_H,
        Qt.AspectRatioMode.IgnoreAspectRatio,
        Qt.TransformationMode.SmoothTransformation,
    )

    if not scaled.save(target, "JPEG", QUALITY):
        print(f"impossibile scrivere {target}", file=sys.stderr)
        return 1

    print(f"scritto {target} ({scaled.width()}x{scaled.height()})")
    return 0


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    return build(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    sys.exit(main())
