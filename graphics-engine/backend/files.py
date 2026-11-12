"""
Navigatore di file per il desktop 2D.

Espone un modello Qt compatibile con QML e tutte le operazioni di base di un
file manager. Le operazioni distruttive sono limitate alla home dell'utente e
ai dispositivi rimovibili montati: fuori da quelle radici la navigazione resta
possibile ma in sola lettura, cosi' un clic sbagliato non puo' cancellare
/config o /usr.
"""

from __future__ import annotations

import os
import shutil
from datetime import datetime
from pathlib import Path

from PySide6.QtCore import QAbstractListModel, QModelIndex, Property, Qt, Signal, Slot

from .trash import human_size, move_to_trash

HOME = Path.home()

# Radici in cui e' consentito scrivere, cancellare, rinominare.
WRITABLE_ROOTS: list[Path] = [HOME]

REMOVABLE_BASES = ("/media", "/run/media", "/mnt")

KIND_BY_EXTENSION = {
    "image": {".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp", ".svg", ".tiff", ".heic"},
    "video": {".mp4", ".mkv", ".avi", ".mov", ".webm", ".m4v", ".mpg"},
    "audio": {".mp3", ".wav", ".flac", ".ogg", ".m4a", ".aac", ".opus"},
    "archive": {".zip", ".tar", ".gz", ".bz2", ".xz", ".7z", ".rar", ".zst"},
    "code": {".py", ".qml", ".js", ".ts", ".json", ".sh", ".c", ".h", ".cpp",
             ".rs", ".go", ".java", ".css", ".html", ".xml", ".yml", ".yaml",
             ".toml", ".ini", ".conf", ".service"},
    "text": {".txt", ".md", ".log", ".csv", ".rst"},
    "pdf": {".pdf"},
    "document": {".odt", ".doc", ".docx", ".rtf"},
    "sheet": {".ods", ".xls", ".xlsx"},
    "presentation": {".odp", ".ppt", ".pptx"},
    "executable": {".deb", ".appimage", ".run", ".bin", ".iso"},
}


def kind_of(path: Path) -> str:
    if path.is_dir():
        return "folder"
    if path.is_symlink():
        return "link"
    suffixes = [s.lower() for s in path.suffixes]
    for extension in reversed(suffixes):
        for kind, extensions in KIND_BY_EXTENSION.items():
            if extension in extensions:
                return kind
    return "file"


def _removable_roots() -> list[Path]:
    roots: list[Path] = []
    for base in REMOVABLE_BASES:
        base_path = Path(base)
        if not base_path.is_dir():
            continue
        try:
            for child in base_path.iterdir():
                if child.is_dir() and not child.is_symlink():
                    roots.append(child)
                    # /media/<utente>/<volume>
                    try:
                        for nested in child.iterdir():
                            if nested.is_dir() and os.path.ismount(nested):
                                roots.append(nested)
                    except OSError:
                        continue
        except OSError:
            continue
    return roots


def _writable_roots() -> list[Path]:
    roots = list(WRITABLE_ROOTS)
    for root in _removable_roots():
        if root not in roots:
            roots.append(root)
    return roots


