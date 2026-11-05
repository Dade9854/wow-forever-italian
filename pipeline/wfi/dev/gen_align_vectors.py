"""Generate vectors/align_vectors.{jsonl,lua}: the shared contract between core/align.py and Core/Align.lua.

Each row: {id, op, text, scope?, allowlist, expected}. `op` ∈ names · checkNames · numbers · numberWords ·
variantKey. `expected` is the Python result (numbers: sorted multiset as a list; variantKey: the key of the
English template in `scope`, which the Lua side must compute from the rendered live line in `text`). Both
suites iterate every row.
Usage: python -m wfi.dev.gen_align_vectors [out_dir]
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from wfi.core import align
from wfi.emit.lua_writer import lua_string

AL = ["health", "mana", "horde", "stamina"]

CASES: list[tuple[str, str, str, str | None]] = [
    # id, op, text, scope
    ("names-01", "names",
     "Parla con Senani Thunderheart a Silverwind Refuge: ha visto Sharptalon's Claw.", None),
    ("names-02", "names", "Ripristina Health. E Mana. I soldati della Horde.", None),
    ("names-03", "names", "Mk2 e ab cd, poi Kul'Tiras", None),
    ("names-04", "names", "{name} e {class} vanno a Northshire Abbey", None),
    ("names-05", "names", "la Sharptalon’s Claw e Deathstalker Quinn", None),
    ("names-06", "names", "a Splintertree Post, Ashenvale", None),
    ("names-07", "names", "i Twilight's Hammer e i twilight's hammer", None),
    ("names-08", "names", "È ora: la Città e il Perché, poi Northshire.", None),
    ("names-09", "names", "Marshal McBride ti cerca. «Cairne Bloodhoof» è a Thunder Bluff!", None),
    ("names-10", "names", "Uccidi 10 Kobold Vermin.\nTorna da Deputy Willem — Marshal Dughan aspetta…", None),
    ("names-11", "names", "dell'Alleanza e l'Orda; nell'Abbazia di Northshire", None),
    ("names-12", "names", "Sei <pronto/pronta>? <Pronto/Pronta> a sfidare Garrick Padfoot?", None),
    (
        "check-01",
        "checkNames",
        "Porta lo Sharptalon's Claw a Senani Thunderheart a Splintertree Post.",
        "Bring Sharptalon's Claw to Senani Thunderheart at Splintertree Post, Ashenvale.",
    ),
    ("check-02", "checkNames", "a Post Splintertree", "Bring it to Splintertree Post, Ashenvale."),
    ("check-03", "checkNames", "Parla con lo Chef Grual.", "Speak with Chef Grual in Goldshire."),
    ("check-04", "checkNames", "Parla con lo Chef Grual.", "Speak with Grual in Goldshire."),
    ("check-05", "checkNames", "Ripristina Health", "Restores 61 health over 18 sec."),
    ("check-06", "checkNames", "le navi di Kul'Tiras", "The ships of Kul Tiras"),
    ("check-07", "checkNames", "l'altare di Hakkar", "the altar of Hakkari"),
    ("check-08", "checkNames", "Vai a Durnholde Keep.", "Go to Durnholde."),
    ("check-09", "checkNames", "Parla con lo Chef Grual a Roccavento.",
     "Speak with Chef Grual in Goldshire."),
    ("numbers-01", "numbers", "Uccidi １０ Kobold Vermin e prendi 3 Mk2", None),
    ("numbers-02", "numbers", "Ripristina 61 punti salute in 18 sec. Devi restare seduto.", None),
    ("numbers-03", "numbers", "1,200 danni e 18.5 sec", None),
    ("numbers-04", "numbers", "N1 e N2 non sono numeri. ５０ oro.", None),
    ("numbers-05", "numbers", "2abc 3 4x 55 66", None),
    ("numbers-06", "numbers", "Use: Restores 61 health over 18 sec. 3 3 3", None),
    ("numbers-07", "numbers", "Usa Mk12, abc12 e 34xyz, in 18sec.", None),
    ("numbers-08", "numbers", "Deals 12abc damage and 120 more", None),
    ("words-01", "numberWords", "twenty-five silver and two hundred gold, a dozen eggs", None),
    ("words-02", "numberWords", "Kill six Kobold Vermin and one Kobold Worker", None),
    ("words-03", "numberWords", "one thousand years; Single target; NINE lives", None),
    ("words-04", "numberWords", "Restores 61 health over 18 sec.", None),
    ("words-05", "numberWords", "thirteen-fourteen fifty two", None),
    ("words-06", "numberWords", "one2 and 3three and ten thousand and twenty five", None),
    ("words-07", "numberWords", "Hundred one-time a single", None),
    # variantKey: text = the live line as the client renders it, scope = the English template it came from
    ("key-01", "variantKey", "Increases all damage you deal by 4%.",
     "Increases all damage you deal by $s1%."),
    ("key-02", "variantKey", "Increases the damage you deal with physical attacks in all forms by 4%.",
     "Increases the damage you deal with physical attacks in all forms by $s1%."),
    ("key-03", "variantKey", "The Enrage ability instantly generates an additional 5 Rage.",
     "The Enrage ability instantly generates an additional $/10;17080s1 Rage."),
    ("key-04", "variantKey", "Immune to snare and root effects.\r\nMovement speed increased by 50%.",
     "Immune to snare and root effects.\r\nMovement speed increased by 50%."),
    ("key-05", "variantKey", "3 trophies gathered as victories while Dueling to the Death.",
     "$w trophies gathered as victories while Dueling to the Death."),
    ("key-06", "variantKey", "Absorbs 1,230 Fire damage for 30 sec.", "Absorbs $s1 Fire damage for $d."),
    ("key-07", "variantKey", "Causes 14 to 22 Fire damage every 3 sec.",
     "Causes $s1 to $s2 Fire damage every $t1 sec."),
    ("key-08", "variantKey", "Deals 2.5% damage over 2 min and lasts 1 hr 30 min.",
     "Deals ${$s1/4}.1% damage over $d and lasts $1d."),
    ("key-09", "variantKey", "|Tinterface\\icons\\x:0|t Quick Draw: 25 damage.",
     "$I1 Quick Draw: $s1 damage."),
    ("key-10", "variantKey", "|cFFFFFFFFRequires Cat Form|r  Increases damage by 5.",
     "|cFFFFFFFFRequires Cat Form|r  Increases damage by $s1."),
    ("key-11", "variantKey",
     "Each melee attack or non-instant spell cast has a chance of causing Clearcasting.",
     "Each melee attack or non-instant spell cast has a chance of causing Clearcasting."),
    ("key-12", "variantKey", "Heals a friendly target for 120 to 140.",
     "Heals a friendly target for ${$<healpower>*$436517m1/100} to ${$<healpower>*$436517M1/100}."),
    ("key-13", "variantKey", "Stacks up to 5. Lasts 2 min, then 3 sec.",
     "Stacks up to $m2. Lasts $d, then 3 sec."),
    ("key-14", "variantKey", "Restores 61 health over 18 sec.  Must remain seated.",
     "Restores 61 health over 18 sec.  Must remain seated."),
]


def build() -> list[dict]:
    al = set(AL)
    rows = []
    for id_, op, text, scope in CASES:
        if op == "names":
            expected: object = align.latin_names(text, al)
        elif op == "checkNames":
            expected = align.check_names(text, scope or "", al)[1]
        elif op == "numbers":
            expected = sorted(align.numbers(text).elements(), key=lambda s: (len(s), s))
        elif op == "numberWords":
            expected = align.english_number_words(text)
        elif op == "variantKey":
            expected = align.variant_key(scope or "")
        else:
            raise ValueError(op)
        row = {"id": id_, "op": op, "text": text, "scope": scope, "allowlist": AL, "expected": expected}
        rows.append(row)
    return rows


def to_lua(rows: list[dict]) -> str:
    lines = [
        "-- GENERATED by pipeline/wfi/dev/gen_align_vectors.py from align_vectors.jsonl. Do not edit.",
        "return { cases = {",
    ]
    al = ", ".join(lua_string(a) for a in AL)
    for r in rows:
        scope = lua_string(r["scope"]) if r["scope"] is not None else "nil"
        # a key is one string; every other op expects a list
        if isinstance(r["expected"], str):
            exp = lua_string(r["expected"])
        else:
            exp = "{ " + ", ".join(lua_string(e) for e in r["expected"]) + " }"
        lines.append(
            f"  {{ id = {lua_string(r['id'])}, op = {lua_string(r['op'])}, text = {lua_string(r['text'])}, "
            f"scope = {scope}, allowlist = {{ {al} }}, expected = {exp} }},"
        )
    lines.append("} }")
    return "\n".join(lines) + "\n"


def write(out_dir: Path) -> None:
    rows = build()
    out_dir.mkdir(parents=True, exist_ok=True)
    with (out_dir / "align_vectors.jsonl").open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False) + "\n")
    (out_dir / "align_vectors.lua").write_text(to_lua(rows), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    args = argv if argv is not None else sys.argv[1:]
    out = Path(args[0]) if args else Path(__file__).resolve().parents[3] / "vectors"
    write(out)
    print(f"wrote {out / 'align_vectors.jsonl'} + .lua ({len(CASES)} cases)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
