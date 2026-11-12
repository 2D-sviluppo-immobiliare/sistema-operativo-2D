"""
Cestino secondo la specifica freedesktop.org (XDG Trash).

Riferimento: https://specifications.freedesktop.org/trash-spec/

Il cestino della home vive in ``$XDG_DATA_HOME/Trash`` con due sottocartelle:

* ``files/``  i file spostati
* ``info/``   un file ``<nome>.trashinfo`` per ogni voce

Il file ``.trashinfo`` contiene il percorso originale e la data di
eliminazione, ed e' cio' che rende possibile il ripristino.

I file che stanno su un altro filesystem (una chiavetta USB) vanno nel cestino
di quel filesystem, non in quello della home: altrimenti "spostare" il file
significherebbe copiarlo per intero.
"""

from __future__ import annotations

import os
import shutil
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from urllib.parse import quote, unquote

from PySide6.QtCore import QAbstractListModel, QModelIndex, Property, Qt, Signal, Slot


def _data_home() -> Path:
    return Path(os.environ.get("XDG_DATA_HOME") or (Path.home() / ".local" / "share"))


def _mount_point(path: Path) -> Path:
    """Restituisce il punto di mount che contiene ``path``."""
    current = path if path.is_dir() else path.parent
    while current != current.parent:
        if os.path.ismount(current):
            return current
        current = current.parent
    return Path("/")


def trash_directory_for(path: Path) -> tuple[Path, Path]:
    """Indica (cartella files, cartella info) del cestino competente."""
    home_trash = _data_home() / "Trash"
    home_dev = os.stat(Path.home()).st_dev

    try:
        target_dev = os.stat(path if not path.is_symlink() else path.parent).st_dev
    except OSError:
        target_dev = home_dev

    if target_dev == home_dev:
        return home_trash / "files", home_trash / "info"

    top = _mount_point(path)

    # Prima scelta: <top>/.Trash/<uid>, valida solo se .Trash esiste, non e'
    # un symlink ed e' sticky.
    shared = top / ".Trash"
    if shared.is_dir() and not shared.is_symlink():
        try:
            mode = shared.stat().st_mode
        except OSError:
            mode = 0
        if mode & 0o1000:
            base = shared / str(os.getuid())
            return base / "files", base / "info"

    # Seconda scelta: <top>/.Trash-<uid>
    base = top / f".Trash-{os.getuid()}"
    return base / "files", base / "info"


def _unique_name(files_dir: Path, info_dir: Path, name: str) -> str:
    candidate = name
    index = 1
    while (files_dir / candidate).exists() or (info_dir / f"{candidate}.trashinfo").exists():
        if "." in name and not name.startswith("."):
            stem, suffix = name.rsplit(".", 1)
            candidate = f"{stem}.{index}.{suffix}"
        else:
            candidate = f"{name}.{index}"
        index += 1
    return candidate


def move_to_trash(paths: list[str]) -> list[tuple[str, str]]:
    """Sposta i percorsi nel cestino.

    Restituisce una lista di coppie ``(percorso, errore)``: errore vuoto
    significa operazione riuscita.
    """
    results: list[tuple[str, str]] = []

    for raw in paths:
        source = Path(raw).expanduser()
        if not source.exists() and not source.is_symlink():
            results.append((raw, "il file non esiste"))
            continue

        try:
            files_dir, info_dir = trash_directory_for(source)
            files_dir.mkdir(parents=True, exist_ok=True)
            info_dir.mkdir(parents=True, exist_ok=True)

            name = _unique_name(files_dir, info_dir, source.name)
            info_path = info_dir / f"{name}.trashinfo"

            stamp = datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
            info_path.write_text(
                "[Trash Info]\n"
                f"Path={quote(str(source))}\n"
                f"DeletionDate={stamp}\n",
                encoding="utf-8",
            )

            shutil.move(str(source), str(files_dir / name))
            results.append((raw, ""))
        except OSError as error:
            results.append((raw, str(error)))

    return results


def read_info(info_path: Path) -> tuple[str, str]:
    """Legge ``Path`` e ``DeletionDate`` da un file .trashinfo."""
    original = ""
    deleted = ""
    try:
        for line in info_path.read_text(encoding="utf-8").splitlines():
            if line.startswith("Path="):
                original = unquote(line[5:].strip())
            elif line.startswith("DeletionDate="):
                deleted = line[13:].strip()
    except OSError:
        pass
    return original, deleted


@dataclass
class TrashEntry:
    name: str
    file_path: Path
    info_path: Path
    original: str
    deleted: str
    size: int
    is_dir: bool


def _entry_size(path: Path) -> int:
    try:
        if path.is_dir() and not path.is_symlink():
            total = 0
            for root, _dirs, files in os.walk(path):
                for name in files:
                    try:
                        total += os.path.getsize(os.path.join(root, name))
                    except OSError:
                        continue
            return total
    except OSError:
        return 0
    try:
        return path.stat().st_size
    except OSError:
        return 0


def human_size(num: int) -> str:
    if num < 1024:
        return f"{num} B"
    value = float(num)
    for unit in ("KB", "MB", "GB", "TB"):
        value /= 1024.0
        if value < 1024.0:
            return f"{value:.0f} {unit}" if value >= 100 else f"{value:.1f} {unit}"
    return f"{value:.1f} PB"


