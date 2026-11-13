"""
Rilevamento e avvio delle applicazioni esterne reali.

Nessuna finestra simulata: se il binario non c'e', la shell lo dice e mostra
come installarlo invece di fingere che l'applicazione esista.
"""

from __future__ import annotations

import shutil
import sys

from PySide6.QtCore import QObject, QProcess, Slot

CANDIDATES: dict[str, list[str]] = {
    "browser": [
        "google-chrome-stable",
        "google-chrome",
        "chromium",
        "chromium-browser",
        "brave-browser",
    ],
    "code": [
        "code",
        "codium",
        "code-insiders",
    ],
}

DISPLAY_NAMES: dict[str, str] = {
    "browser": "Google Chrome",
    "code": "Visual Studio Code",
}

INSTALL_HINTS: dict[str, str] = {
    "browser": (
        "Nessun browser Chromium installato.\n\n"
        "Opzione 1 (Debian/Ubuntu):\n"
        "    sudo apt install chromium\n\n"
        "Opzione 2 (Google Chrome ufficiale):\n"
        "    scarica il pacchetto .deb da google.com/chrome\n"
        "    sudo apt install ./google-chrome-stable_current_amd64.deb"
    ),
    "code": (
        "Visual Studio Code non risulta installato.\n\n"
        "Opzione 1 (repository Microsoft):\n"
        "    sudo apt install code\n\n"
        "Opzione 2 (VSCodium, senza telemetria):\n"
        "    sudo apt install codium"
    ),
}


def _which(candidates: list[str]) -> str:
    for candidate in candidates:
        found = shutil.which(candidate)
        if found:
            return found
    return ""


class Apps(QObject):
    """Informazioni e avvio delle applicazioni esterne."""

    def __init__(self) -> None:
        super().__init__()
        self._procs: dict[str, QProcess] = {}

    def stop_all(self) -> None:
        """Chiude le applicazioni avviate dalla shell.

        Alla fine della sessione i figli non devono sopravvivere alla shell.
        """
        for key in list(self._procs):
            proc = self._procs.pop(key)
            if proc.state() == QProcess.NotRunning:
                continue
            print(f"[2D] arresto: {key}", flush=True)
            proc.terminate()
            if not proc.waitForFinished(1200):
                proc.kill()
                proc.waitForFinished(600)

    @Slot(str, result="QVariantMap")
    def info(self, key: str) -> dict:
        path = _which(CANDIDATES.get(key, []))
        return {
            "key": key,
            "name": DISPLAY_NAMES.get(key, key),
            "available": bool(path),
            "path": path,
            "install": INSTALL_HINTS.get(key, ""),
        }

    @Slot(str, result=bool)
    def isAvailable(self, key: str) -> bool:  # noqa: N802
        return bool(_which(CANDIDATES.get(key, [])))

    @Slot(str, str, result=bool)
    def start(self, key: str, argument: str) -> bool:
        """Avvia l'applicazione; ``argument`` e' un URL o un percorso."""
        binary = _which(CANDIDATES.get(key, []))
        if not binary:
            return False

        running = self._procs.get(key)
        if running is not None and running.state() != QProcess.NotRunning:
            # gia' avviata: Chrome apre una nuova scheda, VS Code una nuova
            # finestra sullo stesso processo
            running.terminate()
            running.waitForFinished(600)
            self._procs.pop(key, None)

        proc = QProcess(self)
        proc.setProgram(binary)
        proc.setArguments([argument] if argument else [])
        proc.finished.connect(lambda *_: self._procs.pop(key, None))
        proc.start()
        if not proc.waitForStarted(3000):
            print(f"[2D] avvio fallito: {binary}", file=sys.stderr, flush=True)
            return False
        self._procs[key] = proc
        print(f"[2D] avvio: {binary} {argument}".rstrip(), flush=True)
        return True

    @Slot(str, result=bool)
    def openFile(self, path: str) -> bool:  # noqa: N802
        """Apre un file con l'applicazione associata dal sistema."""
        opener = shutil.which("xdg-open")
        if not opener:
            print("[2D] xdg-open non disponibile", file=sys.stderr, flush=True)
            return False

        proc = QProcess(self)
        proc.setProgram(opener)
        proc.setArguments([path])
        proc.startDetached()
        print(f"[2D] apri: {path}", flush=True)
        return True

    @Slot(result="QVariantList")
    def detected(self) -> list[dict]:
        return [self.info(key) for key in CANDIDATES]

    @Slot(result=str)
    def projectPath(self) -> str:  # noqa: N802
        """Cartella da aprire nell'editor quando non ne viene indicata una."""
        from pathlib import Path

        for candidate in ("/opt/2d-os/engine", "/app", str(Path.home())):
            if Path(candidate).is_dir():
                return candidate
        return str(Path.home())
