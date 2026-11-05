-- UI/Slash.lua: /wfi and /wowforeveritalian. The grammar is generic over the registry:
--   /wfi                      status: every setting and its value
--   /wfi on | off | toggle    the master switch (sugar for `enabled`)
--   /wfi <setting> [<value>]  read or set any setting; dotted ids may be split: /wfi area quests off
--   /wfi config [collector|about]   open the settings (a page)
--   /wfi debug                unresolved Compat candidates, surfaces whose init raised, state, font
--                             failures, memory, data counts, panel error
--   /wfi debug hash           run the shipped hash vectors through Normalize + Hash in-client
--   /wfi debug quest <id>     the shipped row for a quest (each field: status + the start of the Japanese)
--   /wfi debug item <id> | spell <id>
--   /wfi debug gossip         the gossip entry count, then each open gossip line: surface, record, key, status
--   /wfi debug book           the book entry count, then the open page's keys, the shipped one and its record
--   /wfi debug ui             the UI string index: shipped / indexed / hashed / mismatched / ambiguous / unresolved /
--                             unsupported (a template with more plural groups than the matcher takes)
--   /wfi debug objective      the objective index: shipped (objective / area rows) / indexed by
--                             fingerprint / ambiguous
--   /wfi debug ui scan        English still showing on visible frames: "hook?" = the dictionary knows it, "key?" = not
--   /wfi debug fonts          the refused-font retry: timer state, one pending widget, then a retry now
--   /wfi debug intro [novoice] open the first-install window (novoice: drawn as with no voice pack loaded)
--   (plain /wfi debug also prints the voice packs' counts: lines, matched, missing, stale, played, refused,
--   and the lines of each pack)
--   /wfi version              the addon, normalization and Lua versions
--   /wfi bug                  the report window (a bug, with the addon's own Lua errors, or an idea)
--   /wfi log [<n>]            the problem log's last n entries, then how many Lua errors it holds
--   /wfi taint                the action-bar taint scan into the problem log (UI/TaintWatch)
--   /wfi collector [on|off|status|path|clear|send [all]]   the English collector; other words fall through to
--                             settings; clear asks for the same command again within 5 s (like the page's two
--                             clicks); send opens the send window (all: every line again)
--   /wfi glosses [on|off]     readings.glosses · /wfi readings [on|off]  readings.enabled
--   /wfi togglekey [<key>|none]   the toggle binding the settings page's Set key / Unbind row writes
--   /wfi panel reset          the voice panel back at the bottom centre
local _, WFI = ...
local Slash = {}
WFI.Slash = Slash

local S = WFI.Settings

local function fmt(v)
  if v == true then return "on" elseif v == false then return "off" end
  return tostring(v)
end

local function say(line, ...)
  print(("WFI: " .. line):format(...))
end

-- A command that asks to be typed again (replace a bound key, clear the collector) runs on the same line
-- within CONFIRM_SECONDS; any other command in between forgets it.
Slash.CONFIRM_SECONDS = 5
local armed, pending, current -- armed: the line the previous command asked for; current: this command's line

local function confirmed()
  if armed and armed.line == current and GetTime() - armed.at <= Slash.CONFIRM_SECONDS then return true end
  pending = { line = current, at = GetTime() }
  return false
end

-- The toggle binding's key as the client names it, or "not set".
local function toggleText()
  local KC = WFI.KeyCapture
  if not KC then return "n/a" end
  local key = KC.toggleKey()
  return key and KC.keyText(key) or "not set"
end

function Slash.version()
  print(("WoW Forever Italian %s (norm %s, %s)"):format(WFI.VERSION, WFI.NORM_VERSION, _VERSION))
end

function Slash.status()
  say("translation %s · hold %s for English · modifier %s", fmt(WFI.State.enabled),
    WFI.Modifier.display(S.get("modifier")), WFI.State.modifierHeld and "held" or "up")
  for _, d in ipairs(S.list()) do
    if not S.isHidden(d) then print(("  %s = %s"):format(d.id, fmt(S.get(d.id)))) end
  end
  print(("  togglekey = %s"):format(toggleText())) -- a binding, not a setting, but set on the same page
  print("  /wfi on|off|toggle · /wfi <setting> <value> · /wfi readings|glosses [on|off] · /wfi togglekey [<key>|none]"
    .. " · /wfi config [collector|about] · /wfi collector · /wfi bug · /wfi debug · /wfi version")
end

-- First 60 bytes of the Japanese, cut back to a UTF-8 boundary (never mid-sequence), one line.
local function short(ja)
  local s = ja:gsub("\n", " ")
  if #s <= 60 then return s end
  local cut = 60
  while cut > 1 and s:byte(cut + 1) and s:byte(cut + 1) >= 0x80 and s:byte(cut + 1) < 0xC0 do cut = cut - 1 end
  return s:sub(1, cut) .. "…"
end

local function debugRow(type_, idText)
  local id = tonumber(idText)
  if not id or id ~= math.floor(id) or id < 1 then return say("usage: /wfi debug %s <id>", type_) end
  local any = false
  for _, field in ipairs(WFI.SLOTS[type_].fields) do
    local kind = type_ .. "." .. field  -- always field-qualified: spell has two fields
    local e = WFI.Lookup.get(kind, id)
    if e then
      any = true
      print(("  %s.%s: %s (h1 %s) %s"):format(type_, field, WFI.STATUS[e.status] or e.status,
        e.h1 and WFI.Hash.hex8(e.h1) or "-", -- no h1: checked against another field
        e.variants and ("%d branch variants"):format(#e.variants) -- a branch line
          or e.sections and ("%d sections"):format(#e.sections) -- a heading with optional paragraphs
          or short(e.ja)))
    else
      print(("  %s.%s: -"):format(type_, field))
    end
  end
  if not any then say("%s %s: not shipped", type_, idText) end
end

-- One line: the UI string index counts.
local function uiSummary()
  local index = WFI.UIIndex
  if not index then return "not built" end
  local c = index.counts
  return ("shipped %d · indexed %d · hashed %d · mismatched %d · ambiguous %d · unresolved %d · unsupported %d"
    .. " · owned %d") -- keys that own their Japanese (UIStrings.OWN)
    :format(c.shipped, c.indexed, c.hashed, c.mismatched, c.ambiguous, c.unresolved, c.unsupported or 0, c.owned or 0)
end

local function debugUI()
  say("ui: %s", uiSummary())
  local index = WFI.UIIndex
  if not index then return end
  for _, kind in ipairs({ "mismatched", "ambiguous", "unresolved", "unsupported" }) do
    local list = index.problems[kind] or {}
    if #list > 0 then
      local shown = {}
      for i = 1, math.min(10, #list) do shown[i] = list[i] end
      print(("  %s: %s%s"):format(kind, table.concat(shown, ", "), #list > 10 and (" … +" .. (#list - 10)) or ""))
    end
  end
end

-- One line: the objective index counts: rows shipped (objective and area rows, each counted), found
-- by fingerprint, and those two rows with one English and different Japanese leave unshown.
local function objectiveSummary()
  local index = WFI.ObjectiveIndex
  if not index then return "not built" end
  local c = index.counts
  local by = c.byType or {}
  return ("shipped %d (objective %d · area %d) · indexed %d · ambiguous %d"):format(c.shipped, by.objective or 0,
    by.area or 0, c.indexed, c.ambiguous)
end

-- The shipped gossip count, then every live gossip-kind record: surface, record key, gossip key, status.
local function debugGossip()
  say("gossip entries: %d", WFI.Data.count("gossip"))
  local any = false
  for _, surface in ipairs({ "gossip", "questframe.greeting" }) do
    local keys = {}
    for key, rec in pairs(WFI.SurfaceState.records(surface)) do
      if rec.meta and rec.meta.kind == "gossip" then keys[#keys + 1] = key end
    end
    table.sort(keys)
    for _, key in ipairs(keys) do
      local rec = WFI.SurfaceState.get(surface, key)
      local e = WFI.Lookup.gossip(rec.meta.id)
      print(("  %s %s %s %s"):format(surface, key, tostring(rec.meta.id), e and (WFI.STATUS[e.status] or e.status)
        or "none"))
      any = true
    end
  end
  if not any then print("  no gossip window open") end
end

-- The open book page: the shipped book count, the page's candidate keys, the one a translation is shipped
-- under, and its record.
local function debugBook()
  say("book entries: %d", WFI.Data.count("book"))
  local info = WFI.ItemText.inspect()
  if not info.open then return print("  no book open") end
  if info.creator then print("  a player's letter (never translated)") end
  print("  keys: " .. table.concat(info.keys, " "))
  local rec = info.record
  print(("  shipped: %s · record: %s"):format(info.shipped or "none",
    rec and (rec.applied ~= nil and "Japanese" or "English") or "none"))
end

local function debugHash()
  local V = WFI.Data.vectors
  if not V then return say("no vectors shipped") end
  local ok, total = 0, #V.cases
  for _, c in ipairs(V.cases) do
    if WFI.Hash.keyOf(c.raw, c.player) == c.key then
      ok = ok + 1
    else
      say("hash vector %s FAILED", c.id)
    end
  end
  say("hash vectors: %d/%d ok (norm %s)", ok, total, V.norm)
end

local function debugFonts()
  local r = WFI.fontRetry
  if r then
    say("fonts: retry %s · %d tries · %d left at the last try · %.0fs since PLAYER_ENTERING_WORLD · timer %s",
      r.running and "running" or "stopped", r.tries, r.left, GetTime() - r.at, r.timer and "yes" or "missing")
  else
    say("fonts: no retry started (PLAYER_ENTERING_WORLD not seen)")
  end
  local rec = WFI.Render.pendingFontSample()
  if rec then
    local path, size, flags = rec.fs:GetFont()
    local shown = rec.fs.IsVisible and rec.fs:IsVisible()
    say("fonts: pending %s.%s now %s %s %q · visible %s", tostring(rec.surface), tostring(rec.key), tostring(path),
      tostring(size), tostring(flags), tostring(shown))
  end
  local before = WFI.Render.pendingFonts()
  local after = WFI.Render.retryFonts()
  say("fonts: records pending %d → %d after a retry now · own widgets pending %d", before, after,
    WFI.Font.retryPending())
end

-- /wfi debug tooltip [on | off]: record every pass over a spell or item tooltip (UI/Tooltip's trace) and show it in
-- a window whose text selects itself on a click, to copy out.
local traceWindow
local function showTrace()
  local lines = WFI.Tooltip.trace or {}
  local text = #lines == 0 and "(nothing recorded: /wfi debug tooltip on, then hover the tooltip)"
    or table.concat(lines, "\n")
  if not traceWindow then
    local W = WFI.OptionsWidgets
    local f = CreateFrame("Frame", "WFITooltipTrace", WFI.Compat.resolve("UIParent"), "ButtonFrameTemplate")
    f:SetSize(760, 520)
    f:SetPoint("CENTER")
    if f.SetFrameStrata then f:SetFrameStrata("DIALOG") end
    if f.SetMovable and f.RegisterForDrag then -- dragged by its frame
      f:EnableMouse(true)
      f:SetMovable(true)
      f:RegisterForDrag("LeftButton")
      f:SetScript("OnDragStart", f.StartMoving)
      f:SetScript("OnDragStop", f.StopMovingOrSizing)
    end
    if f.SetTitle then f:SetTitle("WFI tooltip trace") end
    if ButtonFrameTemplate_HidePortrait then ButtonFrameTemplate_HidePortrait(f) end
    f.text = W.scrollText(f, 14, -64, 730, 440)
    local special = WFI.Compat.resolve("UISpecialFrames") -- Escape closes it
    if type(special) == "table" then table.insert(special, "WFITooltipTrace") end
    traceWindow = f
  end
  -- `|` doubled: the edit box shows a colour code or a link as the characters it is, not as a colour. The window is
  -- shown first and the text written again on the next frame: a scrolling edit box made while its parent was never
  -- laid out can come up blank (seen in game).
  local shown = (text:gsub("|", "||"))
  traceWindow:Show()
  traceWindow.text:setText(shown)
  local after = WFI.Compat.resolve("C_Timer.After")
  if type(after) == "function" then
    after(0, function() if traceWindow:IsShown() then traceWindow.text:setText(shown) end end)
  end
  say("tooltip trace: %d passes shown; click the text, Ctrl+A, Ctrl+C (or /wfi debug tooltip chat)", #lines)
end

-- /wfi debug tooltip chat: the same trace printed into the chat frame, line by line, for a screenshot.
local function traceToChat()
  local lines = WFI.Tooltip.trace or {}
  if #lines == 0 then return say("tooltip trace: nothing recorded (/wfi debug tooltip on, then hover the tooltip)") end
  for _, pass in ipairs(lines) do
    for row in (pass .. "\n"):gmatch("(.-)\n") do say("%s", (row:gsub("|", "||"))) end
  end
end

local function debugTooltip(arg)
  arg = arg and arg:lower()
  if arg == "on" then
    WFI.Tooltip.trace = {}
    WFI.Tooltip.installCallTrace()
    return say("tooltip trace: on (every spell / item tooltip pass is recorded; /wfi debug tooltip to see it)")
  end
  if arg == "off" then
    WFI.Tooltip.trace = nil
    return say("tooltip trace: off")
  end
  if arg == "chat" then return traceToChat() end
  return showTrace()
end

function Slash.debug(sub, arg)
  if sub == "fonts" then return debugFonts() end
  if sub == "intro" then return WFI.IntroWindow.open(arg ~= nil and arg:lower() == "novoice") end
  if sub == "tooltip" then return debugTooltip(arg) end
  if sub == "hash" then return debugHash() end
  if sub == "quest" or sub == "item" or sub == "spell" then return debugRow(sub, arg) end
  if sub == "gossip" then return debugGossip() end
  if sub == "book" then return debugBook() end
  if sub == "ui" and arg and arg:lower() == "scan" then return WFI.Scan.run(print) end
  if sub == "ui" then return debugUI() end
  if sub == "objective" then return say("objectives: %s", objectiveSummary()) end
  if sub ~= nil then return print(("WFI: unknown command 'debug %s' (try /wfi)"):format(sub)) end
  local unresolved = WFI.Compat.unresolved()
  say("unresolved widgets: %s", #unresolved == 0 and "none" or table.concat(unresolved, ", "))
  -- The surfaces whose init raised. Each one cost only itself; the rest of the addon loaded around it.
  local initErrors = WFI.initErrors or {}
  local failed = {}
  for i, e in ipairs(initErrors) do failed[i] = ("%s: %s"):format(e.surface, e.err) end
  say("surface errors: %s", #failed == 0 and "none" or table.concat(failed, " · "))
  local areas = {}
  for _, a in ipairs(WFI.AREAS) do areas[#areas + 1] = a .. "=" .. fmt(WFI.State.areaEnabled(a)) end
  say("enabled=%s held=%s %s", fmt(WFI.State.enabled), fmt(WFI.State.modifierHeld), table.concat(areas, " "))
  -- the voice pack (ADR-061): lines registered, then since registration: voiced, no file, Japanese changed since the
  -- file was made, and what the player could not play
  local V, P = WFI.Voice, WFI.VoicePlayer
  if V and V.hasPack() then
    local c = V.counts
    say("voice: %d lines (%d invalid) · matched %d · missing %d · stale %d · played %d · refused %d",
      c.registered, c.invalid, c.matched, c.missing, c.stale, P and P.counts.played or 0, P and P.counts.refused or 0)
    local list = {}
    for folder, n in pairs(V.packs()) do list[#list + 1] = ("%s=%d"):format(folder, n) end
    table.sort(list)
    say("voice packs: %s", table.concat(list, " · "))
    if WFI.VoicePanel and WFI.VoiceQueue then
      local st = WFI.VoicePlayer.state()
      say("voice panel: look %d · %d waiting · playing %s · paused %s", WFI.VoiceQueue.opt.look, #st.waiting,
        st.item and st.playing and tostring(st.item.key) or "none", st.paused and "yes" or "no")
    end
    local E = WFI.VoiceErrors
    if E then
      local ec, l = E.counts, E.last
      say("voice errors: game asked %d · message known %d · played %d · repeats skipped %d · refused %d",
        ec.calls, ec.shown, ec.played, ec.skipped, ec.refused)
      say("voice errors, last: voice id %s · message %s · %s %s · %s", tostring(l.voiceID), tostring(l.message),
        tostring(l.race), tostring(l.sex), tostring(l.why))
    end
  else
    say("voice: no pack%s", V and V.counts.invalid > 0 and " (a pack registered an invalid table)" or "")
  end
  local fails = {}
  for surface, f in pairs(WFI.Render.fontFailureSurfaces) do fails[#fails + 1] = { surface = surface, f = f } end
  table.sort(fails, function(a, b)
    if a.f.n ~= b.f.n then return a.f.n > b.f.n end
    return a.surface < b.surface
  end)
  for i, x in ipairs(fails) do
    fails[i] = ("%s ×%d (%s size=%s flags=%q)"):format(x.surface, x.f.n, tostring(x.f.key), tostring(x.f.size),
      tostring(x.f.flags))
  end
  say("font failures: %d (%d pending)%s", WFI.Render.fontFailures, WFI.Render.pendingFonts(),
    #fails > 0 and (" · " .. table.concat(fails, " · ")) or "")
  local RV = WFI.ReadingView -- the word-reading box
  if RV then
    say("readings: %d quests / greetings loaded · %s · %d attached · %d spans refused%s · %d errors",
      WFI.Data.count("reading"), RV.enabled and "on" or "off", RV.attached, RV.refused,
      RV.refusedAt and (" (first: " .. RV.refusedAt .. ")") or "", WFI.Render.readingErrors or 0)
    say("glosses: %d meanings loaded · %s", WFI.Data.count("gloss"), RV.glossesOn and "on" or "off")
  end
  local nUnknown, unknownList = WFI.Placeholders.unknownTokens()
  local listed = nUnknown > 0 and (" (" .. table.concat(unknownList, " ") .. ")") or ""
  say("placeholders: %d unknown tokens seen%s", nUnknown, listed)
  local got, want, api, path, auras = WFI.Tooltip.resolved()
  say("tooltip frames: %d/%d · hook path: %s · spell description API: %s · aura hooks: %d · aura errors: %d",
    got, want, tostring(path), api and "present" or "absent (positional rule)", auras or 0,
    WFI.Tooltip.auraErrors or 0)
  local hp = WFI.Tooltip.hidden
  say("hidden tooltips: %d written from the client's own tooltip data · %d left as the client wrote them%s",
    hp.written, hp.left, hp.last and (" · last: " .. hp.last) or "")
  say("tooltip time: %s", WFI.TimeLine.status())
  local kb = WFI.Compat.memoryKB()
  say("memory: %s", kb and ("%.1f MB"):format(kb / 1024) or "n/a")
  local c = WFI.Data.counts
  say("data: quests %d · items %d · spells %d · gossip %d · ui %d", c.quest, c.item, c.spell, c.gossip, c.ui)
  say("ui: %s", uiSummary())
  say("objectives: %s", objectiveSummary())
  say("collector: %s", WFI.Collector.describe())
  local M = WFI.Modifier
  say("modifier: %s (%s%s)", S.get("modifier"), M.class(S.get("modifier")),
    M.bindingKey() and (" · override " .. WFI.RevealBinding.state) or "")
  say("addon list button: %s", WFI.AddonListButton.installed and "installed" or "absent")
  if WFI.Options.buildError then say("settings panel failed to build: %s", WFI.Options.buildError) end
end

local COLLECTOR_VERBS = { on = true, off = true, status = true, path = true, clear = true, send = true }

-- /wfi collector … → true when handled; any other second word is left to the registry grammar.
function Slash.collector(sub, arg)
  local C = WFI.Collector
  if sub ~= nil and not COLLECTOR_VERBS[sub] then return false end
  if sub == "on" or sub == "off" then
    S.set("collector.enabled", sub)
  elseif sub == "path" then
    local st = C.status()
    say("collected English is saved when you log out or /reload, in:")
    print("  " .. C.path())
    say("%d %s · %s. /wfi collector send sends them; a file too long to paste is attached (zipped) to the same issue",
      st.entries, st.entries == 1 and "entry" or "entries", C.formatBytes(st.bytes))
    return true
  elseif sub == "send" then
    -- `all`: every entry again, for a send that was copied but never submitted
    WFI.CollectorSendWindow.open(arg == "all")
    return true
  elseif sub == "clear" then
    local st = C.status() -- nothing to lose (empty, or a newer version's file that is never cleared): no ask
    if not st.readOnly and st.entries > 0 and not confirmed() then
      local n = st.entries
      say("type /wfi collector clear again within %d seconds to clear %d %s", Slash.CONFIRM_SECONDS, n,
        n == 1 and "entry" or "entries")
      return true
    end
    local n = C.clear()
    if n == nil then
      say("collector file is from a newer version; not cleared")
    else
      say("collector cleared (%d)", n)
    end
    return true
  end
  say("collector %s", C.describe())
  return true
end

-- /wfi togglekey [<key> | none]: the settings page's toggle-key row by slash, with its refusals, never in
-- combat, never the modifier's key, and a key bound to another action only when the command is repeated (Replace).
function Slash.togglekey(value, extra)
  local KC = WFI.KeyCapture
  if value == nil then return say("togglekey = %s", toggleText()) end
  if extra ~= nil then return say("togglekey: one key, with - between its parts (ctrl-j)") end
  local combat = KC.inCombat() -- through Compat, as the page reads it; nil: the client cannot say, so never write
  if combat == true then return say("togglekey: key bindings cannot change in combat") end
  if combat == nil then return say("togglekey: key bindings are not available on this client") end
  if value:lower() == "none" then
    if not KC.clearToggle() and KC.toggleKey() then return say("togglekey: %s was not unbound", toggleText()) end
    return say("togglekey = %s", toggleText())
  end
  local chord, why = KC.parseChord(value)
  if not chord then return say("togglekey: %s", why) end
  if S.get("modifier"):upper() == chord then
    return say("togglekey: %s is the key you hold for English (/wfi modifier)", KC.keyText(chord))
  end
  local action = KC.conflict(chord, KC.TOGGLE)
  if action and not confirmed() then
    return say('%s is used for "%s"; type the same command again within %d seconds to replace it',
      KC.keyText(chord), action, Slash.CONFIRM_SECONDS)
  end
  if not KC.setToggle(chord) then return say("togglekey: %s was not bound", KC.keyText(chord)) end
  say("togglekey = %s", toggleText())
end

local BOOLEAN_WORDS = { on = true, off = true, ["true"] = true, ["false"] = true, ["1"] = true, ["0"] = true }

-- Resolves `words` against the registry: "<id> <value>" or "<group> <name> <value>". → id, value | nil
local function settingFromWords(words)
  local id = S.find(words[1])
  if id then return id, words[2] end
  if words[2] then
    id = S.find(words[1] .. "." .. words[2])
    if id then return id, words[3] end
  end
  return nil
end

function Slash.handle(msg)
  local words = {}
  for w in (msg or ""):gmatch("%S+") do words[#words + 1] = w end
  armed, pending, current = pending, nil, table.concat(words, " "):lower()
  local verb = words[1]
  if verb == nil then return Slash.status() end
  local lower = verb:lower()

  if lower == "version" then return Slash.version() end
  if lower == "on" or lower == "off" then
    S.set("enabled", lower)
    return say("translation %s", lower)
  end
  if lower == "toggle" then
    S.set("enabled", not S.get("enabled"))
    return say("translation %s", fmt(S.get("enabled")))
  end
  if lower == "config" then
    if not WFI.Compat.openOptions(words[2] and words[2]:lower()) then
      say("settings panel not available on this client; use /wfi <setting> <value>")
    end
    return
  end
  if lower == "fix" then -- the fix window (report a line)
    local ok = WFI.FixWindow and pcall(WFI.FixWindow.open)
    if not ok then say("the fix window is not available on this client") end
    return
  end
  if lower == "bug" then -- the report window (a bug or an idea)
    local ok = WFI.ReportWindow and pcall(WFI.ReportWindow.open)
    if not ok then say("the report window is not available on this client") end
    return
  end
  if lower == "debug" then return Slash.debug(words[2] and words[2]:lower(), words[3]) end
  if lower == "glosses" then -- the word popup's meanings (setting readings.glosses)
    if words[2] then
      local ok, err = S.set("readings.glosses", words[2])
      if not ok then return say("glosses: %s", err) end
    end
    return say("glosses %s · %d meanings loaded", fmt(S.get("readings.glosses")), WFI.Data.count("gloss"))
  end
  if lower == "readings" and (words[2] == nil or BOOLEAN_WORDS[words[2]:lower()]) then -- readings.enabled
    if words[2] then
      local ok, err = S.set("readings.enabled", words[2])
      if not ok then return say("readings: %s", err) end
    end
    return say("readings %s", fmt(S.get("readings.enabled")))
  end
  if lower == "togglekey" then return Slash.togglekey(words[2], words[3]) end
  if lower == "panel" and WFI.VoicePanel then -- /wfi panel reset: the voice panel back at the bottom centre
    local rest = {}
    for i = 2, #words do rest[#rest + 1] = words[i] end
    return WFI.VoicePanel.command(rest, say)
  end
  if lower == "log" then -- the diagnostics log (Core/Diag): the last N entries, 10 by default
    for _, line in ipairs(WFI.Diag.lines(words[2])) do say("%s", line) end
    local errors = WFI.ErrorLog.status()
    return say("errors: %d recorded, %d not sent (/wfi bug)", errors.count, errors.unsent)
  end
  if lower == "taint" then -- the taint scan (UI/TaintWatch): fields and globals this addon's taint reached, to the log
    local fields, globals = WFI.TaintWatch.scan("slash")
    return say("taint: %d tainted fields, %d globals of this addon; /reload saves them, /wfi log shows them", fields,
      globals)
  end
  if lower == "collector" and Slash.collector(words[2] and words[2]:lower(), words[3] and words[3]:lower()) then
    return
  end

  local id, value = settingFromWords(words)
  if id then
    if value == nil then return say("%s = %s", id, fmt(S.get(id))) end
    local ok, err = S.set(id, value)
    if ok and id == "modifier" then
      local key = WFI.Modifier.bindingKey()
      local action = key and WFI.KeyCapture.conflict(key, WFI.KeyCapture.REVEAL)
      if key and WFI.RevealBinding.state == "queued" then
        say("modifier = %s: takes effect after combat", fmt(S.get(id)))
      else
        say("%s = %s", id, fmt(S.get(id)))
      end
      if action then say("%s was used for \"%s\"; while the addon is loaded it shows English instead", key, action) end
      return
    end
    if ok then return say("%s = %s", id, fmt(S.get(id))) end
    return say("%s: %s", id, err)
  end

  if lower == "readings" then return say("readings: expected on|off") end -- a known verb, a bad word
  print(("WFI: unknown command '%s' (try /wfi)"):format(verb))
end

function Slash.register()
  SLASH_WFI1 = "/wfi"
  SLASH_WFI2 = "/wowforeveritalian"
  SlashCmdList["WFI"] = function(msg) Slash.handle(msg) end
end
