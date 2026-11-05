"""`translate_lint` fails a draft row for each problem it names and passes only clean rows."""

from pathlib import Path

import pytest

from wfi.core import align
from wfi.dev import translate_lint as tl
from wfi.dev.translate_batch import read_jsonl, write_jsonl

ALLOW = {"horde"}
GLOSSARY = {"light"}


def _row(en, kind="completion", ref="r"):
    return {"ref": ref, "kind": kind, "en": en, "targets": [[1, "completion"]]}


def _check(en, ja, kind="completion"):
    return tl.check_row(_row(en, kind), ja, ALLOW, GLOSSARY)


def test_a_clean_row_passes():
    en = "Thank you, {name}. Take these 3 coins to Stormwind.\n\nThe Horde thanks you."
    ja = "parola,{name}, testo 3 cosa Stormwind frase,\n\nHorde voce,"
    assert _check(en, ja) == []


@pytest.mark.parametrize(
    ("en", "ja", "reason"),
    [
        ("Thank you.", "Thank you.", "not_italian"),
        ("Thank you.", "谢谢你们。", "not_italian"),
        ("Thank you, {name}.", "parola,", "tokens:{name}×1→none"),
        ("Hi {name}.", "parola {name},{name},", "tokens:{name}×1→{name}×2"),
        ("Hi {race}.", "parola {class},", "tokens:{race}×1→{class}×1"),
        ("Thanks $Gsir:madam;.", "parola,$Gsir:madam;,", "leftover:$G"),
        ("Thanks.", "parola,{foo},", "leftover:{foo}"),
        ("Thanks, sir.", "Grazie, <signore/signora> e <più/meno>.", "leftover:<più/meno>"),
        ("Thanks, sir.", "Grazie, <Mr./Ms.>.", "leftover:<Mr./Ms.>"),
        ("One.\n\nTwo.", "parola, testo,", "paragraphs:1/2"),
        ("We have $1997w of $1998w bars.", "$1998w parola 1997 testo,", "counters:$1997w×1,$1998w×1→$1998w×1"),
        ("Go north.", "ecco Goldshire parola,", "alignment_failed:Goldshire"),
        ("Bring me three.", "4 parola,", "numbers_changed:4"),
        ("Go to Stormwind now.", "parola,", "name_missing:Stormwind"),
    ],
)
def test_each_reason(en, ja, reason):
    assert reason in _check(en, ja)


def test_a_plural_name_kept_in_the_singular_passes():
    assert _check("Have you been killing Gnolls near Goldshire?", "ecco Goldshire parola Gnoll testo?") == []


def test_server_counters_kept_exactly_pass():
    assert _check("We have $1997w of $1998w bars.", "$1998w parola $1997w testo,") == []


def test_allowlisted_latin_word_and_number_words_pass():
    assert _check("Bring me three, for the Horde.", "ecco Horde parola 3 testo,") == []


@pytest.mark.parametrize(
    "en",
    [
        "Yes. I'm glad, and I'll go.",  # I'm / I'll are not names
        "You must be STEADY now.",  # a shouted word
        "Walk in the Light, friend.",  # glossary term
        "Thank you. Stormwind is safe.",  # a sentence-initial capital is never a name candidate
    ],
)
def test_english_names_exemptions(en):
    names = tl.english_names(en, GLOSSARY)
    assert "I'm" not in names and "I'll" not in names and "STEADY" not in names and "Light" not in names
    assert "Yes" not in names and "You" not in names and "Walk" not in names and "Thank" not in names


def test_names_mid_sentence_and_possessive():
    assert tl.english_names("Speak to Lord Kazzak's guard in Stormwind.", set()) == ["Lord", "Kazzak", "Stormwind"]
    assert tl.english_names("Thank you. Stormwind is safe.", set()) == []


def test_glossary_plurals_are_exempt():
    exempt = {"tauren", "gnome", "dwarf", "night", "elf"}
    en = "Ask the Taurens, the Gnomes, the Dwarves and the Night Elves in Stormwind."
    assert tl.english_names(en, exempt) == ["Stormwind"]


def test_exempt_words_split_multi_word_terms():
    assert tl.exempt_words({"night elf": "parola", "light": "parola"}) == {"night", "elf", "light"}


def _files(tmp_path, batch, draft):
    b, d = tmp_path / "b.jsonl", tmp_path / "b.draft.jsonl"
    write_jsonl(b, batch)
    write_jsonl(d, draft)
    return b, d


def test_lint_coverage_and_ok_rows(tmp_path):
    batch = [_row("Hello.", ref="a"), _row("Bye.", ref="b"), _row("Hi.", ref="c"), _row("Yo.", ref="d")]
    draft = [
        {"ref": "a", "ja": "parola,"},
        {"ref": "b", "ja": "parola,"},
        {"ref": "b", "ja": "parola,"},  # duplicate
        {"ref": "z", "ja": "parola,"},  # unknown
        {"ref": "d", "ja": "Yo."},  # fails a check
    ]  # c missing
    ok, failures = tl.lint(*_files(tmp_path, batch, draft), ALLOW, GLOSSARY)
    assert [r["ref"] for r in ok] == ["a"]
    assert ok[0] == {"ref": "a", "kind": "completion", "ja": "parola,", "targets": [[1, "completion"]]}
    assert failures == {"b": ["duplicate"], "z": ["unknown_ref"], "c": ["missing"], "d": ["not_italian"]}


def test_main_writes_ok_file_and_exit_code(tmp_path, root: Path, capsys):
    b, d = _files(tmp_path, [_row("Hello.", ref="a")], [{"ref": "a", "ja": "parola,"}])
    assert tl.main([str(b), str(d)]) == 0
    assert read_jsonl(tmp_path / "b.draft.ok.jsonl")[0]["ja"] == "parola,"
    b, d = _files(tmp_path, [_row("Hello.", ref="a")], [{"ref": "a", "ja": "Hello."}])
    assert tl.main([str(b), str(d)]) == 1
    assert "a: not_italian" in capsys.readouterr().out


@pytest.mark.parametrize(
    ("en", "ja", "ok"),
    [
        ("You are a true warrior, {name}.", "Sei un vero combattente, {name}.", False),
        ("You are a true warrior, {name}.", "Sei <un/una> vera guerriera, {name}.", True),  # any listed form
        ("The dwarves of Ironforge send word.", "i nani di Ironforge mandano notizie.", True),
        ("Night Elves guard Teldrassil.", "gli elfi della notte sorvegliano Teldrassil.", True),
        ("A warlock's pact.", "Il patto di un mago oscuro.", False),  # possessive of a required word
        ("They were warriorlike.", "Erano bellicosi.", True),  # not the word itself
    ],
)
def test_required_glossary_terms(en, ja, ok):
    required = {"warrior": "guerriero | guerriera | guerrieri", "dwarf": "nano | nani",
                "night elf": "elfo della notte | elfi della notte", "warlock": "stregone | strega"}
    reasons = [r for r in tl.check_row(_row(en), ja, set(), {"warrior", "dwarf", "night", "elf", "warlock"}, required)
               if r.startswith("glossary:")]
    assert (reasons == []) is ok, reasons


