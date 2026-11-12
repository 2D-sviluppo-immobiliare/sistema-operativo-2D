#!/usr/bin/env bash
#
# Verifica il contenuto della ISO senza avviarla.
#
# Controlla che i file critici di 2D OS siano davvero dentro l'immagine:
# tema di avvio (anche nell'initramfs), script 2D, configurazioni, bootloader.
#
# Uso: ./scripts/inspect-iso.sh dist/2d-os-0.1.0-amd64.iso
#
set -euo pipefail

ISO="${1:-}"
[ -f "${ISO}" ] || { echo "ISO non trovata: ${ISO}" >&2; exit 1; }
ISO_ABS="$(cd "$(dirname "${ISO}")" && pwd)/$(basename "${ISO}")"

docker run --rm -v "${ISO_ABS}:/iso.iso:ro" debian:trixie bash -c '
set -u
export DEBIAN_FRONTEND=noninteractive
apt-get -qq update >/dev/null 2>&1
apt-get -qq install -y xorriso squashfs-tools cpio gzip xz-utils zstd file initramfs-tools-core >/dev/null 2>&1

WORK=$(mktemp -d)
cd "$WORK"
FAIL=0

check() { # nome, condizione
    if eval "$2"; then printf "  \033[32mOK\033[0m   %s\n" "$1"
    else printf "  \033[31mFAIL\033[0m %s\n" "$1"; FAIL=$((FAIL+1)); fi
}

echo "== Struttura della ISO =="
xorriso -osirrox on -indev /iso.iso -extract /live/filesystem.squashfs "$WORK/fs.squashfs" >/dev/null 2>&1
xorriso -osirrox on -indev /iso.iso -extract /live/vmlinuz "$WORK/vmlinuz" >/dev/null 2>&1
xorriso -osirrox on -indev /iso.iso -extract /live/initrd.img "$WORK/initrd.img" >/dev/null 2>&1
xorriso -indev /iso.iso -find / -maxdepth 1 2>/dev/null | sed -n "s/^.*-find \(.*\)$/\1/p" | head -20

check "filesystem.squashfs presente"        "[ -s $WORK/fs.squashfs ]"
check "kernel presente"                     "[ -s $WORK/vmlinuz ]"
check "initramfs presente"                  "[ -s $WORK/initrd.img ]"

echo
echo "== Contenuto del sistema =="
unsquashfs -l "$WORK/fs.squashfs" > "$WORK/list.txt" 2>/dev/null

check "tema Plymouth 2d"                    "grep -q "usr/share/plymouth/themes/2d/2d.plymouth" $WORK/list.txt"
check "script del tema"                     "grep -q "usr/share/plymouth/themes/2d/2d.script" $WORK/list.txt"
check "config Plymouth (Theme=2d)"          "grep -q "etc/plymouth/plymouthd.conf" $WORK/list.txt"
check "zram configurato"                    "grep -q "etc/default/zramswap" $WORK/list.txt"
check "2d-hwreport"                         "grep -q "usr/local/bin/2d-hwreport" $WORK/list.txt"
check "2d-info"                             "grep -q "usr/local/bin/2d-info" $WORK/list.txt"
check "2d-branding"                         "grep -q "usr/local/bin/2d-branding" $WORK/list.txt"
check "icona rapporto hardware"             "grep -q "etc/skel/Desktop/2D-Rapporto-Hardware.desktop" $WORK/list.txt"
check "autologin lightdm"                   "grep -q "etc/lightdm/lightdm.conf.d/50-2d-autologin.conf" $WORK/list.txt"
check "versione /etc/2d-os/release"         "grep -q "etc/2d-os/release" $WORK/list.txt"
check "sessione XFCE (xfce4-session)"       "grep -q "usr/bin/xfce4-session" $WORK/list.txt"
check "lightdm"                             "grep -q "usr/sbin/lightdm" $WORK/list.txt"
check "chromium"                            "grep -q "usr/bin/chromium" $WORK/list.txt"
check "git"                                 "grep -q "usr/bin/git" $WORK/list.txt"
check "python3"                             "grep -q "usr/bin/python3" $WORK/list.txt"
check "SSH server"                          "grep -q "usr/sbin/sshd" $WORK/list.txt"
check "sfondo 2D"                           "grep -q "usr/share/backgrounds/2d/2d-wallpaper.svg" $WORK/list.txt"

echo
echo "== Interfaccia adattiva =="
check "2d-mode"                             "grep -q "usr/local/bin/2d-mode" $WORK/list.txt"
check "2d-gpu"                              "grep -q "usr/local/bin/2d-gpu" $WORK/list.txt"
check "2d-bootsound"                        "grep -q "usr/local/bin/2d-bootsound" $WORK/list.txt"
check "dock: plank"                         "grep -q "usr/bin/plank" $WORK/list.txt"
check "compositore: picom"                  "grep -q "usr/bin/picom" $WORK/list.txt"
check "HUD: conky"                          "grep -q "usr/bin/conky" $WORK/list.txt"
check "config HUD (skel)"                   "grep -q "etc/skel/.config/conky/2d-hud.conf" $WORK/list.txt"
check "config picom (skel)"                 "grep -q "etc/skel/.config/picom/2d.conf" $WORK/list.txt"
check "dock plank (skel)"                   "grep -q "etc/skel/.config/plank/dock1/settings" $WORK/list.txt"
check "autostart adattamento"               "grep -q "etc/xdg/autostart/2d-mode.desktop" $WORK/list.txt"
check "logo di avvio (PNG)"                 "grep -q "usr/share/plymouth/themes/2d/logo.png" $WORK/list.txt"
check "suono di avvio"                      "grep -q "usr/share/sounds/2d/2d-boot.wav" $WORK/list.txt"
check "2D Shell (desktop proprietario)"     "grep -q "usr/lib/2d-os/shell/2d-shell" $WORK/list.txt"
check "config 2D Shell"                     "grep -q "etc/2d/shell.conf" $WORK/list.txt"
check "PyGObject (GTK3)"                    "grep -q "usr/lib/python3/dist-packages/gi/__init__.py" $WORK/list.txt"
check "driver video per tutti i PC"         "grep -q "usr/lib/xorg/modules/drivers/modesetting_drv.so" $WORK/list.txt"

echo
echo "== Tema di avvio dentro l initramfs =="
# lsinitramfs legge anche gli initramfs con piu' archivi concatenati
# (microcode + sistema); cpio si fermerebbe al primo.
lsinitramfs "$WORK/initrd.img" > "$WORK/initrd-list.txt" 2>/dev/null || true
check "tema 2d nell initramfs"              "grep -q "themes/2d" $WORK/initrd-list.txt"
check "plymouth nell initramfs"             "grep -q "plymouth" $WORK/initrd-list.txt"
check "logo nell initramfs"                 "grep -q "themes/2d/logo.png" $WORK/initrd-list.txt"

echo
echo "== Bootloader =="
xorriso -indev /iso.iso -ls /boot/grub 2>/dev/null | grep -q cfg && echo "  OK   GRUB (UEFI)" || { echo "  FAIL GRUB"; FAIL=$((FAIL+1)); }
xorriso -indev /iso.iso -ls /isolinux 2>/dev/null | grep -q cfg && echo "  OK   syslinux (BIOS)" || { echo "  FAIL syslinux"; FAIL=$((FAIL+1)); }

echo
if [ "$FAIL" -eq 0 ]; then
    echo "RISULTATO: tutti i controlli superati."
else
    echo "RISULTATO: $FAIL controlli falliti."
fi
exit "$FAIL"
'
