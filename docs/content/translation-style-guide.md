# Guida di stile della traduzione: testi del server, tooltip del client e interfaccia

version: sg1

> Cosa riceve il modello che traduce, insieme a `pipeline/translation_glossary.tsv` e a un file di lotto, per scrivere l'italiano di: titolo, obiettivi e descrizione delle quest, testo di avanzamento e di consegna, dialoghi e frasi degli NPC, pagine di libri, lettere e targhe, testi degli obiettivi, e descrizioni dei tooltip di oggetti e spell (sezione **Tooltip**: un registro diverso e regole diverse per i segnaposto). Le regole vengono dalla politica sui nomi del progetto ([principio 2](../architecture/principles.md#2-names-stay-in-english)): i nomi restano in inglese. Cambiare una regola o un esempio è una nuova versione: si porta `version:` al numero `sg` successivo, e i nomi delle bozze finiscono con il nuovo `-sg<N>`. La sezione **Testi dell'interfaccia** fa eccezione: governa le bozze del dizionario dell'interfaccia, che non hanno versione.

## Il compito

- Ogni riga del lotto è `{"ref", "kind", "en", "targets"}`; le righe delle quest (`progress`, `completion`) hanno anche `"items"`: i nomi degli oggetti negli obiettivi della quest (`["Sack of Barley", "Sack of Rye"]`, spesso vuoto). `kind` è `progress` (l'NPC chiede se il compito è fatto, prima della consegna), `completion` (l'NPC ringrazia e consegna la ricompensa), `gossip` (cosa dice un NPC quando gli si parla), `book` (una pagina di libro, lettera, biglietto o targa), uno dei tipi **quest** `quest_title` / `quest_objectives` / `quest_description` (vedi **Quest**), `objective` / `area` (il testo di un obiettivo), o uno dei tipi **tooltip** `item_description`, `spell_description` e `spell_aura`, le cui righe hanno anche `"slots"` (vedi **Tooltip**).
- Scrivi una riga di uscita per ogni riga del lotto: `{"ref": "<il ref della riga>", "ja": "<italiano>"}`, un oggetto JSON per riga, nient'altro. Ogni ref esattamente una volta. (Il campo si chiama `ja` per eredità dal progetto originale giapponese: contiene il testo italiano.)
- Traduci il significato di tutto il testo inglese. Non aggiungere frasi, non toglierne, non riassumere e non spiegare.
- Scrivi un italiano naturale e scorrevole, come in un gioco di ruolo fantasy: non un calco parola per parola dell'inglese.

## I nomi restano in inglese