def test_a_listed_required_term_is_not_checked_on_that_row():
    """"a rogue spark" is a stray spark, not the class; the not-names list exempts the term on that row
    only, and every other required term on the row is still checked."""
    required = {"rogue": "ladro | ladra", "dwarf": "nano | nana"}
    en = "A rogue spark hit the dwarf's machine."
    ja = "Una scintilla vagante ha colpito la macchina."
    assert tl.check_row(_row(en), ja, set(), set(), required) == ["glossary:rogue", "glossary:dwarf"]
    assert tl.check_row(_row(en), ja, set(), set(), required, {"rogue"}) == ["glossary:dwarf"]
    # only the exact lower-case term: a capitalised not-name ("Warrior of the Scarlet Crusade") exempts nothing
    assert tl.check_row(_row(en), ja, set(), set(), required, {"Rogue"}) == ["glossary:rogue", "glossary:dwarf"]


def test_read_required(tmp_path):
    p = tmp_path / "g.tsv"
    p.write_text("hero\teroe\ndruid\tdruido | druida\trequired\n", encoding="utf-8")
    assert tl.read_glossary(p) == {"hero": "eroe", "druid": "druido | druida"}
    assert tl.read_required(p) == {"druid": "druido | druida"}
    p.write_text("druid\tdruido\tmaybe\n", encoding="utf-8")
    with pytest.raises(ValueError, match="required"):
        tl.read_glossary(p)


def test_read_glossary_rejects_bad_lines(tmp_path):
    p = tmp_path / "g.tsv"
    p.write_text("# c\nhero\teroe\n", encoding="utf-8")
    assert tl.read_glossary(p) == {"hero": "eroe"}
    p.write_text("hero eroe\n", encoding="utf-8")
    with pytest.raises(ValueError):
        tl.read_glossary(p)
    p.write_text("Hero\teroe\nhero\teroina\n", encoding="utf-8")
    with pytest.raises(ValueError, match="twice"):
        tl.read_glossary(p)


def test_committed_allowlist_and_glossary_load(root: Path):
    assert align.load_allowlist((root / tl.ALLOWLIST).read_text(encoding="utf-8"))
    assert tl.read_glossary(root / tl.GLOSSARY)


TITLES = {"captain", "king", "kingdom", "his", "majesty", "guard", "light", "warrior"}


@pytest.mark.parametrize(
    ("en", "names"),
    [
        # a title or common noun used alone is translated …
        ("Talk with the Captain, for the Kingdom and His Majesty.", []),
        ("And the Guard no longer protects Darkshire?", ["Darkshire"]),
        # … but directly before a capitalised name it is part of the name
        ("Ask the Captain, then find Captain Althea and King Magni.", ["Captain", "Althea", "King", "Magni"]),
        ("Slay the Murloc Warriors near the Kingdom.", ["Murloc", "Warriors"]),
        # a word after a quote, a dash, `<`, `>` or `)` starts a sentence
        ("Ugh, the-- Well, no matter, no matter!", []),
        ("(Sniff, sniff) You smell that?", []),
        ('He wrote, "Chained Beneath the Land."', ["Beneath", "Land"]),
        # a stage direction is not read
        ("<Sob> Oh please, don't look at me!", []),
        ("<You are well versed in the creation of this robot.>", []),
        ("Hi. <Thrall nods> Go now, Varian.", ["Varian"]),
        # a hyphenated word led by a glossary word
        ("We will fight those Light-burning troggs.", []),
    ],
)
def test_english_names_titles_sentence_starts_and_stage_directions(en, names):
    assert tl.english_names(en, TITLES) == names


def test_a_glossary_word_before_another_glossary_word_stays_exempt():
    assert tl.english_names("Ask the Night Elf Druids in Stormwind.", {"night", "elf", "druid"}) == ["Stormwind"]


@pytest.mark.parametrize(
    ("en", "ja", "ok"),
    [
        ("...", "……", True),
        ("...", "...", True),
        ("…", "……", True),
        ("Hello...", "……", False),
        ("...", "Hello", True),  # a word for a dotted line is a (free) translation, not the English left in place
    ],
)
def test_a_dots_only_line_may_stay_dots(en, ja, ok):
    assert ("not_italian" not in _check(en, ja, kind="gossip")) is ok


def test_a_required_class_word_kept_in_english_letters_passes():
    required = {"warrior": "guerriero | guerrieri", "mage": "mago | maghi"}
    exempt = {"warrior", "mage"}
    en = "Return once you have slain 8 Skeletal Warriors and 6 Skeletal Mages."
    kept = "torna dopo aver ucciso 8 Skeletal Warrior e 6 Skeletal Mage."
    assert tl.check_row(_row(en), kept, set(), exempt, required) == []
    dropped = "torna dopo aver ucciso 8 scheletri e 6 stregoni."
    reasons = tl.check_row(_row(en), dropped, set(), exempt, required)
    assert "glossary:warrior" in reasons and "glossary:mage" in reasons and "name_missing:Skeletal" in reasons


@pytest.mark.parametrize(
    ("ja", "reason"),
    [
        ("Vai dal tuo maestro/padrone.", "slash:maestro/padrone"),  # the words around the slash
        ("Vai dal tuo maestro / padrone.", "slash:maestro/padrone"),
        ("Vai dal tuo amico/amica.", "slash:amico/amica"),
    ],
)
def test_a_slash_between_words_fails(ja, reason):
    assert reason in _check("Go see your master.", ja)


@pytest.mark.parametrize("ja", ["Prendine 1/2.", "vai a Stormwind/Ironforge.", "Vai dal tuo maestro.",
                                "Vai da <lui/lei>, sei <pronto/pronta>."])
def test_a_slash_not_between_words_passes(ja):
    assert not any(r.startswith("slash:") for r in _check("Go see your master.", ja))


@pytest.mark.parametrize(
    "en",
    [
        "Hello, $Gsir:madam;.",
        "$G Sir : Ma'am;, yes $g sir : ma'am;! Private Porter reporting.",
        "Be advised, $g Jackson : Princess; - I am in no mood.",
    ],
)
def test_gender_code_words_are_not_names(en):
    names = tl.english_names(en, set())
    assert not {"Gsir", "Sir", "Ma'am", "Jackson", "Princess"} & set(names)


def test_a_gender_code_drafted_neutral_passes_and_kept_english_fails():
    en = "$G Sir : Ma'am;, yes $g sir : ma'am;! Private Porter reporting."
    assert _check(en, "parola, testo, cosa! Private Porter, frase,") == []
    assert "alignment_failed:Sir" in _check(en, "parola,Sir, testo! Private Porter, cosa,")


@pytest.mark.parametrize(
    ("en", "names"),
    [
        ("There be shadows on the perches of Orgrimmar--somethin' must hide there.", ["Orgrimmar"]),
        ("Don't tell Elling--he'd never let me hear the end of it.", ["Elling"]),
        ("We sailed to Ratchet \u2014 the bay was closed.", ["Ratchet"]),
        ("We sailed to Ratchet–the bay was closed.", ["Ratchet"]),
    ],
)
def test_a_double_dash_ends_a_name(en, names):
    assert tl.english_names(en, set()) == names


