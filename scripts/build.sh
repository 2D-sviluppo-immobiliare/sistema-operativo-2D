#!/usr/bin/env bash
#
# Costruisce l'immagine ISO di 2D OS in un container Docker riproducibile.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(tr -d '[:space:]' < "${ROOT}/VERSION")"
IMAGE="2dos-builder:latest"

NAME="2dos-build-$$"
MIN_FREE_GB="${MIN_FREE_GB:-14}"

if ! docker info >/dev/null 2>&1; then
    echo "ERRORE: il demone Docker non e' raggiungibile." >&2
    exit 1
fi

# --- Spazio libero: una build incompleta lascia ~7 GB appesi in Docker -----
FREE_GB="$(df -BG --output=avail "${ROOT}" | tail -1 | tr -dc '0-9')"
if [ "${FREE_GB}" -lt "${MIN_FREE_GB}" ]; then
    cat >&2 <<EOF
ERRORE: spazio insufficiente.

  Liberi    : ${FREE_GB} GB
  Richiesti : ${MIN_FREE_GB} GB

Pulizia consigliata:
  docker rm -f \$(docker ps -aq --filter ancestor=${IMAGE})   # container orfani
  docker builder prune -f                                     # cache di build
  rm -f ${ROOT}/dist/*.iso                                    # ISO vecchie
EOF
    exit 1
fi

# --- Container di build rimasti appesi da esecuzioni interrotte ------------
ORPHANS="$(docker ps -aq --filter "ancestor=${IMAGE}" 2>/dev/null || true)"
if [ -n "${ORPHANS}" ]; then
    echo "==> Rimuovo container di build rimasti appesi"
    # shellcheck disable=SC2086
    docker rm -f ${ORPHANS} >/dev/null 2>&1 || true
fi

cleanup() { docker rm -f "${NAME}" >/dev/null 2>&1 || true; }
trap cleanup EXIT INT TERM

echo "==> Build ambiente ($(basename "${IMAGE}"))"
docker build -f "${ROOT}/build/Dockerfile" -t "${IMAGE}" "${ROOT}/build"

mkdir -p "${ROOT}/dist"

echo "==> Build ISO 2D OS ${VERSION} (spazio libero: ${FREE_GB} GB)"
# Nota: /src e' montato dal workspace. La build avviene su un filesystem
# interno al container perche' il volume condiviso e' "nodev" e i device
# node del chroot non sarebbero utilizzabili.
docker run --rm --name "${NAME}" --privileged \
    -v "${ROOT}:/src" \
    -e "VERSION=${VERSION}" \
    "${IMAGE}" \
    /bin/sh /src/build/container-entrypoint.sh

echo
echo "==> ISO pronta in dist/"
ls -lh "${ROOT}/dist/"*.iso
