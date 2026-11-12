# 2D OS

**Portable Intelligence Operating System** — distribuzione Linux live avviabile da USB,
personalizzata per l'ecosistema 2D. Uso interno.

> **Stato: v0.1.0 — prototipo di laboratorio (Fase 1-2).**
> Si tratta di una distro Debian personalizzata, non di un kernel scritto da zero.
> Questa distinzione è deliberata e va mantenuta in tutta la comunicazione.

---

## Cosa fa oggi

| Funzione | Stato |
|---|---|
| Avvio da USB su BIOS legacy e UEFI | ✅ implementato |
| Desktop XFCE con identità 2D | ✅ implementato |
| Tema di avvio Plymouth 2D | ✅ implementato |
| zram (memoria compressa) per PC con 4 GB | ✅ implementato |
| Strumenti di diagnostica hardware (`2d-hwreport`) | ✅ implementato |
| Strumenti di sviluppo (git, Python, Node, gcc) | ✅ implementato |
| Persistenza dei dati su USB | ⚠️ manuale, non cifrata |
| Persistenza cifrata LUKS | ⏳ v0.2 |
| **Adattamento automatico all'hardware** (`2d-mode`) | ✅ classic / immersive |
| **2D Shell** (desktop proprietario, icone animate) | ✅ profilo immersive |
| **Logo ufficiale 2D nell'avvio** | ⚠️ predisposto: `brand/logo/logo.svg` |
| **Dock animata** (Plank) | ✅ profilo immersive |
| **HUD CPU/RAM/GPU** (Conky) | ✅ profilo immersive |
| **Suono di avvio** | ✅ disattivabile |
| Window manager proprietario / effetti 3D | ⏳ non previsto |
| Chat2D / agenti AI integrati | ⏳ Fase 5 |
| VS Code nell'immagine | ⏳ opzionale via `vendor/debs` |

## Requisiti

- Docker (per la build)
- ~20 GB di spazio libero
- Una chiavetta USB ≥ 8 GB per il test su hardware
- Per i test: `qemu-system-x86` (facoltativo)

## Uso rapido

```bash
make build          # costruisce dist/2d-os-<versione>-amd64.iso
make vm             # la avvia in QEMU
make flash DEST=/dev/sdX       # la scrive su USB (CANCELLA il dispositivo)
make persistence DEST=/dev/sdX # aggiunge la partizione dati persistente
```

Per provarla nel browser senza hardware: `./scripts/demo-vm.sh` (vedi
[docs/08-demo-vm.md](docs/08-demo-vm.md)).

## Prima ISO costruita

| Campo | Valore |
|---|---|
| File | `dist/2d-os-0.1.0-amd64.iso` |
| Dimensione | 1,9 GB |
| SHA256 | `fff4c338c5f750fdc89911b75fa0b135bf07b9948055c9bcc388879fc94e8c52` |
| Esito | `Build completed successfully` |

## Struttura

```text
.
├── build/           # ambiente di build Docker riproducibile
├── brand/           # identità visiva: Plymouth, sfondi, asset
├── live/            # configurazione live-build (la fonte di verità)
│   ├── auto/config  # opzioni di build
│   └── config/      # pacchetti, include, hook
├── scripts/         # build, flash, persistenza, test in VM
├── vendor/debs/     # pacchetti .deb opzionali (es. VS Code)
└── docs/            # architettura, build, test, roadmap
```

## Documentazione

- [docs/00-progetto.md](docs/00-progetto.md) — obiettivi, perimetro, non-obiettivi
- [docs/01-architettura.md](docs/01-architettura.md) — com'è fatta l'immagine
- [docs/02-build.md](docs/02-build.md) — come funziona la build, come modificarla
- [docs/03-persistenza.md](docs/03-persistenza.md) — dati persistenti e cifratura
- [docs/04-lab-test.md](docs/04-lab-test.md) — piano di test su Acer e HP
- [docs/05-roadmap.md](docs/05-roadmap.md) — fasi e prossimi passi
- [docs/06-interfaccia.md](docs/06-interfaccia.md) — profili classic/immersive
- [docs/07-shell.md](docs/07-shell.md) — 2D Shell, il desktop proprietario

## Avvertenze

- Il sistema è pensato per l'uso interno su macchine proprie.
- La persistenza v0.1 **non è cifrata**: non usarla per credenziali reali.
- L'avvio con Secure Boot attivo non è supportato (GRUB non firmato).
- I file `.deb` in `vendor/debs/` diventano parte dell'immagine: verificarne la provenienza.