def test_a_name_before_a_double_dash_kept_passes():
    en = "There be shadows on the perches of Orgrimmar--somethin' must hide there."
    assert _check(en, "ecco Orgrimmar parola …… testo,") == []


def test_an_upper_case_counter_is_a_counter():
    en = "Number of necropolises remaining: $2283W"
    assert _check(en, "parola: $2283W") == []
    assert "counters:$2283W×1→none" in _check(en, "parola: 2283")


@pytest.mark.parametrize(
    ("en", "names"),
    [
        ("Tell Malin'll be there soon, will you?", ["Malin"]),
        ("Ask whether Elling'd help us.", ["Elling"]),
        ("Speak to Kazzak's guard.", ["Kazzak"]),
    ],
)
def test_contractions_are_dropped_from_names(en, names):
    assert tl.english_names(en, set()) == names


def test_committed_glossary_titles_translate_alone_and_stay_english_before_a_name(root: Path):
    glossary = tl.exempt_words(tl.read_glossary(root / tl.GLOSSARY))
    en = "Go to the Inn and tell the Warchief, the Lady and the Stable Master that Highlord Bolvar is here."
    assert tl.english_names(en, glossary) == ["Highlord", "Bolvar"]
    en = "Serve the Dark Lady, then rest at the Lion's Pride Inn or The Inn in town."
    assert tl.english_names(en, glossary) == ["Dark", "Lady", "Lion", "Pride", "Inn"]
    assert tl.english_names("Speak with Colonel Kurzen, then the Professor.", glossary) == ["Colonel", "Kurzen"]



def test_committed_glossary_trainers_arch_druid_and_creators(root: Path):
    """A trainer keeps the skill name and translates the role; `the Arch Druid` and
    `the Creators` alone are translated; `Arch Druid` before a name stays English with it."""
    glossary = tl.exempt_words(tl.read_glossary(root / tl.GLOSSARY))
    assert tl.english_names("There's a Skinning Trainer in Orgrimmar.", glossary) == ["Skinning", "Orgrimmar"]
    assert tl.english_names("Ask the First Aid Trainer.", glossary) == ["First", "Aid"]
    assert tl.english_names("Train with the Hunter Trainer.", glossary) == []
    en = "The Arch Druid wants twenty, and Arch Druid Hamuul agrees."
    assert tl.english_names(en, glossary) == ["Arch", "Druid", "Hamuul"]
    assert tl.english_names("This is where the Creators worked.", glossary) == []


@pytest.mark.parametrize(
    ("en", "ja", "reasons"),
    [
        ("There's a Skinning Trainer in Orgrimmar.", "ecco Orgrimmar parola Skinning testo,", []),
        ("There's a Skinning Trainer in Orgrimmar.", "ecco Orgrimmar parola,", ["name_missing:Skinning"]),
        ("The Arch Druid is always watching.", "L'arcidruido osserva sempre.", []),
        ("Speak with Arch Druid Hamuul.", "parla con Arch Druid Hamuul.", []),
        ("Speak with Arch Druid Hamuul.", "parla con l'arcidruido Hamuul.", ["name_missing:Arch", "name_missing:Druid"]),
        ("The Creators shaped this world.", "parola,", []),
    ],
)
def test_committed_glossary_trainer_arch_druid_creators_drafts(root: Path, en, ja, reasons):
    path = root / tl.GLOSSARY
    got = tl.check_row(_row(en), ja, set(), tl.exempt_words(tl.read_glossary(path)), tl.read_required(path))
    assert got == reasons


@pytest.mark.parametrize(
    ("en", "ja", "reasons"),
    [
        ("You've come to the Temple seeking our aid.", "parola,", []),
        ("At ease, Private. Unload the soil.", "parola, testo, cosa,", []),
        ("I'm a Commendation Officer acting on behalf of Darnassus.", "parola Darnassus testo,", []),
        ("Even the Queen...", "parola ……", []),
        ("Speak with Commander Althea.", "parola Althea testo,", ["name_missing:Commander"]),
        ("The Holy Light shines upon you.", "parola,", []),
        ("There is a mailbox outside of the Bank in Darnassus.", "ecco Darnassus parola,", []),
    ],
)
def test_committed_glossary_lone_titles_and_nouns(root: Path, en, ja, reasons):
    """Lone titles and nouns (`the Temple`, `Private`, `Commendation Officer`,
    `the Queen`, `the Holy Light`, `the Bank`) are translated; before a name they stay English with it."""
    path = root / tl.GLOSSARY
    got = tl.check_row(_row(en), ja, set(), tl.exempt_words(tl.read_glossary(path)), tl.read_required(path))
    assert got == reasons


@pytest.mark.parametrize(
    ("en", "ja", "reasons"),
    [
        ("Report to the Temple of the Moon.", "ecco Temple of the Moon parola,", []),
        ("Report to the Temple of the Moon.", "parola,", ["name_missing:Temple", "name_missing:Moon"]),
        ("Look for the Bank of Orgrimmar.", "ecco Bank of Orgrimmar parola,", []),
        ("Look for the Bank of Orgrimmar.", "ecco Orgrimmar parola,", ["name_missing:Bank"]),
        ("We of the Brotherhood of the Light.", "parola Brotherhood of the Light,", []),
        ("We of the Brotherhood of the Light.", "parola Brotherhood of the testo,", ["name_missing:Light"]),
        ("Serve the King of Stormwind.", "ecco Stormwind parola,", []),
        ("Ask the Queen of the Dragons.", "ecco Dragons parola,", []),
        ("The Temple is quiet.", "parola,", []),
        ("Beware the Duke of Shards!", "ecco Duke of Shards parola!", []),
        ("Beware the Duke of Shards!", "ecco Shards parola!", ["name_missing:Duke"]),
    ],
)
def test_committed_glossary_of_names(root: Path, en, ja, reasons):
    """A place or group word with `of (the)` and a capitalised word is one name; a person
    title with `of` stays translatable; `Duke of Shards` is a fixed name."""
    path = root / tl.GLOSSARY
    got = tl.check_row(_row(en), ja, set(), tl.exempt_words(tl.read_glossary(path)), tl.read_required(path))
    assert got == reasons


@pytest.mark.parametrize(
    ("en", "names"),
    [
        # a word that starts a sentence is capitalised because it starts one: no name, and no name for the
        # glossary word after it either
        ("Er... that's how I found them. Say Captain... I overheard you!", []),
        ("Our Alchemist's name is Carolai Anise.", ["Carolai", "Anise"]),
        ("Six Lieutenants control the front line.", []),
        # a profession name there is still checked: it stays in English letters
        ("Tailoring you say? Head to Thunder Bluff.", ["Tailoring", "Thunder", "Bluff"]),
        # a glossary word there is still checked: it leads a name
        ("Captain Althea rides at dawn.", ["Captain", "Althea"]),
        ("Captain, the ship is lost.", []),
        # a name that starts a sentence still leads the name after it
        ("Dark Lady Sylvanas commands us.", ["Lady", "Sylvanas"]),
    ],
)
def test_a_sentence_start_word_is_no_name_but_glossary_and_skill_words_are_checked(root: Path, en, names):
    """`Say Captain` is the Captain, not a name; `Tailoring you say?` keeps
    the skill name in English letters."""
    glossary = tl.exempt_words(tl.read_glossary(root / tl.GLOSSARY))
    assert tl.english_names(en, glossary) == names


