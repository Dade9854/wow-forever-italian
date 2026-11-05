-- UI/FixWindow: pick a line, say what is wrong, keep it pending, copy the report out.
local H = require("tests.lua.spec.helpers")
local Stub = require("tests.lua.spec.wow_stub")
local F = require("tests.lua.spec.stub_fixwindow")
local Loader = require("tests.lua.spec.loader")

local FILES = { "Core/Const.lua", "Core/Compat.lua", "Core/Normalize.lua", "Core/Hash.lua", "Core/State.lua",
  "Core/Settings.lua", "Core/Modifier.lua", "Core/RecentLines.lua", "Core/Reports.lua", "Core/ReportText.lua",
  "UI/Font.lua", "UI/OptionsText.lua", "UI/OptionsWidgets.lua", "UI/FixWindow.lua" }

local ENGLISH = "Welcome, traveler. This land has been in darkness." -- what the client would show; never ours to show
local ROWS = {
  ["quest.description"] = { [7] = { ja = "旅の者よ、よく来てくれた。\n長い間、この地は闇の中だ。", status = "." } },
  ["quest.title"] = { [7] = { ja = "旅立ち", status = "." } },
  gossip = { ["0001ce030c010973"] = { ja = "ようこそ。", status = "." } },
  ui = { OKAY = { ja = "了解", status = "." } },
}

local function load()
  Stub.install(H.ADDON_DIR .. "/WoWForeverItalian.toc")
  F.install()
  local WFI = H.loadChunks(FILES)
  WFI.Compat.init(function(name) return _G[name] end)
  local db = WFI.Settings.load(nil, 1, {})
  WFI.Reports.load(db)
  WFI.Lookup = { get = function(kind, id) return ROWS[kind] and ROWS[kind][id] or nil end }
  _G.QUEST_7_ENGLISH = ENGLISH
  WFI.RecentLines.note("quest.title", 7, "questframe")
  WFI.RecentLines.note("gossip", "0001ce030c010973", "gossip")
  WFI.RecentLines.note("quest.description", 7, "questframe")
  return WFI, db
end

