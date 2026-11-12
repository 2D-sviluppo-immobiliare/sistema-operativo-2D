#!/usr/bin/python3
"""
2D OS - cattura dello schermo X11 per il laboratorio di test.

Utile insieme a Xvfb per verificare la shell senza aprire una sessione reale:

    Xvfb :99 -screen 0 1280x800x24 &
    DISPLAY=:99 python3 scripts/lab-shot.py /tmp/desktop.png

Uso:
    DISPLAY=:99 lab-shot.py <file.png> [larghezza] [altezza]
"""

from __future__ import annotations

import sys

import gi

gi.require_version("Gdk", "3.0")
from gi.repository import Gdk  # noqa: E402


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2

    target = sys.argv[1]
    width = int(sys.argv[2]) if len(sys.argv) > 2 else 1280
    height = int(sys.argv[3]) if len(sys.argv) > 3 else 800

    root = Gdk.get_default_root_window()
    if root is None:
        print("nessun display disponibile", file=sys.stderr)
        return 1

    pixbuf = Gdk.pixbuf_get_from_window(root, 0, 0, width, height)
    if pixbuf is None:
        print("cattura fallita", file=sys.stderr)
        return 1

    pixbuf.savev(target, "png", [], [])
    print(target)
    return 0


if __name__ == "__main__":
    sys.exit(main())