@pytest.mark.parametrize(
    ("en", "ja", "reasons"),
    [
        ("Say Captain... I overheard you!", "parola …… testo!", []),
        ("Our Alchemist's name is Carolai Anise.", "parola Carolai Anise testo,", []),
        ("Tailoring you say? Head north.", "ecco Tailoring parola? testo,", []),
        ("Tailoring you say? Head north.", "parola? testo,", ["name_missing:Tailoring"]),
        ("The Ambassador is waiting.", "parola,", []),
        ("Speak with Ambassador Malcin.", "ecco Ambassador Malcin parola,", []),
        ("Speak with Ambassador Malcin.", "parola Malcin testo,", ["name_missing:Ambassador"]),
        ("Father, forgive me.", "parola, testo,", []),
        ("The Templar guards the shrine.", "parola,", []),
        ("Tell the Grunt to report.", "parola,", []),
        ("The Blacksmith and the Tradesman are inside.", "parola,", []),
        ("The Earthshaper knows.", "parola,", []),
        ("Meet me at the Auction House in Ironforge.", "ecco Ironforge parola,", []),
    ],
)
def test_committed_glossary_ranks_and_trades(root: Path, en, ja, reasons):
    """Ambassador, father, templar, grunt, blacksmith, tradesman,
    earthshaper and auction house are translated on their own; before a name they stay English with it."""
    path = root / tl.GLOSSARY
    got = tl.check_row(_row(en), ja, set(), tl.exempt_words(tl.read_glossary(path)), tl.read_required(path))
    assert got == reasons


@pytest.mark.parametrize(
    ("en", "names"),
    [
        # a single hyphen ends a word, like `--`
        ("The Scourge-driven ghouls came.", ["Scourge"]),
        ("He was an A-number-one fisherman.", []),
        ("We will fight those Light-burning troggs.", []),
        ("Ask Thauris-something about it.", ["Thauris"]),
        # a `*…*` stage direction is not read, and the word after it starts a sentence
        ("*cough* You don't have that stranglekelp?", []),
        ("Bad urges... *Fizzule slaps himself* Not yet... Listen.", []),
        ("Tell *Renee* the news.", []),
    ],
)
def test_hyphens_split_and_star_stage_directions(en, names):
    assert tl.english_names(en, {"light"}) == names


@pytest.mark.parametrize(
    ("en", "ja", "reasons"),
    [
        ("The Scourge-driven ghouls came.", "ecco Scourge parola ghoul testo,", []),
        ("He was an A-number-one fisherman.", "parola,", []),
        ("*cough* You don't have it?", "* parola * testo?", []),
        ("The contest is this Sunday.", "parola,", []),
        ("Come back on Friday.", "parola,", []),
    ],
)
def test_committed_glossary_hyphens_stage_directions_and_weekdays(root: Path, en, ja, reasons):
    """A hyphen ends a word, `*…*` is a stage direction, and a day of the
    week is translated."""
    path = root / tl.GLOSSARY
    got = tl.check_row(_row(en), ja, set(), tl.exempt_words(tl.read_glossary(path)), tl.read_required(path))
    assert got == reasons


# ── book pages ─────────────────────────────────────────────────────────────

HTML_EN = '<HTML>\n<BODY>\n<BR/>\n<H1 align="center">\nKurdran Wildhammer\n</H1>\n<P>\nHe rode the winds.\n</P>\n</BODY>\n</HTML>'
HTML_JA = '<HTML>\n<BODY>\n<BR/>\n<H1 align="center">\nKurdran Wildhammer\n</H1>\n<P>\n parola,\n</P>\n</BODY>\n</HTML>'


def _book(en, ja, kind="book"):
    return tl.check_row({"ref": "r", "kind": kind, "en": en, "targets": [[1, "text"]]}, ja, ALLOW, GLOSSARY)


def test_a_book_name_in_katakana_fails_the_name_guard():
    en = "Famed dragonslayer. Leader of the gryphon riders, Kurdran rode for the Alliance."
    assert "name_missing:Kurdran" in _book(en, "parola, testo, cosa Alliance frase,")
    assert "name_missing:Alliance" in _book(en, "parola, testo,Kurdran cosa,")
    assert _book(en, "parola, testo,Kurdran cosa Alliance frase,") == []


def test_a_short_book_row_gets_every_reason():
    assert "not_italian" in _book("Welcome!", "Welcome!")
    assert _book("Welcome!", "parola!") == []


def test_an_html_page_keeping_every_tag_passes_with_no_tag_reasons():
    assert _book(HTML_EN, HTML_JA) == []


@pytest.mark.parametrize(
    ("ja", "reason"),
    [
        (HTML_JA.replace("<BR/>\n", ""), "markup_changed:tag 3: en <BR /> ja <H1 align=\"center\">"),
        (HTML_JA.replace("<P>\n parola,\n</P>", "parola,"), "markup_changed:tag 6: en <P> ja </BODY>"),
        (HTML_JA.replace("</BODY>", "<BR/>\n</BODY>"), "markup_changed:tag 8: en </BODY> ja <BR />"),
        (HTML_JA.replace('<H1 align="center">', '<H1 align="left">'), "markup_changed:tag 4"),
    ],
)
def test_an_html_page_that_changes_its_tags_fails(ja, reason):
    reasons = _book(HTML_EN, ja)
    assert any(r.startswith(reason) for r in reasons), reasons


def test_markup_changed_never_applies_to_plain_text():
    # a plain page's bracketed prose is not markup (ADR-022)
    assert not any(r.startswith("markup_changed") for r in _book("A <illegible text> note.", "parola,"))
    assert not any(r.startswith("markup_changed") for r in _check("<P>Hi</P> there.", "parola,"))


def test_a_space_only_line_is_one_break_on_both_sides():
    # book pages carry "\n \n"; the English and the Japanese count it the same way
    # `lint` canonicalises the draft's breaks before checking it
    assert _book("One.\n \nTwo.", tl.paragraphs.normalize_breaks("parola,\n \n testo,")) == []
    assert _book("One.\n \nTwo.", "parola,\n\n testo,") == []
    assert "paragraphs:1/2" in _book("One.\n \nTwo.", "parola, testo,")


def test_a_word_after_a_carriage_return_line_break_starts_a_sentence():
    # book pages break lines with "\n\r"
    assert tl.english_names("Day one.\n\rWe marched north.\n\rThe Gem shone.", set()) == ["Gem"]