def _all_trash_roots() -> list[Path]:
    """Tutti i cestini noti: quello della home piu' quelli dei volumi montati."""
    roots = [(_data_home() / "Trash")]

    for base in ("/media", "/run/media", "/mnt"):
        base_path = Path(base)
        if not base_path.is_dir():
            continue
        try:
            for child in base_path.iterdir():
                candidates = [child, child / str(os.getuid())]
                for candidate in candidates:
                    if (candidate / "files").is_dir() and (candidate / "info").is_dir():
                        roots.append(candidate)
                # <top>/.Trash/<uid> e <top>/.Trash-<uid>
                uid = str(os.getuid())
                for name in (f".Trash/{uid}", f".Trash-{uid}"):
                    candidate = child / name
                    if (candidate / "files").is_dir():
                        roots.append(candidate)
        except OSError:
            continue

    unique: list[Path] = []
    for root in roots:
        if root not in unique and (root / "files").is_dir():
            unique.append(root)
    return unique


class TrashModel(QAbstractListModel):
    """Modello QML del contenuto del cestino."""

    NameRole = Qt.UserRole + 1
    OriginalRole = Qt.UserRole + 2
    DeletedRole = Qt.UserRole + 3
    SizeRole = Qt.UserRole + 4
    IsDirRole = Qt.UserRole + 5
    FilePathRole = Qt.UserRole + 6

    countChanged = Signal()
    changed = Signal()
    lastErrorChanged = Signal()

    def __init__(self) -> None:
        super().__init__()
        self._entries: list[TrashEntry] = []
        self._last_error = ""
        self.refresh()

    # --- ruoli ---------------------------------------------------------------
    def roleNames(self) -> dict[int, bytes]:
        return {
            self.NameRole: b"name",
            self.OriginalRole: b"originalPath",
            self.DeletedRole: b"deletedAt",
            self.SizeRole: b"sizeText",
            self.IsDirRole: b"isDir",
            self.FilePathRole: b"filePath",
        }

    def rowCount(self, parent=QModelIndex()) -> int:  # noqa: N802
        return 0 if parent.isValid() else len(self._entries)

    def data(self, index: QModelIndex, role: int = Qt.DisplayRole):
        if not index.isValid() or index.row() >= len(self._entries):
            return None
        entry = self._entries[index.row()]
        if role == self.NameRole:
            return entry.name
        if role == self.OriginalRole:
            return entry.original
        if role == self.DeletedRole:
            return entry.deleted.replace("T", " ")
        if role == self.SizeRole:
            return human_size(entry.size)
        if role == self.IsDirRole:
            return entry.is_dir
        if role == self.FilePathRole:
            return str(entry.file_path)
        return None

    # --- proprieta' ----------------------------------------------------------
    def _get_count(self) -> int:
        return len(self._entries)

    count = Property(int, _get_count, notify=countChanged)

    def _get_error(self) -> str:
        return self._last_error

    lastError = Property(str, _get_error, notify=lastErrorChanged)

    def _get_is_empty(self) -> bool:
        return not self._entries

    isEmpty = Property(bool, _get_is_empty, notify=countChanged)

    # --- operazioni ----------------------------------------------------------
    @Slot()
    def refresh(self) -> None:
        entries: list[TrashEntry] = []

        for root in _all_trash_roots():
            files_dir = root / "files"
            info_dir = root / "info"
            try:
                names = sorted(files_dir.iterdir(), key=lambda p: p.name.lower())
            except OSError:
                continue

            for item in names:
                info_path = info_dir / f"{item.name}.trashinfo"
                original, deleted = read_info(info_path)
                entries.append(
                    TrashEntry(
                        name=item.name,
                        file_path=item,
                        info_path=info_path,
                        original=original,
                        deleted=deleted,
                        size=_entry_size(item),
                        is_dir=item.is_dir() and not item.is_symlink(),
                    )
                )

        # piu' recenti in cima
        entries.sort(key=lambda e: e.deleted, reverse=True)

        self.beginResetModel()
        self._entries = entries
        self.endResetModel()
        self.countChanged.emit()
        self.changed.emit()

    def _path_at(self, row: int) -> TrashEntry | None:
        if 0 <= row < len(self._entries):
            return self._entries[row]
        return None

    @Slot(int, result=bool)
    def restore(self, row: int) -> bool:
        entry = self._path_at(row)
        if entry is None:
            return False

        if not entry.original:
            self._fail("percorso originale sconosciuto")
            return False

        destination = Path(entry.original)
        if destination.exists():
            self._fail(f"esiste gia': {destination}")
            return False

        try:
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.move(str(entry.file_path), str(destination))
            entry.info_path.unlink(missing_ok=True)
        except OSError as error:
            self._fail(str(error))
            return False

        self.refresh()
        return True

    @Slot(int, result=bool)
    def deleteForever(self, row: int) -> bool:
        entry = self._path_at(row)
        if entry is None:
            return False

        try:
            if entry.is_dir and not entry.file_path.is_symlink():
                shutil.rmtree(entry.file_path)
            else:
                entry.file_path.unlink(missing_ok=True)
            entry.info_path.unlink(missing_ok=True)
        except OSError as error:
            self._fail(str(error))
            return False

        self.refresh()
        return True

    @Slot(result=bool)
    def empty(self) -> bool:
        failures = 0
        for entry in list(self._entries):
            try:
                if entry.is_dir and not entry.file_path.is_symlink():
                    shutil.rmtree(entry.file_path)
                else:
                    entry.file_path.unlink(missing_ok=True)
                entry.info_path.unlink(missing_ok=True)
            except OSError:
                failures += 1

        self.refresh()
        if failures:
            self._fail(f"{failures} elementi non rimossi")
            return False
        return True

    @Slot(str, result=int)
    def movePathsToTrash(self, path: str) -> int:  # noqa: N802
        """Sposta un percorso nel cestino e restituisce il numero di errori."""
        errors = [e for _p, e in move_to_trash([path]) if e]
        self.refresh()
        if errors:
            self._fail(errors[0])
        return len(errors)

    def _fail(self, message: str) -> None:
        self._last_error = message
        self.lastErrorChanged.emit()
