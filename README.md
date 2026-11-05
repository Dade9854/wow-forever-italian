# WoW Forever Italian

**WoW Forever Italian** mostra World of Warcraft: Forever in italiano. L'inglese originale del gioco è sempre a un tasto di distanza: tieni premuto **Alt** e torna l'inglese, rilascia e torna l'italiano.

È un fork di [WoW Forever Japanese](https://github.com/zyaga/wow-forever-japanese) di Zyaga (GPL-2.0-or-later): ne riusa il motore (gli agganci alle finestre del gioco, la ricerca delle traduzioni per id e per hash dell'inglese, il tasto per l'inglese) e il testo inglese già estratto dal client, ed è adattato all'italiano. Crediti completi in [ATTRIBUTION.md](ATTRIBUTION.md).

*English below.*

## Stato

Il progetto è all'inizio. Le traduzioni sono bozze a macchina controllate automaticamente (nomi, numeri, segnaposto, paragrafi), una zona alla volta.

| Fase | Contenuto | Stato |
|---|---|---|
| 1 | Fork funzionante, ripulito dalle parti giapponesi; quest della zona iniziale degli umani (Northshire) | fatto |
| 2 | Quest e dialoghi degli NPC | da fare |
| 3 | Tooltip di oggetti e spell, menu e interfaccia | da fare |

### Quanto è tradotto

| | In italiano |
|---|---|
| Quest | 19 |
| Dialoghi degli NPC | 0 righe |
| Pagine di libri | 0 |
| Pagine di lettere | 0 |
| Tooltip degli oggetti | 0 |
| Tooltip delle spell | 0 |
| Interfaccia | 0 |

## Cosa traduce e cosa no

- **Si traducono**: testi delle quest (titolo, obiettivi, descrizione, avanzamento, consegna); in seguito dialoghi degli NPC, libri e lettere, tooltip e interfaccia.
- **Restano in inglese**: i nomi di personaggi, luoghi, creature, oggetti, spell e fazioni (`Marshal McBride`, `Northshire Abbey`, `Kobold Vermin`, `Tough Wolf Meat`, `Alliance`), come nel progetto originale.
- **Razze e classi** sono in italiano, al genere del tuo personaggio (guerriero / guerriera, elfo della notte / elfa della notte).
- **Il genere del personaggio**: dove l'italiano accorda ("sei pronto / pronta"), l'addon sceglie la forma giusta per il tuo personaggio.

## Installazione

**Con l'app CurseForge**: cerca **WoW Forever Italian**, controlla che in alto sia selezionata l'installazione **Forever** e clicca **Installa**.

**A mano**:

1. Scarica lo zip dell'ultima versione dalla pagina delle release su GitHub.
2. Apri la cartella del client Forever (dall'app Battle.net: World of Warcraft, versione Forever, "Mostra in Esplora risorse"), poi `Interface` e `AddOns` (crea `AddOns` se non c'è).
   - Windows: `<World of Warcraft>\<cartella Forever>\Interface\AddOns`
   - macOS: `<World of Warcraft>/<cartella Forever>/Interface/AddOns`
3. Estrai lo zip lì: dentro `AddOns` deve esserci una cartella che si chiama esattamente `WoWForeverItalian`.
4. Alla schermata dei personaggi clicca **AddOn**, controlla che **WoW Forever Italian** sia spuntato ed entra in gioco.

## Come si usa

- **Alt** (modificabile): tienilo premuto per vedere l'inglese originale.
- **Impostazioni**: Esc > Opzioni > AddOn > WoW Forever Italian, oppure `/wfi config`.
- **Comandi**: `/wfi` (stato), `/wfi on` / `/wfi off`, `/wfi config`, `/wfi bug`.
- **Segnalare una traduzione sbagliata**: clic sinistro sul pulsante della minimappa, scegli la riga e invia la segnalazione (si apre un modulo su GitHub).
- Per vedere cosa non è ancora tradotto, attiva "Segna i testi non tradotti" nelle impostazioni.

## Sviluppo

Il repository contiene l'addon (`addon/WoWForeverItalian/`), la pipeline dei dati in Python (`pipeline/`), le traduzioni (`data/`) e il testo inglese di riferimento (`data/english/`, mai spedito nell'addon).

```sh
python3 -m venv .venv && .venv/bin/pip install -e "pipeline[dev]"
make test        # test Python e Lua
make lint        # ruff, luacheck e i controlli del repository
make check       # assegna lo stato a ogni riga di data/
make generate    # data/ → addon/WoWForeverItalian/Data/*.lua
make validate    # il controllo completo (quello della CI)
```

Le traduzioni si fanno a lotti, con la procedura di [docs/operations/translation-batches.md](docs/operations/translation-batches.md): si taglia un lotto di inglese da tradurre, un modello scrive le bozze seguendo la [guida di stile](docs/content/translation-style-guide.md) e il [glossario](pipeline/translation_glossary.tsv), il lint le controlla, poi si importano e si rigenera l'addon:

```sh
cd pipeline
python3 -m wfi.dev.translate_batch cut --kind quest_description --size 100 --ids batches/zona.ids --out batches/zona-description.jsonl
# … il modello scrive batches/zona-description.draft.jsonl …
python3 -m wfi.dev.translate_lint batches/zona-description.jsonl batches/zona-description.draft.jsonl
python3 -m wfi.dev.translate_batch expand batches/zona-description.draft.ok.jsonl --name zona-description-sg1 --out batches
cd .. && make import-draft DRAFT=pipeline/batches/zona-description-sg1.quest.jsonl TYPE=quest NAME=zona-description-sg1 MODEL=<id del modello> DATE=<AAAA-MM-GG>
make generate && make validate
```

La documentazione in `docs/` (architettura, decisioni, runbook) è quella del progetto originale: vale anche qui, leggendo "Italian" dove dice "Japanese"; le parti su voce, letture dei kanji e font giapponese non si applicano più.

## Licenza

GPL-2.0-or-later (vedi [LICENSE](LICENSE)). Il testo inglese in `data/english/` è di Blizzard Entertainment e non è concesso in licenza da questo progetto. World of Warcraft è un marchio di Blizzard Entertainment; questo addon non è affiliato né approvato da Blizzard.

---

## English

**WoW Forever Italian** shows World of Warcraft: Forever in Italian, with the game's own English one key away (hold **Alt**). It is a fork of [WoW Forever Japanese](https://github.com/zyaga/wow-forever-japanese) by Zyaga (GPL-2.0-or-later), whose engine, data pipeline and extracted English text it reuses. Names (characters, places, creatures, items, spells, factions) stay in English; races and classes are in Italian. The translations are machine drafts checked by the pipeline's rules, one zone at a time.

## What it translates

| | In Italian |
|---|---|
| Quests | 19 |
| NPC dialogue lines | 0 |
| Book pages | 0 |
| Letter pages | 0 |
| Item tooltips | 0 |
| Spell tooltips | 0 |
| UI | 0 |

Install: with the CurseForge app (Forever install selected), or unzip the release into your Forever client's `Interface/AddOns` folder (the folder must be named `WoWForeverItalian`). Settings: Esc > Options > AddOns, or `/wfi config`. License: GPL-2.0-or-later; credits in [ATTRIBUTION.md](ATTRIBUTION.md).
