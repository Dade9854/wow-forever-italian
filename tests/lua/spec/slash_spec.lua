local H = require("tests.lua.spec.helpers")
local Stub = require("tests.lua.spec.wow_stub")
local Loader = require("tests.lua.spec.loader")

describe("/wfi covers every setting", function()
  local meta, WFI, S
  before_each(function()
    meta = Stub.install(H.ADDON_DIR .. "/WoWForeverItalian.toc")
    -- the surfaces (quest, tooltip, gossip) declare their client names on load
    Stub.installQuestAPI(); Stub.installTooltipAPI(); Stub.installGossipAPI()
    WFI = Loader.load("WoWForeverItalian")
    Stub.fireAll("ADDON_LOADED", "WoWForeverItalian")
    S = WFI.Settings
    Stub.prints = {}
  end)

  local function wfi(line) SlashCmdList.WFI(line) end

  it("every non-hidden setting is settable through the slash grammar", function()
    for _, d in ipairs(S.list()) do
      if not d.hidden then
        local before = S.get(d.id)
        if d.id == "enabled" then
          wfi("off"); assert.is_false(S.get("enabled"))
          wfi("on"); assert.is_true(S.get("enabled"))
          wfi("toggle"); assert.is_false(S.get("enabled"))
          wfi("toggle"); assert.is_true(S.get("enabled"))
        elseif d.kind == "boolean" and not d.id:find(".", 1, true) then -- top-level boolean: "<id> <value>"
          wfi(("%s %s"):format(d.id, before and "off" or "on"))
          assert.are.equal(not before, S.get(d.id), d.id)
          wfi(("%s %s"):format(d.id:lower(), before and "on" or "off")) -- the id is matched case-insensitively
          assert.are.equal(before, S.get(d.id), d.id)
        elseif d.kind == "boolean" then
          local group, name = d.id:match("^(.-)%.(.+)$")
          wfi(("%s %s %s"):format(group, name, before and "off" or "on"))
          assert.are.equal(not before, S.get(d.id), d.id)
          wfi(("%s %s"):format(d.id, before and "on" or "off"))
          assert.are.equal(before, S.get(d.id), d.id)
        else
          local other
          if d.kind == "key" then other = before == "ctrl" and "alt" or "ctrl" end
          for _, c in ipairs(d.choices or {}) do if c ~= before then other = c end end
          wfi(("%s %s"):format(d.id, other))
          assert.are.equal(other, S.get(d.id), d.id)
        end
      end
    end
  end)

  it("bare /wfi prints one line per non-hidden setting with its value", function()
    wfi("")
    local n = 0
    for _, d in ipairs(S.list()) do
      if not d.hidden then
        n = n + 1
        local found = false
        for _, line in ipairs(Stub.prints) do
          if line:find("  " .. d.id .. " = ", 1, true) then found = true end
        end
        assert.is_true(found, d.id)
      end
    end
    -- the original eight + collector.enabled + area.interface + area.books + readings.enabled + readings.glosses
    -- + minimapButton + collector.remind
    assert.are.equal(15, n)
  end)

  it("/wfi bug opens the report window on Bug; /wfi log ends with the Lua error count", function()
    local opened, real = 0, WFI.ReportWindow.open
    WFI.ReportWindow.open = function() opened = opened + 1 end
    wfi("bug")
    wfi("BUG")
    WFI.ReportWindow.open = real
    assert.are.equal(2, opened)
    Stub.prints = {}
    wfi("log")
    assert.are.equal("WFI: errors: 0 recorded, 0 not sent (/wfi bug)", Stub.prints[#Stub.prints])
  end)

  it("panel reset puts the voice panel back without saving anything new; other panel words get the help", function()
    wfi("panel reset")
    assert.are.equal("WFI: voice panel: back at the bottom centre", Stub.prints[#Stub.prints])
    assert.is_nil(WFI_DB.voicePanel)
    wfi("panel look 2")
    assert.are.equal("WFI: panel: /wfi panel reset puts the voice panel back at the bottom centre",
      Stub.prints[#Stub.prints])
  end)

  it("reads a setting when no value is given; rejects a bad value with the reason", function()
    wfi("modifier")
    assert.is_truthy(Stub.prints[#Stub.prints]:find("modifier = alt", 1, true))
    wfi("modifier meta")
    assert.is_truthy(Stub.prints[#Stub.prints]:find("expected a key", 1, true))
    assert.are.equal("alt", S.get("modifier"))
  end)

  it("accepts values case-insensitively", function()
    wfi("modifier ALT")
    assert.are.equal("alt", S.get("modifier"))
    wfi("Area.Quests OFF")
    assert.is_false(S.get("area.quests"))
  end)

  it("matches setting ids case-insensitively", function()
    wfi("area itemtooltips off")
    assert.is_false(S.get("area.itemTooltips"))
    wfi("AREA.ITEMTOOLTIPS on")
    assert.is_true(S.get("area.itemTooltips"))
  end)

  it("keeps the version and unknown-command lines", function()
    wfi("version")
    assert.is_truthy(Stub.prints[1]:find(meta.Version, 1, true))
    Stub.prints = {}
    wfi("bogus")
    assert.is_truthy(Stub.prints[1]:find("unknown command 'bogus'", 1, true))
  end)

  it("debug tooltip turns the trace on and off and shows it in a window, colour codes as text", function()
    local F = require("tests.lua.spec.stub_fixwindow")
    F.install() -- the window templates (ButtonFrameTemplate, ScrollingEditBoxTemplate)
    F.scrollUtil()
    wfi("debug tooltip on")
    assert.are.same({}, WFI.Tooltip.trace)
    WFI.Tooltip.trace[1] = "[12:00:00] GameTooltip secret spell id=<secret> |cffffd100gold|r"
    wfi("debug tooltip")
    local window = _G.WFITooltipTrace
    assert.is_truthy(window and window:IsShown())
    assert.are.equal("[12:00:00] GameTooltip secret spell id=<secret> ||cffffd100gold||r", window.text.value)
    assert.is_truthy(Stub.prints[#Stub.prints]:find("1 passes shown", 1, true))
    wfi("debug tooltip off")
    assert.is_nil(WFI.Tooltip.trace)
  end)

  it("debug sub-verbs read the shipped data", function()
    wfi("debug hash")
    local n = #H.vectors().cases
    assert.is_truthy(Stub.prints[#Stub.prints]:find(("hash vectors: %d/%d ok"):format(n, n), 1, true))
    Stub.prints = {}
    wfi("debug quest 2")
    local out = table.concat(Stub.prints, "\n")
    assert.is_truthy(out:find("quest.title: trusted (h1 d311f9a5)", 1, true))
    assert.is_truthy(out:find("Sharptalon's Claw", 1, true)) -- the item name, in English letters
    assert.is_truthy(out:find("quest.progress:", 1, true))
    Stub.prints = {}
    wfi("debug quest 5")
    out = table.concat(Stub.prints, "\n")
    assert.is_truthy(out:find("quest.progress: -", 1, true)) -- an unshipped field prints a dash
    Stub.prints = {}
    wfi("debug quest 999999")
    assert.is_truthy(Stub.prints[#Stub.prints]:find("quest 999999: not shipped", 1, true))
    Stub.prints = {}
    wfi("debug item " .. tostring((next(WFI.Data.item))))
    assert.is_truthy(Stub.prints[1]:find("item.description: unaligned", 1, true))
    Stub.prints = {}
    wfi("debug spell " .. tostring((next(WFI.Data.spell))))
    assert.is_truthy(Stub.prints[1]:find("spell.description: unaligned", 1, true))
    Stub.prints = {}
    -- a sectioned line (a heading with optional paragraphs) has no single Japanese text to print
    local get = WFI.Lookup.get
    WFI.Lookup.get = function(kind) -- luacheck: ignore 212
      if kind == "spell.aura" then return { status = "t", h1 = 1, sections = { head = "見出し", {}, {} } } end
    end
    wfi("debug spell 1229741")
    WFI.Lookup.get = get
    assert.is_truthy(table.concat(Stub.prints, "\n"):find("spell.aura: t (h1 00000001) 2 sections", 1, true))
    Stub.prints = {}
    wfi("debug gossip")
    assert.is_truthy(Stub.prints[1]:find(("gossip entries: %d"):format(WFI.Data.count("gossip")), 1, true))
    Stub.prints = {}
    wfi("debug bogus")
    assert.is_truthy(Stub.prints[1]:find("unknown command 'debug bogus'", 1, true))
    Stub.prints = {}
    wfi("debug quest")
    assert.is_truthy(Stub.prints[1]:find("usage: /wfi debug quest <id>", 1, true))
    Stub.prints = {}
    wfi("debug quest 2.5")
    assert.is_truthy(Stub.prints[1]:find("usage: /wfi debug quest <id>", 1, true))
    Stub.prints = {}
    wfi("debug")
    assert.is_truthy(table.concat(Stub.prints, "\n"):find("data: quests %d+")) -- the shipped quest count
    assert.is_truthy(table.concat(Stub.prints, "\n"):find("placeholders: 0 unknown tokens seen", 1, true))
  end)

  it("debug prints font failures with pending and per-surface detail; debug fonts retries now", function()
    wfi("debug")
    assert.is_truthy(table.concat(Stub.prints, "\n"):find("font failures: 0 (0 pending)", 1, true))
    Stub.prints = {}
    wfi("debug fonts")
    local out = table.concat(Stub.prints, "\n")
    assert.is_truthy(out:find("fonts: no retry started", 1, true))
    assert.is_truthy(out:find("fonts: records pending 0 → 0 after a retry now · own widgets pending 0", 1, true))
  end)

  it("debug objective prints the objective index counts, area rows included", function()
    wfi("debug objective")
    local c = WFI.ObjectiveIndex.counts
    assert.are.equal(WFI.Data.count("objective") + WFI.Data.count("area"), c.shipped)
    assert.are.equal(WFI.Data.count("objective"), c.byType.objective)
    assert.are.equal(WFI.Data.count("area"), c.byType.area)
    assert.are.equal(c.shipped, c.indexed + c.ambiguous)
    assert.is_truthy(table.concat(Stub.prints, "\n"):find(
      ("objectives: shipped %d (objective %d · area %d) · indexed %d · ambiguous %d")
      :format(c.shipped, c.byType.objective, c.byType.area, c.indexed, c.ambiguous), 1, true))
  end)

  it("debug ui prints the UI index counts and the unresolved keys", function()
    wfi("debug ui")
    local out = table.concat(Stub.prints, "\n")
    local n = WFI.Data.count("ui")
    -- the stub client defines almost no UI globals: fingerprint rows are hashed, the rest unresolved (the tooltip
    -- stub's ITEM_SPELL_TRIGGER_ONEQUIP is the one global-string key it holds)
    local c = WFI.UIIndex.counts
    -- `ambiguous` is part of the accounting, not assumed zero. Two shipped rows whose English the Forever import
    -- made identical land there, and the index shows neither rather than guess between them, so the total only
    -- balances when they are counted. `mismatched` stays a real number for the same reason.
    assert.is_true(c.hashed > 0 and c.unresolved > 0)
    assert.are.equal(n, c.indexed + c.hashed + c.unresolved + c.ambiguous + c.mismatched)
    assert.is_truthy(out:find(("ui: shipped %d · indexed %d · hashed %d · mismatched %d · ambiguous %d · unresolved %d")
      :format(n, c.indexed, c.hashed, c.mismatched, c.ambiguous, c.unresolved), 1, true))
    assert.is_truthy(out:find(" · unsupported 0", 1, true))
    assert.is_truthy(out:find("  unresolved: ", 1, true))
    assert.is_truthy(out:find(" … +" .. (c.unresolved - 10), 1, true))
    Stub.prints = {}
    wfi("debug")
    assert.is_truthy(table.concat(Stub.prints, "\n"):find("ui: shipped " .. n, 1, true))
  end)

  it("config opens the panel through Compat; debug prints without error", function()
    wfi("config")
    assert.are.same({ "OpenToCategory", 42 }, Stub.settingsCalls[#Stub.settingsCalls])
    -- the subpages by name; an unknown page opens the main one
    wfi("config collector")
    assert.are.same({ "OpenToCategory", 43 }, Stub.settingsCalls[#Stub.settingsCalls])
    wfi("config ABOUT")
    assert.are.same({ "OpenToCategory", 44 }, Stub.settingsCalls[#Stub.settingsCalls])
    wfi("config nope")
    assert.are.same({ "OpenToCategory", 42 }, Stub.settingsCalls[#Stub.settingsCalls])
    Stub.prints = {}
    assert.has_no.errors(function() wfi("debug") end)
    -- this stub builds no window the window modules declare; the quest, tooltip and game menu names all resolve
    assert.is_truthy(Stub.prints[1]:find("unresolved widgets:", 1, true))
    -- a surface's own names, at the start of a list entry ("friends.tooltip.…" is another surface's)
    for _, ns in ipairs({ "questframe%.", "tooltip%.", "gamemenu%.", "scan%." }) do
      assert.is_nil(Stub.prints[1]:find("[ ,]" .. ns), ns)
    end
    local out = table.concat(Stub.prints, "\n")
    assert.is_truthy(out:find("modifier: alt (either)", 1, true))
    assert.is_truthy(out:find("addon list button: absent", 1, true))
  end)

  it("/wfi modifier takes any key, refuses the main mouse button, and status names the key", function()
    wfi("modifier q")
    assert.are.equal("Q", S.get("modifier"))
    assert.is_truthy(Stub.prints[#Stub.prints]:find("modifier = Q", 1, true))
    wfi("modifier button1")
    assert.is_truthy(Stub.prints[#Stub.prints]:find("expected a key", 1, true))
    assert.are.equal("Q", S.get("modifier"))
    Stub.prints = {}
    wfi("")
    assert.is_truthy(Stub.prints[1]:find("hold Q for English", 1, true))
    Stub.prints = {}
    wfi("debug")
    assert.is_truthy(table.concat(Stub.prints, "\n"):find("modifier: Q (bound · override applied)", 1, true))
  end)

  it("/wfi modifier on a key with an action says it is taken over; a polled key in combat applies now", function()
    Stub.bindings.W = "MOVEFORWARD"
    wfi("modifier w")
    assert.is_truthy(Stub.prints[#Stub.prints - 1]:find("modifier = W", 1, true))
    assert.is_truthy(Stub.prints[#Stub.prints]:find('W was used for "Move Forward"', 1, true))
    Stub.combat = true
    wfi("modifier lalt")
    assert.is_truthy(Stub.prints[#Stub.prints]:find("modifier = lalt", 1, true))
    assert.is_nil(Stub.prints[#Stub.prints]:find("after combat", 1, true))
  end)

  it("a modifier set in combat says it takes effect after combat", function()
    Stub.combat = true
    Stub.bindingCalls = {}
    wfi("modifier f5")
    assert.is_truthy(Stub.prints[#Stub.prints]:find("modifier = F5: takes effect after combat", 1, true))
    assert.are.same({}, Stub.bindingCalls)
  end)
end)

describe("/wfi debug gossip", function()
  it("prints the entry count and each open gossip line's record, key and status", function()
    Stub.install(H.ADDON_DIR .. "/WoWForeverItalian.toc")
    Stub.installQuestAPI(); Stub.installTooltipAPI(); Stub.installGossipAPI()
    local WFI = Loader.load("WoWForeverItalian")
    Stub.fireAll("ADDON_LOADED", "WoWForeverItalian")
    local player = { name = "Reyn", class = "Hunter", race = "Night Elf" }
    local key = WFI.Collector.key("Hello there.", player)
    WFI.Data.add("gossip", { [key] = { "やあ。", "." } })
    local count = ("WFI: gossip entries: %d"):format(WFI.Data.count("gossip"))
    Stub.prints = {}
    SlashCmdList.WFI("debug gossip")
    assert.are.same({ count, "  no gossip window open" }, Stub.prints)

    Stub.showGossip({ text = "Hello there.", options = { "Goodbye." } })
    assert.are.equal("やあ。", GossipFrame.GreetingPanel.ScrollBox.frames[1].GreetingText:GetText())
    Stub.prints = {}
    SlashCmdList.WFI("debug gossip")
    assert.are.same({
      count,
      "  gossip greeting " .. key .. " trusted",
      "  gossip option.0 " .. WFI.Collector.key("Goodbye.", player) .. " none",
    }, Stub.prints)
  end)
end)

describe("/wfi debug book", function()
  it("prints the entry count, then the open page's keys, the shipped key and its record", function()
    Stub.install(H.ADDON_DIR .. "/WoWForeverItalian.toc")
    Stub.installQuestAPI(); Stub.installTooltipAPI(); Stub.installGossipAPI()
    Stub.installItemTextAPI()
    local WFI = Loader.load("WoWForeverItalian")
    Stub.fireAll("ADDON_LOADED", "WoWForeverItalian")
    local player = { name = "Reyn", class = "Hunter", race = "Night Elf" }
    local en = "Greetings, Reyn. This page names you."
    local key = WFI.Hash.key(WFI.Normalize.v1("Greetings, $N. This page names you."))
    WFI.Data.add("book", { [key] = { "ようこそ、{name}。このページはあなたの名を記す。", "." } })
    local count = ("WFI: book entries: %d"):format(WFI.Data.count("book"))
    Stub.prints = {}
    SlashCmdList.WFI("debug book")
    assert.are.same({ count, "  no book open" }, Stub.prints)

    Stub.openItemText({ en }) -- through Main: the book key function and the player's name token
    assert.are.equal("ようこそ、Reyn。このページはあなたの名を記す。", WFI.ItemText.page.fs.text)
    Stub.prints = {}
    SlashCmdList.WFI("debug book")
    assert.are.same({
      count,
      "  keys: " .. table.concat(WFI.Collector.keys(en, player), " "),
      "  shipped: " .. key .. " · record: Japanese",
    }, Stub.prints)
  end)
end)

describe("/wfi collector", function()
  local WFI, S
  before_each(function()
    Stub.install(H.ADDON_DIR .. "/WoWForeverItalian.toc")
    Stub.installQuestAPI(); Stub.installTooltipAPI(); Stub.installGossipAPI()
    WFI = Loader.load("WoWForeverItalian")
    Stub.fireAll("ADDON_LOADED", "WoWForeverItalian")
    S = WFI.Settings
    Stub.prints = {}
  end)

  local function wfi(line) SlashCmdList.WFI(line) end
  local function last() return Stub.prints[#Stub.prints] end

  it("remind off / remind on set collector.remind, the command the reminder line names", function()
    wfi("collector remind off")
    assert.is_false(S.get("collector.remind"))
    assert.is_true(S.get("collector.enabled")) -- collecting goes on
    wfi("collector remind on")
    assert.is_true(S.get("collector.remind"))
  end)

  it("prints the status line bare and with status", function()
    WFI.Collector.record("quest", 9999, "title", "A Forever Quest")
    wfi("collector")
    assert.is_truthy(last():find("WFI: collector on · 1 entry (1 unsent) · ", 1, true))
    assert.is_truthy(last():find(" of 4.0 MB", 1, true))
    wfi("collector status")
    assert.is_truthy(last():find("WFI: collector on · 1 entry", 1, true))
  end)

  it("on / off set collector.enabled; other words fall through to the registry", function()
    wfi("collector off")
    assert.is_false(S.get("collector.enabled"))
    assert.is_truthy(last():find("collector off", 1, true))
    wfi("collector on")
    assert.is_true(S.get("collector.enabled"))
    wfi("collector enabled off")
    assert.is_false(S.get("collector.enabled"))
    assert.is_truthy(last():find("collector.enabled = off", 1, true))
  end)

  it("path prints <ACCOUNT> as a literal placeholder, the counts and how to send", function()
    WFI.Collector.record("quest", 9999, "title", "A Forever Quest")
    wfi("collector path")
    local text = table.concat(Stub.prints, "\n")
    assert.is_truthy(text:find("<ACCOUNT>", 1, true))
    assert.is_truthy(text:find("SavedVariables\\WoWForeverItalian.lua", 1, true))
    assert.is_truthy(text:find("log out or /reload", 1, true))
    assert.is_truthy(text:find("1 entry", 1, true))
    assert.is_truthy(text:find("/wfi collector send", 1, true))
    assert.is_truthy(text:find("World of Warcraft\\_forever_\\WTF", 1, true))
  end)

  it("send opens the send window; send all packs every line again", function()
    local opened = {}
    local real = WFI.CollectorSendWindow.open
    WFI.CollectorSendWindow.open = function(all) opened[#opened + 1] = all end
    wfi("collector send")
    wfi("collector send all")
    wfi("collector SEND ALL")
    WFI.CollectorSendWindow.open = real
    assert.are.same({ false, true, true }, opened)
  end)

  it("clear empties the dump, keeps the disclosure flag and prints the count", function()
    Stub.fireAll("PLAYER_ENTERING_WORLD")
    WFI.Collector.record("quest", 9999, "title", "A Forever Quest")
    WFI.Collector.record("quest", 9999, "description", "New text.")
    wfi("collector clear")
    wfi("collector clear") -- the second within 5 s clears
    assert.is_truthy(last():find("collector cleared (2)", 1, true))
    assert.are.same({}, WFI_Collector.entries)
    assert.is_true(WFI_Collector.disclosed)
  end)

  it("/wfi debug includes the collector line", function()
    wfi("debug")
    local found = false
    for _, line in ipairs(Stub.prints) do
      if line:find("WFI: collector: on · 0 entries", 1, true) then found = true end
    end
    assert.is_true(found)
  end)
end)

describe("slash / options parity", function()
  local WFI, S, now
  before_each(function()
    Stub.install(H.ADDON_DIR .. "/WoWForeverItalian.toc")
    Stub.installQuestAPI(); Stub.installTooltipAPI(); Stub.installGossipAPI()
    WFI = Loader.load("WoWForeverItalian")
    Stub.fireAll("ADDON_LOADED", "WoWForeverItalian")
    S = WFI.Settings
    now = 100
    _G.GetTime = function() return now end
    Stub.prints, Stub.bindingCalls = {}, {}
  end)

  local function wfi(line) SlashCmdList.WFI(line) end
  local function last() return Stub.prints[#Stub.prints] end
  local function sets()
    local n = 0
    for _, c in ipairs(Stub.bindingCalls) do if c[1] == "SetBinding" then n = n + 1 end end
    return n
  end

  it("togglekey binds the parsed chord, case-insensitively, meta keys in the client's order", function()
    for _, typed in ipairs({ "ctrl-j", "CTRL-J", "Ctrl-J" }) do
      wfi("togglekey " .. typed)
      assert.are.equal("WFI_TOGGLE", Stub.bindings["CTRL-J"], typed)
      assert.are.equal("WFI: togglekey = CTRL-J", last())
    end
    wfi("togglekey shift-ctrl-q")
    assert.are.equal("WFI_TOGGLE", Stub.bindings["CTRL-SHIFT-Q"])
    assert.is_nil(Stub.bindings["CTRL-J"]) -- the old key is replaced, like the page
    wfi("togglekey f5")
    assert.are.equal("WFI_TOGGLE", Stub.bindings.F5)
    assert.are.same({ "SaveBindings", 2 }, Stub.bindingCalls[#Stub.bindingCalls])
  end)

  it("bare togglekey reads the key; none unbinds it; status lists it", function()
    wfi("togglekey")
    assert.are.equal("WFI: togglekey = not set", last())
    Stub.bindings.BUTTON4 = "WFI_TOGGLE"
    wfi("togglekey")
    assert.are.equal("WFI: togglekey = Mouse Button 4", last())
    Stub.prints = {}
    wfi("")
    assert.is_truthy(table.concat(Stub.prints, "\n"):find("  togglekey = Mouse Button 4", 1, true))
    wfi("togglekey none")
    assert.is_nil(Stub.bindings.BUTTON4)
    assert.are.equal("WFI: togglekey = not set", last())
  end)

  it("refuses malformed chords, lone modifiers, the main buttons, Escape and the modifier's key", function()
    wfi("modifier q")
    Stub.bindingCalls = {}
    for _, typed in ipairs({ "ctrl-", "ctrl-ctrl-j", "foo-j", "alt", "lshift", "ctrl-alt", "button1", "button2",
        "escape", "q" }) do
      wfi("togglekey " .. typed)
      assert.is_truthy(last():find("^WFI: togglekey: "), typed .. " → " .. last())
    end
    assert.is_truthy(last():find("the key you hold for English", 1, true))
    assert.are.equal(0, sets())
  end)

  it("in combat nothing is written", function()
    Stub.bindings.F5 = "WFI_TOGGLE"
    Stub.combat = true
    wfi("togglekey f6")
    assert.is_truthy(last():find("cannot change in combat", 1, true))
    wfi("togglekey none")
    assert.is_truthy(last():find("cannot change in combat", 1, true))
    assert.are.equal(0, sets())
    assert.are.equal("WFI_TOGGLE", Stub.bindings.F5)
  end)

  it("a key bound elsewhere is replaced only when the command is repeated within 5 s", function()
    Stub.bindings.W = "MOVEFORWARD"
    wfi("togglekey w")
    assert.are.equal('WFI: W is used for "Move Forward"; type the same command again within 5 seconds to replace it',
      last())
    assert.are.equal(0, sets())
    now = now + 6
    wfi("togglekey w") -- too late: asks again
    assert.are.equal("MOVEFORWARD", Stub.bindings.W)
    wfi("togglekey")   -- another command in between forgets it
    now = now + 1
    wfi("togglekey w")
    assert.are.equal("MOVEFORWARD", Stub.bindings.W)
    now = now + 4
    wfi("togglekey W") -- same command (case-insensitive), within 5 s
    assert.are.equal("WFI_TOGGLE", Stub.bindings.W)
    assert.are.equal("WFI: togglekey = W", last())
  end)

  it("/wfi readings on|off sets readings.enabled; the long forms still work", function()
    wfi("readings off")
    assert.is_false(S.get("readings.enabled"))
    assert.are.equal("WFI: readings off", last())
    wfi("readings")
    assert.are.equal("WFI: readings off", last())
    wfi("readings ON")
    assert.is_true(S.get("readings.enabled"))
    wfi("readings enabled off")
    assert.is_false(S.get("readings.enabled"))
    wfi("readings glosses off")
    assert.is_false(S.get("readings.glosses"))
  end)

  it("collector clear asks first and clears on the repeat within 5 s", function()
    WFI.Collector.record("quest", 9999, "title", "A Forever Quest")
    wfi("collector clear")
    assert.are.equal("WFI: type /wfi collector clear again within 5 seconds to clear 1 entry", last())
    assert.are.equal(1, WFI.Collector.status().entries)
    now = now + 3
    wfi("collector clear")
    assert.are.equal("WFI: collector cleared (1)", last())
    WFI.Collector.record("quest", 9999, "title", "A Forever Quest")
    wfi("collector clear")
    now = now + 6
    wfi("collector clear")
    assert.is_truthy(last():find("again within 5 seconds", 1, true))
    assert.are.equal(1, WFI.Collector.status().entries)
  end)

  it("an empty dump clears without asking; a newer version's file is never cleared and never asks", function()
    wfi("collector clear")
    assert.are.equal("WFI: collector cleared (0)", last())
    Stub.install(H.ADDON_DIR .. "/WoWForeverItalian.toc")
    Stub.installQuestAPI(); Stub.installTooltipAPI(); Stub.installGossipAPI()
    _G.WFI_Collector = { version = 2, entries = { anything = { kept = true } } }
    WFI = Loader.load("WoWForeverItalian")
    Stub.fireAll("ADDON_LOADED", "WoWForeverItalian")
    assert.is_true(WFI.Collector.status().readOnly)
    Stub.prints = {}
    wfi("collector clear")
    assert.are.same({ "WFI: collector file is from a newer version; not cleared" }, Stub.prints)
    assert.are.same({ kept = true }, WFI_Collector.entries.anything)
  end)

  it("togglekey refuses + chords, made-up names, the wheel, a second word; readings names its own error", function()
    for _, typed in ipairs({ "ctrl+j", "foo", "ctrl-foo", "mousewheelup", "-j", "f25" }) do
      wfi("togglekey " .. typed)
      assert.is_truthy(last():find("^WFI: togglekey: "), typed .. " → " .. last())
    end
    assert.is_truthy(Stub.prints[1]:find("use - between keys", 1, true))
    wfi("togglekey ctrl j")
    assert.are.equal("WFI: togglekey: one key, with - between its parts (ctrl-j)", last())
    assert.are.equal(0, sets())
    wfi("readings bogus")
    assert.are.equal("WFI: readings: expected on|off", last())
  end)

  it("togglekey writes nothing when the client cannot report combat, and says so", function()
    Stub.bindings.F5 = "WFI_TOGGLE"
    _G.InCombatLockdown = nil
    wfi("togglekey f6")
    assert.are.equal("WFI: togglekey: key bindings are not available on this client", last())
    wfi("togglekey none")
    assert.are.equal("WFI: togglekey: key bindings are not available on this client", last())
    assert.are.equal(0, sets())
    assert.are.equal("WFI_TOGGLE", Stub.bindings.F5)
  end)
end)
