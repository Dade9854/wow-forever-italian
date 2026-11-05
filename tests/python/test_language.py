from wfi.core.language import has_cjk, is_italian, reads_english, reads_italian, word_counts


def test_prose_italian():
    assert is_italian("Il potente ippogrifo Sharptalon è stato ucciso.", "description")
    assert is_italian("Uccidi 10 Kobold Vermin.", "objectives")  # no function word, not the English: passes
    assert is_italian("Ben fatto!!!!!", "completion")


def test_prose_rejects_english_cjk_and_blank():
    assert not is_italian("I will keep three of the weapons, and you can have the rest.", "completion")
    assert not is_italian("大いなるヒポグリフSharptalonは倒された。", "description")
    assert not is_italian("   ", "objectives")
    # the English itself, left in place, is not a translation (case and whitespace, `$B` breaks, folded)
    assert not is_italian("Kill 10  kobold vermin.", "objectives", "Kill 10 Kobold Vermin.")
    assert not is_italian("Hello.\n\nBye.", "completion", "Hello.$B$BBye.")


def test_names_kept_in_english_do_not_make_a_line_english():
    assert is_italian("Porta la Head of the Captain of the Guard a Marshal McBride.", "objectives")


def test_title_rules():
    assert is_italian("Una taglia su Garrick Padfoot", "title")
    assert is_italian("Garrick Padfoot", "title")  # a title that is only a name passes
    assert not is_italian("賞金首Garrick Padfoot", "title")


def test_word_counts_and_the_two_directions():
    assert word_counts("Il tuo primo compito è fare pulizia, e non è facile.") == (6, 0)
    assert reads_english("You have done well, and the town is safe for now.")
    assert not reads_english("Hai fatto un buon lavoro e la città è salva.")
    assert reads_italian("Hai fatto un buon lavoro e la città è salva, per ora.")
    assert not reads_italian("Kill the wolf.")
    assert has_cjk("狼") and not has_cjk("città")
