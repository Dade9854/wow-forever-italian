"""Facts about the committed `data/` (the Italian translations). Every rule here holds for any store, so a
data PR keeps them; the one floor (the Northshire quests of phase 1) only ever grows."""


import re

import pytest

from wfi.core import language, paragraphs
from wfi.core.report import SHIPPED
from wfi.io.jsonl_store import Store

TYPES = ("quest", "item", "spell", "gossip", "book", "objective", "area", "ui")
DRAFT = re.compile(r"^draft-[a-z0-9-]+-sg\d+@\d{4}-\d{2}-\d{2}$")
# Northshire Valley's quests, the zone phase 1 shipped (pipeline/batches/northshire.ids)
NORTHSHIRE = (783, 7, 33, 5261, 15, 21, 18, 3903, 3904, 3905, 6, 54, 3100, 3101, 3102, 3103, 3104, 3105)


def _lines(root, type_):
    return Store(root / "data").load(type_)


@pytest.mark.parametrize("type_", TYPES)
def test_every_machine_variant_names_its_style_version_and_model(root, type_):
    """ADR-023: a draft's source is `draft-<name>-sg<N>@<date>` with the model that wrote it."""
    for ln in _lines(root, type_):
        for v in [ln, *ln["conflicts"]]:
            p = v["provenance"]
            if p["class"] == "machine":
                assert DRAFT.match(p["source"]) and p.get("model"), p


@pytest.mark.parametrize("type_", TYPES)
def test_no_japanese_is_left_in_the_store(root, type_):
    """The fork carries none of the original project's Japanese: every variant is Italian (or a kept name)."""
    left = [(ln["id"], ln["field"]) for ln in _lines(root, type_) for v in [ln, *ln["conflicts"]]
            if language.has_cjk(v["ja"])]
    assert not left, left[:10]


def test_northshire_ships_in_italian(root):
    by = {(ln["id"], ln["field"]): ln for ln in _lines(root, "quest")}
    english = {(e["id"], e["field"]) for e in Store(root / "data", english=True).load("quest")}
    for id_ in NORTHSHIRE:
        for field in ("title", "objectives", "description", "progress", "completion"):
            if (id_, field) not in english:
                continue
            ln = by.get((id_, field))
            if field == "progress" and ln is None:  # a progress text with no prose is not drafted
                continue
            assert ln is not None and ln["status"] == "trusted", (id_, field, ln and ln["status"])


def test_every_shipped_quest_line_keeps_its_paragraphs(root):
    english = {(e["id"], e["field"]): e["en"] for e in Store(root / "data", english=True).load("quest")}
    for ln in _lines(root, "quest"):
        en = english.get((ln["id"], ln["field"]))
        if ln["status"] in SHIPPED and en and ln["field"] in ("description", "progress", "completion"):
            assert paragraphs.count(ln["ja"]) == paragraphs.count_english(en), (ln["id"], ln["field"])


def test_generated_shard_carries_paragraph_breaks(root):
    shard = (root / "addon/WoWForeverItalian/Data/Quest/Quest_0000.lua").read_text(encoding="utf-8")
    row = next(line for line in shard.splitlines() if line.strip().startswith("[6] ="))
    assert "\\n\\n" in row  # Lua-escaped newlines inside the description slot


@pytest.mark.parametrize("type_", ["item", "spell"])
def test_no_shipped_tooltip_asks_for_more_slots_than_its_english_prints(root, type_):
    """A `$N<k>` or `$D<k>` past what the template prints can never be filled, so the line falls back to English
    for every player. Shipped tooltip rows stay within `align.value_slots` / `align.duration_slots` of their
    current English."""
    from wfi.core import align

    english = {(ln["id"], ln["field"]): ln["en"] for ln in Store(root / "data", english=True).load(type_)}
    over = []
    for ln in _lines(root, type_):
        en = english.get((ln["id"], ln["field"]))
        if ln["status"] not in SHIPPED or en is None:
            continue
        slots, durations = align.value_slots(en), align.duration_slots(en)
        if slots is None:
            continue
        n = max((int(m) for m in re.findall(r"\$N(\d+)", ln["ja"])), default=0)
        d = max((int(m) for m in re.findall(r"\$D(\d+)", ln["ja"])), default=0)
        if n > slots or (durations is not None and d > durations):
            over.append((ln["id"], ln["field"], n, slots, d, durations))
    assert not over, f"{len(over)} shipped {type_} line(s) ask for a slot the English never prints: {over[:10]}"