- Ogni nome resta esattamente come lo scrive l'inglese, in lettere inglesi, dentro la frase italiana: persone (`Renee`, `Marshal McBride`), luoghi e zone (`Stormwind`, `Elwynn Forest`, `Northshire Abbey`, `the Barrens` → `Barrens`), creature e tipi di creatura (`Kobold Vermin`, `quilboar`, `murloc`). I tipi di creatura propri di WoW restano in inglese (`kobold`, `gnoll`, `murloc`, `harpy`, `centaur`, `furbolg`, `ogre`, `raptor`, `wyvern`, `gryphon`, `worgen`, `quilboar`, `scorpid`, `crocolisk`), mentre gli animali reali e i mostri fantasy comuni sono parole italiane (`wolf` → lupo, `timber wolf` → lupo dei boschi, `spider` → ragno, `bear` → orso, `boar` → cinghiale, `zombie` → zombi, `skeleton` → scheletro, `ghost` → fantasma, `dragon` → drago). Anche gli oggetti restano in inglese, pure quando l'inglese li scrive in minuscolo (`tough wolf meat`), ma solo quando la parola indica un oggetto che la quest chiede o consegna: gli `items` della riga elencano gli oggetti degli obiettivi; una parola comune che non è uno di quegli oggetti si traduce (`candles` → candele, `pie` → torta). Restano in inglese anche le spell, i nomi delle professioni come li mostra l'interfaccia (`Skinning`, `Herbalism`, `First Aid`), le fazioni e le organizzazioni (`Horde`, `Alliance`, `Scourge`, `Defias`, `Stormwind Army`, `Cenarion Circle`) e gli eventi (`Winter Veil`).
- Non tradurre mai un nome e non usare il nome italiano ufficiale (niente `Roccavento` per `Stormwind`, niente `Foresta di Elwynn`), e non aggiungere una traduzione tra parentesi.
- Un titolo che fa parte di un nome resta con il nome (`Lord Kazzak`, `Commander Althea`, `King Magni`, `Deputy Willem`, `Brother Neals`, `Priestess Anetta`, `the Dark Lady`, `Lion's Pride Inn`): un titolo subito prima o subito dopo un nome resta in inglese con esso.
- Un titolo o un nome comune usato da solo si traduce, anche se l'inglese lo scrive con la maiuscola: `the Captain` → il capitano, `the Kingdom` → il regno, `His Majesty` → Sua Maestà, `the Guard` → la guardia, `the Marshal` → il maresciallo, `the Warchief` → il capoguerra, `the Inn` → la locanda, `the Holy Light` (la fede) → la Sacra Luce, `the Light` → la Luce. Il glossario li elenca. Un giorno della settimana non è un nome: `this Sunday` → questa domenica.
- Un luogo o un gruppo unito da `of` è un solo nome e resta in inglese: `Temple of the Moon`, `Brotherhood of the Light`. Un titolo di persona con `of` si traduce: `the King of Stormwind` → il re di Stormwind.
- Un istruttore di professione tiene il nome dell'abilità in inglese e traduce il ruolo: `Skinning Trainer` → istruttore di Skinning.
- Un trattino chiude una parola, quindi solo la parte che è un nome resta in inglese: `Scourge-driven` → spinto dagli Scourge.
- Una didascalia come `*cough*` o `<Sob>` non è prosa; si traduce il gesto (`*coff*`, `<Singhiozza>`), e la parola dopo comincia una frase.
- Una parola non è un nome solo perché comincia una frase: `Say Captain... I overheard you!` è il capitano. Un nome di abilità lì resta comunque in inglese: `Tailoring you say?` → Tailoring, dici?
- Il nome di un mob resta in inglese anche quando contiene una parola di classe o di razza (`Skeletal Warrior`, `Murloc Warrior`): la parola fa parte del nome.
- **Articoli e preposizioni davanti ai nomi inglesi**: usa l'articolo che suona naturale per il senso italiano della cosa (`il Kobold Vermin`, `la Sharptalon's Claw`, `al Lion's Pride Inn`, `nella Elwynn Forest`), le preposizioni articolate normali (`dalla`, `nella`) e niente articolo davanti ai nomi di persona e di città (`a Stormwind`, `da Marshal McBride`). Quando un articolo suona forzato, riformula: `Porta 8 Tough Wolf Meat a Eagan Peltskinner`.
- **Razze e classi sono l'eccezione: si scrivono in italiano** quando indicano la razza o la classe del giocatore o di un personaggio (`Tauren` → tauren, `Druid` → druido, `Night Elf` → elfo della notte, `Warlock` → stregone), in minuscolo nella prosa, con le parole del glossario. Sono le stesse parole che l'addon mette al posto di `{race}` e `{class}`. Le forme aggettivali usano la stessa parola o il suo aggettivo (`dwarven` → nanico).
- Una parola con la maiuscola che non è un nome (`the Light`) si traduce; il glossario le elenca. Dentro una frase italiana, la maiuscola resta solo ai nomi inglesi e alle parole del glossario che la vogliono (la Luce, Sua Maestà): il controllo dei nomi legge ogni altra parola maiuscola in mezzo a una frase come un nome, e la boccia se l'inglese non ce l'ha.

## Segnaposto, paragrafi e numeri

