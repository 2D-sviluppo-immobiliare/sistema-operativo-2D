"""
Client Chat2D lato shell.

La shell non conosce nessun provider: chiede al server locale chi e' attivo e
gli manda i messaggi. Qui c'e' solo lo stato per QML e la gestione della
configurazione scelta dall'utente.

Le chiamate HTTP girano in un thread separato: l'interfaccia non si blocca mai.
"""

from __future__ import annotations

import json
import threading
import urllib.error
import urllib.request
from datetime import datetime

from PySide6.QtCore import Property, QObject, Signal, Slot

from .chat_server import (
    PROVIDERS,
    ChatServer,
    load_config,
    provider_settings,
    save_config,
)


class ChatClient(QObject):
    messagesChanged = Signal()
    statusChanged = Signal()
    busyChanged = Signal()
    configChanged = Signal()

    def __init__(self) -> None:
        super().__init__()
        self._messages: list[dict] = []
        self._status = "offline"
        self._detail = ""
        self._busy = False
        self._active = load_config().get("active", "deepseek")
        self._server = ChatServer()

    # --- proprieta' ----------------------------------------------------------
    def _get_messages(self) -> list[dict]:
        return self._messages

    messages = Property("QVariantList", _get_messages, notify=messagesChanged)

    def _get_status(self) -> str:
        return self._status

    status = Property(str, _get_status, notify=statusChanged)

    def _get_detail(self) -> str:
        return self._detail

    detail = Property(str, _get_detail, notify=statusChanged)

    def _get_busy(self) -> bool:
        return self._busy

    busy = Property(bool, _get_busy, notify=busyChanged)

    def _get_ready(self) -> bool:
        return self._status == "ready"

    ready = Property(bool, _get_ready, notify=statusChanged)

    def _get_active(self) -> str:
        return self._active

    def _set_active(self, value: str) -> None:
        if self._active == value:
            return
        self._active = value
        self.configChanged.emit()

    activeProvider = Property(str, _get_active, _set_active, notify=configChanged)

    def _get_active_label(self) -> str:
        return PROVIDERS.get(self._active, {}).get("label", self._active)

    activeLabel = Property(str, _get_active_label, notify=configChanged)

    def _get_model(self) -> str:
        return provider_settings(self._active)["model"] if self._active in PROVIDERS else ""

    model = Property(str, _get_model, notify=configChanged)

    # --- stato ---------------------------------------------------------------
    def _set_status(self, status: str, detail: str = "") -> None:
        self._status = status
        self._detail = detail
        self.statusChanged.emit()

    def _set_busy(self, value: bool) -> None:
        if self._busy == value:
            return
        self._busy = value
        self.busyChanged.emit()

    # --- configurazione ------------------------------------------------------
    @Slot(result="QVariantList")
    def providers(self) -> list[dict]:
        """Elenco dei provider con modello corrente e presenza della chiave."""
        config = load_config()
        out = []
        for key, spec in PROVIDERS.items():
            settings = provider_settings(key)
            out.append(
                {
                    "id": key,
                    "label": spec["label"],
                    "model": settings["model"],
                    "hasKey": bool(settings["api_key"]),
                    "active": key == config.get("active", "deepseek"),
                    "env": spec["env"],
                    "models": list(spec["models"]),
                }
            )
        return out

    @Slot(str, result="QVariantMap")
    def provider(self, provider_id: str) -> dict:
        """Dettaglio di un provider, senza mai restituire la chiave in chiaro."""
        if provider_id not in PROVIDERS:
            return {}
        settings = provider_settings(provider_id)
        return {
            "id": provider_id,
            "label": settings["label"],
            "model": settings["model"],
            "models": settings["models"],
            "hasKey": bool(settings["api_key"]),
            "env": settings["env"],
            "masked": ("•" * 8 + settings["api_key"][-4:]) if len(settings["api_key"]) > 4 else "",
        }

    @Slot(str, result=bool)
    def setActiveProvider(self, provider_id: str) -> bool:  # noqa: N802
        if provider_id not in PROVIDERS:
            return False
        config = load_config()
        config["active"] = provider_id
        if not save_config(config):
            return False
        self._set_active(provider_id)
        self.refreshStatus()
        return True

    @Slot(str, str, str, result=bool)
    def saveProvider(self, provider_id: str, api_key: str, model: str) -> bool:  # noqa: N802
        """Salva chiave e modello del provider e lo rende attivo."""
        if provider_id not in PROVIDERS:
            return False

        config = load_config()
        state = config["providers"].setdefault(provider_id, {"api_key": "", "model": ""})
        if api_key.strip():
            state["api_key"] = api_key.strip()
        if model.strip():
            state["model"] = model.strip()
        config["active"] = provider_id

        if not save_config(config):
            self._set_status("offline", "impossibile scrivere la configurazione")
            return False

        self._set_active(provider_id)
        self.configChanged.emit()
        self.refreshStatus()
        return True

    @Slot(str, result=bool)
    def clearProviderKey(self, provider_id: str) -> bool:  # noqa: N802
        if provider_id not in PROVIDERS:
            return False
        config = load_config()
        state = config["providers"].setdefault(provider_id, {"api_key": "", "model": ""})
        state["api_key"] = ""
        if not save_config(config):
            return False
        self.configChanged.emit()
        self.refreshStatus()
        return True

    @Slot(result="QVariantMap")
    def configuration(self) -> dict:
        settings = provider_settings(self._active)
        return {
            "active": self._active,
            "label": settings["label"],
            "model": settings["model"],
            "keyPresent": bool(settings["api_key"]),
            "env": settings["env"],
        }

    # --- ciclo di vita -------------------------------------------------------
    @Slot()
    def start(self) -> None:
        try:
            port = self._server.ensure_running()
        except OSError as error:
            self._set_status("offline", f"server locale non avviato: {error}")
            return
        self.refreshStatus()

    @Slot()
    def refreshStatus(self) -> None:  # noqa: N802
        if self._server.port == 0:
            try:
                self._server.ensure_running()
            except OSError as error:
                self._set_status("offline", f"server locale non avviato: {error}")
                return
        self._set_status("connecting", "verifica configurazione...")
        threading.Thread(target=self._check_health, daemon=True).start()

    def _check_health(self) -> None:
        try:
            with urllib.request.urlopen(
                f"http://127.0.0.1:{self._server.port}/api/health", timeout=5
            ) as response:
                data = json.loads(response.read().decode("utf-8"))
        except (urllib.error.URLError, OSError, json.JSONDecodeError) as error:
            self._safe_status("offline", f"server locale non raggiungibile: {error}")
            return
        except Exception:  # noqa: BLE001 - il thread non deve mai propagare
            return

        if data.get("ready"):
            self._safe_status(
                "ready",
                f"{data.get('label', '')} · {data.get('model', '')}",
            )
        else:
            self._safe_status(
                "unconfigured",
                str(data.get("reason") or "Chiave API non configurata."),
            )

    def _safe_status(self, status: str, detail: str = "") -> None:
        """Aggiorna lo stato anche se l'oggetto e' gia' in smontaggio."""
        try:
            self._set_status(status, detail)
        except RuntimeError:
            pass

    # --- conversazione -------------------------------------------------------
    @Slot(str)
    def send(self, text: str) -> None:
        message = text.strip()
        if not message or self._busy:
            return

        self._messages.append(
            {"role": "user", "text": message, "time": datetime.now().strftime("%H:%M")}
        )
        self.messagesChanged.emit()
        self._set_busy(True)

        if self._server.port == 0:
            try:
                self._server.ensure_running()
            except OSError as error:
                self._fail(f"server locale non avviato: {error}")
                return

        payload = [
            {"role": m["role"], "content": m["text"]}
            for m in self._messages
            if m["role"] in ("user", "assistant")
        ]
        threading.Thread(target=self._post, args=(payload,), daemon=True).start()

    def _post(self, messages: list[dict]) -> None:
        body = json.dumps({"messages": messages}).encode("utf-8")
        request = urllib.request.Request(
            f"http://127.0.0.1:{self._server.port}/api/chat",
            data=body,
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                data = json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as error:
            try:
                detail = json.loads(error.read().decode("utf-8")).get("error", "")
            except (OSError, json.JSONDecodeError):
                detail = f"HTTP {error.code}"
            self._fail(detail or f"HTTP {error.code}")
            return
        except urllib.error.URLError as error:
            self._fail(f"rete non raggiungibile: {error.reason}")
            return
        except (TimeoutError, OSError) as error:
            self._fail(f"connessione interrotta: {error}")
            return
        except json.JSONDecodeError:
            self._fail("risposta non valida dal server locale")
            return

        reply = data.get("reply", "")
        if not reply:
            self._fail("risposta vuota")
            return

        self._messages.append(
            {"role": "assistant", "text": reply, "time": datetime.now().strftime("%H:%M")}
        )
        self._set_busy(False)
        self.messagesChanged.emit()

    def _fail(self, message: str) -> None:
        self._messages.append(
            {"role": "error", "text": message, "time": datetime.now().strftime("%H:%M")}
        )
        self._set_busy(False)
        self.messagesChanged.emit()

    @Slot()
    def clear(self) -> None:
        self._messages = []
        self.messagesChanged.emit()

    @Slot()
    def stop(self) -> None:
        self._server.stop()
