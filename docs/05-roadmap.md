# 05 — Roadmap

## Stato

| Fase | Contenuto | Stato |
|---|---|---|
| 1 | Fondamenta: repository, live-build, prima ISO | ✅ completata |
| 2 | Avvio USB su hardware reale | 🔄 in corso (test Acer/HP) |
| 3 | Persistenza e cifratura | ⏳ parziale (persistenza sì, LUKS no) |
| 4 | Interfaccia 2D proprietaria | 🔄 avanti (2D Shell, dock, HUD, avvio, suono) |
| 5 | Intelligenza (Chat2D, agenti) | ⏳ |
| 6 | Ecosistema 2D (Nexus, Atlas, …) | ⏳ |
| 7 | Stabilizzazione | ⏳ |

## Fase 2 — criteri di uscita

- [ ] 2D OS arriva al desktop sull'Acer
- [ ] 2D OS arriva al desktop sull'HP
- [ ] rapporto `2d-hwreport` raccolto per entrambe
- [ ] disco interno verificato intatto
- [ ] tempi di avvio misurati e registrati

## Fase 3 — persistenza

- [ ] partizione persistente creata e verificata
- [ ] schermata di richiesta passphrase funzionante nel tema
- [ ] LUKS2 attivo
- [ ] backup della partizione documentato

## Fase 4 — interfaccia

Ordine di lavoro, dal più economico al più costoso:

1. Tema XFCE coerente (colori, font, icone, sfondo) — giorni
2. Pannello e menu personalizzati — settimane
3. Dock dedicata — settimane
4. Componenti animati (QML) — mesi
5. Shell proprietaria completa — mesi, con beneficio marginale

Il punto 5 non è un obiettivo: è un'opzione da valutare solo se i punti 1–3
si rivelano insufficienti.

## Fase 5 — intelligenza

- [ ] Chat2D come applicazione desktop
- [ ] connettore verso i servizi cloud 2D
- [ ] esecuzione locale opzionale solo su macchine con GPU
- [ ] permessi espliciti per ogni azione dell'agente

## Debito tecnico noto

| Voce | Impatto | Quando |
|---|---|---|
| Nessun supporto Secure Boot | Alcuni PC moderni richiedono la disattivazione | Fase 7 |
| Plymouth senza mascheramento password | Blocca la persistenza cifrata | Fase 3 |
| Nessuna build firmata | Le ISO non sono verificabili all'origine | Fase 7 |
| Nessun test automatico dell'immagine | Regressioni scoperte a mano | Fase 2 |
| Aggiornamenti non gestiti | Sistemi live che invecchiano | Fase 7 |

## Idee scartate (per ora)

- `toram`: con 4 GB di RAM toglie memoria alle applicazioni.
- Compiz/effetti 3D: incompatibili con la GMA X4500.
- AI locale su hardware del laboratorio: non entra in 4 GB.
- Kernel proprio: costo enorme, beneficio nullo per il fine del progetto.
