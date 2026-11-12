#!/bin/sh
#
# Eseguito DENTRO il container di build (come root).
# Configura e costruisce l'immagine ISO di 2D OS.
#
set -u

VERSION="${VERSION:-0.0.0}"
SRC="/src"
WORK="/var/tmp/2dos-build"
LIVE="${WORK}/live"
DIST="${SRC}/dist"

log() { printf '\n\033[1;33m[2D-OS]\033[0m %s\n' "$*"; }

[ -d "${SRC}/live" ] || { echo "ERRORE: ${SRC}/live non trovato" >&2; exit 1; }

log "Build 2D OS ${VERSION} (Debian live-build)"

# ---------------------------------------------------------------------------
# 1. Copia pulita del progetto in un'area di lavoro locale al container.
#    Il volume /src e' montato "nodev": il chroot di debootstrap non puo'
#    viverci, perche' /dev/null e gli altri device node non sarebbero
#    apribili. Si costruisce quindi in /var/tmp e si copia fuori il risultato.
# ---------------------------------------------------------------------------
rm -rf "${WORK}"
mkdir -p "${WORK}"
cp -a "${SRC}/live" "${LIVE}"

rm -rf "${LIVE}/binary" "${LIVE}/chroot" "${LIVE}/cache" "${LIVE}/.build" "${LIVE}/.stage"
rm -f "${LIVE}"/config/binary "${LIVE}"/config/bootstrap "${LIVE}"/config/chroot \
      "${LIVE}"/config/common "${LIVE}"/config/source
rm -f "${LIVE}"/*.iso "${LIVE}"/*.log "${LIVE}"/*.contents "${LIVE}"/*.files "${LIVE}"/*.packages

cd "${LIVE}"

# ---------------------------------------------------------------------------
# 2. Branding: copia gli asset del marchio dentro gli include del filesystem
# ---------------------------------------------------------------------------
INC="${LIVE}/config/includes.chroot"

if [ -d "${SRC}/brand/wallpapers" ]; then
    log "Copia sfondi"
    mkdir -p "${INC}/usr/share/backgrounds/2d"
    cp -a "${SRC}"/brand/wallpapers/. "${INC}/usr/share/backgrounds/2d/" 2>/dev/null || true
fi

if [ -d "${SRC}/brand/plymouth" ]; then
    log "Copia tema di avvio"
    mkdir -p "${INC}/usr/share/plymouth/themes/2d"
    cp -a "${SRC}"/brand/plymouth/. "${INC}/usr/share/plymouth/themes/2d/"
fi

# --- Logo: quello ufficiale se presente, altrimenti il marchio provvisorio ---
mkdir -p "${INC}/usr/share/2d"
LOGO_PNG="${INC}/usr/share/plymouth/themes/2d/logo.png"

if [ -f "${SRC}/brand/logo/logo.png" ]; then
    log "Logo: logo.png (ufficiale)"
    cp -f "${SRC}/brand/logo/logo.png" "${LOGO_PNG}"
    cp -f "${SRC}/brand/logo/logo.png" "${INC}/usr/share/2d/logo.png"
elif [ -f "${SRC}/brand/logo/logo.svg" ]; then
    log "Logo: logo.svg (ufficiale)"
    rsvg-convert -h 220 -o "${LOGO_PNG}" "${SRC}/brand/logo/logo.svg"
    cp -f "${SRC}/brand/logo/logo.svg" "${INC}/usr/share/2d/logo.svg"
elif [ -f "${SRC}/brand/logo/2d-wordmark.svg" ]; then
    log "Logo: marchio provvisorio (manca brand/logo/logo.svg)"
    rsvg-convert -h 220 -o "${LOGO_PNG}" "${SRC}/brand/logo/2d-wordmark.svg"
    cp -f "${SRC}/brand/logo/2d-wordmark.svg" "${INC}/usr/share/2d/logo.svg"
fi

# --- Suoni ---
if [ -d "${SRC}/brand/sounds" ]; then
    log "Copia suoni di sistema"
    mkdir -p "${INC}/usr/share/sounds/2d"
    cp -a "${SRC}"/brand/sounds/*.wav "${INC}/usr/share/sounds/2d/" 2>/dev/null || true
fi

# --- Motore grafico QML (desktop proprietario) ---
if [ -d "${SRC}/graphics-engine" ]; then
    log "Copia motore grafico QML in /opt/2d-os/engine"
    mkdir -p "${INC}/opt/2d-os/engine"
    cp -a "${SRC}/graphics-engine/." "${INC}/opt/2d-os/engine/"
    chmod 0755 "${INC}/opt/2d-os/engine/2d-shell-qml"
    chmod -R a+rX "${INC}/opt/2d-os/engine"
fi

# --- Sessione grafica ---
chmod 0755 "${INC}/usr/local/bin/2d-session" 2>/dev/null || true

# Versione del sistema, leggibile da /etc/2d-os/release
mkdir -p "${INC}/etc/2d-os"
printf '%s\n' "${VERSION}" > "${INC}/etc/2d-os/release"

# ---------------------------------------------------------------------------
# 3. Eventuali pacchetti .deb forniti localmente (es. VS Code)
#    Vengono messi a disposizione dell'hook 0200 che li installa nel chroot.
# ---------------------------------------------------------------------------
mkdir -p "${INC}/opt/2d/packages"
if [ -d "${SRC}/vendor/debs" ]; then
    find "${SRC}/vendor/debs" -maxdepth 1 -name '*.deb' \
        -exec cp -av {} "${INC}/opt/2d/packages/" \; 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 4. Configurazione e build
# ---------------------------------------------------------------------------
log "lb config"
chmod +x auto/config
./auto/config || { echo "ERRORE: lb config" >&2; exit 1; }

log "lb build (puo' richiedere 10-30 minuti)"
lb build 2>&1 | tee "${LIVE}/build.log"
BUILD_RC=$?

# ---------------------------------------------------------------------------
# 5. Pubblicazione artefatti (il log serve soprattutto quando fallisce)
# ---------------------------------------------------------------------------
mkdir -p "${DIST}"
cp -f "${LIVE}/build.log" "${DIST}/build.log" 2>/dev/null || true

ISO="$(find "${LIVE}" -maxdepth 1 -name '*.hybrid.iso' -print -quit 2>/dev/null)"

if [ -z "${ISO}" ]; then
    echo "" >&2
    echo "ERRORE: nessuna ISO prodotta (exit ${BUILD_RC})." >&2
    echo "Log completo in dist/build.log" >&2
    tail -25 "${LIVE}/build.log" >&2 2>/dev/null
    chmod -R a+rwX "${DIST}" 2>/dev/null || true
    exit 1
fi

OUT="${DIST}/2d-os-${VERSION}-amd64.iso"
mv -f "${ISO}" "${OUT}"

cd "${DIST}"
sha256sum "$(basename "${OUT}")" > SHA256SUMS
chmod -R a+rwX "${DIST}"

log "Completato"
ls -lh "${OUT}"
cat SHA256SUMS
