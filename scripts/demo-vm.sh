#!/bin/bash
#
# 2D OS in una macchina virtuale, visibile nel browser.
#
# Catena:  ISO -> QEMU (KVM) -> server VNC integrato -> vncviewer sul display
#          virtuale :99 -> streaming MJPEG (scripts/demo-web.py) -> browser
#
# Uso: ./scripts/demo-vm.sh [file.iso] [porta_web]
#
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO="${1:-${ROOT}/dist/2d-os-0.1.0-amd64.iso}"
PORT="${2:-8080}"
SCREEN_W="${SCREEN_W:-1024}"
SCREEN_H="${SCREEN_H:-768}"
VNC_PORT=5901
export DISPLAY=:99

log() { printf '\n\033[1;33m[2D-VM]\033[0m %s\n' "$*"; }

[ -f "${ISO}" ] || { echo "ISO non trovata: ${ISO}" >&2; exit 1; }

cleanup() {
    pkill -f "vncviewer 127.0.0.1:${VNC_PORT}" 2>/dev/null
    pkill -f "qemu-system-x86_64" 2>/dev/null
    pkill -f "demo-web.py" 2>/dev/null
    pkill -f "Xvfb :99" 2>/dev/null
    sleep 1
    rm -f /tmp/.X99-lock
}

cleanup

log "Display virtuale ${SCREEN_W}x${SCREEN_H}"
Xvfb :99 -screen 0 "${SCREEN_W}x${SCREEN_H}x24" -nolisten tcp >/tmp/xvfb.log 2>&1 &
sleep 1.5

log "Avvio della VM (KVM) con ${ISO##*/}"
qemu-system-x86_64 \
    -name "2D OS" \
    -enable-kvm -cpu host -smp 2 -m 2048 \
    -cdrom "${ISO}" -boot d \
    -vga std \
    -display none \
    -vnc "127.0.0.1:1" \
    -device qemu-xhci -device usb-tablet \
    -netdev user,id=net0 -device e1000,netdev=net0 \
    >/tmp/qemu.log 2>&1 &

for _ in $(seq 1 30); do
    (ss -lnt 2>/dev/null | grep -q ":${VNC_PORT}") && break
    sleep 1
done

if ! ss -lnt 2>/dev/null | grep -q ":${VNC_PORT}"; then
    echo "ERRORE: QEMU non ha aperto la porta VNC. Log: /tmp/qemu.log" >&2
    tail -20 /tmp/qemu.log >&2
    exit 1
fi

log "Visualizzatore VNC sul display virtuale"
nohup vncviewer -Shared -geometry "${SCREEN_W}x${SCREEN_H}+0+0" \
    "127.0.0.1:${VNC_PORT}" >/tmp/vncviewer.log 2>&1 &
sleep 3

log "Anteprima web sulla porta ${PORT}"
DEMO_WIDTH="${SCREEN_W}" DEMO_HEIGHT="${SCREEN_H}" \
    nohup /usr/bin/python3 "${ROOT}/scripts/demo-web.py" "${PORT}" \
    >/tmp/demo-web.log 2>&1 &
sleep 2

echo
log "Pronto. URL locale: http://localhost:${PORT}/"
echo "Per fermare tutto: pkill -f demo-vm.sh; pkill -f qemu-system-x86_64; pkill -f vncviewer; pkill -f demo-web.py; pkill -f 'Xvfb :99'"
