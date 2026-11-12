#!/usr/bin/python3
"""
Anteprima web di 2D Shell.

Serve una pagina HTML con lo streaming del display virtuale in MJPEG
(HTTP puro, nessun WebSocket) e inoltra i click sulla shell tramite xdotool.

Serve solo per la dimostrazione: non fa parte del sistema operativo.

Uso:
    DISPLAY=:99 ./scripts/demo-web.py [porta]
"""

from __future__ import annotations

import os
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import gi

gi.require_version("Gdk", "3.0")
from gi.repository import Gdk

DISPLAY = os.environ.get("DISPLAY", ":99")
WIDTH = int(os.environ.get("DEMO_WIDTH", "1366"))
HEIGHT = int(os.environ.get("DEMO_HEIGHT", "768"))
FPS = 6
BOUNDARY = "2dframeboundary"

_frame: bytes | None = None
_lock = threading.Lock()


def capture_loop() -> None:
    global _frame
    root = Gdk.get_default_root_window()
    while True:
        started = time.monotonic()
        try:
            pixbuf = Gdk.pixbuf_get_from_window(root, 0, 0, WIDTH, HEIGHT)
            if pixbuf is not None:
                ok, buffer = pixbuf.save_to_bufferv("jpeg", ["quality"], ["50"])
                if ok:
                    with _lock:
                        _frame = bytes(buffer)
        except Exception as exc:  # lo streaming non deve mai interrompersi
            print(f"capture: {exc}", file=sys.stderr)
        elapsed = time.monotonic() - started
        time.sleep(max(0.0, (1.0 / FPS) - elapsed))


PAGE = """<!doctype html>
<html lang="it">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>2D OS - 2D Shell</title>
<style>
  :root { --gold:#e6c478; --navy:#0b1a2b; }
  * { box-sizing: border-box; }
  html, body { height:100%; margin:0; background:#050a11; color:#c8d6e2;
               font-family: "DejaVu Sans", system-ui, sans-serif; }
  header { display:flex; align-items:center; gap:14px; padding:12px 18px;
           border-bottom:1px solid rgba(230,196,120,.18); }
  header .brand { color:var(--gold); font-weight:700; letter-spacing:.28em; }
  header .sub { font-size:12px; opacity:.6; letter-spacing:.12em; }
  header .spacer { flex:1; }
  header .pill { font-size:11px; padding:4px 10px; border-radius:999px;
                 border:1px solid rgba(230,196,120,.35); color:var(--gold); }
  main { position:relative; padding:14px; display:flex; justify-content:center;
         align-items:center; height:calc(100vh - 110px); }
  .frame { position:relative; max-width:100%; max-height:100%;
           border-radius:10px; overflow:hidden;
           border:1px solid rgba(230,196,120,.22);
           box-shadow:0 18px 60px rgba(0,0,0,.65); }
  .frame img { display:block; max-width:100%; max-height:calc(100vh - 140px);
               width:auto; height:auto; cursor:default; }
  footer { padding:10px 18px 18px; font-size:12px; opacity:.55; line-height:1.7; }
  kbd { border:1px solid #3a4b5e; border-bottom-width:2px; border-radius:4px;
        padding:1px 6px; font-size:11px; color:#dbe6ef; }
</style>
</head>
<body>
<header>
  <span class="brand">2D&nbsp;OS</span>
  <span class="sub">2D SHELL · ANTEPRIMA</span>
  <span class="spacer"></span>
  <span class="pill" id="status">connessione…</span>
</header>
<main>
  <div class="frame">
    <img id="screen" src="/stream" alt="2D OS"
         onload="document.getElementById('status').textContent='live'">
  </div>
</main>
<footer>
  Doppio clic su un'icona per aprire l'applicazione · tasto destro sul desktop per il menu ·
  lo schermo è __W__×__H__.
</footer>
<script>
const img = document.getElementById('screen');
async function send(ev, dbl) {
  const r = img.getBoundingClientRect();
  const x = Math.round((ev.clientX - r.left) * __W__ / r.width);
  const y = Math.round((ev.clientY - r.top) * __H__ / r.height);
  await fetch(`/click?x=${x}&y=${y}&dbl=${dbl?1:0}`).catch(()=>{});
}
img.addEventListener('click', ev => send(ev, false));
img.addEventListener('dblclick', ev => { ev.preventDefault(); send(ev, true); });
img.addEventListener('contextmenu', ev => {
  ev.preventDefault();
  const r = img.getBoundingClientRect();
  const x = Math.round((ev.clientX - r.left) * __W__ / r.width);
  const y = Math.round((ev.clientY - r.top) * __H__ / r.height);
  fetch(`/click?x=${x}&y=${y}&button=3`).catch(()=>{});
});
</script>
</body>
</html>
"""


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, fmt, *args):  # log compatto
        print("%s %s" % (self.address_string(), fmt % args), file=sys.stderr)

    def do_GET(self):
        parsed = urlparse(self.path)

        if parsed.path in ("/", "/index.html"):
            body = PAGE.replace("__W__", str(WIDTH)).replace("__H__", str(HEIGHT)).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if parsed.path == "/click":
            query = parse_qs(parsed.query)
            x = query.get("x", ["0"])[0]
            y = query.get("y", ["0"])[0]
            button = query.get("button", ["1"])[0]
            dbl = query.get("dbl", ["0"])[0] == "1"
            env = dict(os.environ, DISPLAY=DISPLAY)
            try:
                subprocess.run(["xdotool", "mousemove", x, y], env=env,
                               timeout=3, check=False)
                if dbl:
                    subprocess.run(["xdotool", "click", "--repeat", "2",
                                    "--delay", "70", button], env=env,
                                   timeout=3, check=False)
                else:
                    subprocess.run(["xdotool", "click", button], env=env,
                                   timeout=3, check=False)
            except Exception as exc:
                print(f"click: {exc}", file=sys.stderr)
            self.send_response(204)
            self.end_headers()
            return

        if parsed.path == "/stream":
            self.send_response(200)
            self.send_header("Content-Type",
                             f"multipart/x-mixed-replace; boundary={BOUNDARY}")
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            try:
                while True:
                    with _lock:
                        data = _frame
                    if data:
                        self.wfile.write(f"--{BOUNDARY}\r\n".encode())
                        self.wfile.write(b"Content-Type: image/jpeg\r\n")
                        self.wfile.write(f"Content-Length: {len(data)}\r\n\r\n".encode())
                        self.wfile.write(data)
                        self.wfile.write(b"\r\n")
                    time.sleep(1.0 / FPS)
            except (BrokenPipeError, ConnectionResetError):
                return
            return

        self.send_response(404)
        self.end_headers()


def main() -> int:
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8080

    thread = threading.Thread(target=capture_loop, daemon=True)
    thread.start()
    # attende il primo fotogramma
    for _ in range(50):
        if _frame is not None:
            break
        time.sleep(0.1)

    server = ThreadingHTTPServer(("0.0.0.0", port), Handler)
    print(f"2D Shell - anteprima su http://0.0.0.0:{port}/")
    sys.stdout.flush()
    server.serve_forever()
    return 0


if __name__ == "__main__":
    sys.exit(main())