describe("the fix window", function()
  local WFI, FW

  before_each(function()
    WFI = load()
    FW = WFI.FixWindow
  end)
  after_each(function() F.clear(); _G.QUEST_7_ENGLISH = nil end)

  -- the i-th pooled row of a page's ScrollBox list (a missing row reads as hidden)
  local function row(page, i)
    return FW.pages[page].list.box.frames[i] or { IsShown = function() return false end }
  end
  local function tab(id) return FW.frame.tabs[id] end
  local function edit() return FW.pages.edit end

  it("a language flip with no widget on screen only marks them stale; showing re-draws them",
    function()
    local W = WFI.OptionsWidgets -- the window is not built yet: this label is the only widget on the list
    local owner = CreateFrame("Frame")
    owner:Hide()
    local l = W.label(owner, "English", "日本語", 0, 0, 100)
    assert.are.equal("日本語", l.en:GetText())
    Stub.keys.alt = true
    WFI.Modifier.refresh()
    assert.is_true(W.stale)
    assert.are.equal("日本語", l.en:GetText()) -- nothing re-drawn off screen
    W.relabelIfStale()
    assert.is_false(W.stale)
    assert.are.equal("English", l.en:GetText())
    owner:Show()
    Stub.keys.alt = false
    WFI.Modifier.refresh() -- on screen: re-drawn at once
    assert.are.equal("日本語", l.en:GetText())
  end)

  it("lists the recent lines newest first with the type and the Japanese shown", function()
    local f = FW.open()
    assert.is_true(f:IsShown())
    assert.are.equal("recent", FW.current)
    assert.are.equal("Quest", row("recent", 1).left:GetText())
    assert.are.equal("旅の者よ、よく来てくれた。 長い間、この地は闇の中だ。", row("recent", 1).text:GetText())
    assert.are.equal("Dialogo NPC", row("recent", 2).left:GetText())
    assert.are.equal("旅立ち", row("recent", 3).text:GetText())
    assert.is_false(row("recent", 4):IsShown())
    assert.are.equal("Traduzioni", tab("recent").caption:GetText())
    assert.are.equal("In attesa (0)", tab("pending").caption:GetText())
  end)

  it("filters the recent lines by group with radio buttons; All is first and the default", function()
    assert.are.equal("all", FW.filter)
    FW.open()
    local F_ = FW.pages.recent.filters
    assert.are.equal("TOPLEFT", F_.all.point[1]) -- All leads the row; the others follow the previous label
    assert.are.same({ "LEFT", F_.all.text, "RIGHT" }, { F_.story.point[1], F_.story.point[2], F_.story.point[3] })
    assert.is_true(F_.all:GetChecked())
    FW.filter = "story"
    WFI.RecentLines.note("ui", "OKAY", "s", "了解")
    FW.open()
    for i = 1, 4 do
      local left = row("recent", i):IsShown() and row("recent", i).left:GetText() or ""
      assert.is_nil(left:find("画面の文字", 1, true))
    end
    FW.setFilter("windows")
    assert.are.equal("Testo delle finestre", row("recent", 1).left:GetText())
    assert.is_false(row("recent", 2):IsShown())
    FW.setFilter("all")
    assert.is_true(row("recent", 4):IsShown())
    assert.is_true(F_.all:GetChecked())
    assert.is_false(F_.windows:GetChecked())
  end)

  it("a radio's clickable area is its circle plus its own label, never the next option's", function()
    FW.open()
    for _, b in pairs(FW.pages.recent.filters) do
      assert.are.same({ 0, -(b.text:GetStringWidth() + 8), -3, -3 }, b.hitRect)
    end
    for _, b in pairs(FW.pages.edit.reasons) do assert.is_table(b.hitRect) end
  end)

  it("a line written while the list is open appears on the next frame, redrawn once", function()
    FW.open()
    assert.is_false(row("recent", 4):IsShown())
    WFI.RecentLines.note("quest.title", 7, "questframe", nil, 50.0)
    WFI.RecentLines.note("quest.description", 7, "questframe", nil, 50.0)
    local tick = FW.frame.scripts.OnUpdate
    assert.is_function(tick)
    tick(FW.frame)
    assert.is_nil(FW.frame.scripts.OnUpdate) -- cleared: no polling once drawn
    assert.are.equal("旅立ち", row("recent", 1).text:GetText())
    FW.frame:Hide()
    WFI.RecentLines.note("gossip", "0001ce030c010973", "gossip", nil, 60.0)
    assert.is_nil(FW.frame.scripts.OnUpdate) -- a closed window is not redrawn
  end)

  it("an empty log says to read some text first", function()
    WFI.RecentLines.clear()
    FW.open()
    assert.are.equal("Ancora niente. Leggi qualche testo di quest o di NPC, poi riapri questa finestra.",
      FW.pages.recent.empty.en:GetText())
  end)

  it("a row opens the edit panel on exactly that address, the Japanese pre-filled", function()
    FW.open()
    row("recent", 2):click()
    assert.are.equal("edit", FW.current)
    assert.are.same({ "gossip", "0001ce030c010973", "text", WFI.Hash.key("ようこそ。") },
      { FW.edit.type, FW.edit.id, FW.edit.field, FW.edit.ja_hash })
    assert.are.equal("ようこそ。", edit().ja.box:GetText())
    assert.are.equal("ようこそ。", edit().ja.box:GetText())
    assert.are.equal("", edit().note:GetText())
    assert.is_false(edit().delete:IsShown())
  end)

  it("no reason → refused with a message; Save keeps the Japanese only when it was changed", function()
    FW.open()
    row("recent", 1):click()
    edit().save:click()
    assert.are.equal(0, WFI.Reports.count())
    assert.are.equal("Prima scegli cosa c'è che non va.", FW.frame.message:GetText())
    edit().reasons.awkward:click()
    edit().save:click()
    assert.are.equal(1, WFI.Reports.count())
    local fix = WFI.Reports.list()[1]
    assert.are.equal("awkward", fix.reason)
    assert.is_nil(fix.ja) -- the box was left as shown
    assert.are.equal("pending", FW.current)
    -- changed Japanese + a note, saved over the first (second click)
    FW.show("recent")
    row("recent", 1):click()
    edit().ja.box:SetText("旅人よ、よく来た。")
    edit().note:SetText("too formal")
    edit().reasons.wrong:click()
    edit().save:click()
    assert.are.equal(1, WFI.Reports.count()) -- opened from the recent list, it asked first
    assert.is_truthy(FW.frame.message:GetText():find("Clicca ancora", 1, true))
    edit().save:click()
    fix = WFI.Reports.list()[1]
    assert.are.same({ "wrong", "旅人よ、よく来た。", "too formal" }, { fix.reason, fix.ja, fix.note })
  end)

  it("Save with the box untouched stores the reason alone (one Save button, no second button)", function()
    FW.open()
    row("recent", 3):click()
    edit().reasons.typo:click()
    assert.is_nil(edit().noSuggestion)
    edit().save:click()
    local fix = WFI.Reports.list()[1]
    assert.are.same({ "quest", 7, "title", "typo" }, { fix.type, fix.id, fix.field, fix.reason })
    assert.is_nil(fix.ja)
  end)

  it("the player's own name, typed into the Japanese or the note, is saved as the placeholder", function()
    FW.open()
    row("recent", 1):click()
    edit().ja.box:SetText("Reynよ、よく来た。")
    edit().note:SetText("it should greet reyn by name")
    edit().reasons.wrong:click()
    edit().save:click()
    local fix = WFI.Reports.list()[1]
    assert.are.same({ "{name}よ、よく来た。", "it should greet {name} by name" }, { fix.ja, fix.note })
    assert.is_nil(fix.t)
    local report = WFI.ReportText.serialize(WFI.VERSION, "1.60.1.70009", WFI.Reports.list())
    assert.is_nil(report:lower():find("reyn", 1, true))
  end)

  it("a game name that equals the player's name stays as written in a saved fix", function()
    -- the stub's player is "Reyn"; here the stored line carries Reyn as an NPC name
    local stored = ROWS["quest.description"][7]
    local original = stored.ja
    stored.ja = "Reynの元へ行け。"
    WFI.RecentLines.note("quest.description", 7, "questframe") -- the line as the player just saw it
    FW.open()
    row("recent", 1):click()
    edit().note:SetText("Reyn is the quest giver here")
    edit().ja.box:SetText("Reynのところへ行け。")
    edit().reasons.wrong:click()
    edit().save:click()
    local fix = WFI.Reports.list()[1]
    assert.are.same({ "Reyn is the quest giver here", "Reynのところへ行け。" }, { fix.note, fix.ja })
    stored.ja = original
  end)

  it("the reasons are radio buttons: one choice", function()
    FW.open()
    row("recent", 1):click()
    edit().reasons.wrong:click()
    edit().reasons.name:click()
    assert.is_false(edit().reasons.wrong:GetChecked())
    assert.is_true(edit().reasons.name:GetChecked())
    assert.are.equal("name", FW.edit.reason)
  end)

  it("the pending page lists fixes; one opens for edit and can be deleted", function()
    WFI.Reports.save({ type = "quest", id = 7, field = "title", ja_hash = WFI.Hash.key("旅立ち"), reason = "typo",
      note = "missing particle" })
    FW.open("pending")
    -- the type with the reason under it on the left, the Japanese beside them
    assert.are.equal("Quest\nRefuso / testo rovinato", row("pending", 1).left:GetText())
    assert.are.equal("旅立ち", row("pending", 1).text:GetText())
    row("pending", 1):click()
    assert.are.equal("missing particle", edit().note:GetText())
    assert.is_true(edit().reasons.typo:GetChecked())
    assert.is_true(edit().delete:IsShown())
    edit().reasons.other:click()
    edit().save:click() -- opened from the fix itself: replaced at once
    assert.are.equal("other", WFI.Reports.list()[1].reason)
    row("pending", 1):click()
    edit().delete:click()
    assert.are.equal(0, WFI.Reports.count())
    assert.are.equal("Nessuna segnalazione salvata.", FW.pages.pending.empty.en:GetText())
  end)

  it("the 26th fix is refused with a message", function()
    for i = 1, WFI.Reports.CAP do
      WFI.Reports.save({ type = "quest", id = 1000 + i, field = "title", ja_hash = "0011223344556677",
        reason = "other" })
    end
    FW.open()
    row("recent", 1):click()
    edit().reasons.wrong:click()
    edit().save:click()
    assert.are.equal(WFI.Reports.CAP, WFI.Reports.count())
    assert.are.equal(select(2, WFI.OptionsText.get("fix.full", WFI.Reports.CAP)), FW.frame.message:GetText())
  end)

  it("Copy report shows the serialized report, selected; the issue form URL; clear asks first", function()
    WFI.Reports.save({ type = "quest", id = 7, field = "title", ja_hash = WFI.Hash.key("旅立ち"), reason = "typo",
      ja = "旅|立ち" })
    FW.open("copy")
    local text = FW.pages.copy.report.box:GetText()
    assert.are.equal(WFI.ReportText.serialize(WFI.VERSION, "1.15.9.69722", WFI.Reports.list()), text)
    assert.are.equal(FW.reportText(), text)
    assert.is_truthy(text:find("fix quest 7 title " .. WFI.Hash.key("旅立ち") .. " typo\nja 旅\\x7c立ち\n", 1, true))
    assert.is_true(FW.pages.copy.report.box.focused)
    assert.is_true(FW.pages.copy.report.box.highlighted)
    assert.are.equal(WFI.OptionsText.FIX_URL, FW.pages.copy.url.value)
    FW.pages.copy.clear:click()
    assert.are.equal(1, WFI.Reports.count())
    assert.are.equal("Clicca ancora per cancellare 1 segnalazioni", FW.pages.copy.clear.caption:GetText())
    FW.pages.copy.clear:click()
    assert.are.equal(0, WFI.Reports.count())
    assert.are.equal("", FW.pages.copy.report.box:GetText())
  end)

  it("Clear removes only the reports the copied text held; one saved after stays", function()
    WFI.Reports.save({ type = "quest", id = 7, field = "title", ja_hash = WFI.Hash.key("旅立ち"), reason = "typo" })
    FW.open("copy") -- the report is rendered with one fix
    WFI.Reports.save({ type = "gossip", id = "0001ce030c010973", field = "text", ja_hash = WFI.Hash.key("ようこそ。"),
      reason = "awkward" }) -- saved after the copy, never sent
    FW.pages.copy.clear:click()
    assert.are.equal("Clicca ancora per cancellare 1 segnalazioni", FW.pages.copy.clear.caption:GetText())
    FW.pages.copy.clear:click()
    assert.are.equal(1, WFI.Reports.count())
    assert.are.equal("gossip", WFI.Reports.list()[1].type)
  end)

  it("an armed Clear that runs out puts its caption back", function()
    WFI.Reports.save({ type = "quest", id = 7, field = "title", ja_hash = WFI.Hash.key("旅立ち"), reason = "typo" })
    FW.open("copy")
    local t = 50
    _G.GetTime = function() return t end
    FW.pages.copy.clear:click()
    local tick = FW.pages.copy.clear.scripts.OnUpdate
    assert.is_function(tick)
    t = t + 10
    tick(FW.pages.copy.clear)
    assert.are.equal("Cancella le segnalazioni inviate", FW.pages.copy.clear.caption:GetText())
    assert.is_nil(FW.pages.copy.clear.scripts.OnUpdate)
    assert.are.equal(1, WFI.Reports.count())
    _G.GetTime = function() return 0 end
  end)

  it("the report box has no letter limit", function()
    FW.open("copy")
    assert.are.equal(0, FW.pages.copy.report.box.maxLetters)
  end)

  it("Save: carriage returns and a cut-down copy are no change; the note is trimmed",
    function()
    FW.open()
    row("recent", 3):click() -- quest 7 title 旅立ち
    local e = FW.edit
    e.ja = "旅\r立ち" -- a stored line holding a CR the edit box dropped
    edit().ja.box:SetText("旅立ち")
    edit().note:SetText("   ")
    edit().reasons.typo:click()
    edit().save:click()
    local fix = WFI.Reports.list()[1]
    assert.is_nil(fix.ja) -- unchanged: no Japanese of the player's
    assert.is_nil(fix.note) -- only spaces: no note
    FW.open()
    row("recent", 3):click()
    FW.edit.ja = "長い文の全部"
    edit().ja.box:SetText("長い文") -- an edit box that cut a long line
    edit().note:SetText("  stiff  ")
    edit().reasons.wrong:click()
    edit().save:click() -- the line already has a fix: the first Save asks
    edit().save:click()
    fix = WFI.Reports.list()[1]
    assert.is_nil(fix.ja)
    assert.are.equal("stiff", fix.note)
  end)

  it("Save with the saved settings missing says so", function()
    WFI.Reports.load(nil)
    FW.open()
    row("recent", 1):click()
    edit().reasons.wrong:click()
    edit().save:click()
    assert.are.equal(select(2, WFI.OptionsText.get("fix.unavailable")), FW.frame.message:GetText())
  end)

  it("a row whose shown text is empty falls back to the stored Japanese; a CR never reaches a row", function()
    WFI.RecentLines.clear()
    WFI.RecentLines.note("quest.title", 7, "questframe", "")
    FW.open()
    assert.are.equal("旅立ち", row("recent", 1).text:GetText())
  end)

  it("a read-only report box snaps back after a keystroke", function()
    WFI.Reports.save({ type = "quest", id = 7, field = "title", ja_hash = "0011223344556677", reason = "typo" })
    FW.open("copy")
    local box = FW.pages.copy.report.box
    local before = box:GetText()
    box:SetText("x")
    FW.pages.copy.report.editor.callbacks.OnTextChanged(box, true) -- the ScrollingEditBox's text-changed event
    assert.are.equal(before, box:GetText())
  end)

  it("nothing in the window, the saved fixes or the report is English game text", function()
    FW.open()
    row("recent", 1):click()
    edit().reasons.wrong:click()
    edit().save:click()
    FW.open("copy")
    FW.show("pending")
    FW.show("recent")
    assert.is_nil(F.allText():find("traveler", 1, true))
    assert.is_nil(FW.reportText():find("traveler", 1, true))
    for _, fix in ipairs(WFI.Reports.list()) do
      for _, v in pairs(fix) do assert.is_nil(tostring(v):find("traveler", 1, true)) end
    end
    -- and the module reads lines only through RecentLines / Reports / Lookup: no global, frame text or collector
    local src = H.readFile("addon/WoWForeverItalian/UI/FixWindow.lua")
    for _, banned in ipairs({ "_G%[", "Collector", "UIIndex", "english", "%.en%)", "rec%.en" }) do
      assert.is_nil(src:gsub("%-%-[^\n]*", ""):find(banned), banned)
    end
  end)

  it("open → pick a line → reason → save → copy, with the mouse only", function()
    FW.open()
    row("recent", 2):click()
    edit().reasons.awkward:click()
    edit().save:click()
    tab("copy"):click()
    assert.are.equal("copy", FW.current)
    assert.is_truthy(FW.pages.copy.report.box:GetText():find("fix gossip 0001ce030c010973 text", 1, true))
    assert.is_true(FW.pages.copy.report.box.highlighted)
  end)

  it("labels read in Italian; holding the reveal key shows their English", function()
    FW.open()
    row("recent", 1):click()
    assert.are.equal("Traduzioni", FW.frame.tabs.recent.caption:GetText())
    assert.are.equal(WFI.Font.PATH, (FW.frame.tabs.recent.caption:GetFont()))
    for _, rb in pairs(edit().reasons) do
      assert.are_not.equal("", rb.text:GetText())
      assert.are.equal(WFI.Font.PATH, (rb.text:GetFont()))
    end
    Stub.keys.alt = true
    WFI.Modifier.refresh()
    assert.are.equal("Translations", FW.frame.tabs.recent.caption:GetText())
    assert.are.equal("Wrong meaning", edit().reasons.wrong.text:GetText())
    Stub.keys.alt = false
    WFI.Modifier.refresh()
    assert.are.equal("Traduzioni", FW.frame.tabs.recent.caption:GetText())
    WFI.State.setEnabled(false) -- translation off: the window reads in English too
    assert.are.equal("Translations", FW.frame.tabs.recent.caption:GetText())
    WFI.State.setEnabled(true)
    assert.are.equal("Traduzioni", FW.frame.tabs.recent.caption:GetText())
    -- the text fields keep the bundled face: the template's ApplyText puts its own font back, and our hook follows it
    -- (no addon font object)
    assert.are.equal(WFI.Font.PATH, edit().ja.box.font.path) -- the player may type Japanese
    assert.are.equal(WFI.Font.PATH, edit().note.font.path)
    edit().ja:setText("別の文")
    assert.are.equal(WFI.Font.PATH, edit().ja.box.font.path)
  end)
end)

