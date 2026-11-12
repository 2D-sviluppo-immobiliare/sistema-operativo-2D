#!/usr/bin/env bash
#
# Prepara la partizione persistente su una chiavetta gia' scritta con 2D OS.
#
# Crea una seconda partizione con etichetta "persistence" formattata ext4.
# Il sistema la rileva automaticamente all'avvio (parametro kernel "persistence").
#
# Uso: ./scripts/setup-persistence.sh /dev/sdX [dimensione_GB]
#
set -euo pipefail

DEST="${1:-}"
SIZE_GB="${2:-8}"

if [ -z "${DEST}" ]; then
    echo "Uso: $0 /dev/sdX [dimensione_GB]" >&2
    exit 1
fi
[ -b "${DEST}" ] || { echo "Non e' un device a blocchi: ${DEST}" >&2; exit 1; }

echo "== Stato attuale =="
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MOUNTPOINTS "${DEST}"

cat <<'EOF'

Questa operazione:
  1. riduce lo spazio libero in coda alla chiavetta
  2. crea una nuova partizione con etichetta "persistence"
  3. la formatta ext4 (i dati restano su questo supporto)

Non cancella la ISO gia' scritta, ma una partizione gia' esistente
nella stessa area potrebbe essere rimossa.

EOF
read -r -p "Scrivi esattamente SI per continuare: " ans
[ "${ans}" = "SI" ] || { echo "Annullato."; exit 1; }

START_MB="$(sudo parted -s "${DEST}" unit MB print free \
            | awk '/Free Space/ {s=$1; gsub("MB","",s); last=s} END {print last+0}')"
END_MB=$(( START_MB + SIZE_GB * 1000 ))

echo "==> Creazione partizione da ${START_MB}MB a ${END_MB}MB"
sudo parted -s -a optimal "${DEST}" mkpart persistence ext4 "${START_MB}MB" "${END_MB}MB"
sudo partprobe "${DEST}" || true
sleep 2

PART="$(lsblk -ln -o NAME,TYPE "${DEST}" | awk '$2=="part"{n=$1} END{print "/dev/"n}')"
echo "==> Formattazione ${PART}"
sudo mkfs.ext4 -L persistence -F "${PART}"

TMP="$(mktemp -d)"
sudo mount "${PART}" "${TMP}"
echo "/ union" | sudo tee "${TMP}/persistence.conf" >/dev/null
sudo umount "${TMP}"
rmdir "${TMP}"

echo
echo "Persistenza pronta su ${PART} (etichetta: persistence, ${SIZE_GB} GB)."
echo "Avvia 2D OS: i dati in /home e le configurazioni resteranno salvati."
echo
echo "NOTA: questa partizione NON e' cifrata. Vedi docs/03-persistenza.md"
