# 00 — Il progetto

## Obiettivo

Costruire una distribuzione Linux avviabile da USB che faccia da **postazione di lavoro
portatile** per l'ecosistema 2D: stesso ambiente su ogni PC, nessuna installazione,
nessuna modifica al disco interno.

Il nome **2D OS** è il marchio del prodotto. Tecnicamente il sistema è una
**distro Debian personalizzata** (`live-build`), che è una cosa diversa — e molto più
praticabile — dallo scrivere un kernel.

## Perché una distro e non un sistema da zero

| Approccio | Costo | Manutenzione | Rischio |
|---|---|---|---|
| Kernel + stack scritti da zero | Enorme | Continua | Altissimo |
| Distro Debian personalizzata | Contenuto | Aggiornamenti upstream | Basso |
| Ambiente portabile senza distro (dotfiles + container) | Minimo | Bassa | Nullo, ma meno controllo |

La scelta fatta è la seconda. La terza resta il piano di riserva: se il progetto si
arenasse, si torna a una chiavetta con distro standard + configurazione automatica.

## Perimetro v0.1

Dentro:

- avvio da USB su BIOS legacy e UEFI;
- desktop XFCE con identità visiva 2D;
- tema di avvio personalizzato;
- diagnostica hardware (`2d-hwreport`) per valutare le macchine del laboratorio;
- strumenti di sviluppo di base;
- memoria compressa (zram) per i PC con 4 GB.

Fuori (deliberatamente):

- installazione su disco;
- persistenza cifrata;
- shell desktop proprietaria con animazione completa delle icone;
- AI locale;
- supporto Secure Boot;
- distribuzione a terzi.

Dentro dalla v0.1 ma con attivazione condizionata all'hardware
(vedi [06-interfaccia.md](06-interfaccia.md)):

- dock animata, compositore, HUD CPU/GPU;
- suono di avvio;
- due profili grafici (classic / immersive) scelti automaticamente.

## Non-obiettivi

- Sostituire Windows o Linux per il pubblico.
- Ottenere un'esperienza grafica "cinematografica" su hardware del 2009.
- Aggiungere servizi prima che l'avvio sia affidabile.

## Hardware di riferimento

| Macchina | Ruolo | Note |
|---|---|---|
| Acer Veriton X275 | Test di compatibilità difficile | Pentium dual-core, 4 GB RAM, grafica Intel GMA X4500, USB 2.0 |
| HP (Windows 8) | Secondo test | 4 GB RAM, hardware da identificare |
| Macchina moderna | Test di prestazione | SSD/USB 3.x |

Su GMA X4500 non esiste accelerazione OpenGL reale: tutto passa dal rendering software.
È il vincolo che rende irrealistico qualunque effetto grafico pesante su quelle macchine.