describe("the ways into the fix window with the whole addon loaded", function()
  before_each(function()
    Stub.install(H.ADDON_DIR .. "/WoWForeverItalian.toc")
    F.install()
    Stub.installQuestAPI(); Stub.installTooltipAPI(); Stub.installGossipAPI(); Stub.installItemTextAPI()
    F.scrollUtil() -- the gossip stub replaced ScrollUtil
  end)
  after_each(function() F.clear() end)

  it("/wfi fix, the About page's button and the addon dropdown's left click open it", function()
    local WFI = Loader.load("WoWForeverItalian")
    Stub.fireAll("ADDON_LOADED", "WoWForeverItalian")
    assert.are.same({}, WFI.initErrors)
    _G.SlashCmdList.WFI("fix")
    assert.is_true(_G.WFIFixWindow:IsShown())
    _G.WFIFixWindow:Hide()
    WFI.Options.reportLine:click()
    assert.is_true(_G.WFIFixWindow:IsShown())
    _G.WFIFixWindow:Hide()
    _G.WFI_OnAddonCompartmentClick("WoWForeverItalian", "LeftButton")
    assert.is_true(_G.WFIFixWindow:IsShown())
    _G.WFI_OnAddonCompartmentClick("WoWForeverItalian", "RightButton")
    assert.is_true(_G.WFIMinimapMenu:IsShown()) -- the addon's own menu frame
    _G.WFI_OnAddonCompartmentEnter("WoWForeverItalian", _G.Minimap)
    assert.is_true(_G.WFIMinimapTooltip:IsShown())
    _G.WFI_OnAddonCompartmentLeave("WoWForeverItalian", _G.Minimap)
    assert.is_false(_G.WFIMinimapTooltip:IsShown())
    local help = table.concat(WFI.OptionsText.SLASH, "\n")
    assert.is_truthy(help:find("/wfi fix", 1, true))
  end)
end)