- `{name}`, `{class}` e `{race}` vengono riempiti in gioco con il nome, la classe e la razza del giocatore. Tieni ogni segnaposto esattamente com'è, tante volte quante lo ha l'inglese (`Grazie, {name}.`). La classe e la razza arrivano in minuscolo, già al genere del personaggio (guerriero / guerriera), con la maiuscola se aprono una frase. Davanti a `{class}` e `{race}` evita articoli e aggettivi che dovrebbero accordarsi (non `un {class}` né `il nostro {race}`, che darebbe "un elfa della notte"): usa forme invariabili (`giovane {class}`), il vocativo (`Salute, {class}!`) o riformula.
- **Il genere del giocatore.** L'italiano accorda aggettivi e participi con il giocatore (`sei pronto` / `sei pronta`), l'inglese no. Prima prova una forma che vada bene per tutti e due (`Ti do il benvenuto` invece di `Benvenuto`, `Hai fatto un ottimo lavoro` invece di `Sei stato bravo`). Quando suonerebbe forzato, scrivi la coppia `<maschile/femminile>`: l'addon sceglie la forma giusta in gioco (`Sei <pronto/pronta>?`, `<Bentornato/Bentornata>, {name}!`). La coppia è sempre di due parole intere, solo lettere senza accenti e senza spazi (`<pronto/pronta>`, `<stanco/stanca>`, mai `Bentornat<o/a>`); se serve un accento o più di una parola, riformula. Mai `pronto/a`, mai `pronto/pronta` senza le parentesi angolate, mai `pront*`.
- `$G<maschile>:<femminile>;` vuol dire che l'inglese cambia con il genere del giocatore. Scrivi una forma neutra o la coppia `<maschile/femminile>` italiana; mai il codice `$G`. Quando è un modo di rivolgersi al giocatore (`$Glad:lass;`), tieni un appellativo: una coppia di una parola (`<ragazzo/ragazza>`) o una parola che vale per tutti e due (`giovane`). Non toglierlo.
- `$` seguito da cifre e `w` (`$1997w`) è un numero che riempie il gioco. Tienilo esattamente com'è, ogni volta.
- L'inglese separa i paragrafi con una riga vuota. L'italiano ha lo stesso numero di paragrafi, separati da una riga vuota.
- I numeri restano gli stessi valori, scritti in cifre (`three` → 3). Scrivi una cifra solo per un numero che l'inglese scrive in cifre o in lettere. "A", "an", "both", "another", "once" e simili non sono numeri: usa le parole (`an hour ago` → un'ora fa, `both parts` → entrambe le parti).
- La punteggiatura segue l'inglese: stessi puntini (`...`), stesse virgolette dritte (`"`), stessi punti esclamativi e interrogativi. Niente spazio prima di `!`, `?`, `:` e `;`.

## Voce e registro

Deduci chi parla dal testo (chi parla così, a chi) e tieni la stessa voce per tutta la riga.

| Chi parla | Voce |
|---|---|
| sacerdoti, druidi, guaritori, studiosi gentili | cortese e calda, frasi complete |
| anziani, nobili, esseri antichi o regali | solenne, un po' arcaica (`dunque`, `orsù`, `giacché` con misura) |
| soldati, orchi, Forsaken, chi è duro o militare | asciutta e diretta, frasi brevi |
| allegri, informali, mercanti, goblin | colloquiale, vivace |
| incerto | neutra, senza un carattere forte |

- Gli NPC danno del **tu** al giocatore, come nel client italiano ufficiale. Il **voi** solo quando l'inglese si rivolge a un gruppo.
- Rivolgiti al giocatore come fa l'inglese (`{name}`, `{class}`, "friend" → amico mio / `<amico/amica>`).
- Il testo di avanzamento è breve, un po' impaziente o speranzoso; quello di consegna è caloroso o pratico; i dialoghi possono avere colore, ma dicono solo quello che dice l'inglese.

## Frasi degli NPC (gossip detti, urlati, sussurrati o emote)

Il tipo gossip porta anche quello che gli NPC dicono nella chat, nei fumetti e sullo schermo. Valgono le regole sopra, più tre:

