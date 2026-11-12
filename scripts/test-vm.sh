#!/usr/bin/env bash
#
# Avvia la ISO di 2D OS in QEMU per un test rapido prima dell'hardware reale.
#
# Uso: ./scripts/test-vm.sh dist/2d-os-0.1.0-amd64.iso [--uefi]
#
set -euo pipefail

ISO="${1:-}"
MODE="${2:-}"

[ -f "${ISO}" ] || { echo "ISO non trovata: ${ISO}" >&2; exit 1; }

if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
    cat >&2 <<'EOF'
qemu-system-x86_64 non e' installato. Opzioni:

  sudo apt-get install -y qemu-system-x86 ovmf

oppure, senza installare nulla, tramite Docker:

  docker run --rm -it --privileged \
      -v "$PWD:/iso" -v /dev/kvm:/dev/kvm \
      qemux/qemu-docker
EOF
    exit 1
fi

ARGS=(
    -m 2048
    -smp 2
    -cdrom "${ISO}"
    -boot d
    -vga std
    -net nic -net user
    -usb
)

if [ -e /dev/kvm ]; then
    ARGS+=(-enable-kvm -cpu host)
else
    echo "KVM non disponibile: la macchina virtuale sara' lenta." >&2
fi

if [ "${MODE}" = "--uefi" ]; then
    OVMF="/usr/share/OVMF/OVMF_CODE.fd"
    [ -f "${OVMF}" ] || { echo "OVMF non trovato: sudo apt-get install ovmf" >&2; exit 1; }
    cp "${OVMF}" /tmp/2d-os-ovmf.fd
    ARGS+=(-drive "if=pflash,format=raw,file=/tmp/2d-os-ovmf.fd")
fi

echo "==> Avvio QEMU (chiudi la finestra per terminare)"
qemu-system-x86_64 "${ARGS[@]}"
