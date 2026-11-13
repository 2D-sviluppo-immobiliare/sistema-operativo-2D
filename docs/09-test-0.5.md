# 09 — Rapporto di test 2D OS 0.5.0

Data: 2026-11-13
Ambiente: container Debian trixie, Xvfb, Openbox 3.6.1, Qt 6.8 / PySide6, xdotool

Tutti i test sono stati eseguiti realmente con `xdotool` su display virtuale e
verificati con screenshot e con l'ispezione dei processi nel container.

## Window manager interno (`AppWindow.qml`)

| Test | Procedura | Esito |
|---|---|---|
| Spostamento | trascinamento della barra del titolo da (300,148) a (660,260) | ✅ la finestra segue il puntatore, limitata ai bordi schermo |
| Ridimensionamento lato | trascinamento del bordo inferiore (900,668) → (900,750) | ✅ altezza aggiornata, contenuto riadattato |
| Ridimensionamento angolo | trascinamento dell'angolo (1008,626) → (900,560) | ✅ larghezza e altezza aggiornate |
| Massimizzazione | pulsante ▢ | ✅ occupa l'area sotto la barra superiore, angoli squadrati |
| Ripristino geometria | pulsante ❐ | ✅ ritorno esatto a posizione e dimensioni precedenti |
| Minimizzazione | pulsante − | ✅ la finestra scompare dal desktop |
| Ripristino dalla dock | clic sull'icona della dock | ✅ la finestra torna visibile e in primo piano |
| Chiusura | pulsante ✕ | ✅ |
| Primo piano | clic sulla barra del titolo o sul contenuto | ✅ ordine `desktop.stack` aggiornato |
| Alt+Tab | due finestre aperte, `xdotool key alt+Tab` | ✅ la finestra precedente passa davanti |
| Più finestre | Documenti + Chat2D + Terminale insieme | ✅ convivenza corretta, ognuna indipendente |

## Applicazioni

| Applicazione | Test | Esito |
|---|---|---|
| Documenti | navigazione, creazione cartella, rinomina, copia, spostamento, ricerca, selezione multipla | ✅ |
| Documenti | scrittura fuori dalla home | ✅ bloccata (sola lettura, pulsanti disattivati) |
| Cestino | spostamento nel cestino | ✅ `~/.local/share/Trash/files` + `.trashinfo` conformi XDG |
| Cestino | ripristino nella posizione originale | ✅ file tornato in `/root/nota.md`, cestino vuoto |
| Cestino | eliminazione definitiva e svuotamento | ✅ con conferma modale |
| Chrome | binario assente | ✅ finestra con istruzioni di installazione, nessun mockup |
| Chrome | binario presente (stub) | ✅ avviato via `QProcess` con l'URL |
| VS Code | binario presente (stub) | ✅ avviato con il percorso progetto (`/app`) |
| VS Code | binario assente | ✅ istruzioni di installazione |
| Terminale | avvio con Openbox attivo | ✅ barra del titolo e pulsanti nativi |
| Terminale | chiusura dalla dock | ✅ processo terminato |
| Calcolatrice | tastiera fisica `7 + 5 =` | ✅ risultato 12 |
| Chat2D | provider multipli, chiave assente | ✅ banner di configurazione |
| Chat2D | chiave non valida | ✅ errore HTTP del provider mostrato in chat |

## Convivenza con Openbox (TASK 2)

| Verifica | Esito |
|---|---|
| Shell QML a schermo intero con Openbox attivo | ✅ i click arrivano alla shell |
| Finestre QML interne (Documenti, Chat2D…) | ✅ gestite da `AppWindow`, nessuna decorazione esterna |
| Applicazioni X11 esterne (xterm) | ✅ gestite da Openbox con barra del titolo vera |
| Dock e launcher con finestre esterne aperte | ✅ restano cliccabili |
| Tema Openbox | ✅ `openbox-2d.themerc` con palette del marchio |
| Margini Openbox | ✅ le finestre esterne non coprono barra, launcher e dock |

La distinzione richiesta è rispettata: **le finestre interne non vengono mai
simulate dentro `AppWindow`**, e le applicazioni esterne non vengono mai
reimplementate in QML.

## Risoluzioni

| Risoluzione | Esito | Note |
|---|---|---|
| 1280×800 | ✅ | `uiScale` = 1.00 |
| 1366×768 | ✅ | `uiScale` = 1.00, dock e launcher proporzionati |
| 1920×1080 | ✅ | `uiScale` = 1.35, elementi ingranditi senza sovrapposizioni |

## Qualità e sicurezza (TASK 4)

| Verifica | Esito |
|---|---|
| Permessi dei file | ✅ operazioni riservate a home utente e volumi rimovibili |
| Controllo dei percorsi | ✅ `resolve()` + verifica della radice prima di ogni scrittura |
| Operazioni distruttive con conferma | ✅ ogni cestinamento, eliminazione e svuotamento passa da `Dialog2D` |
| Errori dei processi esterni | ✅ `waitForStarted` con log su `stderr` |
| Pulizia processi alla chiusura | ✅ `aboutToQuit` + `SIGTERM`: log `[2D] arresto: Terminale` |
| Protezione credenziali | ✅ chiave API mai nel codice; solo variabile d'ambiente o file `0600` |
| Comandi privilegiati | ✅ nessun `sudo` né comando di sistema invocato dalla shell |
| Servizi remoti | ✅ il server Chat2D ascolta solo su `127.0.0.1` |

## Pulizia alla chiusura — dettaglio

Verifica eseguita con `docker stop` (SIGTERM) mentre un `xterm` era aperto:

```text
[2D] chiusura sessione: arresto dei processi figli
[2D] arresto: Terminale
```

Senza il gestore di `SIGTERM` il ciclo degli eventi Qt non si chiudeva e i
processi figli restavano vivi: difetto trovato durante il test e corretto.

## Problemi residui

| Problema | Stato | Note |
|---|---|---|
| Ridimensionamento delle finestre esterne | non applicabile | lo fa Openbox, non la shell |
| Multi-monitor | aperto | la shell usa solo il monitor primario |
| Riordino delle finestre con la tastiera | aperto | Alt+Tab scorre l'elenco interno, non esiste ancora un selettore visivo |
| Firmware Wi-Fi su hardware molto recente | parziale | il pacchetto `firmware-iwlwifi` copre la maggior parte delle schede Intel; alcune Realtek recenti richiedono firmware non in Debian |
| Persistenza cifrata | assente | prevista per la fase sicurezza |

## Nota su "BYOK / utility models"

L'avviso *"set up BYOK utility models"* **non proviene da 2D OS**: nel progetto
non esiste alcuna occorrenza di `BYOK` né di *utility model*. È un messaggio
dell'editor (VS Code / estensione Copilot) relativo alla configurazione del
provider del modello, e non ha relazione con Chat2D.

Chat2D usa un proprio file di configurazione (`~/.config/2d-os/chat2d.json`) e
legge la chiave dalla variabile d'ambiente o da `~/.config/2d-os/deepseek.key`.