class FileBrowser(QAbstractListModel):
    NameRole = Qt.UserRole + 1
    PathRole = Qt.UserRole + 2
    IsDirRole = Qt.UserRole + 3
    SizeRole = Qt.UserRole + 4
    SizeTextRole = Qt.UserRole + 5
    ModifiedRole = Qt.UserRole + 6
    IconRole = Qt.UserRole + 7
    HiddenRole = Qt.UserRole + 8
    SymlinkRole = Qt.UserRole + 9

    currentPathChanged = Signal()
    countChanged = Signal()
    placesChanged = Signal()
    searchingChanged = Signal()
    lastErrorChanged = Signal()
    writableChanged = Signal()
    requestOpen = Signal(str, bool)  # percorso, e' una cartella

    def __init__(self) -> None:
        super().__init__()
        self._entries: list[dict] = []
        self._current = HOME
        self._query = ""
        self._last_error = ""
        self._show_hidden = False
        self._places: list[dict] = []
        self._rebuild_places()

    # --- ruoli ---------------------------------------------------------------
    def roleNames(self) -> dict[int, bytes]:
        return {
            self.NameRole: b"name",
            self.PathRole: b"path",
            self.IsDirRole: b"isDir",
            self.SizeRole: b"size",
            self.SizeTextRole: b"sizeText",
            self.ModifiedRole: b"modified",
            self.IconRole: b"icon",
            self.HiddenRole: b"hidden",
            self.SymlinkRole: b"isLink",
        }

    def rowCount(self, parent=QModelIndex()) -> int:  # noqa: N802
        return 0 if parent.isValid() else len(self._entries)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid() or index.row() >= len(self._entries):
            return None
        entry = self._entries[index.row()]
        if role == self.NameRole:
            return entry["name"]
        if role == self.PathRole:
            return entry["path"]
        if role == self.IsDirRole:
            return entry["is_dir"]
        if role == self.SizeRole:
            return entry["size"]
        if role == self.SizeTextRole:
            return "" if entry["is_dir"] else human_size(entry["size"])
        if role == self.ModifiedRole:
            return entry["modified"]
        if role == self.IconRole:
            return entry["icon"]
        if role == self.HiddenRole:
            return entry["hidden"]
        if role == self.SymlinkRole:
            return entry["is_link"]
        return None

    # --- proprieta' ----------------------------------------------------------
    def _get_current(self) -> str:
        return str(self._current)

    currentPath = Property(str, _get_current, notify=currentPathChanged)

    def _get_count(self) -> int:
        return len(self._entries)

    count = Property(int, _get_count, notify=countChanged)

    def _get_can_go_up(self) -> bool:
        return self._current.parent != self._current

    canGoUp = Property(bool, _get_can_go_up, notify=currentPathChanged)

    def _get_places(self) -> list[dict]:
        return self._places

    places = Property("QVariantList", _get_places, notify=placesChanged)

    def _get_searching(self) -> bool:
        return bool(self._query)

    searching = Property(bool, _get_searching, notify=searchingChanged)

    def _get_error(self) -> str:
        return self._last_error

    lastError = Property(str, _get_error, notify=lastErrorChanged)

    def _get_writable(self) -> bool:
        return self._is_writable(self._current)

    writable = Property(bool, _get_writable, notify=writableChanged)

    # --- costruzione elenco --------------------------------------------------
    def _rebuild_places(self) -> None:
        places: list[dict] = [{"label": "Home", "path": str(HOME), "glyph": "\u2302"}]

        candidates = [
            ("Documenti", "DOCUMENTS", "\u25A4"),
            ("Scaricati", "DOWNLOAD", "\u21E9"),
            ("Immagini", "PICTURES", "\u25A3"),
            ("Musica", "MUSIC", "\u266B"),
            ("Video", "VIDEOS", "\u25B6"),
            ("Scrivania", "DESKTOP", "\u25AB"),
        ]
        for label, key, glyph in candidates:
            raw = os.environ.get(f"XDG_{key}_DIR", "")
            path = Path(raw) if raw else HOME / label
            if path.is_dir():
                places.append({"label": label, "path": str(path), "glyph": glyph})

        places.append({"label": "Filesystem", "path": "/", "glyph": "\u25C8"})

        for root in _removable_roots():
            places.append({"label": root.name or str(root), "path": str(root), "glyph": "\u25A4"})

        self._places = places
        self.placesChanged.emit()

    def _is_writable(self, path: Path) -> bool:
        try:
            resolved = path.resolve()
        except OSError:
            return False
        for root in _writable_roots():
            try:
                resolved_root = root.resolve()
            except OSError:
                continue
            if resolved == resolved_root or resolved_root in resolved.parents:
                return True
        return False

    def _load(self) -> None:
        self._entries = []
        self._current = self._current if self._current.is_dir() else HOME

        try:
            children = sorted(
                self._current.iterdir(),
                key=lambda p: (not p.is_dir(), p.name.lower()),
            )
        except PermissionError:
            self._fail(f"permesso negato: {self._current}")
            children = []
        except OSError as error:
            self._fail(str(error))
            children = []

        for child in children:
            hidden = child.name.startswith(".")
            if hidden and not self._show_hidden:
                continue
            try:
                stat = child.stat()
                size = stat.st_size
                modified = datetime.fromtimestamp(stat.st_mtime).strftime("%d/%m/%Y %H:%M")
            except OSError:
                size = 0
                modified = ""
            self._entries.append(
                {
                    "name": child.name,
                    "path": str(child),
                    "is_dir": child.is_dir(),
                    "is_link": child.is_symlink(),
                    "size": size,
                    "modified": modified,
                    "icon": kind_of(child),
                    "hidden": hidden,
                }
            )

    def _reset(self) -> None:
        self.beginResetModel()
        self.endResetModel()
        self.countChanged.emit()
        self.currentPathChanged.emit()
        self.writableChanged.emit()

    def _fail(self, message: str) -> None:
        self._last_error = message
        self.lastErrorChanged.emit()

    # --- navigazione ---------------------------------------------------------
    @Slot()
    def goHome(self) -> None:  # noqa: N802
        self.goTo(str(HOME))

    @Slot(str, result=bool)
    def goTo(self, path: str) -> bool:
        target = Path(path).expanduser()
        if not target.is_dir():
            self._fail(f"cartella inesistente: {path}")
            return False
        self._current = target
        self._query = ""
        self.searchingChanged.emit()
        self._load()
        self._reset()
        return True

    @Slot(result=bool)
    def goUp(self) -> bool:
        if not self.canGoUp:
            return False
        return self.goTo(str(self._current.parent))

    @Slot(int, result=bool)
    def enter(self, row: int) -> bool:
        if not 0 <= row < len(self._entries):
            return False
        entry = self._entries[row]
        if entry["is_dir"]:
            return self.goTo(entry["path"])
        self.requestOpen.emit(entry["path"], False)
        return True

    @Slot(int, result=str)
    def pathAt(self, row: int) -> str:
        if 0 <= row < len(self._entries):
            return self._entries[row]["path"]
        return ""

    @Slot(int, result="QVariantMap")
    def infoAt(self, row: int) -> dict:
        if not 0 <= row < len(self._entries):
            return {}
        entry = self._entries[row]
        path = Path(entry["path"])
        info = {
            "name": entry["name"],
            "path": entry["path"],
            "isDir": entry["is_dir"],
            "size": human_size(entry["size"]) if not entry["is_dir"] else "cartella",
            "modified": entry["modified"],
            "kind": entry["icon"],
            "readable": os.access(path, os.R_OK),
            "writable": self._is_writable(path),
        }
        return info

    @Slot(bool)
    def setShowHidden(self, value: bool) -> None:  # noqa: N802
        if self._show_hidden == value:
            return
        self._show_hidden = value
        self._load()
        self._reset()

    @Slot()
    def refresh(self) -> None:
        if self._query:
            self.search(self._query)
            return
        self._load()
        self._reset()
        self._rebuild_places()

    # --- ricerca -------------------------------------------------------------
    @Slot(str)
    def search(self, query: str) -> None:
        self._query = query.strip()
        self.searchingChanged.emit()

        if not self._query:
            self._load()
            self._reset()
            return

        needle = self._query.lower()
        found: list[dict] = []
        limit = 400

        for root, dirs, files in os.walk(self._current):
            dirs[:] = [d for d in dirs if not d.startswith(".")]
            for name in dirs + files:
                if needle not in name.lower():
                    continue
                full = Path(root) / name
                try:
                    stat = full.stat()
                    size = stat.st_size
                    modified = datetime.fromtimestamp(stat.st_mtime).strftime("%d/%m/%Y %H:%M")
                except OSError:
                    size = 0
                    modified = ""
                found.append(
                    {
                        "name": name,
                        "path": str(full),
                        "is_dir": full.is_dir(),
                        "is_link": full.is_symlink(),
                        "size": size,
                        "modified": modified,
                        "icon": kind_of(full),
                        "hidden": False,
                    }
                )
                if len(found) >= limit:
                    break
            if len(found) >= limit:
                break

        self.beginResetModel()
        self._entries = found
        self.endResetModel()
        self.countChanged.emit()

    @Slot()
    def cancelSearch(self) -> None:  # noqa: N802
        self.search("")

    # --- operazioni ----------------------------------------------------------
    @Slot(str, result=bool)
    def makeDirectory(self, name: str) -> bool:  # noqa: N802
        clean = name.strip()
        if not clean or "/" in clean:
            self._fail("nome non valido")
            return False
        if not self._is_writable(self._current):
            self._fail("cartella in sola lettura")
            return False
        target = self._current / clean
        if target.exists():
            self._fail("esiste gia'")
            return False
        try:
            target.mkdir()
        except OSError as error:
            self._fail(str(error))
            return False
        self.refresh()
        return True

    @Slot(int, str, result=bool)
    def renameAt(self, row: int, new_name: str) -> bool:  # noqa: N802
        if not 0 <= row < len(self._entries):
            return False
        source = Path(self._entries[row]["path"])
        clean = new_name.strip()
        if not clean or "/" in clean:
            self._fail("nome non valido")
            return False
        if not self._is_writable(source.parent):
            self._fail("percorso in sola lettura")
            return False
        target = source.parent / clean
        if target.exists():
            self._fail("esiste gia'")
            return False
        try:
            source.rename(target)
        except OSError as error:
            self._fail(str(error))
            return False
        self.refresh()
        return True

    def _transfer(self, paths: list[str], destination: str, move: bool) -> int:
        dest_dir = Path(destination)
        if not dest_dir.is_dir():
            self._fail("destinazione non valida")
            return len(paths)

        failures = 0
        for raw in paths:
            source = Path(raw)
            if not source.exists():
                failures += 1
                continue
            if not self._is_writable(dest_dir):
                self._fail("destinazione in sola lettura")
                failures += 1
                continue
            target = dest_dir / source.name
            if target.exists():
                self._fail(f"esiste gia': {source.name}")
                failures += 1
                continue
            try:
                if move:
                    shutil.move(str(source), str(target))
                else:
                    if source.is_dir():
                        shutil.copytree(str(source), str(target), symlinks=True)
                    else:
                        shutil.copy2(str(source), str(target))
            except (OSError, shutil.Error) as error:
                self._fail(str(error))
                failures += 1

        self.refresh()
        return failures

    @Slot("QVariantList", str, result=int)
    def copyPaths(self, paths, destination: str) -> int:  # noqa: N802
        return self._transfer([str(p) for p in paths], destination, move=False)

    @Slot("QVariantList", str, result=int)
    def movePaths(self, paths, destination: str) -> int:  # noqa: N802
        return self._transfer([str(p) for p in paths], destination, move=True)

    @Slot("QVariantList", result=int)
    def trashPaths(self, paths) -> int:  # noqa: N802
        errors = [error for _p, error in move_to_trash([str(p) for p in paths]) if error]
        self.refresh()
        if errors:
            self._fail(errors[0])
        return len(errors)

    @Slot(result=str)
    def homePath(self) -> str:  # noqa: N802
        return str(HOME)
