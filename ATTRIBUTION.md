# Attribution

## Translators (0 tags, as recorded in the corpus)

None yet: every Italian line so far is a machine draft, which names its model in `data/` instead.

## Lineage

WoW Forever Italian is a fork of **WoW Forever Japanese** by **Zyaga**
(https://github.com/zyaga/wow-forever-japanese), GPL-2.0-or-later: the addon's engine (the window hooks, the
lookup by id and by the English's hash, the reveal key, the fix and bug reports, the collector), the data
pipeline (import, check, generate, validate, the translation batches) and the English text it extracted
(`data/english/`) are that project's work, adapted here to Italian. The fork keeps none of its Japanese
translations, its Japanese font or its voice over.

WoW Forever Japanese itself came from earlier addons for WoW Classic, whose architecture it follows:

1. **WoWpoPolsku-Quests** (Platine, wowpopolsku.pl): the addon architecture the later forks used (GPLv2).
2. **Classic Quest Chinese Translator** (luckycat_tv) and **Tooltips Translator - Chinese** (qqytqqyt)
   (GPLv2).
3. **Classic Quest Japanese Translator** (Crynok / Zyaga) and **Classic Tooltip Japanese Translator** (Zyaga)
   (GPLv2).

## Upstream notices

- WoW Forever Japanese: `## Author: Zyaga` · `## X-Copyright: Copyright (C) 2026 Zyaga` ·
  `## X-License: GPL-2.0-or-later`.
- Classic Quest Japanese Translator: `## Author: Crynok / Zyaga` · `-- Author: Crynok and Zyaga` ·
  `-- Credit to: qytqqyt and Platine https://wowpopolsku.pl`.
- Classic Tooltip Japanese Translator: `## Author: Zyaga` · `-- Credit to: qytqqyt` · Notes: "This is
  a modified version of "Tooltips Translator - Chinese" by qytqqyt."

## English source text

The English text in `data/english/` is Blizzard Entertainment's. It is kept to align and hash the
translations and is never shipped in the addon. WoW Forever Japanese read it from the Forever client's own
tables and quest cache, the Classic Era quest cache, wago.tools DB2 exports (`ItemSparse`, `SpellName`), and:

- pfQuest (`db/enUS/quests.lua`, https://github.com/shagu/pfQuest), under the MIT License (below);
- the VMaNGOS world database (https://github.com/vmangos/core, release `db_latest`, snapshot `db-13b49dc`),
  GPL-2.0: quest progress and completion text, gossip and book pages.
- forever-vo (https://github.com/quinn-dougherty/forever-vo), under the MIT License (below): quest progress
  and turn-in text and NPC greetings that players of the Forever client recorded with its addon and sent in.

## pfQuest license

> MIT License
>
> Copyright (c) 2017-2021 Eric Mauser (Shagu)
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
> associated documentation files (the "Software"), to deal in the Software without restriction, including
> without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
> following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial
> portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
> LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
> EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
> AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
> OR OTHER DEALINGS IN THE SOFTWARE.

## forever-vo license

> MIT License
>
> Copyright (c) 2026 Quinn Dougherty
>
> Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
> associated documentation files (the "Software"), to deal in the Software without restriction, including
> without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
> copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
> following conditions:
>
> The above copyright notice and this permission notice shall be included in all copies or substantial
> portions of the Software.
>
> THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
> LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO
> EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
> AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
> OR OTHER DEALINGS IN THE SOFTWARE.

## This project

WoW Forever Italian ships its own code and translations under GPL-2.0-or-later (see `LICENSE`); every
translated line keeps its provenance in `data/` (a machine draft names its model, a hand-written line its
translator). The English text in `data/english/` is Blizzard Entertainment's and is not licensed by this
project. The addon bundles no font: it uses the game client's own. Details: `docs/legal/licensing.md`.
