from wfi.core.align import allowlist_problems, load_allowlist


def test_every_allowlist_line_is_justified(root):
    text = (root / "pipeline/allowlist.txt").read_text(encoding="utf-8")
    assert allowlist_problems(text) == []
    assert len(load_allowlist(text)) >= 10
