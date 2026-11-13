# 10 — Rete privata con Tailscale

## Perché

Per provare 2D OS sul PC reale (l'Acer) serve poterci entrare mentre gira: leggere
i log, verificare che la shell parta, controllare la rete, senza dover stare
davanti allo schermo con una tastiera.

Tailscale crea una rete privata fra i dispositivi dell'utente. Una volta che
l'Acer è nella rete, dal Codespace si può fare:

```bash
ssh 2dos@<ip-tailscale-dell-acer>
```

## Come è integrato

### Nell'immagine live

Il pacchetto Tailscale **è presente** nell'ISO ma **non è attivo all'avvio**.

| Scelta | Motivo |
|---|---|
| Nessun avvio automatico | collegarsi a una rete privata è una decisione dell'utente |
| Nessuna chiave nell'immagine | un segreto scritto su una chiavetta USB è un segreto perso |
| Attivazione con un comando | `sudo 2d-tailscale on` stampa il link di autenticazione |

Il repository ufficiale Tailscale viene usato solo durante la build e poi
rimosso: l'immagine finale non ha sorgenti di terze parti configurate.

### Nel Codespace

Installato dal repository ufficiale Ubuntu (chiave GPG verificata), con demone
avviato a mano perché il container non usa systemd.

## Comandi

Sul sistema live:

```bash
sudo 2d-tailscale on        # avvia e mostra il link di autenticazione
sudo 2d-tailscale status    # stato e indirizzi della macchina
sudo 2d-tailscale ssh on    # abilita l'accesso SSH via Tailscale
sudo 2d-tailscale off       # esce dalla rete
```

Il primo `on` stampa un indirizzo del tipo
`https://login.tailscale.com/a/xxxxxxxx`. Va aperto nel browser una sola volta:
dopo l'autenticazione la macchina resta associata al nodo.

## Flusso di prova sull'Acer

1. Scrivere la ISO su chiavetta (`./scripts/flash-usb.sh`).
2. Avviare l'Acer dalla chiavetta.
3. Collegare la rete (ethernet o Wi-Fi dal tray).
4. Aprire un terminale e lanciare `sudo 2d-tailscale on`.
5. Aprire il link, autenticare.
6. Dal Codespace: `tailscale status` per vedere il nodo, poi `ssh 2dos@<ip>`.

Da quel momento si può ispezionare la macchina reale mentre la shell gira:

```bash
journalctl -u 2d-session -f        # log della sessione grafica
cat /var/log/2d-os/session.log     # log del motore QML
2d-hwreport                        # scheda hardware rilevata
2d-mode status                     # profilo classic/immersive
```

## Sicurezza

| Aspetto | Stato |
|---|---|
| Chiave di autenticazione nel repository | ❌ mai |
| Chiave dentro l'immagine ISO | ❌ mai |
| Avvio automatico della VPN | ❌ disattivato |
| Accesso SSH di sistema | solo utente `live`, root vietato |
| Accesso SSH via Tailscale | opzionale, `2d-tailscale ssh on` |
| Ascolto del server Chat2D | solo `127.0.0.1` |

L'accesso SSH di Tailscale è disattivato per impostazione predefinita: va
abilitato esplicitamente, e riguarda solo la rete privata dell'utente.
