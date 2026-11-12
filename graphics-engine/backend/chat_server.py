"""
Server locale di Chat2D con supporto multi-provider.

La shell non parla mai direttamente con un provider: chiama questo server su
127.0.0.1, ed e' il server l'unico punto che conosce le chiavi API.

Provider supportati, tutti con lo stesso contratto interno:

* **OpenAI** e **DeepSeek**  → API compatibile OpenAI ``/chat/completions``
* **Anthropic**              → ``/v1/messages`` con header ``x-api-key``
* **Google Gemini**          → ``/v1beta/models/<model>:generateContent``

Le chiavi non stanno mai nel codice: l'utente le inserisce dall'interfaccia e
finiscono in ``~/.config/2d-os/chat2d.json`` con permessi 0600, oppure arrivano
da una variabile d'ambiente.
"""

from __future__ import annotations

import json
import os
import threading
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

DEFAULT_PORT = 8765
DEFAULT_TIMEOUT = 90

SYSTEM_PROMPT = (
    "Sei l'assistente di 2D OS, il sistema operativo di 2D Sviluppo Immobiliare. "
    "Rispondi in italiano, in modo conciso e concreto."
)

# Ogni provider dichiara come si parla con lui e quali modelli proporre.
PROVIDERS: dict[str, dict] = {
    "deepseek": {
        "label": "DeepSeek",
        "kind": "openai",
        "base_url": "https://api.deepseek.com",
        "model": "deepseek-chat",
        "env": "DEEPSEEK_API_KEY",
        "models": ["deepseek-chat", "deepseek-reasoner"],
    },
    "openai": {
        "label": "OpenAI (GPT)",
        "kind": "openai",
        "base_url": "https://api.openai.com/v1",
        "model": "gpt-4o-mini",
        "env": "OPENAI_API_KEY",
        "models": ["gpt-4o-mini", "gpt-4o", "gpt-4.1-mini"],
    },
    "anthropic": {
        "label": "Anthropic (Claude)",
        "kind": "anthropic",
        "base_url": "https://api.anthropic.com",
        "model": "claude-3-5-haiku-latest",
        "env": "ANTHROPIC_API_KEY",
        "models": ["claude-3-5-haiku-latest", "claude-3-5-sonnet-latest"],
    },
    "google": {
        "label": "Google (Gemini)",
        "kind": "google",
        "base_url": "https://generativelanguage.googleapis.com",
        "model": "gemini-2.0-flash",
        "env": "GEMINI_API_KEY",
        "models": ["gemini-2.0-flash", "gemini-1.5-flash", "gemini-1.5-pro"],
    },
}


# ---------------------------------------------------------------------------
# Configurazione
# ---------------------------------------------------------------------------
def config_directory() -> Path:
    base = os.environ.get("XDG_CONFIG_HOME")
    return (Path(base) if base else Path.home() / ".config") / "2d-os"


def config_path() -> Path:
    return config_directory() / "chat2d.json"


def _default_provider_state() -> dict:
    return {"api_key": "", "model": ""}


def load_config() -> dict:
    """Configurazione normalizzata: ``active`` + stato di ogni provider."""
    config = {
        "active": "deepseek",
        "providers": {key: _default_provider_state() for key in PROVIDERS},
        "port": DEFAULT_PORT,
        "timeout": DEFAULT_TIMEOUT,
    }

    path = config_path()
    if not path.is_file():
        return config

    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return config

    if not isinstance(data, dict):
        return config

    if isinstance(data.get("port"), int):
        config["port"] = data["port"]
    if isinstance(data.get("timeout"), int):
        config["timeout"] = data["timeout"]

    # formato nuovo
    providers = data.get("providers")
    if isinstance(providers, dict):
        for key, state in providers.items():
            if key in config["providers"] and isinstance(state, dict):
                config["providers"][key].update(
                    {
                        "api_key": str(state.get("api_key") or ""),
                        "model": str(state.get("model") or ""),
                    }
                )
        if data.get("active") in PROVIDERS:
            config["active"] = str(data["active"])

    # compatibilita' con il formato a singolo provider
    elif data.get("api_key") or data.get("model") or data.get("base_url"):
        legacy = config["providers"]["deepseek"]
        legacy["api_key"] = str(data.get("api_key") or "")
        legacy["model"] = str(data.get("model") or "")

    return config


