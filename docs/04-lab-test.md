# 04 — Piano di test sul laboratorio

## Preparazione

1. Costruire la ISO: `make build`
2. Scrivere la chiavetta: `make flash DEST=/dev/sdX`
3. Sul PC di test, entrare nel menu di avvio: **F12**, **F11** o **ESC** a seconda del BIOS
4. Scegliere la voce USB

> Il disco interno non viene toccato. Windows resta al suo posto.

## Scheda di test

Compilare una scheda per ogni macchina e conservarla in `docs/lab/`.

### Identificazione

| Campo | Valore |
|---|---|
| Macchina | |
| Data | |
| Modello | |
| CPU | |
| RAM | |
| Scheda video | |
| Versione BIOS | |
| Firmware | BIOS legacy / UEFI |
| Supporto | marca e modello della USB |

### Esito dei test

| # | Test | Esito | Note |
|---|---|:---:|---|
| 1 | Compare il menu di avvio GRUB | ☐ | |
| 2 | Il tema di avvio 2D compare | ☐ | |
| 3 | Si arriva al desktop XFCE | ☐ | |
| 4 | Risoluzione video corretta | ☐ | |
| 5 | Tastiera italiana funzionante | ☐ | |
| 6 | Mouse / touchpad | ☐ | |
| 7 | Rete Ethernet | ☐ | |
| 8 | Wi-Fi | ☐ | |
| 9 | Audio | ☐ | |
| 10 | Porte USB (tastiera, mouse, penna) | ☐ | |
| 11 | Sospensione / spegnimento | ☐ | |
| 12 | Riavvio | ☐ | |
| 13 | Persistenza (file salvato dopo riavvio) | ☐ | |
| 14 | Il disco interno non è stato modificato | ☐ | |
| 15 | Tempo di avvio misurato | ☐ | |

### Raccolta dati (obbligatoria)

Dopo l'avvio, aprire il terminale:

```bash
2d-hwreport
```

Oppure doppio clic su **Rapporto Hardware 2D** sul desktop.

Il file prodotto (`~/2d-hwreport-<host>-<data>.txt`) va copiato nel repository in
`docs/lab/`. Contiene tutto ciò che serve per decidere il livello di supporto:
CPU e flag, RAM, driver in uso, renderer OpenGL, velocità USB, rete.

## Test in macchina virtuale (prima dell'hardware)

```bash
make vm                     # BIOS legacy
./scripts/test-vm.sh dist/2d-os-0.1.0-amd64.iso --uefi   # UEFI
```

Serve a intercettare gli errori banali (ISO corrotta, bootloader, tema) senza
sprecare cicli sulla macchina fisica.

## Criteri di accettazione v0.1

| Criterio | Soglia |
|---|---|
| Avvio al desktop sull'Acer | ≤ 180 s |
| Avvio al desktop su macchina moderna | ≤ 60 s |
| Disco interno intatto | obbligatorio |
| Nessun errore bloccante in `journalctl -p err -b` | obbligatorio |
| Persistenza verificata | obbligatorio |

## Problemi attesi

| Macchina | Problema probabile | Azione |
|---|---|---|
| Acer GMA X4500 | Compositing non accelerato, animazioni a scatti | Ridurre gli effetti, usare XFCE senza compositore |
| Acer (2009) | Nessun avvio UEFI | Avviare in BIOS legacy |
| HP Windows 8 | Secure Boot attivo | Disattivarlo nel firmware |
| Entrambe | Wi-Fi Broadcom vecchio | Verificare `dmesg \| grep -i firmware` |
| Entrambe | Avvio lento da USB 2.0 | Atteso: ~25 MB/s di lettura |
