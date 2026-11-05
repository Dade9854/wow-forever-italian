-- UI/ColorPicker.lua over a ColorPickerFrame / OpacityFrame replayed from
-- blizzard_colorpickerframe/mainline (colorpickerframe.xml:3–200, colorpickerframe.lua:120–163).
local H = require("tests.lua.spec.helpers")
local Stub = require("tests.lua.spec.wow_stub")
local S = require("tests.lua.spec.stub_settings")

local FILES = {}
for i, f in ipairs(H.UI_FILES) do FILES[i] = f end
for _, f in ipairs({ "UI/LabelTree.lua", "UI/TooltipLines.lua", "UI/SettingsKeys.lua", "UI/ColorPicker.lua" }) do
  FILES[#FILES + 1] = f
end

local UI = {
  COLOR_PICKER = { "Color Picker", "カラーピッカー" }, COLOR_PICKER_HEX = { "Hex", "16進" },
  OPACITY = { "Opacity", "不透明度" }, CANCEL = { "Cancel", "キャンセル" }, OKAY = { "Okay", "OK" },
}

describe("the colour picker on Forever", function()
  local WFI, frame, opacity

  local function load()
    Stub.install(H.ADDON_DIR .. "/WoWForeverItalian.toc")
    Stub.installTooltipAPI()
    WFI = H.loadChunks(FILES)
    H.uiSetup(WFI, UI)
  end

  before_each(function()
    load()
    frame, opacity = S.installColorPicker()
    WFI.Labels.forbidNames(WFI.ColorPicker.NEVER_TOUCH)
    assert.is_true(WFI.ColorPicker.init())
  end)

  after_each(function()
    H.uiTeardown()
    S.removeColorPicker()
  end)

  it("header, buttons, the hex placeholder and the opacity label translate; the hex value is never touched", function()
    assert.are.equal("カラーピッカー", frame.Header.Text:GetText())
    assert.are.equal("キャンセル", frame.Footer.CancelButton:GetText())
    assert.are.equal("OK", frame.Footer.OkayButton:GetText())
    assert.are.equal("16進", frame.Content.HexBox.Instructions:GetText())
    assert.are.equal("ffd100", frame.Content.HexBox:GetText())
    assert.are.equal("不透明度", ({ _G.OpacityFrameSlider:GetRegions() })[1]:GetText())
    frame.Content.HexBox.text = "Cancel" -- typed text that is a dictionary word
    frame:Show()
    assert.are.equal("Cancel", frame.Content.HexBox:GetText())
    assert.is_truthy(opacity)
  end)

  it("wrong-typed client names degrade with no error; a picker without Content and no picker are skipped",
    function()
      assert.has_no.errors(function()
        for _, bad in ipairs({ 42, "text", true }) do
          frame.Header, frame.Footer = bad, bad
          frame:Show()
        end
      end)
      assert.is_false(WFI.ColorPicker.init())
      load()
      S.removeColorPicker()
      local bare = CreateFrame("Frame", "ColorPickerFrame") -- no Content
      assert.has_no.errors(function() assert.is_false(WFI.ColorPicker.init()) end)
      assert.is_truthy(bare)
      S.removeColorPicker()
      assert.has_no.errors(function() assert.is_false(WFI.ColorPicker.init()) end)
    end)
end)
