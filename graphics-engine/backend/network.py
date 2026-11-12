"""
Stato delle connessioni di rete per il system tray.

Legge direttamente il kernel (``/sys/class/net``) e, quando disponibili, gli
strumenti di sistema per il nome della rete Wi-Fi. Non avvia né configura
connessioni: si limita a riportare quello che il sistema sta facendo, così la
shell non può rompere la rete e non richiede privilegi.
"""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

from PySide6.QtCore import QObject, Property, Signal, Slot

SYS_NET = Path("/sys/class/net")
WIRELESS = Path("/proc/net/wireless")


def _read(path: Path, default: str = "") -> str:
    try:
        return path.read_text(encoding="ascii", errors="replace").strip()
    except OSError:
        return default


def _run(command: list[str], timeout: float = 2.0) -> str:
    if not shutil.which(command[0]):
        return ""
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.SubprocessError):
        return ""
    return result.stdout.strip()


def _ipv4(name: str) -> str:
    output = _run(["ip", "-4", "-o", "addr", "show", "dev", name])
    match = re.search(r"inet\s+(\d+\.\d+\.\d+\.\d+)", output)
    return match.group(1) if match else ""


def _nmcli(arguments: list[str], timeout: float = 40.0) -> tuple[int, str]:
    """Esegue nmcli e restituisce (codice di uscita, output combinato)."""
    binary = shutil.which("nmcli")
    if not binary:
        return 127, "NetworkManager (nmcli) non disponibile"
    try:
        result = subprocess.run(
            [binary] + arguments,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except (OSError, subprocess.SubprocessError) as error:
        return 1, str(error)
    return result.returncode, (result.stdout or "") + (result.stderr or "")


def _split_terse(line: str) -> list[str]:
    """Divide una riga di nmcli -t rispettando i due punti escapati."""
    parts: list[str] = []
    current: list[str] = []
    escaped = False
    for character in line:
        if escaped:
            current.append(character)
            escaped = False
        elif character == "\\":
            escaped = True
        elif character == ":":
            parts.append("".join(current))
            current = []
        else:
            current.append(character)
    parts.append("".join(current))
    return parts


def _clean_message(output: str) -> str:
    """Riduce il messaggio di nmcli alla riga utile."""
    for line in output.splitlines():
        text = line.strip()
        if text.startswith("Error") or text.startswith("error"):
            return text
    return output.strip().splitlines()[0] if output.strip() else "operazione non riuscita"


def _wifi_details(name: str) -> tuple[str, int]:
    """Restituisce (nome rete, qualità del segnale 0-100)."""
    ssid = _run(["iwgetid", "-r", name])
    if not ssid:
        output = _run(["nmcli", "-t", "-f", "GENERAL.CONNECTION", "device", "show", name])
        if output.startswith("GENERAL.CONNECTION:"):
            candidate = output.split(":", 1)[1].strip()
            if candidate and candidate != "--":
                ssid = candidate

    signal = 0
    try:
        for line in WIRELESS.read_text(encoding="ascii", errors="replace").splitlines():
            if ":" in line and line.strip().startswith(name + ":"):
                fields = line.split(":", 1)[1].split()
                if fields:
                    quality = float(fields[1].rstrip("."))
                    signal = max(0, min(100, int(quality / 70 * 100)))
    except (OSError, ValueError):
        pass

    return ssid, signal


def _kind(name: str) -> str:
    if name == "lo":
        return "loopback"
    if (SYS_NET / name / "wireless").exists() or (SYS_NET / name / "phy80211").exists():
        return "wifi"
    if name.startswith(("en", "eth")):
        return "ethernet"
    return "other"


def _operstate(name: str) -> str:
    state = _read(SYS_NET / name / "operstate", "unknown")
    carrier = _read(SYS_NET / name / "carrier", "0")
    if state == "up" and carrier == "1":
        return "up"
    if state == "dormant":
        return "dormant"
    return "down"


class Network(QObject):
    changed = Signal()

    def __init__(self) -> None:
        super().__init__()
        self._interfaces: list[dict] = []
        self._last_error = ""
        self._refresh()

    # --- lettura -------------------------------------------------------------
    def _refresh(self) -> None:
        interfaces: list[dict] = []

        try:
            names = sorted(p.name for p in SYS_NET.iterdir())
        except OSError:
            names = []

        for name in names:
            kind = _kind(name)
            if kind == "loopback":
                continue

            state = _operstate(name)
            address = _ipv4(name) if state == "up" else ""
            ssid, signal = _wifi_details(name) if kind == "wifi" else ("", 0)

            interfaces.append(
                {
                    "name": name,
                    "kind": kind,
                    "state": state,
                    "connected": bool(address),
                    "address": address,
                    "mac": _read(SYS_NET / name / "address"),
                    "ssid": ssid,
                    "signal": signal,
                    "label": ssid if ssid else name,
                }
            )

        # prima le interfacce collegate, poi le altre
        interfaces.sort(key=lambda i: (not i["connected"], i["name"]))
        self._interfaces = interfaces

    def _get_interfaces(self) -> list[dict]:
        return self._interfaces

    interfaces = Property("QVariantList", _get_interfaces, notify=changed)

    def _get_online(self) -> bool:
        return any(i["connected"] for i in self._interfaces)

    online = Property(bool, _get_online, notify=changed)

    def _get_primary_kind(self) -> str:
        for item in self._interfaces:
            if item["connected"]:
                return item["kind"]
        return "none"

    primaryKind = Property(str, _get_primary_kind, notify=changed)

    def _get_primary_name(self) -> str:
        for item in self._interfaces:
            if item["connected"]:
                return item["label"]
        return ""

    primaryName = Property(str, _get_primary_name, notify=changed)

    def _get_summary(self) -> str:
        for item in self._interfaces:
            if item["connected"]:
                if item["kind"] == "wifi" and item["ssid"]:
                    return f"{item['ssid']}  ·  {item['address']}"
                return f"{item['name']}  ·  {item['address']}"
        return "Nessuna connessione"

    summary = Property(str, _get_summary, notify=changed)

    # --- aggiornamento -------------------------------------------------------
    @Slot()
    def refresh(self) -> None:
        before = [(i["name"], i["state"], i["address"], i["ssid"]) for i in self._interfaces]
        self._refresh()
        after = [(i["name"], i["state"], i["address"], i["ssid"]) for i in self._interfaces]
        if before != after:
            self.changed.emit()

    @Slot(result="QVariantList")
    def details(self) -> list[dict]:
        self.refresh()
        return self._interfaces

    # --- Wi-Fi ---------------------------------------------------------------
    def _get_wifi_available(self) -> bool:
        return any(item["kind"] == "wifi" for item in self._interfaces)

    wifiAvailable = Property(bool, _get_wifi_available, notify=changed)

    def _get_error(self) -> str:
        return self._last_error

    lastError = Property(str, _get_error, notify=changed)

    def _fail(self, message: str) -> None:
        self._last_error = message
        self.changed.emit()

    @Slot(result="QVariantList")
    def scanWifi(self) -> list[dict]:  # noqa: N802
        """Reti Wi-Fi visibili, ordinate per segnale."""
        code, output = _nmcli(
            ["-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
             "device", "wifi", "list", "--rescan", "yes"],
            timeout=45.0,
        )
        if code != 0:
            self._fail(_clean_message(output))
            return []

        found: dict[str, dict] = {}
        for line in output.splitlines():
            parts = _split_terse(line)
            if len(parts) < 4:
                continue
            in_use, ssid, signal_text, security = parts[0], parts[1], parts[2], parts[3]
            if not ssid:
                continue
            try:
                strength = int(signal_text)
            except ValueError:
                strength = 0

            entry = {
                "ssid": ssid,
                "signal": strength,
                "secured": bool(security.strip()),
                "security": security.strip() or "aperta",
                "connected": in_use.strip() == "*",
            }
            # una rete puo' comparire piu' volte: si tiene il segnale migliore
            if ssid not in found or strength > found[ssid]["signal"]:
                found[ssid] = entry

        self._last_error = ""
        return sorted(found.values(), key=lambda n: (-n["signal"], n["ssid"].lower()))

    @Slot(str, str, result="QVariantMap")
    def connectWifi(self, ssid: str, password: str) -> dict:  # noqa: N802
        """Connette a una rete Wi-Fi tramite NetworkManager."""
        name = (ssid or "").strip()
        if not name:
            return {"ok": False, "error": "rete non specificata"}

        arguments = ["device", "wifi", "connect", name]
        if password:
            arguments += ["password", password]

        code, output = _nmcli(arguments, timeout=60.0)
        self.refresh()

        if code != 0:
            message = _clean_message(output)
            self._fail(message)
            return {"ok": False, "error": message}

        self._last_error = ""
        return {"ok": True, "error": ""}

    @Slot(result="QVariantMap")
    def wifiStatus(self) -> dict:  # noqa: N802
        self.refresh()
        for item in self._interfaces:
            if item["kind"] == "wifi":
                return item
        return {}
