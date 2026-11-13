#!/usr/bin/env bash
#
# Avvia l'anteprima web di 2D OS in un solo comando.
#
# Fa tutto quello che serve, in modo idempotente:
#   1. display virtuale Xvfb (se non c'e')
#   2. container con la shell QML (se non c'e')
#   3. server MJPEG sulla porta 8080 (se non c'e')
#   4. stampa gli indirizzi da aprire
#
# Uso:
#   ./scripts/demo-start.sh            porta 8080, risoluzione 1280x800
#   PORT=9000 ./scripts/demo-start.sh
#   WIDTH=1920 HEIGHT=1080 ./scripts/demo-start.sh
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-8080}"
WIDTH="${WIDTH:-1280}"
HEIGHT="${HEIGHT:-800}"
DISPLAY_NUM="${DISPLAY_NUM:-:99}"
CONTAINER="${CONTAINER:-2dos-live}"
IMAGE="${IMAGE:-2dos-live:latest}"

echo "==> 2D OS — anteprima ${WIDTH}x${HEIGHT} su porta ${PORT}"

# --- 1. immagine demo -------------------------------------------------------
if ! docker image inspect "${IMAGE}" >/dev/null 2>&1; then
    echo "==> Costruisco l'immagine ${IMAGE}"
    docker build -f "${ROOT}/build/Dockerfile.live" -t "${IMAGE}" "${ROOT}/build"
fi

# --- 2. display virtuale ----------------------------------------------------
if ! pgrep -f "Xvfb ${DISPLAY_NUM}" >/dev/null 2>&1; then
    echo "==> Avvio Xvfb ${DISPLAY_NUM} (${WIDTH}x${HEIGHT})"
    Xvfb "${DISPLAY_NUM}" -screen 0 "${WIDTH}x${HEIGHT}x24" >/dev/null 2>&1 &
    sleep 2
else
    echo "==> Xvfb ${DISPLAY_NUM} gia' attivo"
fi

# --- 3. container con la shell ---------------------------------------------
if ! docker ps --format '{{.Names}}' | grep -qx "${CONTAINER}"; then
    echo "==> Avvio il container ${CONTAINER}"
    docker rm -f "${CONTAINER}" >/dev/null 2>&1 || true
    docker run -d --name "${CONTAINER}" \
        -v /tmp/.X11-unix:/tmp/.X11-unix \
        -e DISPLAY="${DISPLAY_NUM}" \
        -e QT_QPA_PLATFORM=xcb \
        -e QML_XHR_ALLOW_FILE_READ=1 \
        -v "${ROOT}/graphics-engine:/app:ro" \
        "${IMAGE}" >/dev/null
    echo "==> Attendo l'avvio della shell"
    sleep 12
else
    echo "==> Container ${CONTAINER} gia' attivo"
fi

# --- 4. server di anteprima -------------------------------------------------
if pgrep -f "demo-web.py ${PORT}" >/dev/null 2>&1; then
    echo "==> Server di anteprima gia' attivo sulla porta ${PORT}"
else
    pkill -f "demo-web.py ${PORT}" >/dev/null 2>&1 || true
    echo "==> Avvio il server di anteprima"
    DISPLAY="${DISPLAY_NUM}" DEMO_WIDTH="${WIDTH}" DEMO_HEIGHT="${HEIGHT}" \
        nohup /usr/bin/python3 "${ROOT}/scripts/demo-web.py" "${PORT}" \
        > /tmp/2d-demo-web.log 2>&1 &
    sleep 3
fi

# --- 5. verifica ------------------------------------------------------------
if timeout 5 curl -sf -o /dev/null "http://127.0.0.1:${PORT}/"; then
    echo "==> Server OK"
else
    echo "ERRORE: il server non risponde. Log in /tmp/2d-demo-web.log" >&2
    tail -5 /tmp/2d-demo-web.log >&2 || true
    exit 1
fi

# --- 6. inoltro della porta in Codespaces (best effort) ---------------------
# Dopo un riavvio del codespace il tunnel impiega qualche secondo a
# registrare la porta: si ritenta invece di arrendersi al primo 404.
if [ -n "${CODESPACE_NAME:-}" ]; then
    published=""
    attempt=0
    while [ "${attempt}" -lt 8 ]; do
        attempt=$((attempt + 1))
        if gh codespace ports visibility "${PORT}:public" -c "${CODESPACE_NAME}" >/dev/null 2>&1; then
            published="si"
            break
        fi
        sleep 3
    done

    if [ -n "${published}" ]; then
        echo "==> Porta ${PORT} pubblica sul tunnel Codespaces"
    else
        echo "==> Porta ${PORT} non ancora registrata dal tunnel."
        echo "    In VS Code: pannello PORTS -> Forward a Port -> ${PORT} -> Public"
    fi
fi

echo
echo "Apri uno di questi indirizzi:"
echo "  locale      http://localhost:${PORT}/"
if [ -n "${CODESPACE_NAME:-}" ] && [ -n "${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN:-}" ]; then
    echo "  codespaces  https://${CODESPACE_NAME}-${PORT}.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}/"
fi
