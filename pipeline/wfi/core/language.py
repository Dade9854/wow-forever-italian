"""Is this Italian? A translation is not English left in place, and holds no CJK.

Italian and English share their letters, so the script cannot tell them apart. The check is three rules:

1. Empty text, or text holding a CJK character (a line from the Japanese project), is not Italian.
2. A title-like field (a quest title, an objective's label) may be only a name, which renders identically to
   the English: it passes.
3. Prose (`PROSE_FIELDS`) is not Italian when it is the English itself (compared after folding case and
   whitespace), when it holds no letter at all (only dots, marks or tokens), or when it reads as English: at
   least `ENGLISH_MIN` English function words, and more of them than Italian ones (names kept in English
   letters bring the odd "the" or "of" into an Italian line, so one or two never decide).

Pure: no disk.
"""

from __future__ import annotations

import re

_CJK = re.compile(r"[぀-ヿ㐀-鿿豈-﫿＀-￯]")
PROSE_FIELDS = {"description", "objectives", "completion", "progress", "text"}

# The commonest function words of each language. Short, frequent and unambiguous: none is a word of the
# other language ("a" and "i" are left out, "come" is English too, so is "con" in "con man": left out).
_ITALIAN = (
    "il lo la gli le un uno una di del dello della dei degli delle che è e ed per non al allo alla ai agli"
    " alle da dal dallo dalla dai dagli dalle nel nello nella nei negli nelle sul sullo sulla sui sugli sulle"
    " sono sei siamo siete hai ha abbiamo avete hanno ti mi ci si vi ne questo questa questi queste quello"
    " quella quelli quelle mio mia miei mie tuo tua tuoi tue suo sua suoi sue nostro nostra vostro vostra"
    " ma se più anche già qui qua dove quando cosa perché molto tutto tutti tra fra senza dopo prima ancora"
    " dell nell all dall sull dev puoi può devi deve essere stato stata fatto"
)
ITALIAN_WORDS = frozenset(_ITALIAN.split())
_ENGLISH = (
    "the and of to you your is are that this with for have has it be will from they we my me not but what"
    " who was were been there their them his her our would could should can into about which an"
)
ENGLISH_WORDS = frozenset(_ENGLISH.split())
ENGLISH_MIN = 3
_WORD = re.compile(r"[a-zàèéìíîòóùú]+")
_LETTER = re.compile(r"[A-Za-zÀ-ÿ]")
# A name kept in English letters that holds function words ("Head of the Captain of the Guard", "Brotherhood
# of the Light"): capitalised words joined by English connectors. Its "of" and "the" are the name's.
_CAP = r"[A-Z][A-Za-z'’\-]*"
_NAME_SPAN = re.compile(rf"{_CAP}(?:\s+(?:(?:of|the|and|in|on|at|for|to|from)\s+)+{_CAP})+")
_SPACE = re.compile(r"(?:\s|\$[Bb])+")  # a `$B` break in stored English is a line break


def has_cjk(text: str) -> bool:
    return _CJK.search(text) is not None


def _fold(text: str) -> str:
    return _SPACE.sub(" ", text).strip().casefold()


def word_counts(text: str) -> tuple[int, int]:
    """(Italian function words, English function words) in `text`, names kept in English set aside."""
    words = _WORD.findall(_NAME_SPAN.sub(" ", text).casefold())
    return sum(w in ITALIAN_WORDS for w in words), sum(w in ENGLISH_WORDS for w in words)


def reads_english(text: str) -> bool:
    italian, english = word_counts(text)
    return english >= ENGLISH_MIN and english > italian


def reads_italian(text: str) -> bool:
    """The mirror of `reads_english`: an English intake (a collector send) refuses a line that reads as
    Italian, which can only be this addon's own text recorded by mistake."""
    italian, english = word_counts(text)
    return italian >= ENGLISH_MIN and italian > english


def is_italian(text: str, field: str, english: str | None = None) -> bool:
    """Italian = not empty, no CJK; and for prose, neither the English itself nor text that reads as English.
    A title-like field may be a name that renders identically to the English, and passes."""
    if not text.strip() or has_cjk(text):
        return False
    if field not in PROSE_FIELDS:
        return True
    if english is not None and _fold(text) == _fold(english):
        return False
    if not _LETTER.search(text):  # only dots, marks or tokens: nothing was translated
        return False
    return not reads_english(text)
