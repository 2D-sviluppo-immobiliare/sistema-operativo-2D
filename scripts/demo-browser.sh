#!/bin/bash
#
# Demo locale di 2D Shell: display virtuale + streaming noVNC nel browser.
# Non fa parte del sistema operativo: serve solo per la presentazione.
#
set -u

ROOT="/workspaces/sistema-operativo-2D"
SHELL_BIN="${ROOT}/live/config/includes.chroot/usr/lib/2d-os/shell/2d-shell"
WALL="${ROOT}/brand/wallpapers/2d-wallpaper.svg"
DEMO_HOME="/tmp/t2d/home"
DEMO_DATA="/tmp/t2d"

export DISPLAY=:99

cleanup() {
    pkill -f "Xvfb :99" 2>/dev/null
    pkill -x x11vnc 2>/dev/null
    pkill -f "websockify" 2>/dev/null
    pkill -f "${SHELL_BIN}" 2>/dev/null
    sleep 0.5
    rm -f /tmp/.X99-lock
}

cleanup

echo "==> Display virtuale"
Xvfb :99 -screen 0 1366x768x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
sleep 1.5

echo "==> 2D Shell"
HOME="${DEMO_HOME}" \
XDG_DATA_DIRS="${DEMO_DATA}:/usr/share" \
TWO_D_WALLPAPER="${WALL}" \
/usr/bin/python3 "${SHELL_BIN}" >/tmp/shell-demo.log 2>&1 &
sleep 1.5

echo "==> Server VNC"
x11vnc -display :99 -nopw -listen localhost -forever -shared -rfbport 5900 -quiet \
    >/tmp/x11vnc.log 2>&1 &
sleep 0.5

echo "==> noVNC sul browser (porta 6080)"
websockify --web=/usr/share/novnc 6080 localhost:5900 >/tmp/websockify.log 2>&1 &
sleep 1

echo "READY http://localhost:6080/vnc.html?autoconnect=true&resize=scale&reconnect=true&show_dot=true"

# Resta in vita finche' la shell gira
while pgrep -f "${SHELL_BIN}" >/dev/null 2>&1; do
    sleep 5
done
echo "shell terminata"
