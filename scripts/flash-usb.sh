#!/usr/bin/env bash
#
# Scrive la ISO di 2D OS su una chiavetta USB.
#
# ATTENZIONE: il dispositivo indicato viene COMPLETAMENTE CANCELLATO.
#
# Uso: ./scripts/flash-usb.sh dist/2d-os-0.1.0-amd64.iso /dev/sdX
#
set -euo pipefail

ISO="${1:-}"
DEST="${2:-}"

if [ -z "${ISO}" ] || [ -z "${DEST}" ]; then
    echo "Uso: $0 <file.iso> <dispositivo>   es. $0 dist/2d-os-0.1.0-amd64.iso /dev/sdb" >&2
    exit 1
fi

[ -f "${ISO}" ] || { echo "ISO non trovata: ${ISO}" >&2; exit 1; }
[ -b "${DEST}" ] || { echo "Non e' un device a blocchi: ${DEST}" >&2; exit 1; }

# Sicurezza: mai scrivere sul disco di sistema
ROOT_SRC="$(findmnt -n -o SOURCE / | sed 's/[0-9]*$//')"
ROOT_DISK="$(lsblk -no pkname "${ROOT_SRC}" | head -1)"
if [ -n "${ROOT_DISK}" ] && [ "/dev/${ROOT_DISK}" = "${DEST}" ]; then
    echo "RIFIUTATO: ${DEST} contiene il sistema in esecuzione." >&2
    exit 1
fi

echo "== Dispositivo selezionato =="
lsblk -o NAME,SIZE,TYPE,TRAN,MODEL,MOUNTPOINTS "${DEST}"
echo
echo "Verra' CANCELLATO ogni dato su ${DEST}."
read -r -p "Scrivi esattamente SI per continuare: " ans
[ "${ans}" = "SI" ] || { echo "Annullato."; exit 1; }

# Smonta eventuali partizioni montate
for part in $(lsblk -lno NAME "${DEST}" | tail -n +2); do
    sudo umount "/dev/${part}" 2>/dev/null || true
done

echo "==> Scrittura in corso"
sudo dd if="${ISO}" of="${DEST}" bs=4M status=progress oflag=sync conv=fsync
sudo sync

echo "==> Verifica integrita'"
ISO_SHA="$(sha256sum "${ISO}" | awk '{print $1}')"
DEV_SHA="$(sudo dd if="${DEST}" bs=4M count=$(( $(stat -c%s "${ISO}") / 4194304 + 1 )) status=none | head -c "$(stat -c%s "${ISO}")" | sha256sum | awk '{print $1}')"
if [ "${ISO_SHA}" = "${DEV_SHA}" ]; then
    echo "OK: copia verificata (${ISO_SHA})"
else
    echo "ATTENZIONE: la verifica non corrisponde. Riscrivere la chiavetta." >&2
    exit 1
fi

echo "Fatto. Inserisci la chiavetta nel PC e avvia dal menu di boot (F12/F11/ESC)."