def save_config(config: dict) -> bool:
    """Scrive la configurazione con permessi riservati all'utente."""
    directory = config_directory()
    try:
        directory.mkdir(parents=True, exist_ok=True)
        path = config_path()
        path.write_text(json.dumps(config, indent=2), encoding="utf-8")
        os.chmod(path, 0o600)
    except OSError:
        return False
    return True


def provider_settings(provider_id: str) -> dict:
    """Impostazioni effettive di un provider (config + default + ambiente)."""
    spec = PROVIDERS[provider_id]
    state = load_config()["providers"].get(provider_id, {})

    key = state.get("api_key", "").strip()
    if not key:
        key = os.environ.get(spec["env"], "").strip()

    model = state.get("model", "").strip() or spec["model"]
    return {
        "id": provider_id,
        "label": spec["label"],
        "kind": spec["kind"],
        "base_url": spec["base_url"],
        "model": model,
        "models": list(spec["models"]),
        "api_key": key,
        "env": spec["env"],
    }


# ---------------------------------------------------------------------------
# Adattatori per i tre dialetti di API
# ---------------------------------------------------------------------------
def _post_json(url: str, body: dict, headers: dict, timeout: int) -> dict:
    payload = json.dumps(body).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/json", **headers},
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as error:
        detail = ""
        try:
            raw = error.read().decode("utf-8", "replace")
            parsed = json.loads(raw)
            detail = (
                parsed.get("error", {}).get("message")
                if isinstance(parsed.get("error"), dict)
                else str(parsed.get("error") or raw[:200])
            )
        except (OSError, json.JSONDecodeError, AttributeError):
            detail = f"HTTP {error.code}"
        raise RuntimeError(f"{detail or 'errore HTTP'} (codice {error.code})") from error
    except urllib.error.URLError as error:
        raise RuntimeError(f"rete non raggiungibile: {error.reason}") from error
    except (TimeoutError, OSError) as error:
        raise RuntimeError(f"connessione interrotta: {error}") from error
    except json.JSONDecodeError as error:
        raise RuntimeError("risposta del provider non valida") from error


def _call_openai(settings: dict, messages: list[dict], timeout: int) -> str:
    url = settings["base_url"].rstrip("/") + "/chat/completions"
    body = {
        "model": settings["model"],
        "messages": [{"role": "system", "content": SYSTEM_PROMPT}] + messages,
        "temperature": 0.6,
        "stream": False,
    }
    data = _post_json(url, body, {"Authorization": f"Bearer {settings['api_key']}"}, timeout)
    try:
        return str(data["choices"][0]["message"]["content"])
    except (KeyError, IndexError, TypeError) as error:
        raise RuntimeError("risposta senza contenuto") from error


def _call_anthropic(settings: dict, messages: list[dict], timeout: int) -> str:
    url = settings["base_url"].rstrip("/") + "/v1/messages"
    body = {
        "model": settings["model"],
        "max_tokens": 2048,
        "system": SYSTEM_PROMPT,
        "messages": messages,
    }
    headers = {
        "x-api-key": settings["api_key"],
        "anthropic-version": "2023-06-01",
    }
    data = _post_json(url, body, headers, timeout)
    try:
        parts = data["content"]
        return "".join(part.get("text", "") for part in parts if isinstance(part, dict))
    except (KeyError, TypeError) as error:
        raise RuntimeError("risposta senza contenuto") from error


def _call_google(settings: dict, messages: list[dict], timeout: int) -> str:
    url = (
        f"{settings['base_url'].rstrip('/')}/v1beta/models/"
        f"{settings['model']}:generateContent?key={settings['api_key']}"
    )
    contents = [
        {
            "role": "model" if message["role"] == "assistant" else "user",
            "parts": [{"text": message["content"]}],
        }
        for message in messages
    ]
    body = {
        "contents": contents,
        "systemInstruction": {"parts": [{"text": SYSTEM_PROMPT}]},
        "generationConfig": {"temperature": 0.6},
    }
    data = _post_json(url, body, {}, timeout)
    try:
        candidates = data["candidates"]
        parts = candidates[0]["content"]["parts"]
        return "".join(part.get("text", "") for part in parts if isinstance(part, dict))
    except (KeyError, IndexError, TypeError) as error:
        raise RuntimeError("risposta senza contenuto") from error


