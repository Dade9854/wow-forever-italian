-- UI/Font.lua: which face the addon's text wears. Italian is written in the letters the client's own fonts already
-- have (accented vowels included), so translated game text keeps the face the client gave each widget, and the
-- addon's own widgets (settings pages, the marker banner, the fix window) use the client's standard UI face.
-- No font file is bundled, so nothing has to wait for one to load. Never creates or modifies a global font object
-- (luacheck forbids CreateFont / GameFont* / SystemFont*).
local _, WFI = ...
local Font = {}
WFI.Font = Font

Font.CLIENT = "Fonts\\FRIZQT__.TTF" -- the client's standard UI face, always loaded
Font.PATH = Font.CLIENT -- the face of the addon's own widgets
Font.DEFAULT_SIZE = 12

-- SetFont for a FontString the addon owns outright (settings pages, the marker banner). → the SetFont result
function Font.set(fs, path, size, flags)
  return fs:SetFont(path or Font.PATH, size or Font.DEFAULT_SIZE, flags or "")
end

-- A pooled FontString the client reuses (chat rows, the guild bank log, speech bubbles) that shows a translated
-- line. It keeps the client's face; only its size is reported, at `fontObject`'s size when one is given (the
-- owner's font). → the size
function Font.bundle(fs, fontObject)
  local _, size = fs:GetFont()
  if type(fontObject) == "table" and type(fontObject.GetFont) == "function" then
    local _, objSize = fontObject:GetFont()
    size = objSize or size
  end
  return size or Font.DEFAULT_SIZE
end

-- The addon never dresses a widget in another face, so there is nothing to give back.
function Font.dressed() return false end
function Font.restore() return false end
function Font.follow() return false end

-- The client's fonts are always loaded: nothing is ever refused and waiting.
function Font.isPending() return false end
function Font.retryPending() return 0 end

-- The face a translated line is written in: nil, the face the client gave the widget.
function Font.bundled() return nil end
