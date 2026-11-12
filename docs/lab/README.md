# Laboratorio — rapporti hardware

Qui vanno i file prodotti da `2d-hwreport` sulle macchine di test.

## Convenzione di nome

```text
<macchina>-<data>.txt
```

Esempi:

```text
acer-veriton-x275-2026-11-10.txt
hp-win8-2026-11-10.txt
```

## Come raccoglierli

1. Avviare 2D OS da USB sulla macchina
2. Aprire il terminale (o l'icona **Rapporto Hardware 2D**)
3. Eseguire `2d-hwreport`
4. Copiare il file dalla home al repository

Se la macchina non ha rete, salvare il file su una seconda chiavetta.

## Perché sono importanti

Determinano le decisioni tecniche successive:

- se la GPU regge il compositing (renderer OpenGL / llvmpipe)
- se il Wi-Fi funziona e con quale firmware
- se la CPU ha accelerazione AES (velocità di LUKS)
- se esiste la virtualizzazione hardware (test in VM su quella macchina)