CALLERS = {
    "openai": _call_openai,
    "anthropic": _call_anthropic,
    "google": _call_google,
}


def ask(provider_id: str, messages: list[dict]) -> str:
    """Invia la conversazione al provider attivo e restituisce il testo."""
    settings = provider_settings(provider_id)
    if not settings["api_key"]:
        raise RuntimeError(
            f"Chiave API mancante per {settings['label']}. "
            f"Inseriscila nelle impostazioni di Chat2D oppure imposta {settings['env']}."
        )

    config = load_config()
    timeout = int(config.get("timeout", DEFAULT_TIMEOUT))
    caller = CALLERS[settings["kind"]]
    return caller(settings, messages[-20:], timeout)


# ---------------------------------------------------------------------------
# HTTP
# ---------------------------------------------------------------------------
class _Handler(BaseHTTPRequestHandler):
    server_version = "2DChat/2.0"

    def log_message(self, fmt: str, *args) -> None:  # noqa: A003
        return

    def _json(self, status: int, payload: dict) -> None:
        body = json.dumps(payload).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:  # noqa: N802
        if self.path.startswith("/api/health"):
            config = load_config()
            active = config.get("active", "deepseek")
            settings = provider_settings(active)
            self._json(
                200,
                {
                    "ready": bool(settings["api_key"]),
                    "active": active,
                    "label": settings["label"],
                    "model": settings["model"],
                    "reason": "" if settings["api_key"] else
                              f"Chiave API mancante per {settings['label']}.",
                    "providers": [
                        {
                            "id": key,
                            "label": spec["label"],
                            "model": provider_settings(key)["model"],
                            "hasKey": bool(provider_settings(key)["api_key"]),
                            "models": list(spec["models"]),
                        }
                        for key, spec in PROVIDERS.items()
                    ],
                },
            )
            return
        self._json(404, {"error": "endpoint sconosciuto"})

    def do_POST(self) -> None:  # noqa: N802
        if not self.path.startswith("/api/chat"):
            self._json(404, {"error": "endpoint sconosciuto"})
            return

        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length) or b"{}")
        except (ValueError, json.JSONDecodeError):
            self._json(400, {"error": "richiesta non valida"})
            return

        messages = payload.get("messages") or []
        if not isinstance(messages, list) or not messages:
            self._json(400, {"error": "nessun messaggio"})
            return

        active = load_config().get("active", "deepseek")
        try:
            reply = ask(active, messages)
        except RuntimeError as error:
            self._json(502, {"error": str(error)})
            return
        except Exception as error:  # noqa: BLE001 - il server non deve mai cadere
            self._json(500, {"error": f"errore interno: {error}"})
            return

        self._json(200, {"reply": reply})


class ChatServer:
    """Server HTTP locale, avviabile e arrestabile a richiesta."""

    def __init__(self) -> None:
        self._thread: threading.Thread | None = None
        self._server: ThreadingHTTPServer | None = None
        self._port = 0

    @property
    def port(self) -> int:
        return self._port

    def ensure_running(self) -> int:
        if self._server is not None:
            return self._port

        config = load_config()
        port = int(config.get("port", DEFAULT_PORT))

        try:
            server = ThreadingHTTPServer(("127.0.0.1", port), _Handler)
        except OSError:
            server = ThreadingHTTPServer(("127.0.0.1", 0), _Handler)

        server.daemon_threads = True
        self._server = server
        self._port = server.server_address[1]

        self._thread = threading.Thread(target=server.serve_forever, daemon=True)
        self._thread.start()
        return self._port

    def stop(self) -> None:
        if self._server is not None:
            self._server.shutdown()
            self._server.server_close()
            self._server = None
            self._thread = None
