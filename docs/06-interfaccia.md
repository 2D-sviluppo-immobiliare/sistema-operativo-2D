# 06 — Interfaccia adattiva

## Il principio

2D OS deve girare **su qualsiasi PC**, dal Pentium del 2009 a una workstation.
Non esiste un'unica interfaccia che vada bene su entrambi: esiste un'interfaccia
che **cambia da sola** in base all'hardware.

## I due profili

| | **2D CLASSIC** | **2D IMMERSIVE** |
|---|---|---|
| Destinatari | GPU integrata datata, ≤ 4 GB RAM | GPU con accelerazione reale |
| Compositore | nessuno (xfwm4 senza compositing) | `picom` (GLX, ombre, dissolvenze, zoom) |
| Dock | nessuna | `plank` con zoom e ingresso animato |
| HUD hardware | nessuno | `conky` con CPU/RAM/SWAP/GPU/rete |
| Ombre / angoli | disattivati | attivi (raggio 8 px) |
| Costo RAM | ~0 MB aggiuntivi | ~80-120 MB |

## Rilevamento automatico

`2d-mode auto` (eseguito all'avvio della sessione) legge:

1. il **renderer OpenGL** (`glxinfo`): se contiene `llvmpipe`, `softpipe` o `swrast`,
   la GPU non accelera → **classic**;
2. la **RAM totale**: sotto ~3,5 GB → **classic**.

Il profilo viene applicato e il motivo viene scritto nel log della sessione.

```bash
2d-mode status      # cosa ha rilevato e cosa sta usando
2d-mode classic     # forzatura manuale
2d-mode immersive   # forzatura manuale
2d-mode reset       # torna al rilevamento automatico
```

La scelta manuale viene salvata in `~/.config/2d/system.conf` (`mode=`).

## Componenti

### Avvio (Plymouth)

- Sfondo blu notte con gradiente.
- Logo ufficiale 2D (o marchio provvisorio) centrato.
- Anello oro come alone pulsante.
- Barra di avanzamento a 24 punti che segue il **progresso reale** del boot.

Tutto in Lua, senza dipendenze da font: se un asset manca, l'avvio non si blocca.

### Dock (Plank)

- Posizione basso, centrata, zoom al 140%, nascondimento automatico intelligente (modo 2).
- Icone con animazione di ingresso gestita da Plank stesso.
- Launcher predefiniti: Chromium, Thunar, Terminale, Rapporto Hardware.

Per cambiarli: `~/.config/plank/dock1/launchers/*.dockitem`.

### HUD (Conky)

Pannello sobrio in alto a destra con ora, CPU, RAM, swap (zram), disco, GPU, rete.
Il valore GPU viene da `2d-gpu`, che gestisce NVIDIA, AMD, Intel e — sui PC datati —
mostra il nome del driver invece di una percentuale inventata.

Configurazione: `~/.config/conky/2d-hud.conf`.

### Compositore (picom)

Ombre leggere, dissolvenze brevi (≈300 ms), angoli arrotondati e animazione di
apertura/chiusura delle finestre. Se la versione di `picom` non supporta le
animazioni, `2d-mode` riparte con una configurazione minima: **il sistema non si rompe**.

Configurazione: `~/.config/picom/2d.conf`.

### Suono di avvio

`2d-boot.wav` (accordo elettronico breve, generato da `brand/generate-sounds.py`).
Viene riprodotto all'ingresso nella sessione, dopo che il server audio è pronto.

Disattivabile:

```bash
sed -i 's/^boot_sound=.*/boot_sound=0/' ~/.config/2d/system.conf
```

## Limite dichiarato sulle animazioni

La sequenza "icone che entrano dai lati e si dispongono" del concept video
**non è replicabile** con il desktop di XFCE (`xfdesktop` disegna le icone come
superficie statica, senza API di animazione).

Per questo è stata scritta **2D Shell** (`/usr/lib/2d-os/shell/2d-shell`), un
desktop layer proprietario che sostituisce `xfdesktop` nel profilo *immersive* e
implementa proprio quell'animazione. Vedi [07-shell.md](07-shell.md).

Resta fuori: un window manager proprietario e gli effetti 3D. Su GMA X4500 il
profilo attivo sarà comunque *classic*, con `xfdesktop` e nessuna animazione.