- `%s` è il nome dell'NPC che parla, inserito dal gioco (`%s goes into a frenzy!`). Tieni ogni `%s`, esattamente quanti ne ha l'inglese, e scrivi la frase in modo che ci stia un nome inglese: `%s va su tutte le furie!`. Non scrivere nessun altro `%`.
- Un urlo è breve e forte: tieni i punti esclamativi dell'inglese e non ammorbidirlo. Un grido di battaglia resta un grido di battaglia (`For the Horde!` → Per la Horde!).
- Un'emote descrive l'NPC in terza persona, al presente (`%s laughs.` → `%s ride.`).

## Libri, lettere e targhe (`book`)

- Una pagina si traduce intera, con lo stesso numero di paragrafi. Un saluto e una firma di lettera restano saluto e firma (`Dear Mother,` → Cara madre, ; la firma è un nome e resta in inglese).
- Una pagina scritta in HTML (`<HTML><BODY>…`) tiene ogni tag, con i suoi attributi, nello stesso ordine; si traduce solo il testo tra i tag.
- Un titolo di libro è un'intestazione: niente punto finale, iniziale maiuscola solo sulla prima parola e sui nomi.

## Tooltip (`item_description`, `spell_description`, `spell_aura`)

Il testo di un tooltip è uno **schema**: il client riempie i valori per oggetto, rango, livello e talento. Quindi una bozza non scrive mai un numero che fornisce il client.

### `$N<k>`: un numero

Scrivi `$N<k>` per il k-esimo valore della riga che il giocatore vede, contato in ordine di lettura dell'inglese (`Restores $o1 health over $d.`: il valore della salute è `$N1`). Il numero di valori è nello `"slots"` della riga. `Ripristina $N1 punti salute in $D1.`

### `$D<k>`: una durata

Scrivi `$D<k>` per la k-esima durata: l'addon copia la durata dalla riga dal vivo, con l'unità che sceglie il client (secondi o minuti). Non scrivere mai l'unità da te (`$N2 sec` è sbagliato). Un numero che l'inglese scrive davanti a un'unità (`every 5 sec`) è anch'esso una durata. Il numero di durate è in `"durations"`.

### Contare i valori

Si contano in ordine di lettura dell'inglese, una volta per ogni codice che stampa un numero (`$s1`, `$o1`, `$m1`, `$d`, `${…}`): `$N1` è il primo, `$N2` il secondo. Una somma `${$m1/60}` è un solo valore. Un codice che stampa una parola (`$lsecond:seconds;`) non è un valore.

### Testo incluso e icone

`$I<k>` è un'icona: tienila una volta, dove sta nell'inglese. `$T` in fondo a una riga è un elenco di nomi che l'addon copia dal vivo: traduci la parte prima, con le stesse interruzioni di riga, e chiudi con `$T`.

### Rami

Una riga con `$?<condizione>[A][B]` tiene la stessa struttura: traduci ogni ramo per conto suo, con gli stessi segnaposto del ramo inglese.

### Nomi e parole fisse nei tooltip

I nomi di oggetti, spell e creature restano in inglese, come ovunque. Le parole delle statistiche si scrivono come le scrive l'interfaccia italiana (salute, mana, stamina, intelletto, agilità, forza, spirito, armatura): mai in lettere inglesi da sole (`health`, `Stamina`). Dentro un nome (`Mana Shield`, `Elixir of Agility`) restano in inglese.

## Quest (`quest_title`, `quest_objectives`, `quest_description`)

Le tre parti della finestra della quest; ognuna ha il suo registro. `progress` e `completion` sono il testo successivo della stessa quest e seguono **Voce e registro**.

### `quest_description`: chi dà la quest parla

È l'NPC che parla al giocatore: vale per intero **Voce e registro**. Deduci chi parla, tieni quella voce per tutto il testo, rivolgiti al giocatore come fa l'inglese.

### `quest_objectives`: cosa deve fare il giocatore

La riga sotto "Obiettivi": un'istruzione, all'**imperativo di seconda persona**, come nel client italiano ufficiale:

```
EN   Kill 10 Kobold Vermin, then return to Marshal McBride.
IT   Uccidi 10 Kobold Vermin, poi torna da Marshal McBride.

EN   Bring 8 pieces of Tough Wolf Meat to Eagan Peltskinner outside Northshire Abbey.
IT   Porta 8 pezzi di Tough Wolf Meat a Eagan Peltskinner, fuori dalla Northshire Abbey.
```

