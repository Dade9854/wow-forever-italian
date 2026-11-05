-- Core/Glosses.lua: the word popup's meanings (ADR-039), the read path over WFI.Data.gloss.
-- Pure: no globals, no frames. The display is UI/ReadingPopup.lua.
--   Glosses.get(n) → { lemma, lemmaReading, meaning } | nil; n is a word's meaning number from its reading row
-- Rows (generated, Data/Gloss/*.lua): [n] = "dictionary form<TAB>its reading<TAB>meaning", written by the model with
-- the sentence in front of it, so the meaning is the one the sentence uses; the pipeline guarantees no tab inside.
local _, WFI = ...
local Glosses = {}
WFI.Glosses = Glosses

function Glosses.get(n)
  local row = type(n) == "number" and WFI.Data.gloss[n]
  if type(row) ~= "string" then return nil end
  local lemma, lemmaReading, meaning = row:match("^([^\t]+)\t([^\t]+)\t([^\t]+)$")
  if not lemma then return nil end
  return { lemma = lemma, lemmaReading = lemmaReading, meaning = meaning }
end
