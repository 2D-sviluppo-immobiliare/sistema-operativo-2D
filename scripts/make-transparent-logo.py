#!/usr/bin/env python3
"""
2D OS - estrae il marchio con canale alpha dal PNG brandizzato.

Il logo fornito dal cliente e' un'immagine a sfondo pieno (gradiente blu):
per poterlo comporre sopra uno sfondo procedurale serve una versione
trasparente. L'alpha viene stimata confrontando la luminanza di ogni pixel con
il gradiente di fondo ricostruito dai bordi dell'immagine; le zone di marchio
(bianco, grigio chiaro, oro, ciano) sono sensibilmente piu' chiare del fondo.

Uso:
    python3 scripts/make-transparent-logo.py <sorgente.png> <destinazione.png>
"""

from __future__ import annotations

import sys

from PySide6.QtGui import QColor, QImage

# Luminanza del fondo: il gradiente va da ~0.30 (alto/centro) a ~0.18 (angoli).
BG_TOP = 0.315
BG_BOTTOM = 0.175

# Ampiezza della rampa alpha sopra la luminanza del fondo: stretta, cosi' il
# testo bianco e gli elementi pieni restano opachi invece di sfrangiarsi.
ALPHA_RAMP = 0.16
ALPHA_OFFSET = 0.018


def luminance(r: int, g: int, b: int) -> float:
    return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0


def background_at(x: int, y: int, w: int, h: int) -> float:
    """Ricostruisce la luminanza del fondo nel punto (x, y)."""
    # Il gradiente del logo e' quasi verticale, con un alone chiaro in alto.
    vertical = y / max(1, h - 1)
    base = BG_TOP + (BG_BOTTOM - BG_TOP) * vertical
    # Alone radiale centrato poco sopra la meta' dell'immagine.
    dx = (x / max(1, w - 1)) - 0.5
    dy = (y / max(1, h - 1)) - 0.32
    radial = max(0.0, 1.0 - (dx * dx * 2.4 + dy * dy * 2.0) * 1.7)
    return base + radial * 0.022


def build(source: str, target: str) -> int:
    image = QImage(source)
    if image.isNull():
        print(f"impossibile aprire {source}", file=sys.stderr)
        return 1

    image = image.convertToFormat(QImage.Format.Format_ARGB32)
    w, h = image.width(), image.height()
    out = QImage(w, h, QImage.Format.Format_ARGB32)
    out.fill(QColor(0, 0, 0, 0))

    for y in range(h):
        for x in range(w):
            color = image.pixelColor(x, y)
            r, g, b = color.red(), color.green(), color.blue()
            lum = luminance(r, g, b)
            bg = background_at(x, y, w, h)

            # Quanto il pixel e' piu' chiaro del fondo locale.
            alpha = (lum - bg - ALPHA_OFFSET) / ALPHA_RAMP
            alpha = max(0.0, min(1.0, alpha))

            if alpha <= 0.004:
                continue

            # Rimuove il contributo del fondo dal colore (un-premultiply).
            if alpha > 0.02:
                fr = (r - (1 - alpha) * bg * 255) / alpha
                fg = (g - (1 - alpha) * bg * 255) / alpha
                fb = (b - (1 - alpha) * bg * 255) / alpha
            else:
                fr, fg, fb = r, g, b

            rr = max(0, min(255, int(fr)))
            gg = max(0, min(255, int(fg)))
            bb = max(0, min(255, int(fb)))
            out.setPixelColor(x, y, QColor(rr, gg, bb, int(alpha * 255)))

    if not out.save(target, "PNG"):
        print(f"impossibile scrivere {target}", file=sys.stderr)
        return 1

    print(f"scritto {target} ({w}x{h})")
    return 0


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    return build(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    sys.exit(main())
