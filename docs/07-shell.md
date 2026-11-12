# 07 — 2D Shell (desktop proprietario)

## Cos'è

La shell 2D è il livello desktop di 2D OS: disegna **tutto** quello che si vede
dopo l'accensione, dalla sequenza di avvio alla dock, dal launcher laterale alle
finestre delle applicazioni.

È scritta in **QML su Qt 6** con un launcher Python (PySide6). Nessuna
dipendenza da XFCE, da un window manager esterno o da temi GTK.

## Struttura

```text
graphics-engine/
├── 2d-shell-qml                 launcher Python: launcher + systemInfo
├── assets/
│   ├── logo-mark.png            marchio con canale alpha
│   ├── logo.png                 logo originale (fallback)
│   └── wallpaper-villa.jpg      sfondo del desktop
└── qml/
    ├── Main.qml                 finestra principale (boot → desktop)
    ├── BootExperience.qml       sequenza di avvio
    ├── Desktop.qml              composizione e gestione finestre
    └── components/
        ├── CityBackdrop.qml     sfondo: fotografia + fallback procedurale
        ├── LogoBadge.qml        marchio in alto a destra, con alone
        ├── TopBar.qml           barra superiore
        ├── Launcher.qml         colonna applicazioni a sinistra
        ├── Dock.qml             dock inferiore
        ├── SystemTray.qml       wi-fi, audio, data e ora
        ├── HardwarePanel.qml    CPU / RAM / DISCO a indicatori circolari
        ├── AppWindow.qml        cornice, titolo, chiusura, spostamento, ridimensionamento
        ├── FileManager.qml      gestore file (Documenti)
        ├── TrashBin.qml         cestino freedesktop
        ├── Chat2D.qml           assistente multi-provider
        ├── MissingApp.qml       avviso e istruzioni per app non installate
        ├── Dialog2D.qml         dialogo modale (conferme e input)
        ├── FileIcon.qml         icona per tipologia di file
        ├── Calculator.qml       calcolatrice nativa
        ├── Notes.qml            blocco note
        ├── PlaceholderContent.qml
        ├── RadialGlow.qml       alone radiale morbido
        └── Theme.qml            palette e misure (singleton)
```

## Gestione delle finestre

`AppWindow.qml` implementa un window manager minimo, interamente in QML:

| Funzione | Come |
|---|---|
| Spostamento | trascinamento dalla barra del titolo, limitato ai bordi dello schermo |
| Ridimensionamento | 8 maniglie: quattro lati e quattro angoli, con il cursore corretto |
| Massimizzazione | pulsante ▢ oppure doppio clic sul titolo; la geometria precedente viene memorizzata e ripristinata |
| Chiusura | pulsante ✕ |
| Primo piano | un clic in qualunque punto della finestra la porta in cima |

L'ordine di sovrapposizione è un elenco (`desktop.stack`): l'ultima voce è la
finestra in primo piano. Le `z` restano sotto 42, cioè **sotto la barra, il
launcher, la dock e il tray**, che sono la struttura del sistema e devono restare
sempre raggiungibili. Logo e pannello hardware stanno invece a `z: 6`: sono
decorazioni del desktop e una finestra deve poterli coprire.

Le dimensioni minime sono 300×200 px. La massimizzazione occupa l'area sotto la
barra superiore (44 px), come il "ridimensiona" di un sistema desktop.

## Applicazioni reali

| Voce | Implementazione |
|---|---|
| Documenti | `backend/files.py` + `FileManager.qml`: navigazione, ricerca, creazione, rinomina, copia, spostamento, cestinamento, selezione multipla, percorsi digitabili, dispositivi rimovibili |
| Cestino | `backend/trash.py` + `TrashBin.qml`: specifica freedesktop, ripristino nella posizione originale, eliminazione definitiva, svuotamento |
| Chat2D | `backend/chat*.py` + `Chat2D.qml`: server locale che fa da proxy verso DeepSeek, OpenAI, Anthropic e Google |
| Chrome / VS Code | applicazioni esterne vere, avviate da `backend/apps.py`; se il binario manca la shell mostra come installarlo |
| Calcolatrice / Note | native QML |
| Terminale | `xterm` esterno, avviato a destra del launcher |

