-- UI/CombatLog.lua over the overflow button of camelot
-- blizzard_combatlog/mainline/blizzard_combatlog.xml:34–55, in both load orders. A filter's name is never touched.
local H = require("tests.lua.spec.helpers")
local Stub = require("tests.lua.spec.wow_stub")

local FILES = {}
for i, f in ipairs(H.UI_FILES) do FILES[i] = f end
FILES[#FILES + 1] = "UI/CombatLog.lua"

local ADDON = "Blizzard_CombatLog"
local OVERFLOW = "CombatLogQuickButtonFrame_CustomAdditionalFilterButton"
local UI = { ADDITIONAL_FILTERS = { "Additional Filters", "その他のフィルター" }, ALL = { "All", "すべて" } }

local function loadCombatLog()
  CreateFrame("Button", OVERFLOW)
  Stub.button("CombatLogQuickButtonFrameButton1", "All") -- a filter the player named like a dictionary word
  Stub.loadedAddons[ADDON] = true
end

describe("the combat log quick-button bar on Forever", function()
  local WFI

  local function load()
    Stub.install(H.ADDON_DIR .. "/WoWForeverItalian.toc")
    Stub.installTooltipAPI()
    WFI = H.loadChunks(FILES)
    H.uiSetup(WFI, UI)
  end

  after_each(function()
    H.uiTeardown()
    _G[OVERFLOW], _G.CombatLogQuickButtonFrameButton1 = nil, nil
  end)

  for _, order in ipairs({ { true, "loaded before init" }, { false, "loaded on demand" } }) do
    it("Blizzard_CombatLog " .. order[2] .. ": the overflow hover is Japanese; a filter's name is never touched",
      function()
        load()
        if order[1] then
          loadCombatLog()
          assert.is_true(WFI.CombatLog.init())
        else
          assert.is_false(WFI.CombatLog.init())
          loadCombatLog()
          assert.are.equal(1, WFI.LoadOnDemand.loaded(ADDON))
        end
        assert.are.equal(1, WFI.Labels.forbidNames(WFI.CombatLog.NEVER_TOUCH))
        local tt = _G.GameTooltip
        tt:SetOwner(_G[OVERFLOW])
        tt:SetText(_G.ADDITIONAL_FILTERS)
        assert.are.equal("その他のフィルター", _G.GameTooltipTextLeft1:GetText())
        assert.are.equal(0, WFI.Labels.show("combatlog", "x", _G.CombatLogQuickButtonFrameButton1))
        assert.are.equal("All", _G.CombatLogQuickButtonFrameButton1:GetText())
        assert.is_false(WFI.CombatLog.setup()) -- once
      end)
  end

  it("a wrong-typed button and a missing button both degrade with no error", function()
    load()
    _G[OVERFLOW] = 12
    Stub.loadedAddons[ADDON] = true
    assert.has_no.errors(function() WFI.CombatLog.init() end)
    assert.is_false(WFI.CombatLog.setup())
    load()
    Stub.loadedAddons[ADDON] = true
    assert.has_no.errors(function() WFI.CombatLog.init() end) -- loaded, no button
    assert.is_false(WFI.CombatLog.setup())
  end)
end)
