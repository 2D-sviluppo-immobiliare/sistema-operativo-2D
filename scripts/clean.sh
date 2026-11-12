#!/usr/bin/env bash
#
# Rimuove tutti gli artefatti di build (chroot, binary, ISO, log).
# Le personalizzazioni in live/config non vengono toccate.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

sudo rm -rf \
    "${ROOT}/live/binary" \
    "${ROOT}/live/chroot" \
    "${ROOT}/live/cache" \
    "${ROOT}/live/.build" \
    "${ROOT}/live/.stage" \
    "${ROOT}/dist"

sudo rm -f \
    "${ROOT}/live/config/binary" \
    "${ROOT}/live/config/bootstrap" \
    "${ROOT}/live/config/chroot" \
    "${ROOT}/live/config/common" \
    "${ROOT}/live/config/source"

# Container di build rimasti appesi (una build interrotta ne lascia ~7 GB)
ORPHANS="$(docker ps -aq --filter "ancestor=2dos-builder:latest" 2>/dev/null || true)"
if [ -n "${ORPHANS}" ]; then
    # shellcheck disable=SC2086
    docker rm -f ${ORPHANS} >/dev/null 2>&1 || true
    echo "Container di build orfani rimossi."
fi

if [ "${PRUNE_DOCKER:-0}" = "1" ]; then
    docker builder prune -f >/dev/null 2>&1 || true
    echo "Cache di build Docker ripulita."
fi

echo "Artefatti rimossi."