### Limiti di sicurezza delle operazioni sui file

`backend/files.py` consente scrittura, rinomina e cancellazione **solo** dentro la
home dell'utente e dentro i volumi rimovibili montati. Fuori da quelle radici il
file manager resta navigabile ma in sola lettura, e i pulsanti distruttivi sono
disattivati. Ogni operazione distruttiva passa da un `Dialog2D` di conferma.

### Configurazione di Chat2D

La chiave API non è mai nel codice. Il server locale la cerca, nell'ordine:

1. nella variabile d'ambiente indicata da `api_key_env` (default `DEEPSEEK_API_KEY`);
2. nel file indicato da `api_key_file` (default `~/.config/2d-os/deepseek.key`).

Il file `~/.config/2d-os/chat2d.json` permette di cambiare provider, modello,
endpoint e porta:

```json
{
  "provider": "deepseek",
  "base_url": "https://api.deepseek.com",
  "model": "deepseek-chat",
  "api_key_env": "DEEPSEEK_API_KEY",
  "api_key_file": "~/.config/2d-os/deepseek.key",
  "port": 8765
}
```

Il server ascolta solo su `127.0.0.1`.

## Perché non c'è un window manager

## Lo sfondo

`assets/wallpaper-villa.jpg` (1920×1080) è lo sfondo ufficiale, caricato con
`PreserveAspectCrop` e ridimensionato a runtime. Il componente registra lo stato
di caricamento:

```text
qml: [2D WALLPAPER] 2        file:///app/assets/wallpaper-villa.jpg   (Loading)
qml: [2D WALLPAPER] 1 READY  file:///app/assets/wallpaper-villa.jpg
```

Sotto la fotografia resta un **paesaggio procedurale** (cielo, stelle, skyline,
riflessi) che viene scoperto solo se l'immagine non si carica: il desktop non
può mai restare nero.

Sopra la fotografia si applicano due velature: una vignettatura verticale e un
velo sul bordo sinistro, necessari perché il launcher resti leggibile anche sulle
zone chiare della villa.

## Perché non c'è un window manager

Il desktop 2D disegna da sé cornici, barre del titolo e pulsanti di chiusura
(`AppWindow.qml`). Questo elimina due problemi storici:

1. **I click arrivano sempre**: con un WM esterno la cornice si sovrappone al
   client e intercetta gli eventi destinati alla shell.
2. **Ogni finestra si chiude**: il pulsante ✕ è un elemento QML, non dipende dal
   fatto che l'applicazione esterna onori il protocollo ICCCM.

Il prezzo è che le applicazioni esterne non hanno decorazioni. Per questo le
applicazioni principali sono native:

| Applicazione | Dove | Chiudibile |
|---|---|---|
| Calcolatrice | `Calculator.qml` | ✅ pulsante ✕ |
| Blocco note | `Notes.qml` | ✅ pulsante ✕ |
| Chrome, VS Code, Documenti, Chat2D | `PlaceholderContent.qml` | ✅ pulsante ✕ |
| Cestino | pannello nativo | ✅ pulsante ✕ |
| Terminale | `xterm` (processo esterno) | ⚠️ solo dalla dock (secondo clic) |

## Sequenza di avvio

`BootExperience.qml` riproduce la composizione di riferimento
(`docs/demo/riferimento-boot.jpg`):

| Fase | Tempo | Cosa succede |
|---|---|---|
| Risveglio | 0–1400 ms | si accende il fondo, compaiono le stelle, entra `PORTABLE INTELLIGENCE SYSTEM` |
| Composizione | 1400–2400 ms | le tre orbite (due ciano, una oro) entrano e si assestano |
| Identità | 2400–3300 ms | il marchio entra con alone, scala 0.92 → 1.0 |
| Caricamento | 3300–6100 ms | pulsazione del marchio, barra di avanzamento al 100% |
| Transizione | 6100–7000 ms | dissolvenza incrociata verso il desktop |
| Desktop | da 7000 ms | ingresso di launcher, dock, logo, tray e pannello |

Tutte le animazioni sono **finite**: a boot concluso non resta nessun timer
attivo e la CPU scende a zero.

## Ingresso del desktop

Alla fine del boot `Desktop.revealed` passa a `true` e parte una coreografia
unica:

