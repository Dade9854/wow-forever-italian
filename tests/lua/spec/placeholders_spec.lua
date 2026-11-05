local H = require("tests.lua.spec.helpers")

describe("Core/Placeholders.expand", function()
  local P
  local HUNTER = { name = "Reyn", className = "Hunter", classFile = "HUNTER", raceName = "Night Elf",
    raceFile = "NightElf", sex = 2 }

  before_each(function()
    local WFI = {}
    H.loadPure("Core/Placeholders.lua", "WoWForeverItalian", WFI) -- pure: any global access raises
    P = WFI.Placeholders
  end)

  it("{name} becomes the player's name, every occurrence; missing or empty stays literal", function()
    assert.are.equal("Salve, Reyn. Reyn, ascolta.", (P.expand("Salve, {name}. {name}, ascolta.", HUNTER)))
    assert.are.equal("Salve, {name}.", (P.expand("Salve, {name}.", { name = nil })))
    assert.are.equal("Salve, {name}.", (P.expand("Salve, {name}.", { name = "" })))
    assert.are.equal("{name}", (P.expand("{name}", nil)))
  end)

  it("every class and race file has its Italian word, in the character's gender, lower case mid-sentence", function()
    local line = "Vai, giovane {class}."
    for file, pair in pairs(P.CLASS) do
      assert.are.equal("Vai, giovane " .. pair[1] .. ".", (P.expand(line, { classFile = file, sex = 2 })))
      assert.are.equal("Vai, giovane " .. pair[2] .. ".", (P.expand(line, { classFile = file, sex = 3 })))
    end
    for file, pair in pairs(P.RACE) do
      assert.are.equal("Un " .. pair[1] .. " qui?", (P.expand("Un {race} qui?", { raceFile = file, sex = 2 })))
    end
    assert.are.equal("Vai, giovane cacciatore.", (P.expand("Vai, giovane {class}.", HUNTER)))
    assert.are.equal("Vai, giovane cacciatrice.", (P.expand("Vai, giovane {class}.",
      { classFile = "HUNTER", sex = 3 })))
    assert.are.equal("Un elfo della notte qui?", (P.expand("Un {race} qui?", HUNTER)))
  end)

  it("a class or race word opening the text or a sentence takes a capital", function()
    assert.are.equal("Cacciatore, ascolta.", (P.expand("{class}, ascolta.", HUNTER)))
    assert.are.equal("Bene. Cacciatore, vieni.", (P.expand("Bene. {class}, vieni.", HUNTER)))
    assert.are.equal("Elfo della notte!", (P.expand("{race}!", HUNTER)))
    assert.are.equal("Bene, cacciatore.", (P.expand("Bene, {class}.", HUNTER)))
  end)

  it("an unlisted file falls back to the localized name; with neither the token stays literal", function()
    local dk = { classFile = "DEATHKNIGHT", className = "Death Knight" }
    assert.are.equal("Vai, giovane Death Knight.", (P.expand("Vai, giovane {class}.", dk)))
    assert.are.equal("Un Draenei qui?", (P.expand("Un {race} qui?", { raceFile = "Draenei", raceName = "Draenei" })))
    assert.are.equal("Vai, giovane {class}.", (P.expand("Vai, giovane {class}.", { classFile = "DEATHKNIGHT" })))
    assert.are.equal("Un {race} qui?", (P.expand("Un {race} qui?", {})))
  end)

  it("an ASCII gender pair takes the female form only for UnitSex 3", function()
    assert.are.equal("Sei pronto?", (P.expand("Sei <pronto/pronta>?", { sex = 2 })))
    assert.are.equal("Sei pronta?", (P.expand("Sei <pronto/pronta>?", { sex = 3 })))
    assert.are.equal("Sei pronto?", (P.expand("Sei <pronto/pronta>?", { sex = 1 })))
    assert.are.equal("Sei pronto?", (P.expand("Sei <pronto/pronta>?", {})))
    -- an emote and a single <word> are not pairs
    assert.are.equal("<Sirra inizia a tradurre la lettera.>",
      (P.expand("<Sirra inizia a tradurre la lettera.>", { sex = 3 })))
    assert.are.equal("<mage>", (P.expand("<mage>", { sex = 3 })))
    -- a non-ASCII pair is not expanded (the pipeline's validate rule blocks it from shipping)
    assert.are.equal("<andrà/andrà>", (P.expand("<andrà/andrà>", { sex = 3 })))
  end)

  it("an unknown {word} stays literal; distinct tokens are recorded once however often they render", function()
    local text, unknown = P.expand("{foo} e {name} e {Name}", HUNTER)
    assert.are.equal("{foo} e Reyn e {Name}", text) -- tokens are case-sensitive: {Name} is unknown
    assert.are.equal(2, unknown)
    for _ = 1, 5 do P.expand("{foo}", HUNTER) end -- re-resolves (Alt, refresh) do not inflate the count
    local _, again = P.expand("{bar}", HUNTER)
    assert.are.equal(1, again)
    local n, list = P.unknownTokens()
    assert.are.equal(3, n)
    assert.are.same({ "{Name}", "{bar}", "{foo}" }, list)
  end)

  it("text without tokens comes back unchanged; a known token with no value is not counted", function()
    local text, unknown = P.expand("Nessun segnaposto", HUNTER)
    assert.are.equal("Nessun segnaposto", text); assert.are.equal(0, unknown)
    local _, n = P.expand("{class}", {})
    assert.are.equal(0, n); assert.are.equal(0, (P.unknownTokens()))
    assert.are.same({ "name", "class", "race" }, P.KNOWN)
    assert.is_false(P.mayHaveTokens("Nessun segnaposto")); assert.is_true(P.mayHaveTokens("{name}"))
    assert.is_true(P.mayHaveTokens("<pronto/pronta>")); assert.is_false(P.mayHaveTokens(nil))
  end)
end)