def test_a_listed_not_name_passes_on_its_row_only(tmp_path):
    # a capitalised common word in a heading, reviewed and listed for one row
    en = "Chapter 3 - The Four Commanders\n\nThe Horde marched."
    ja = "parola 3 testo - cosa \n\nHorde frase,"
    assert "name_missing:Commanders" in _book(en, ja)
    listed = tl.check_row({"ref": "r", "kind": "book", "en": en, "targets": [[1, "text"]]}, ja, ALLOW, GLOSSARY,
                          None, {"Four", "Commanders"})
    assert listed == []
    path = tmp_path / "not_names.tsv"
    path.write_text("# comment\n0123456789\tFour\tChapter 3 - The Four Commanders\n"
                    "0123456789\tCommanders\tChapter 3 - The Four Commanders\n", encoding="utf-8")
    not_names = tl.read_not_names(path)
    assert not_names == {"0123456789": {"Four", "Commanders"}}
    b, d = _files(tmp_path, [{"ref": "0123456789", "kind": "book", "en": en, "targets": [[1, "text"]]},
                             {"ref": "abcdefabcd", "kind": "book", "en": en, "targets": [[2, "text"]]}],
                  [{"ref": "0123456789", "ja": ja}, {"ref": "abcdefabcd", "ja": ja}])
    ok, failures = tl.lint(b, d, ALLOW, GLOSSARY, None, not_names)
    assert [r["ref"] for r in ok] == ["0123456789"]
    assert "name_missing:Commanders" in failures["abcdefabcd"]  # another row with the same words is still checked


def test_read_not_names_rejects_bad_lines_and_allows_a_missing_file(tmp_path):
    assert tl.read_not_names(tmp_path / "none.tsv") == {}
    path = tmp_path / "bad.tsv"
    for bad in ("0123456789\tFour\n", "XYZ\tFour\tline\n", "0123456789\t \tline\n"):
        path.write_text(bad, encoding="utf-8")
        with pytest.raises(ValueError, match="need"):
            tl.read_not_names(path)


def test_committed_not_names_list_loads(root: Path):
    tl.read_not_names(root / tl.NOT_NAMES)


# A client-template kind. `$N<k>` is the addon's value placeholder and must pass; a baked literal
# number must not, because the template holds `$s1`, not the value, and a baked line stops shipping the
# moment the client's value differs.
def _tooltip(en, kind="item_description"):
    return {"ref": "r1", "kind": kind, "en": en, "targets": [[117, "description"]]}


def _reasons(row, ja):
    return tl.check_row(row, ja, ALLOW, GLOSSARY)


def test_the_value_placeholder_passes_but_a_baked_number_does_not():
    # the `en` a batch row carries is `model_english`, which collapses the English's double spaces.
    # The duration takes `$D1` rather than `$N2` plus a unit: `test_a_duration_must_be_carried_as_a_
    # placeholder_not_a_named_unit` is why.
    row = _tooltip("Restores $o1 health over $d. Must remain seated while eating.")
    assert _reasons(row, "$D1 parola $N1 testo, cosa,") == []
    baked = _reasons(row, "18 parola 61 testo, cosa,")
    assert any(r.startswith("numbers_changed:") for r in baked), baked


def test_any_other_dollar_code_left_in_a_draft_still_fails():
    row = _tooltip("Restores $o1 health over $d.")
    assert "leftover:$o" in _reasons(row, "$d parola $o1 testo,")
    assert "leftover:$B" in _reasons(row, "$D1 parola $N1 testo,$B")


def test_a_placeholder_past_the_templates_slots_is_refused():
    """`Align.fill` is closed-ended: one unfillable `$N<k>` drops the whole line back to English."""
    row = _tooltip("Restores $s1 health.")
    assert _reasons(row, "parola $N1 testo,") == []
    assert "value_index:2>1" in _reasons(row, "$N2 parola $N1 testo,")
    assert "value_index:3,4>1" in _reasons(row, "parola $N1,$N3,$N4 testo,")


def test_the_index_is_not_checked_when_the_template_makes_it_unknowable():
    """A conditional's slot count is verified in game, not guessed at here. `translate_batch`
    leaves these rows out of a batch entirely; the lint stays permissive in case one is drafted by hand."""
    row = _tooltip("Absorbs $s1$?a1[ and $s2 more][]. Lasts $d.", kind="spell_description")
    assert not [r for r in _reasons(row, "$N5 parola $N9 testo,") if r.startswith("value_index")]
    # arithmetic IS counted now, so an index past it is caught
    sums = _tooltip("Deals ${$m1*2} damage over $d.", kind="spell_description")
    assert "value_index:9>2" in _reasons(sums, "$D1 parola $N9 testo,")


def test_a_literal_the_template_shows_may_be_written_as_a_literal():
    row = _tooltip("Teaches Frost Ward (Rank 5).")
    assert _reasons(row, "ecco Frost Ward(Rank 5) parola,") == []
    wrong = _reasons(row, "ecco Frost Ward(Rank 6) parola,")
    assert any(r.startswith("numbers_changed:") for r in wrong), wrong
    # Under today's glossary "Rank" is a capitalised word inside an English sentence, so it must stay in
    # English letters. Whether a tooltip word like this should instead be translated (`ランク`) is a style
    # decision the tooltip kinds still need; recorded here so a change of mind is a visible test change.
    assert "name_missing:Rank" in _reasons(row, "ecco Frost Ward( parola 5) testo,")


def test_a_duration_must_be_carried_as_a_placeholder_not_a_named_unit():
    """The unit is the client's choice, and `Align.check` cannot catch a wrong one; this is the only gate."""
    row = _tooltip("Restores $o1 health over $d. Must remain seated while eating.")
    good = "$D1 parola $N1 testo, cosa,"
    assert _reasons(row, good) == []
    # a bare number with a unit written by hand: right in seconds, wrong the moment the client says minutes
    named = _reasons(row, "$N2 parola $N1 testo, cosa,")
    assert "duration_missing:D1" in named
    # baking both the number and the unit fails twice over
    baked = _reasons(row, "18 parola 61 testo, cosa,")
    assert "duration_missing:D1" in baked
    assert any(r.startswith("numbers_changed:") for r in baked)


def test_every_duration_of_a_template_needs_its_own_placeholder():
    row = _tooltip("Stuns for $d and slows for $d1.", kind="spell_description")
    assert _reasons(row, "$D1 parola,$D2 testo,") == []
    assert "duration_missing:D2" in _reasons(row, "$D1 parola, testo,")
    assert "duration_index:3>2" in _reasons(row, "$D1 parola,$D3 testo,")


def test_a_template_with_no_duration_needs_no_placeholder():
    row = _tooltip("Restores $s1 health.")
    assert _reasons(row, "parola $N1 testo,") == []
    assert not [r for r in _reasons(row, "parola $N1 testo,") if r.startswith("duration")]


def test_the_duration_rule_is_skipped_when_the_template_is_uncountable():
    row = _tooltip("Absorbs $s1$?a1[ more][]. Lasts $d.", kind="spell_description")
    assert not [r for r in _reasons(row, "$N1 parola,") if r.startswith("duration")]
    # but a countable template with arithmetic still needs its duration carried
    sums = _tooltip("Deals ${$m1*2} damage over $d.", kind="spell_description")
    assert "duration_missing:D1" in _reasons(sums, "$N1 parola,")


