def test_gpl2_license_text(root):
    text = (root / "LICENSE").read_text(encoding="utf-8")
    assert "GNU GENERAL PUBLIC LICENSE" in text[:200]
    assert "Version 2, June 1991" in text[:200]


def test_or_later_declared(root):
    assert 'license = { text = "GPL-2.0-or-later" }' in (root / "pipeline" / "pyproject.toml").read_text()
    assert "## X-License: GPL-2.0-or-later" in (
        root / "addon" / "WoWForeverItalian" / "WoWForeverItalian.toc"
    ).read_text(encoding="utf-8")


def test_no_font_is_bundled(root):
    """Italian is written in the client's own fonts: the addon bundles no font (the original's IPA face is gone)."""
    assert not (root / "addon" / "WoWForeverItalian" / "Fonts").exists()
