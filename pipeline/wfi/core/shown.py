"""The translated text a line ships, as the addon and the fix reports see it. Pure: no disk."""

from __future__ import annotations

import re

from wfi.core.hashing import key as hash_key

_HTML = re.compile(r"<html", re.IGNORECASE)


def ja_hash(ja: str) -> str:
    """The hash that pins a record (a fix report, an audit row) to the exact translated text it was
    written for: the addon's hash primitive over the text as stored. (`ja` is the store's name for the
    translation field.)"""
    return hash_key(ja)


def html_page(type_: str, ja: str) -> bool:
    """A book page written as HTML (`<HTML>…`): the client shows it through its SimpleHTML."""
    return type_ == "book" and _HTML.search(ja) is not None