def test_a_client_templates_arithmetic_is_not_a_player_token():
    """`${$m1/60}` is Blizzard arithmetic. Its inner braces looked like a `{name}`-style token, so the
    lint demanded the Japanese copy it through, which the leftover rule then refused. Neither is right: the
    sum is a value the client computes, and `$N<k>` carries its result."""
    row = _tooltip("Coats a weapon with poison that lasts for ${$m1/60} minutes.", kind="spell_description")
    assert _reasons(row, "$N1 parola, testo,") == []
    two = _tooltip("Causes ${$m2*$<dmg>} to ${$M2*$<dmg>} Frost damage.", kind="spell_description")
    # a range is one value the addon fills as `14～22`, so `$N1～$N2` points past it
    assert _reasons(two, "$N1 parola Frost testo,") == []
    assert "value_index:2>1" in _reasons(two, "$N1-$N2 parola Frost testo,")
    # copying the sum in is still refused, from the other side
    assert any(r.startswith("leftover:") for r in _reasons(row, "${$m1/60} parola, testo,"))
    # a real player token is still required (a row's `en` carries it normalized, as `{name}`)
    named = _tooltip("Greetings {name}, this deals $s1 damage.", kind="spell_description")
    assert any(r.startswith("tokens:") for r in _reasons(named, "$N1 parola,"))
    assert _reasons(named, "{name} parola,$N1 testo,") == []


def test_a_conditionals_bracketed_prose_starts_a_sentence():
    """`$?j1g[Increases ground speed by $j1g%. ][]`: the prose inside the brackets starts a
    sentence, so `Increases` is a verb and not a name the Japanese must keep in English letters."""
    row = _tooltip("$?j1g[Increases ground speed by $j1g%. ][]", kind="spell_aura")
    assert _reasons(row, "parola $N1% testo,") == []


def test_a_code_before_a_word_does_not_make_it_a_sentence_start():
    """The narrow half of the same rule: a name after a value code is still a name."""
    row = _tooltip("Deals $s1 Frostbolt damage.", kind="spell_description")
    assert "name_missing:Frostbolt" in _reasons(row, "$N1 parola,")
    assert _reasons(row, "$N1 parola Frostbolt testo,") == []


def test_a_plural_codes_word_is_not_a_name():
    """`$LFire:Fires;` prints "Fire" or "Fires", the client's choice, not a name the Japanese must
    keep in English letters. Without stripping it, `LFire` reads as a capitalised word and every
    `$L<Capitalised>:…;` row fails `name_missing` for good."""
    row = _tooltip("Transmutes a Heart of Fire into $s1 Elemental $LFire:Fires;.", kind="spell_description")
    assert _reasons(row, "ecco Heart of Fire parola Elemental Fire $N1 testo,") == []
    # a real name in the same line is still required
    assert "name_missing:Heart" in _reasons(row, "parola Elemental Fire $N1 testo,")


def test_the_home_location_code_is_not_a_value_slot():
    """`$z` prints the player's home town, not a number, so a `$N<k>` aimed at it would never fill and the
    whole line would drop back to English (`Align.fill` is closed-ended)."""
    from wfi.core import align

    # single-spaced, as `model_english` gives it to a drafter
    en = "Returns you to $z. Speak to an Innkeeper in a different place to change your home location."
    assert align.value_slots(en) == 0
    assert align.duration_slots(en) == 0
    row = _tooltip(en)
    assert _reasons(row, "parola, testo Innkeeper cosa,") == []
    assert "value_index:1>0" in _reasons(row, "$N1 parola, testo Innkeeper cosa,")


def test_a_placeholder_with_english_glued_to_it_is_refused():
    """`$N1c1` and `$N2roccooldown`: a drafter gluing a fragment of the English source onto a
    placeholder. The value fills and the fragment stays on screen, and the name check cannot catch it: a
    fragment of the English IS present in the English, so it is vouched for. Seen 7 times in one batch."""
    row = _tooltip("Permanently enchant a head slot item to increase Attack Power by $s1.",
                   kind="spell_description")
    assert "placeholder_run:$N1c1" in _reasons(row, "ecco Attack Power parola $N1c1 testo,")
    assert _reasons(row, "ecco Attack Power parola $N1 testo,") == []
    proc = _tooltip("Restores $s1 mana. This effect cannot occur more than once every $proccooldown sec.",
                    kind="spell_description")
    bad = _reasons(proc, "parola $N1 testo,$N2roccooldown cosa,")
    assert "placeholder_run:$N2roccooldown" in bad
    # a placeholder ending at its digits is fine, next to Japanese or punctuation
    assert _reasons(proc, "parola $N1 testo,$N2 cosa,") == []


def test_the_precision_digit_cannot_vouch_for_a_number_in_the_japanese():
    """The `.1` of `${$s1}.1%` is never printed, so a Japanese line stating its own decimal is wrong even
    though the digit appears in the template."""
    row = _tooltip("Improves your chance to get a critical strike with spells by ${$s1}.1%.",
                   kind="spell_description")
    assert _reasons(row, "parola $N1% testo,") == []
    assert "numbers_changed:1" in _reasons(row, "parola $N1.1% testo,")
    assert "value_index:2>1" in _reasons(row, "parola $N1.$N2% testo,")


def test_newlines_inside_arithmetic_are_not_paragraphs():
    """`${$m1+\n$m2}` holds a newline inside a code the client computes, not a paragraph break the
    Japanese must mirror. Five rows in one batch could only have passed by adding blank lines to the
    Japanese that the player never sees."""
    row = _tooltip("Absorbs ${$m1+\n$m2+\n$m3} damage.", kind="spell_description")
    assert _reasons(row, "$N1 parola,") == []


def test_a_tooltips_cross_spell_code_is_not_a_quest_counter():
    """`$1310167w2` starts like a quest's server counter `$1997w` but is a value code. Requiring it to be
    copied through would have put the raw code on screen."""
    row = _tooltip("Suffering $1310167w2 damage every $t1 sec.", kind="spell_aura")
    assert not [r for r in _reasons(row, "$N2 parola $N1 testo,") if r.startswith("counters")]
    # a real quest counter is still required, in its own kind
    quest = {"ref": "r", "kind": "completion", "en": "You have $1997w left.", "targets": [[1, "completion"]]}
    assert any(r.startswith("counters") for r in _reasons(quest, "parola,"))


def test_a_quest_title_is_not_checked_for_names():
    """A title is written in title case, so capitalisation says nothing about which word is a name.
    On the first batch the check flagged 157 of 256 rows ("Needs", "Price", "Flame"); none of them names.
    Names still stay in English; the style guide's Quests section says so."""
    title = {"ref": "r", "kind": "quest_title", "en": "The Alliance Needs Copper Bars",
             "targets": [[1, "title"]]}
    assert _reasons(title, "ecco Alliance parola Copper Bar testo") == []
    # every other quest kind is still checked
    objectives = {"ref": "r", "kind": "quest_objectives", "en": "Bring 6 Copper Bars to Vrang.",
                  "targets": [[1, "objectives"]]}
    assert "name_missing:Vrang" in _reasons(objectives, "parola 6 testo,")
    desc = {"ref": "r", "kind": "quest_description", "en": "Go and speak to Vrang for me.",
            "targets": [[1, "description"]]}
    assert "name_missing:Vrang" in _reasons(desc, "parola,")


def test_a_value_the_client_fills_in_cannot_be_dropped():
    """149 crafting-writ rows passed every other check while leaving out the count they ask for.
    Nothing else catches that: a line that simply does not mention a number has no wrong number in it."""
    writ = {"ref": "r", "kind": "quest_description",
            "en": "The note is requesting $2oa Elixir of Ogre's Strength.", "targets": [[1, "description"]]}
    assert "slot_missing:N1" in _reasons(writ, "parola Elixir of Ogre's Strength testo,")
    assert _reasons(writ, "parola Elixir of Ogre's Strength testo $N1 cosa,") == []


