# 03 — Persistenza

## Come funziona

Il filesystem del sistema è `squashfs`, in sola lettura. Le modifiche non possono
finire lì: serve un secondo livello scrivibile.

2D OS usa la persistenza standard di Debian Live:

```text
USB
├── partizione 1  ISO 9660  (sistema, sola lettura)
└── partizione 2  ext4, etichetta "persistence"
    ├── persistence.conf
    └── upper/            ← qui finiscono le modifiche
```

`persistence.conf` contiene:

```text
/ union
```

Il parametro kernel `persistence` è già incluso nell'avvio di 2D OS: se la partizione
esiste viene usata, altrimenti la sessione resta effimera senza errori bloccanti.

## Creare la partizione

Dopo aver scritto la ISO sulla chiavetta:

```bash
make persistence DEST=/dev/sdX
```

Lo script `scripts/setup-persistence.sh` crea una partizione da 8 GB (configurabile),
la formatta `ext4` con etichetta `persistence` e scrive `persistence.conf`.

Verifica:

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL /dev/sdX
```

Deve comparire una partizione con `LABEL=persistence`.

## Verifica in esecuzione

```bash
2d-info            # mostra "Persistenza: attiva / non attiva"
```

Oppure:

```bash
findmnt /run/live/persistence
```

## Stato di sicurezza — leggere

**La persistenza v0.1 non è cifrata.** Chiunque abbia la chiavetta può leggere
i file con qualsiasi PC Linux.

Regole pratiche finché non arriva la v0.2:

1. Non salvare credenziali, token o chiavi SSH nella home persistente.
2. Se la chiavetta si perde, considerare compromesso tutto ciò che conteneva.
3. Usare la persistenza per configurazioni e file di lavoro, non per segreti.

## Cifratura (v0.2)

Il piano tecnico è LUKS2 su una partizione `persistence` contenente un volume
logico con `persistence.conf`. Il parametro `persistence-encryption=luks` attiva
la richiesta della passphrase all'avvio.

Il punto delicato non è la cifratura in sé, ma **la schermata di richiesta password**:
se il tema di avvio non la mostra correttamente, l'avvio sembra bloccarsi.
Per questo la cifratura arriva dopo che il tema è stato verificato su hardware reale.

## Limiti noti

| Limite | Dettaglio |
|---|---|
| Usura della chiavetta | Le scritture continue consumano le celle; `vm.dirty_*` e zram riducono il problema |
| Prestazioni | Su USB 2.0 l'overlay è lento: evitare di scrivere file grandi |
| Aggiornamenti | `apt upgrade` sulla persistenza può riempire la partizione: tenerla ≥ 8 GB |
| Filesystem | `ext4` è la scelta più semplice e robusta per l'overlay |
