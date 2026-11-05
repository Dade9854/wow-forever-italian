-- The scrapping machine on Forever: UI/ScrappingMachine.lua over a ScrappingMachineFrame replayed
-- from camelot blizzard_scrappingmachineui/blizzard_scrappingmachineui.xml (:72) and .lua (:51, :65), load-on-demand
-- in both load orders. The machine's own name (the title) stays English.
local Stub = require("tests.lua.spec.wow_stub")
local C = require("tests.lua.spec.stub_commerce")

local UI = { SCRAP_BUTTON = { "Scrap", "解体" } }

local function build()
  local frame = C.window("ScrappingMachineFrame")
  C.tree(frame, { ScrapButton = { button = _G.SCRAP_BUTTON } })
  frame:SetTitle("Scrap") -- the machine's name, here spelled like a dictionary word
  return frame
end

C.suite(getfenv(1), {
  title = "the scrapping machine on Forever", module = "ScrappingMachine",
  file = "UI/ScrappingMachine.lua", addon = "Blizzard_ScrappingMachineUI", root = "ScrappingMachineFrame", ui = UI,
  build = build, globals = { "ScrappingMachineFrame" },
  cases = {
    { "the button is Japanese, Alt shows English, and it stays shown (a static label)", function(frame, WFI)
      frame:Show()
      assert.are.equal("解体", frame.ScrapButton:GetText())
      C.alt(WFI, true)
      assert.are.equal("Scrap", frame.ScrapButton:GetText())
      C.alt(WFI, false)
      frame:Hide()
      assert.are.equal("解体", frame.ScrapButton:GetText())
    end },
  },
  name = function(frame, WFI)
    frame:Show()
    local title = frame.TitleContainer.TitleText
    assert.are.equal("Scrap", title:GetText())
    assert.are.equal(0, WFI.Labels.show("scrappingmachine", "x", title))
    assert.is_true(C.unrecorded(WFI, title))
  end,
  wrong = function(frame)
    frame.ScrapButton = Stub -- a table that is no widget
    return function(f, WFI) assert.is_true(C.unrecorded(WFI, f.TitleContainer.TitleText)) end
  end,
})