def test_a_literal_the_english_shows_may_be_written_out_instead():
    """Only a value the client fills in needs a placeholder. A number already in the English may be copied."""
    row = {"ref": "r", "kind": "quest_objectives", "en": "Kill 7 Young Nightsabers.",
           "targets": [[1, "objectives"]]}
    assert _reasons(row, "ecco Young Nightsaber parola 7 testo,") == []
    assert _reasons(row, "ecco Young Nightsaber parola $N1 testo,") == []


def test_values_and_durations_are_counted_in_their_own_namespaces():
    """`$N1` and `$D1` are two carried slots, not one; counting them as a set of indices collapsed them and
    flagged 284 correct rows in one batch."""
    row = _tooltip("Increases resistance to Shadow spells by $s1 for $d.", kind="spell_description")
    assert _reasons(row, "$D1 parola,Shadow testo $N1 cosa,") == []
    assert "duration_missing:D1" in _reasons(row, "ecco Shadow parola $N1 testo,")


def test_a_title_keeps_the_names_cut_found():
    """`The Gift of Skysight` shipped as ` parola ` while titles skipped the name check."""
    row = {"ref": "r", "kind": "quest_title", "en": "Aetheen of the Gales", "targets": [[1, "title"]],
           "names": ["Aetheen", "Gales"]}
    assert "name_missing:Gales" in _reasons(row, "parola Aetheen")
    assert not [r for r in _reasons(row, "Aetheen of the Gales") if r.startswith("name_missing")]


def test_a_name_list_tail_is_one_trailing_marker():
    # Languages translates its head and ends in `$T`; the chain is never written out
    en = "You are fluent in the following languages:$?s668[\r\n$@spellname668][]$?s669[\r\n$@spellname669][]"
    assert _check(en, "parola:$T", kind="spell_description") == []
    assert "tail_missing" in _check(en, "parola:", kind="spell_description")
    assert "tail_misplaced" in _check(en, "$T parola:", kind="spell_description")
    assert "tail_unexpected" in _check("Deals $s1 damage.", "$N1 parola,$T", kind="spell_description")


def test_an_npc_emote_keeps_the_speakers_name_slot():
    """An emote's `%s` is the speaker's name the client fills in; a Japanese without it (or with a stray
    `%`, which the client's format() would read as a specifier) is refused."""
    row = {"ref": "r", "kind": "gossip", "en": "%s goes into a frenzy!", "targets": [["r", "text"]]}
    assert not [r for r in _reasons(row, "%s parola!") if r.startswith("speaker")]
    assert "speaker:1→0" in _reasons(row, "parola!")
    assert "speaker:1→1" in _reasons(row, "%s parola 100% testo!")


def test_a_title_word_before_a_name_stays_english_in_a_quest_title():
    """ecco In a title-case quest title a glossary title directly before a listed name is part of the name
("Baron Aquanis"), so translating it ( parola Aquanis) fails, as the prose check already does; the title used
on its own is still translated."""
    row = {"ref": "r1", "kind": "quest_title", "en": "Baron Aquanis", "targets": [[1, "title"]], "names": ["Aquanis"]}
    assert tl.check_row(row, "parola Aquanis", set(), {"baron"}) == ["name_missing:Baron"]
    assert tl.check_row(row, "Baron Aquanis", set(), {"baron"}) == []
    alone = {"ref": "r2", "kind": "quest_title", "en": "The Baron's Demise", "targets": [[2, "title"]], "names": []}
    assert tl.check_row(alone, "parola", set(), {"baron"}) == []


def test_a_title_word_check_ignores_numerals_and_needs_the_whole_word():
    """`Volume II` is a numeral, not a name a title word belongs to; ` parola Lordaeron` does not keep
the word `Lord` just because `lordaeron` starts with it."""
    vol = {"ref": "r3", "kind": "quest_title", "en": "Lord II", "targets": [[3, "title"]], "names": ["II"]}
    assert tl.check_row(vol, "parola II", set(), {"lord"}) == []
    lord = {"ref": "r4", "kind": "quest_title", "en": "Lord Lordaeron", "targets": [[4, "title"]],
            "names": ["Lordaeron"]}
    assert tl.check_row(lord, "parola Lordaeron", set(), {"lord"}) == ["name_missing:Lord"]


# ── no word readings in this project ─────────────────────────


def test_a_draft_row_carrying_words_fails(tmp_path):
    b, d = _files(tmp_path, [_row("Guard the forest.", ref="a")],
                  [{"ref": "a", "ja": "Sorveglia la foresta.", "words": [["foresta", "x"]]}])
    ok, failures = tl.lint(b, d, ALLOW, GLOSSARY)
    assert ok == [] and failures == {"a": ["words_unexpected"]}


# branch variants and included icons (ADR-043) ---------------------------------------------------------------------------------------------

FIRE_WARD = "Absorbs $s1 Fire damage$?s11094[ and grants a $s2% chance to reflect Fire spells][]. Lasts $d."


def _branch_row(en):
    return {**_row(en, "spell_description"), "branches": 2}


def test_a_branch_row_is_checked_variant_by_variant():
    ok = "$N1 parola Fire testo $?s11094[, cosa $N2% frase Fire voce ][], parola $D1,"
    assert tl.check_row(_branch_row(FIRE_WARD), ok, ALLOW, GLOSSARY) == []
    no_clause = "$N1 parola Fire testo, cosa $D1,"
    assert tl.check_row(_branch_row(FIRE_WARD), no_clause, ALLOW, GLOSSARY) == ["branch_skeleton"]
    dropped = "$N1 parola Fire testo $?s11094[, cosa Fire frase ][], voce $D1,"
    assert tl.check_row(_branch_row(FIRE_WARD), dropped, ALLOW, GLOSSARY) == ["v1:slot_missing:N2"]


def test_branches_the_japanese_cannot_tell_apart_are_refused():
    en = "Add the sign to your $?pc923[Orcish Tradeskill Sign][Dwarven Tradeskill Sign] toy."
    named = "parola $?pc923[Orcish Tradeskill Sign][Dwarven Tradeskill Sign] testo,"
    assert tl.check_row(_branch_row(en), named, ALLOW, GLOSSARY) == []
    # the item names translated away (a lint failure on its own), and nothing left to tell the variants apart
    unnamed = "parola $?pc923[ testo ][ cosa ] frase,"
    reasons = tl.check_row(_branch_row(en), unnamed, ALLOW, GLOSSARY)
    assert "v1:name_missing:Orcish" in reasons or "branches_indistinguishable" in reasons


@pytest.mark.parametrize(("ja", "reason"), [
    ("$N1 parola,Quick Draw,", "icon_missing:1"),
    ("$I1 $I1 $N1 parola,Quick Draw,", "icon_index:1"),
    ("$I2 $N1 parola,Quick Draw,", "icon_index:2"),
])
def test_icons_are_carried_once_each(ja, reason):
    reasons = tl.check_row(_row("Gain $I1 Quick Draw: $s1 damage.", "spell_description"), ja, ALLOW, GLOSSARY)
    assert reason in reasons


