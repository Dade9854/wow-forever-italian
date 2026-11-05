-- Core/Placeholders.lua: the player tokens the translations carry, expanded when the Italian is applied.
-- Pure: the player arrives as a table (Main.lua reads the client). Tokens stay literal in data/.
--   {name}  → player.name (the client's own spelling of the character name)
--   {class} → the Italian class word for the character's sex, by classFile (UnitClass 2nd return); else the
--             localized className
--   {race}  → the Italian race word for the character's sex, by raceFile (UnitRace 2nd return); else the
--             localized raceName
--             A class or race word is written in lower case, as Italian prose writes it ("un guerriero"), and
--             with a capital where it opens the text or a sentence.
--   <m/f>   → f for a female character (UnitSex 3), else m; ASCII word pairs only. Italian agrees adjectives and
--             participles with the player ("Sei <pronto/pronta>?"); an emote such as <Sirra ride> is not a pair
--   any other {word} → left literal and recorded once in Placeholders.unknown (distinct tokens; /wfi debug)
-- A token whose value is unavailable (no name yet, an unlisted class with no localized name) stays literal.
-- Class and race are prose words, not proper names (which stay English); the words are the official Italian
-- client's.
local _, WFI = ...
local Placeholders = {}
WFI.Placeholders = Placeholders

Placeholders.KNOWN = { "name", "class", "race" }

-- { male, female }
Placeholders.CLASS = {
  WARRIOR = { "guerriero", "guerriera" }, PALADIN = { "paladino", "paladina" },
  HUNTER = { "cacciatore", "cacciatrice" }, ROGUE = { "ladro", "ladra" }, PRIEST = { "sacerdote", "sacerdotessa" },
  SHAMAN = { "sciamano", "sciamana" }, MAGE = { "mago", "maga" }, WARLOCK = { "stregone", "strega" },
  DRUID = { "druido", "druida" },
}

Placeholders.RACE = {
  Human = { "umano", "umana" }, Orc = { "orco", "orchessa" }, Dwarf = { "nano", "nana" },
  NightElf = { "elfo della notte", "elfa della notte" }, Scourge = { "non morto", "non morta" },
  Tauren = { "tauren", "tauren" }, Gnome = { "gnomo", "gnoma" }, Troll = { "troll", "troll" },
}

Placeholders.unknown = {} -- set of distinct unknown {word} tokens met this session

local FEMALE = 3 -- UnitSex: 1 unknown · 2 male · 3 female
local known = {}
for _, word in ipairs(Placeholders.KNOWN) do known[word] = true end

local function nonEmpty(s)
  if type(s) == "string" and s ~= "" then return s end
  return nil
end

-- True when `text` could hold a token; lets a caller skip reading the client for token-free text.
function Placeholders.mayHaveTokens(text)
  return type(text) == "string" and (text:find("{", 1, true) ~= nil or text:find("<", 1, true) ~= nil)
end

-- Distinct unknown tokens met this session, sorted: → count, { "{foo}", … }.
function Placeholders.unknownTokens()
  local list = {}
  for token in pairs(Placeholders.unknown) do list[#list + 1] = token end
  table.sort(list)
  return #list, list
end

-- → expanded text, number of unknown {word} tokens left literal in this text
-- ASCII classes, not %a: %a follows the C locale in PUC Lua and could take high bytes of UTF-8 text.
-- The word for the character's sex from a { male, female } pair; nil when the key is not listed.
local function gendered(pair, sex)
  if not pair then return nil end
  return sex == FEMALE and pair[2] or pair[1]
end

-- Whether the token at byte `at` opens the text or a sentence (spaces skipped back to a . ! ? : or a line break).
local function opensSentence(text, at)
  local before = text:sub(1, at - 1):gsub("[ \t]+$", "")
  return before == "" or before:find("[%.!%?:\n]$") ~= nil
end

local function capitalize(word)
  return (word:gsub("^%l", string.upper))
end

-- → expanded text, number of unknown {word} tokens left literal in this text
-- ASCII classes, not %a: %a follows the C locale in PUC Lua and could take high bytes of UTF-8 text.
function Placeholders.expand(text, player)
  if not Placeholders.mayHaveTokens(text) then
    return text, 0
  end
  player = player or {}
  local values = {
    name = nonEmpty(player.name),
    class = gendered(Placeholders.CLASS[player.classFile], player.sex) or nonEmpty(player.className),
    race = gendered(Placeholders.RACE[player.raceFile], player.sex) or nonEmpty(player.raceName),
  }
  local unknown = 0
  local out = text:gsub("(){([A-Za-z]+)}", function(at, word)
    if not known[word] then
      unknown = unknown + 1
      Placeholders.unknown["{" .. word .. "}"] = true
      return nil -- keep the token literal
    end
    local value = values[word]
    if value and word ~= "name" and opensSentence(text, at) then value = capitalize(value) end
    return value -- nil keeps a known token literal when its value is unavailable
  end)
  out = out:gsub("<([A-Za-z]+)/([A-Za-z]+)>", function(male, female)
    if player.sex == FEMALE then return female end
    return male
  end)
  return out, unknown
end
