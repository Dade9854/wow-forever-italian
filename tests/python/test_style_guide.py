"""The style guide has a version and the sections the drafting prompt points at; the glossary holds translated
words, never names, and spells races and classes the way the addon fills `{race}` / `{class}`."""

import re
from pathlib import Path

import pytest

from wfi.core import align, language
from wfi.dev import translate_lint as tl
from wfi.dev.translate_batch import STYLE_GUIDE, style_version


@pytest.fixture(scope="module")
def guide(root: Path) -> str:
    return (root / STYLE_GUIDE).read_text(encoding="utf-8")


def test_guide_has_a_version(root: Path):
    assert style_version(root) >= 1


SECTIONS = ("## Il compito", "## I nomi restano in inglese", "## Segnaposto, paragrafi e numeri",
            "## Voce e registro", "## Frasi degli NPC", "## Libri, lettere e targhe", "## Tooltip",
            "## Quest", "## Testi dell'interfaccia", "## Glossario", "## Esempi")


def test_guide_has_its_sections(guide):
    for heading in SECTIONS:
        assert f"\n{heading}" in guide, heading


def test_the_guide_explains_the_gender_pair_the_addon_expands(guide):
    assert "<pronto/pronta>" in guide and "<maschile/femminile>" in guide


# English token word → the key Core/Placeholders.lua fills `{class}` / `{race}` from
TOKEN_WORDS = {
    "warrior": "WARRIOR", "paladin": "PALADIN", "hunter": "HUNTER", "rogue": "ROGUE", "priest": "PRIEST",
    "shaman": "SHAMAN", "mage": "MAGE", "warlock": "WARLOCK", "druid": "DRUID",
    "human": "Human", "orc": "Orc", "dwarf": "Dwarf", "night elf": "NightElf", "undead": "Scourge",
    "tauren": "Tauren", "gnome": "Gnome", "troll": "Troll",
}
ADJECTIVES = {"dwarven": "dwarf", "orcish": "orc", "gnomish": "gnome"}


def _token_spellings(root: Path) -> dict[str, tuple[str, str]]:
    lua = (root / "addon/WoWForeverItalian/Core/Placeholders.lua").read_text(encoding="utf-8")
    return {k: (m, f) for k, m, f in re.findall(r'(\w+) = \{ "([^"]+)", "([^"]+)" \}', lua)}


def _forms(rendering: str) -> list[str]:
    return [f.strip() for f in rendering.split("|")]


def test_race_and_class_words_use_the_addon_token_spellings(root: Path):
    """The glossary's forms of a race or class word hold the masculine and feminine `{race}` / `{class}` give."""
    glossary, required = tl.read_glossary(root / tl.GLOSSARY), tl.read_required(root / tl.GLOSSARY)
    spelled = _token_spellings(root)
    for word, key in TOKEN_WORDS.items():
        male, female = spelled[key]
        assert word in required, word
        assert male in _forms(glossary[word]) and female in _forms(glossary[word]), word
    for adjective in ADJECTIVES:
        assert adjective in required, adjective


def test_glossary_renderings_are_single_choices(root: Path):
    """One rendering per term (its forms joined by `|`): a drafter copies a `/` pair literally (`slash`)."""
    for term, it in tl.read_glossary(root / tl.GLOSSARY).items():
        assert "/" not in it, term


def test_glossary_words_are_translated_not_names(root: Path):
    allowlist = align.load_allowlist((root / tl.ALLOWLIST).read_text(encoding="utf-8"))
    for term, it in tl.read_glossary(root / tl.GLOSSARY).items():
        assert term not in allowlist, f"{term} is an allowlisted English word"
        assert not language.has_cjk(it), term
        # a capitalised Italian rendering is one the name check would read as a name: it must be allowlisted
        # (a word glued to an accented letter, `Maestà`, is never read as one)
        for word in re.findall(r"(?<![A-Za-zÀ-ÿ])[A-Z][a-z]{2,}(?![A-Za-zÀ-ÿ])", it):
            assert word.casefold() in allowlist, f"{term}: {word} is capitalised and not allowlisted"