def test_an_icon_placeholder_is_not_a_leftover_code():
    ja = "$I1 Quick Draw:$N1 parola,"
    assert tl.check_row(_row("Gain $I1 Quick Draw: $s1 damage.", "spell_description"), ja, ALLOW, GLOSSARY) == []


def test_a_colour_code_glued_to_a_word_is_not_part_of_a_name():
    en = "$?a768[|CFFFFFFFFRequires Cat Form|R][|CFFFF2020Requires Cat Form|R] and deals $s1 damage."
    ja = "$?a768[|CFFFFFFFF parola:Cat Form|R][|CFFFF2020 testo:Cat Form|R] $N1 cosa,"
    reasons = tl.check_row(_branch_row(en), ja, ALLOW, GLOSSARY)
    assert not [r for r in reasons if "name_missing" in r]


def test_a_name_inside_a_gender_code_may_be_kept():
    # the neutral draft of a `$g a : b;` line keeps a name from its branch; a common word still fails
    en = "$g Hey there, need a ride? : Come to the jungles of Stranglethorn with my brother Frezza!;"
    assert _check(en, "ecco Stranglethorn parola, testo Frezza cosa!") == []
    assert "alignment_failed:Hey" in _check(en, "ecco Hey,Stranglethorn parola!")


@pytest.mark.skip(reason="fase 3 (tooltip): il controllo delle parole statistiche va riscritto per l'italiano")
@pytest.mark.parametrize(
    ("en", "ja", "reason"),
    [
        ("Restores $s1 health.", "health parola $N1 testo,", "stat_word:health"),
        ("Increases Stamina by $s1.", "ecco Stamina parola $N1 testo,", "stat_word:stamina"),
        ("Restores $s1 health.", "parola $N1 testo,", "stat_word: parola"),
        ("Increases intellect by $s1 at night.", "parola, testo $N1 cosa,", "stat_word: parola"),
        ("Restores $s1 energy.", "parola $N1 testo,", "stat_word: parola"),
    ],
)
def test_a_tooltip_keeping_a_stat_word_in_english_fails(en, ja, reason):
    assert reason in _check(en, ja, kind="spell_description")


@pytest.mark.skip(reason="fase 3 (tooltip): il controllo delle parole statistiche va riscritto per l'italiano")
def test_a_tooltip_stat_word_in_japanese_passes_and_is_no_name_to_keep():
    assert _check("Increases Stamina by $s1.", "parola $N1 testo,", kind="item_description") == []
    assert _check("Increases your Spirit by $s1.", "parola $N1 testo,", kind="spell_aura") == []


@pytest.mark.skip(reason="fase 3 (tooltip): il controllo delle parole statistiche va riscritto per l'italiano")
def test_a_stat_word_inside_a_name_is_still_a_name():
    en = "Absorbs $s1 damage while your Mana Shield lasts."
    assert _check(en, "ecco Mana Shield parola,$N1 testo,", kind="spell_description") == []
    assert "name_missing:Mana" in _check(en, "parola Shield testo,$N1 cosa,",
                                         kind="spell_description")


@pytest.mark.skip(reason="fase 3 (tooltip): il controllo delle parole statistiche va riscritto per l'italiano")
def test_a_stat_word_used_both_free_and_in_a_name_is_still_a_name():
    en = "Restores $s1 Mana. Your Mana Shield absorbs $s2."
    assert "name_missing:Mana" in _check(en, "parola $N1 testo, cosa Shield frase $N2 voce,", kind="spell_description")
    assert _check(en, "parola $N1 testo,Mana Shield cosa $N2 frase,", kind="spell_description") == []


def test_a_name_wrapped_onto_the_next_line_is_still_a_name():
    en = "Absorbs $s1 damage while your Mana\nShield lasts."
    assert "name_missing:Mana" in _check(en, "ecco Mana\nShield parola,$N1 testo,".replace("Mana\nShield", "parola Shield"), kind="spell_description")


def test_a_healthstone_is_no_health_spelling():
    assert not any(r.startswith("stat_word") for r in _check("Creates a Healthstone.", "parola,", kind="spell_description"))


def test_the_stat_word_rule_is_for_tooltips_only():
    assert not any(r.startswith("stat_word") for r in _check("Take the mana potions.", "mana parola,"))


def test_a_stat_word_joined_by_of_is_still_a_name():
    en = "Drink an Elixir of Agility."
    assert "name_missing:Agility" in _check(en, "parola Elixir testo,", kind="item_description")
    assert _check(en, "ecco Elixir of Agility parola,", kind="item_description") == []


def test_a_stat_word_leading_a_capitalised_word_is_no_new_name():
    reasons = _check("Strength Increased by $s1.", "parola $N1 testo,", kind="spell_aura")
    assert "name_missing:Strength" not in reasons


def test_a_title_case_tooltip_row_is_checked_by_its_names():
    """A tooltip row without prose (`cut` marks it `title_case`) is checked like a quest title: its
    capitals say nothing, the `names` `cut` found must stay in English letters."""
    flavour = {**_tooltip("Soft Like Pudding"), "title_case": True}
    assert _reasons(flavour, "parola") == []
    named = {**_tooltip("By Hemet Nesingwary"), "title_case": True, "names": ["Hemet", "Nesingwary"]}
    assert "name_missing:Nesingwary" in _reasons(named, "parola")
    assert _reasons(named, "ecco Hemet Nesingwary parola") == []


def test_only_a_name_only_tooltip_row_may_keep_its_english():
    name = {**_tooltip("Umbrinoth"), "title_case": True, "names": ["Umbrinoth"], "name_only": True}
    assert _reasons(name, "Umbrinoth") == []
    flavour = {**_tooltip("Made With Love"), "title_case": True}
    assert _reasons(flavour, "Made With Love") == ["not_italian"]


RIDING = ("Allows you to ride basic ground mounts that require a riding skill of 75.\r\n\r\nKnown abilities:"
          "$?s824[\r\n$@spellname824][]$?s18995[\r\n$@spellname18995][]")


def test_a_tail_after_a_multi_line_head_keeps_the_heads_breaks():
    row = {**_row(RIDING, "spell_description"), "tail": True, "slots": 1}
    assert _reasons(row, "parola $N1 testo,\n\n cosa:$T") == []
    reasons = _reasons(row, "parola $N1 testo, cosa:$T")
    assert "tail_breaks" in reasons


def test_a_keyed_branch_row_passes_when_its_wordings_differ():
    en = ("$?s436895[Increases all damage you deal by $s1%.]"
          "[Increases the damage you deal with physical attacks in all forms by $s1%.]")
    ja = "$?s436895[ parola $N1% testo,][ cosa $N2% frase,]"
    assert tl.check_row(_branch_row(en), ja, ALLOW, GLOSSARY) == []
    # a wording the key cannot tell apart (a word code) is still refused
    word = "$?a1[Returns you to $z.][Returns you home.]"
    assert tl.check_row(_branch_row(word), "$?a1[$z parola,][ testo,]", ALLOW, GLOSSARY) != []
