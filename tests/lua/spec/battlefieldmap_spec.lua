-- UI/BattlefieldMap.lua over a BattlefieldMapTab replayed from camelot
-- blizzard_battlefieldmap/mainline/blizzard_battlefieldmap.xml:3, 41. Either load order.
local H = require("tests.lua.spec.helpers")
local Stub = require("tests.lua.spec.wow_stub")
local Maps = require("tests.lua.spec.stub_maps")

local FILES = {}
for i, f in ipairs(H.UI_FILES) do FILES[i] = f end
FILES[#FILES + 1] = "UI/BattlefieldMap.lua"

local ADDON = "Blizzard_BattlefieldMap"
local UI = { BATTLEFIELD_MINIMAP = { "Zone Map", "ゾーンマップ" }, WORLD = { "World", "ワールド" } }

local function en(key) return _G[key] end

describe("the zone map on Forever", function()
  local WFI, tab

  local function load()
    Stub.install(H.ADDON_DIR .. "/WoWForeverItalian.toc")
    Stub.installTooltipAPI()
    WFI = H.loadChunks(FILES)
    H.uiSetup(WFI, UI)
    Maps.clear()
  end

  after_each(function()
    H.uiTeardown()
    Stub.keys.alt = false
    Maps.clear()
  end)

  for _, order in ipairs({ { true, "loaded at login" }, { false, "loaded on demand" } }) do
    it("Blizzard_BattlefieldMap " .. order[2] .. ": the tab label translates; Alt shows English", function()
      load()
      if order[1] then
        tab = Maps.battlefieldMap(en)
        assert.is_true(WFI.BattlefieldMap.init())
      else
        assert.is_false(WFI.BattlefieldMap.init())
        tab = Maps.battlefieldMap(en)
        assert.are.equal(1, WFI.LoadOnDemand.loaded(ADDON))
      end
      assert.are.equal("ゾーンマップ", tab:GetText())
      Stub.keys.alt = true
      WFI.Modifier.refresh()
      assert.are.equal("Zone Map", tab:GetText())
    end)
  end

  it("the tab takes only its own key: any other text (a name) stays English", function()
    load()
    tab = Maps.battlefieldMap(en)
    tab:SetText("World")
    assert.is_true(WFI.BattlefieldMap.init())
    assert.are.equal("World", tab:GetText())
  end)

  it("a wrong-typed tab and a missing tab set nothing up, with no error",
    function()
      load()
      Stub.loadedAddons[ADDON] = true
      _G.BattlefieldMapTab = "tab"
      assert.has_no.errors(function() WFI.BattlefieldMap.init() end)
      assert.is_false(WFI.BattlefieldMap.setup())
      load()
      Stub.loadedAddons[ADDON] = true
      WFI.BattlefieldMap.init()
      assert.is_false(WFI.BattlefieldMap.setup()) -- no frame
    end)
end)