- il **launcher** entra da sinistra, voce per voce, con 70 ms di sfasamento;
- la **dock** sale dal bordo inferiore;
- il **logo** compare in dissolvenza con una leggera scala;
- il **pannello hardware** e il **system tray** si accendono in dissolvenza.

## Adattamento alla risoluzione

Le misure della cornice sono pensate per 800 px di altezza. Oltre quella soglia
`Desktop.uiScale` cresce fino a 1,55 e gli elementi vengono scalati attorno al
proprio punto di ancoraggio, così restano proporzionati su 1080p:

| Risoluzione | `uiScale` |
|---|---|
| 1280×800 | 1,00 |
| 1366×768 | 1,00 |
| 1920×1080 | 1,35 |

Verificato con screenshot reali in `docs/demo/`:
`desktop-2d.png` (1280×800), `desktop-2d-1366.png`, `desktop-2d-1920.png`.

## Telemetria

`systemInfo.stats()` (Python) legge `/proc/stat`, `/proc/meminfo` e `statvfs("/")`
e restituisce `{cpu, ram, disk}` come frazioni 0–1. La shell interroga il metodo
ogni 1,5 s; il primo campionamento della CPU non ha un riferimento precedente e
restituisce zero, così il pannello non mostra mai un 100% fasullo all'avvio.

## Componenti interattivi

| Elemento | Azione |
|---|---|
| Voce del launcher | apre / chiude la finestra corrispondente |
| Icona della dock | apre / chiude la finestra corrispondente |
| Terminale (launcher o dock) | avvia `xterm`; un secondo clic lo termina |
| ✕ nella barra del titolo | chiude la finestra |
| Barra del titolo trascinata | sposta la finestra |
| Wi-fi nel tray | apre il pannello di stato della rete |
| Audio nel tray | apre il pannello del volume |
| Calcolatrice | tastiera fisica attiva (cifre, operatori, Invio, Esc) |

## Il marchio trasparente

`logo-mark.png` si ottiene dal PNG brandizzato con:

```bash
python3 scripts/make-transparent-logo.py \
    graphics-engine/assets/logo.png \
    graphics-engine/assets/logo-mark.png
```

Lo script stima il gradiente di fondo pixel per pixel e ne ricava il canale
alpha: serve perché il logo fornito ha uno sfondo pieno e non può essere
sovrapposto a una fotografia. Se il file manca, logo e boot ricadono
automaticamente su `logo.png`.

Lo sfondo JPEG si rigenera invece con:

```bash
python3 scripts/prepare-wallpaper.py \
    docs/demo/riferimento-sfondo.png \
    graphics-engine/assets/wallpaper-villa.jpg
```

## Comandi utili

```bash
# desktop diretto, senza sequenza di avvio
python3 graphics-engine/2d-shell-qml

# sequenza di avvio completa
python3 graphics-engine/2d-shell-qml --boot

# schermo intero, senza decorazioni (usato dalla sessione reale)
python3 graphics-engine/2d-shell-qml --boot --fullscreen
```

Nell'immagine live la sessione è avviata da `/usr/local/bin/2d-session`, che
sceglie il motore QML e ricade sulla shell GTK storica se i moduli Qt non sono
presenti.

## Prestazioni misurate

| Voce | Valore |
|---|---|
| CPU del processo in idle | 0,0 % (nessuna animazione attiva) |
| RAM del processo | ~270–315 MB |
| Avvio del motore su Xvfb | ~2–4 s fino al primo fotogramma |
| Disegno dello sfondo | una sola passata, poi cache |

## Shell GTK storica

`/usr/lib/2d-os/shell/2d-shell` (GTK3/Cairo) resta nell'immagine come rete di
sicurezza. Disegna solo icone e sfondo, senza dock né finestre, ed è usata
unicamente se il motore QML non è disponibile.

## Limiti noti

| Limite | Nota |
|---|---|
| Minimizzare | non implementato: le finestre si chiudono o si massimizzano |
| Multi-monitor | solo monitor primario |
| Terminale | finestra esterna `xterm`: si sposta e si chiude solo dalla dock |
| Impilamento | ordine gestito, ma senza raggruppamento per applicazione |
