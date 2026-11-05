-- UI/CollectorSendWindow: one send per window, the steps for each mode, I sent it, and both languages.
local H = require("tests.lua.spec.helpers")
local Stub = require("tests.lua.spec.wow_stub")
local F = require("tests.lua.spec.stub_fixwindow")

local FILES = { "Core/Const.lua", "Core/Compat.lua", "Core/Normalize.lua", "Core/Hash.lua", "Core/State.lua",
  "Core/Settings.lua", "Core/Modifier.lua", "Core/Collector.lua", "Core/CollectorSend.lua", "UI/Font.lua",
  "UI/OptionsText.lua", "UI/OptionsWidgets.lua", "UI/CollectorSendWindow.lua" }

local ENGLISH = "A Forever Quest" -- recorded English: the window never shows it

local function load(out)
  Stub.install(H.ADDON_DIR .. "/WoWForeverItalian.toc")
  F.install()
  local WFI = H.loadChunks(FILES)
  WFI.Compat.init(function(name) return _G[name] end)
  WFI.Settings.load(nil, 1, {})
  WFI.Collector.load(nil, H.collectorDeps())
  WFI.CollectorSend.init({ encode = function() return string.rep("A", out.n) end, version = function() return "1" end })
  return WFI
end

describe("the collector send window", function()
  local WFI, SW, out

  before_each(function()
    out = { n = 40 }
    WFI = load(out)
    SW = WFI.CollectorSendWindow
    WFI.Collector.record("quest", 9999, "title", ENGLISH)
  end)
  after_each(function() F.clear() end)

  local function ja(key, ...) return select(2, WFI.OptionsText.get(key, ...)) end
  local function shown(w) return (w.frame or w):IsShown() end

  it("link mode: the link holds the string, the form opens filled in, I sent it marks the lines", function()
    local f = SW.open()
    assert.is_true(f:IsShown())
    assert.are.equal(ja("send.title"), f.title:GetText())
    assert.are.equal(ja("send.summary", 1, 0), f.summary.en:GetText())
    assert.are.equal(ja("send.step1"), f.step1.en:GetText())
    assert.is_true(shown(f.url))
    assert.is_truthy(f.url:GetText():find("&dump=WFIC1%3AAAAA", 1, true))
    assert.are.equal(ja("send.step2.link"), f.step2.en:GetText())
    assert.is_false(shown(f.text))
    assert.is_false(shown(f.path))
    assert.is_true(shown(f.sent))
    assert.are.equal(ja("send.sent"), f.sent.caption:GetText())
    f.sent.scripts.OnClick(f.sent, "LeftButton")
    assert.are.equal(ja("send.marked", 1), f.message.en:GetText())
    assert.is_false(shown(f.sent))
    assert.are.equal(0, WFI.Collector.status().unsent)
    -- the next send has nothing; send all packs it again
    SW.open()
    assert.are.equal(ja("send.summary.empty"), f.summary.en:GetText())
    assert.is_false(shown(f.url))
    assert.is_false(shown(f.sent))
    SW.open(true)
    assert.are.equal(ja("send.summary", 1, 0), f.summary.en:GetText())
  end)

  it("paste mode shows the string in its own box; file mode shows the file's path", function()
    out.n = 7000
    local f = SW.open()
    assert.are.equal(ja("send.step2.paste"), f.step2.en:GetText())
    assert.is_true(shown(f.text))
    assert.are.equal(WFI.CollectorSend.PREFIX .. string.rep("A", 7000), f.text.value)
    assert.are.equal(WFI.Collector.ISSUE_URL, f.url:GetText())
    out.n = 70000
    SW.open()
    assert.are.equal(ja("send.step2.file"), f.step2.en:GetText())
    assert.is_false(shown(f.text))
    assert.is_true(shown(f.path))
    assert.are.equal(WFI.Collector.path(), f.path:GetText())
    assert.is_true(shown(f.sent))
    -- the line was recorded this session: the saved file does not hold it until /reload
    assert.are.equal(ja("send.later", 1), f.message.en:GetText())
  end)

  it("without the client's encoder the form's link and the file go instead", function()
    WFI.CollectorSend.init({})
    local f = SW.open()
    assert.are.equal(ja("send.summary.unavailable"), f.summary.en:GetText())
    assert.is_true(shown(f.url))
    assert.are.equal(WFI.Collector.ISSUE_URL, f.url:GetText())
    assert.are.equal(ja("send.step2.file"), f.step2.en:GetText())
    assert.is_true(shown(f.path))
    assert.is_true(shown(f.sent))
  end)

  it("a file from a newer version says so and offers nothing to click", function()
    WFI.Collector.load({ version = 2, entries = {}, builds = {} }, H.collectorDeps())
    local f = SW.open()
    assert.are.equal(ja("send.summary.readonly"), f.summary.en:GetText())
    assert.is_false(shown(f.url))
    assert.is_false(shown(f.sent))
  end)

  it("reads English while the reveal key is held, and never shows the recorded English", function()
    local f = SW.open()
    Stub.keys.alt = true
    WFI.Modifier.refresh()
    local en = WFI.OptionsText.get("send.title")
    assert.are.equal(en, f.title:GetText())
    assert.are.equal((WFI.OptionsText.get("send.step1")), f.step1.en:GetText())
    Stub.keys.alt = false
    WFI.Modifier.refresh()
    for _, w in ipairs({ f.summary, f.step1, f.step2, f.step3, f.step4, f.message }) do
      assert.is_nil((w.en:GetText() or ""):find(ENGLISH, 1, true))
    end
    assert.is_nil(f.url:GetText():find(ENGLISH, 1, true))
  end)
end)
