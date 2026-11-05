-- The Obliterum Forge on Forever: UI/ObliterumForge.lua over an ObliterumForgeFrame replayed from camelot
-- blizzard_obliterumui/blizzard_obliterumui.xml (:60) and .lua (:13), load-on-demand in both load orders. The
-- forge's own name (the title) stays English.
local Stub = require("tests.lua.spec.wow_stub")
local C = require("tests.lua.spec.stub_commerce")

local UI = { OBLITERATE_BUTTON = { "Obliterate", "抹消" } }

local function build()
  local frame = C.window("ObliterumForgeFrame")
  C.tree(frame, { ObliterateButton = { button = _G.OBLITERATE_BUTTON } })
  frame:SetTitle("Obliterate") -- the forge's name, here spelled like a dictionary word
  return frame
end

C.suite(getfenv(1), {
  title = "the Obliterum Forge on Forever", module = "ObliterumForge", file = "UI/ObliterumForge.lua",
  addon = "Blizzard_ObliterumUI", root = "ObliterumForgeFrame", ui = UI, build = build,
  globals = { "ObliterumForgeFrame" },
  cases = {
    { "the button is Japanese, Alt shows English, and it stays shown (a static label)", function(frame, WFI)
      frame:Show()
      assert.are.equal("抹消", frame.ObliterateButton:GetText())
      C.alt(WFI, true)
      assert.are.equal("Obliterate", frame.ObliterateButton:GetText())
      C.alt(WFI, false)
      frame:Hide()
      assert.are.equal("抹消", frame.ObliterateButton:GetText())
    end },
  },
  name = function(frame, WFI)
    frame:Show()
    local title = frame.TitleContainer.TitleText
    assert.are.equal("Obliterate", title:GetText())
    assert.are.equal(0, WFI.Labels.show("obliterumforge", "x", title))
    assert.is_true(C.unrecorded(WFI, title))
  end,
  wrong = function(frame)
    frame.ObliterateButton = Stub -- a table that is no widget
    return function(f, WFI) assert.is_true(C.unrecorded(WFI, f.TitleContainer.TitleText)) end
  end,
})