Quando l'inglese dice "X wants you to…", dillo: `Marshal McBride vuole che tu…`.

### `quest_title`: un'intestazione breve

Un sintagma nominale o un infinito, senza punto finale, con la maiuscola solo sulla prima parola e sui nomi inglesi (all'italiana, non con tutte le iniziali maiuscole): `Una minaccia interna`, `Ripulire il campo dei kobold`, `Lupi oltre il confine`. Un titolo che è solo un nome resta quel nome (`Milly Osworth`).

**Il controllo dei nomi non gira sulle righe dei titoli** (in inglese sono in title case, quindi la maiuscola non dice quale parola è un nome): la regola dei nomi qui è tua, senza rete. Un nome di persona, luogo, mob, oggetto o spell resta in inglese, e nient'altro.

### Numeri nelle quest

Un numero scritto nell'inglese (`Bring 10 Linen Cloth`) è scritto uguale in italiano. Un codice del server che sta per un numero (`$1oa`, `$2oa`) prende `$N<k>` come in un tooltip. Niente `$D<k>` nelle quest.

## Testi dell'interfaccia (stringhe UI)

Le stringhe dell'interfaccia (pulsanti, etichette, messaggi di errore) seguono il client italiano ufficiale quando esiste una sua resa, altrimenti una resa breve e chiara. Regole:

1. **Significato nel contesto**: la stessa parola inglese può voler dire cose diverse in finestre diverse ("Back": indietro / schiena).
2. **Lunghezza che ci sta**: un pulsante resta breve; preferisci la parola più corta tra due equivalenti.
3. **Registro**: frasi impersonali o all'imperativo di cortesia minimo (`Accetta`, `Annulla`, `Impossibile farlo ora.`).
4. **Coerenza**: una stessa stringa inglese ha una sola resa in tutto il dizionario, salvo i casi di significato diverso.
5. **Formato intatto**: ogni `%s`, `%d`, `%1$s`, codice colore `|c…|r`, texture `|T…|t`, link e interruzione di riga resta, nello stesso ordine.
6. **I nomi restano in inglese**, come ovunque.

## Glossario

Usa `pipeline/translation_glossary.tsv` per le parole ricorrenti che si traducono (`adventurer` → avventuriero, `the Light` → la Luce) e per le parole di razza e classe. Un termine segnato `required` deve comparire in una delle forme che dà il glossario (`warrior` → guerriero / guerriera / guerrieri / guerriere, mai `combattente`), a meno che faccia parte di un nome e resti quindi in inglese (`Skeletal Warrior`); gli altri sono la resa preferita. Titoli e nomi comuni (`captain`, `kingdom`, `his majesty`) si traducono quando sono usati da soli e restano in inglese con il nome che segue. Non scrivere mai due rese unite da `/` (`maestro/padrone`): scegline una (la coppia di genere `<pronto/pronta>` è un'altra cosa). Una parola che non è nel glossario e non è un nome: traducila in modo naturale.

## Esempi

Esempi di riferimento (non presi dai dati: illustrano le regole).

```text
EN   Your first task is one of cleansing, {name}.  A clan of kobolds have infested the woods to the north.  Go there and fight the Kobold Vermin you find.  Reduce their numbers so that we may one day drive them from Northshire.
IT   Il tuo primo compito è fare pulizia, {name}. Un clan di kobold ha infestato i boschi a nord. Vai là e combatti i Kobold Vermin che trovi. Riducine il numero, così che un giorno potremo cacciarli da Northshire.

EN   How goes the hunting, {name}?  Have you found and defeated those vermin?
IT   Come va la caccia, {name}? Hai trovato e sconfitto quei parassiti?

EN   Finally! We meet face to face, brother to $gbrother:sister;.
IT   Finalmente! Ci incontriamo faccia a faccia, fratello e <fratello/sorella>.

EN   %s laughs.
IT   %s ride.
```
