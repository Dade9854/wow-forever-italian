-- Main.lua: composition root. The only non-UI file allowed to create a frame. Wires the modules together on
-- ADDON_LOADED; no policy lives here (docs/architecture/addon-modules.md).
local ADDON, WFI = ...

-- Global entry point for Bindings.xml (a binding body runs as a global chunk and cannot see the addon namespace).
function WFI_ToggleTranslation()
  local S = WFI.Settings
  S.set("enabled", not S.get("enabled"))
  print(("WFI: translation %s"):format(S.get("enabled") and "on" or "off"))
end

-- Global entry point for the hidden WFI_REVEAL binding (runOnUp: keystate "down" / "up"), which UI/RevealBinding
-- puts on a `bound` modifier key (ADR-018). The edge only invalidates; Modifier's poll is the truth.
function WFI_RevealKey(keystate)
  local down = keystate == "down"
  WFI.Modifier.bindingEdge(down)
  WFI.RevealBinding.watch(down and WFI.State.modifierHeld)
end

-- The TOC's AddonCompartmentFunc entries. Blizzard's addon dropdown on the minimap calls these globals by
-- name with (addonName, buttonName) on a click and (addonName, frame) on hover [verified: Blizzard_Minimap/Mainline/
-- AddonCompartment.lua:102–142]. Left-click opens the fix window, right-click the minimap button's menu.
function WFI_OnAddonCompartmentClick(_, buttonName)
  WFI.MinimapButton.click(nil, buttonName)
end

function WFI_OnAddonCompartmentEnter(_, frame)
  WFI.MinimapButton.showTooltip(frame)
end

function WFI_OnAddonCompartmentLeave()
  WFI.MinimapButton.hideTooltip()
end

-- Global entry point for the voice pack (ADR-061): its Register.lua runs in its own addon's chunk and cannot see this
-- namespace. The pack loads after this addon (it lists it as a dependency), so the settings pages may already be
-- built: its page is added then.
function WoWForeverItalian_RegisterVoice(tbl)
  local n, invalid = WFI.Voice.register(tbl)
  -- a pack loads after this addon: the character's error lines can only take over once it has registered
  if WFI.loaded and WFI.VoiceErrors then pcall(WFI.VoiceErrors.refresh) end
  if WFI.loaded and WFI.Options and WFI.Voice.hasPack() then
    local ok, err = pcall(WFI.Options.addPage, "voice")
    if not ok then WFI.initErrors[#WFI.initErrors + 1] = { surface = "options.voice", err = tostring(err) } end
    ok, err = pcall(WFI.Options.addPage, "voicepanel")
    if not ok then WFI.initErrors[#WFI.initErrors + 1] = { surface = "options.voicepanel", err = tostring(err) } end
  end
  return n, invalid
end

-- The one reader of the player's own name / class / race / sex, shared by Core/Placeholders (the corpus tokens)
-- and Core/Collector (English normalization). Read at call time rather than cached at load. Each API
-- is guarded: a client without one leaves that token literal and makes the collector refuse (no_player) instead of
-- raising from every surface hook. A name equal to the client's UNKNOWNOBJECT string ("Unknown", when the global
-- exists) is treated as unavailable [unverified that "player" ever returns it once a quest window can be open].
local function call(fn, ...)
  if type(fn) ~= "function" then return nil end
  return fn(...)
end

local function player()
  local className, classFile = call(UnitClass, "player")
  local raceName, raceFile = call(UnitRace, "player")
  local name = call(UnitName, "player")
  if name ~= nil and name == _G.UNKNOWNOBJECT then name = nil end
  return {
    name = name, className = className, classFile = classFile,
    raceName = raceName, raceFile = raceFile, sex = call(UnitSex, "player"),
  }
end

-- The player as the Collector normalizes English with: the name and the localized class / race.
local function collectorPlayer()
  local p = player()
  return { name = p.name, class = p.className, race = p.raceName }
end

-- The key of a live English text for a keyed type (gossip: ADR-005 / ADR-017; book pages: ADR-022): the
-- first candidate key a translation of that type is shipped under, else the full key (for gossip, the value the
-- Collector stores as the line's hash). → function(text) → key | nil
local function keyOf(type_)
  return function(text)
    local keys = WFI.Collector.keys(text, collectorPlayer())
    for _, k in ipairs(keys) do
      if WFI.Lookup.keyed(type_, k) then return k end
    end
    return keys[1]
  end
end
local gossipKey = keyOf("gossip")

-- Whether `text` is the English quest `id`'s `field` ships under: one of its fingerprints (as the live check reads
-- them) is the entry's h1 or female-variant h1. → boolean
function WFI.IsQuestFieldEnglish(id, field, text)
  local entry = WFI.Lookup.get("quest." .. field, id)
  if type(entry) ~= "table" or type(text) ~= "string" or (entry.h1 == nil and entry.h1f == nil) then return false end
  for _, h in ipairs(WFI.Collector.fingerprints(text, collectorPlayer())) do
    if h == entry.h1 or h == entry.h1f then return true end
  end
  return false
end

-- The gossip key a translation of `text` is actually shipped under, or nil: quest text the client shows with no id
-- the addon can read (a quest's conditional description, its completion log line) is keyed like NPC dialogue.
-- Memoized per player and text (the minimap's quest block asks every frame; the keys depend on the player's name,
-- class and race); the memo is dropped at 256 entries. Nothing is memoized before the player is known, so an early
-- miss is asked again.
local shippedMemo, shippedCount, shippedWho = {}, 0, nil
function WFI.ShippedGossipKey(text)
  if type(text) ~= "string" or text == "" then return nil end
  local p = collectorPlayer()
  local known = type(p.name) == "string" and type(p.class) == "string" and type(p.race) == "string"
  local who = known and (p.name .. "|" .. p.class .. "|" .. p.race) or nil
  if who ~= shippedWho then shippedMemo, shippedCount, shippedWho = {}, 0, who end
  local hit = shippedMemo[text]
  if hit ~= nil then return hit or nil end
  local found = false
  for _, k in ipairs(WFI.Collector.keys(text, p)) do
    if WFI.Lookup.keyed("gossip", k) then found = k; break end
  end
  if who then
    if shippedCount >= 256 then shippedMemo, shippedCount = {}, 0 end
    shippedMemo[text], shippedCount = found, shippedCount + 1
  end
  return found or nil
end

local function expand(ja)
  if not WFI.Placeholders.mayHaveTokens(ja) then return ja end -- token-free text never touches the client
  return (WFI.Placeholders.expand(ja, player()))
end

-- The client's live English for a UI string key (ADR-015): its global string. An item subclass has none the
-- tooltip uses (C_Item.GetItemSubClassInfo returns the long name "Staves" where the tooltip shows "Staff"),
-- so those rows are matched by the live line's fingerprint (Core/UIStrings). Never stored English: the
-- addon ships only the h1 of the English it was drafted against.
-- The renderer `$D<k>` copies a duration with: only the forms a spell's `$d` prints, with the unit the client
-- chose (ADR-028).
local function spellDuration(text)
  return WFI.UIIndex and WFI.UIIndex:duration(text, true) or nil
end

-- The Japanese the tooltip shows for a shipped item / spell entry against these live lines (Align.gate, with the
-- client's spell durations). → ok, text
function WFI.GateText(entry, lines)
  return WFI.Align.gate(entry, lines, spellDuration)
end

local function uiEnglish(key)
  -- item subclasses and enchantment stat lines are fingerprint rows: no client string to read
  if WFI.UIStrings.isFingerprintKey(key) then return nil end
  local v = _G[key]
  return type(v) == "string" and v or nil
end

local function uiHash(text)
  return (WFI.Hash.h32x2(WFI.Normalize.v1(text)))
end

-- Builds WFI.UIIndex from the shipped UI strings; called once at load (Core/UIStrings).
function WFI.BuildUIIndex()
  WFI.UIIndex = WFI.UIStrings.build({ rows = WFI.Data.ui, english = uiEnglish, hash = uiHash })
  return WFI.UIIndex
end

-- Builds WFI.ObjectiveIndex from the shipped objective texts (Core/Objectives) and the quests' area texts,
-- found by the fingerprint of the live line's text, the same hash the UI index uses.
function WFI.BuildObjectiveIndex()
  WFI.ObjectiveIndex = WFI.Objectives.build({
    sources = { { type = "objective", rows = WFI.Data.objective }, { type = "area", rows = WFI.Data.area } },
    hash = uiHash,
  })
  return WFI.ObjectiveIndex
end

-- One step of OnLoad. Every call below runs through this: a step that raises is recorded with its name and error
-- and the load continues, so one broken surface costs that surface and nothing else (an unguarded raise would also
-- take `Slash.register`, hence `/wfi` itself, down with it). Steps run in the order written; the
-- order is load-bearing and the guard does not change it. Returns the step's first value, or nil when it failed.
-- `/wfi debug` prints WFI.initErrors.
local function step(name, fn)
  WFI.initErrors = WFI.initErrors or {} -- also called from the ADDON_LOADED handler, after OnLoad has run
  local ok, value = pcall(fn)
  if ok then return value end
  WFI.initErrors[#WFI.initErrors + 1] = { surface = name, err = tostring(value) }
  if WFI.Diag then WFI.Diag.initFailed(name, value) end
  -- the pcall kept it from the error handler: the bug report gets it this way
  if WFI.ErrorLog then pcall(WFI.ErrorLog.recordCaught, value) end
  return nil
end
-- the same guard for work a module runs later than the event that asked for it (UI/IntroWindow)
WFI.step = step

function WFI.OnLoad()
  WFI.initErrors = {}
  -- `or WFI_Log` for the same reason as WFI_DB below: a failed load never hands the client an empty global
  WFI_Log = step("diag", function()
    WFI.Diag.setDeps({ now = GetTime, mem = function() return collectgarbage("count") end,
      clock = function()
        local clock = WFI.Compat.resolve("date")
        return type(clock) == "function" and clock("%Y-%m-%d %H:%M:%S") or ""
      end, print = print, stack = debugstack, inCombat = InCombatLockdown })
    return WFI.Diag.load(WFI_Log)
  end) or WFI_Log
  step("compat", function() WFI.Compat.init(function(name) return _G[name] end) end)
  -- the addon's own Lua errors (Core/ErrorLog wrapped the error handler when its file loaded), kept in WFI_Log;
  -- after compat, which its clock reads `date` through
  step("errorlog", function()
    WFI.ErrorLog.setDeps({
      clock = function()
        local clock = WFI.Compat.resolve("date")
        return type(clock) == "function" and clock("%Y-%m-%d %H:%M:%S") or ""
      end,
      name = function() return (UnitName("player")) end,
      print = print,
      -- a secret value may not be read by addon code [verified: forever-ui Blizzard_APIDocumentationGenerated/
      -- FrameScriptDocumentation.lua:65 canaccessvalue]
      accessible = function(value)
        return type(canaccessvalue) ~= "function" or canaccessvalue(value) == true
      end,
      stack = function()
        return WFI.ErrorLog.stack({ debugstack = debugstack, height = GetCallstackHeight,
          errorHeight = GetErrorCallstackHeight })
      end,
    })
    return WFI.ErrorLog.load(WFI_Log)
  end)

  -- `or WFI_DB` / `or WFI_Collector` is load-bearing, not defensive noise: these two ARE the SavedVariables
  -- globals (see the TOC). Assigning `step`'s nil would hand the client an empty global to write at logout,
  -- wiping the player's settings and the whole collected English corpus, which cannot be regenerated. A failed
  -- load keeps what was on disk and reports the failure instead.
  local fresh = type(WFI_DB) ~= "table" -- a first install: read before the settings load creates the table
  WFI_DB = step("settings", function()
    return WFI.Settings.load(WFI_DB, WFI.SCHEMA, WFI.Settings.MIGRATIONS)
  end) or WFI_DB
  step("intro.prepare", function() WFI.Intro.prepare(WFI_DB, fresh) end)
  step("reports", function() WFI.Reports.load(WFI_DB) end) -- pending fixes live in WFI_DB.reports
  step("forget", function() -- saved tables of mechanisms the addon no longer has
    if type(WFI_DB) == "table" then WFI_DB.buffIdentity, WFI_DB.timeRule = nil, nil end
  end)
  WFI_Collector = step("collector", function() return WFI.Collector.load(WFI_Collector, {
    enabled = function() return WFI.Settings.get("collector.enabled") end,
    lookup = WFI.Lookup.get,
    player = collectorPlayer, -- the collector reads the localized class / race names
    build = function()
      local version, build = GetBuildInfo()
      if type(version) ~= "string" or build == nil then return nil end
      return version .. "." .. tostring(build)
    end,
    print = print,
    -- the tooltip gate the Translator's align deps run, so an item / spell line counts as covered only when its
    -- Japanese would show for it
    -- a line recorded with the client's tail on it (an older version kept it) is gated as the tooltip gates it
    aligns = function(entry, lines)
      local index = WFI.UIIndex
      if index then
        for i, line in ipairs(lines) do lines[i] = index:clientTail(line) or line end
      end
      return (WFI.GateText(entry, lines)) == true
    end,
    statLine = function(text) return WFI.UIIndex ~= nil and WFI.UIIndex:statLine(text) ~= nil end,
  }) end) or WFI_Collector
  -- the client's own encoder [verified: forever-ui Blizzard_APIDocumentationGenerated/EncodingUtilDocumentation.lua
  -- (Environment "All"; CompressionMethod.Zlib, Base64Variant.StandardUrlSafe), used the same way by
  -- Blizzard_CooldownViewer/CooldownViewerSettingsDataStoreSerialization.lua:277–281]. A client without it leaves
  -- the send window on the file fallback.
  step("collectorsend", function() WFI.CollectorSend.init({
    version = function() return WFI.VERSION end,
    encode = function(payload)
      local U, E = _G.C_EncodingUtil, _G.Enum
      if type(U) ~= "table" or type(E) ~= "table" or not E.CompressionMethod or not E.Base64Variant then return nil end
      if type(U.SerializeJSON) ~= "function" or type(U.CompressString) ~= "function"
        or type(U.EncodeBase64) ~= "function" then return nil end
      local json = U.SerializeJSON(payload)
      if type(json) ~= "string" then return nil end
      local packed = U.CompressString(json, E.CompressionMethod.Zlib)
      if type(packed) ~= "string" then return nil end
      return U.EncodeBase64(packed, E.Base64Variant.StandardUrlSafe)
    end,
  }) end)

  step("uiindex", WFI.BuildUIIndex)
  -- lines a newer addon covers leave the collector file; the tooltip gate needs the UI index's duration strings
  step("collectorprune", function() WFI.Collector.prune() end)
  step("objectiveindex", WFI.BuildObjectiveIndex)
  -- voice over: the pack's lines are matched against the shipped Japanese (tokens unfilled) by its hash
  step("voice", function() WFI.Voice.init({
    lookup = WFI.Lookup.get,
    hash = WFI.Hash.key,
    setting = WFI.Settings.get,
    revealed = WFI.Modifier.isDown,
    enabled = function() return WFI.State.enabled end,
  }) end)
  step("voicequeue", function() WFI.VoiceQueue.init(WFI_DB) end)
  step("voiceplayer", function() WFI.VoicePlayer.init(WFI_DB) end)
  step("voicepanel", function() WFI.VoicePanel.init() end)
  step("voicequestlog", function() WFI.VoiceQuestLog.init(WFI_DB) end)
  step("voiceerrors", function() WFI.VoiceErrors.init(WFI_DB) end)
  step("render", function() WFI.Render.init(WFI.Translator.new({
    enabled = function() return WFI.State.enabled end,
    areaEnabled = WFI.State.areaEnabled,
    modifierHeld = WFI.Modifier.isDown,
    lookup = WFI.Lookup.get,
    marker = function(name) return WFI.Settings.get("marker." .. name) end,
    -- the runtime gate for unaligned entries (ADR-007). The duration renderer is UIStrings',
    -- so a `$D<k>` in a tooltip translation copies the live line's duration with the unit the
    -- client chose instead of the Japanese naming one.
    align = function(ja, lines, nameScope)
      return WFI.Align.check(ja, lines, nameScope, spellDuration)
    end,
    -- a branch line's variants (ADR-043), the one that fits the live line
    alignVariants = function(variants, shapes, lines, nameScope)
      return WFI.Align.checkVariants(variants, shapes, lines, nameScope, spellDuration)
    end,
    -- a sectioned line's heading and paragraphs, each found by the words it begins with
    alignSections = function(sections, lines, nameScope)
      return WFI.Align.sections(sections, lines, nameScope, spellDuration)
    end,
    expand = expand, -- {name}/{class}/{race} per player
    -- a trusted line's `$N<k>` / `$D<k>` filled from the live text, with no gate: a quest's
    -- count is in the line the player is shown, not in the text the server sent.
    fillValues = function(ja, live) return WFI.Align.fillValues(ja, live, spellDuration) end,
    fill = function(ja, args) return WFI.UIIndex:fill(ja, args) end, -- UI templates get the live values
    -- the quest live check: the stale marker follows the client's English (ADR-019)
    fingerprints = function(text, masked) return WFI.Collector.fingerprints(text, collectorPlayer(), masked) end,
  })) end)
  step("modifier", WFI.Modifier.refresh)
  -- Tab fonts across PanelTemplates state changes, Lua-built help tooltips, and the readiness of
  -- load-on-demand Blizzard addons (their ADDON_LOADED is forwarded below; ADR-016). Before the surfaces.
  step("buttontext", WFI.ButtonText.init)
  step("helptooltip", WFI.HelpTooltip.init)
  step("tooltipdata", WFI.TooltipData.init) -- tooltip-data kinds with no module of their own
  step("loadondemand", function()
    WFI.LoadOnDemand.init(function(name)
      return type(C_AddOns) == "table" and type(C_AddOns.IsAddOnLoaded) == "function" and C_AddOns.IsAddOnLoaded(name)
    end)
  end)
  -- Surfaces: declare their client names and post-hook the client's writers (ADR-009); each feeds the API English
  -- to the Collector before rendering.
  step("questframe", function() WFI.QuestFrame.init({ key = gossipKey }) end) -- the greeting prose is gossip
  step("questmap", WFI.QuestMap.init) -- the quest map, popup, list and tracker
  step("tooltip", WFI.Tooltip.init)
  step("tooltip.unit", WFI.TooltipUnit.init) -- the unit mouseover lines the client composes
  step("gamemenu", WFI.GameMenu.init) -- the Esc menu's buttons (quest labels ride their surfaces' hooks)
  step("gossip", function() WFI.Gossip.init({ key = gossipKey }) end) -- the NPC talk window
  step("itemtext", function()
    WFI.ItemText.init({ key = keyOf("book"), -- the book / letter / plaque window
      keys = function(text) return WFI.Collector.keys(text, collectorPlayer()) end })
  end)
  -- The always-visible windows (ADR-016). Each shows its load-time labels now (before the window's first
  -- show, so a tab measures its Japanese), hooks its writers, and registers its help-tooltip owners; the talent
  -- frame, trainer and raid roster set up when their Blizzard addon loads. The never-touch widgets are registered
  -- first (Labels refuses them on any surface); a load-on-demand window registers its own again when it sets up.
  local windows = { "Character", "Reputation", "Skills", "SpellBook", "Talents", "Trainer", "GossipChrome",
    "Merchant", "Bank", "Bags", "Mail", "Friends", "Raid", "MicroMenu", "ItemText", "PvPRank",
    "Communities", "CommunitiesFrame", "CommunitiesGuild", "ClubFinder", "ClubFinderApplicants", "CommunitiesDialogs" }
  for _, name in ipairs(windows) do
    step("forbid." .. name:lower(), function() WFI.Labels.forbidNames(WFI[name].NEVER_TOUCH) end)
  end
  -- Every other window the Forever client loads, one surface each (ADR-030)
  -- (pipeline/forever_addon_dispositions.txt). Its never-touch lists join this pass; its inits run after the
  -- windows below, each under its own guard.
  local forever = {
    "Professions", "Crafting", "CustomerOrders", "QuestTimer", "Trade", "Loot", "GroupLoot", "Taxi", "Tabard",
    "Petition", "GuildRegistrar", "DressUp", "CastingBar", "MapLegend", "WorldMap", "MapPins", "FlightMap",
    "BattlefieldMap", "Tracker", "AuctionHouse", "BarberShop", "BlackMarket", "Currency", "CurrencyTransfer",
    "GuildBank", "GuildControl", "GuildRename", "ItemInteraction", "ItemSocketing", "ItemUpgrade",
    "ObliterumForge", "ScrappingMachine", "Stable", "SubscriptionInterstitial", "Transmog", "Achievement",
    "Calendar", "ClickBinding", "Collections", "MountJournal", "PetJournal", "Wardrobe", "Inspect", "Legacy",
    "Statistics", "Widgets",
    "Macro", "SpellSearch", "TimeManager", "CombatText", "CooldownViewer", "DamageMeter", "DeathRecap",
    "GamepadEdit", "Gamepad", "HudLabels", "HudTips", "Minimap", "PvPMatch", "QueueStatus", "RaidManager", "UnitFrames",
    "GroupFinder", "Channels", "QuickJoin", "RecentAllies", "RecruitAFriend", "ReportFrame", "HelpFrame",
    "StatusNotices", "BNetToast", "SettingsPanel", "SettingsTutorials", "EditMode", "QuickKeybind", "ColorPicker",
    "ChatConfig", "TextToSpeech", "ChatTabs", "CombatLog", "AddonList", "ScriptErrors", "Splash", "EventTrace",
    "ChromieTime", "Alerts", "Errors", "ChatSystem", "ChatInput", "BossBanner", "Cinematic", "Subtitles",
    "CoinPickup", "CombatFeedback", "EquipmentFlyout",
    "GhostFrame", "GuildInvite", "InstanceAbandon", "LootHistory", "LossOfControl",
    "MajorFactionToast", "PartyPose", "PetHappiness", "PlayerChoice", "ReadyCheck", "StackSplit", "StreamingIcon",
    "ZoneText",
    -- the tutorial popup and the new player experience's screen prompts
    "Tutorial", "NewPlayerTutorial",
    -- the StaticPopup dialogs (ADR-037)
    "Popups"
  }
  for _, name in ipairs(forever) do
    step("forbid." .. name:lower(), function() WFI.Labels.forbidNames(WFI[name].NEVER_TOUCH) end)
  end
  step("character", WFI.Character.init)
  step("reputation", WFI.Reputation.init)
  step("skills", WFI.Skills.init)
  step("pvprank", WFI.PvPRank.init) -- the character window's PvP rank panel
  step("spellbook", WFI.SpellBook.init)
  step("talents", WFI.Talents.init)
  step("trainer", WFI.Trainer.init)
  step("gossipchrome", WFI.GossipChrome.init)
  step("merchant", WFI.Merchant.init)
  step("bank", WFI.Bank.init)
  step("bags", WFI.Bags.init)
  step("mail", WFI.Mail.init)
  step("friends", WFI.Friends.init)
  step("friends.tooltip", WFI.FriendsTooltip.init) -- the friends list's own tooltip (zone / realm)
  step("communities", WFI.Communities.init) -- the guild UI is the Communities window
  -- the rest of the Communities window (chrome, guild benefits, ClubFinder, applicants, dialogs)
  step("communities.frame", WFI.CommunitiesFrame.init)
  step("communities.benefits", WFI.CommunitiesGuild.init)
  step("communities.clubfinder", WFI.ClubFinder.init)
  step("communities.applicants", WFI.ClubFinderApplicants.init)
  step("communities.dialogs", WFI.CommunitiesDialogs.init)
  step("raid", WFI.Raid.init)
  step("micromenu", WFI.MicroMenu.init)
  for _, name in ipairs(forever) do step(name:lower(), function() return WFI[name].init() end) end
  -- NPC speech, after ChatSystem (in the list above): it rewrites lines through the chat side's Alt / switch
  step("speech", function() WFI.Speech.init({ key = gossipKey, expand = expand }) end) -- NPC speech
  -- menu entries (Menu.ModifyMenu per tag) and HelpTip callouts, for every window above
  step("menus", WFI.Menus.init)
  step("menus.untagged", WFI.MenusUntagged.init) -- the Options and Edit Mode dropdowns (no tag)
  step("helptips", WFI.HelpTips.init)
  step("scan", WFI.Scan.init) -- /wfi debug ui scan
  step("slash", WFI.Slash.register)
  step("minimapbutton", function() WFI.MinimapButton.init(WFI_DB) end) -- the fix-report minimap button
  step("diag.timer", function()
    if type(C_Timer) == "table" then C_Timer.NewTicker(WFI.Diag.CHECK_INTERVAL, WFI.Diag.tick) end
  end)
  step("taintwatch", WFI.TaintWatch.init) -- the action-bar taint watch (UI/TaintWatch)

  -- The settings pages lean on client templates; a failure there must not take /wfi down with it (three
  -- pages, one AddOns category + two subcategories). The page error keeps its own field (the settings surface
  -- reads it) as well as being recorded by the guard.
  local ok, err = pcall(function()
    WFI.Compat.registerOptions(WFI.Options.build())
  end)
  if not ok then
    WFI.Options.buildError = tostring(err)
    WFI.initErrors[#WFI.initErrors + 1] = { surface = "options", err = tostring(err) }
  end
  -- the AddOn List's "Settings" button; retried on Blizzard_AddOnList's ADDON_LOADED
  step("addonlistbutton", WFI.AddonListButton.install)
  step("diag.session", function()
    local version, build = GetBuildInfo()
    WFI.Diag.session({ build = tostring(version) .. "." .. tostring(build),
      version = WFI.VERSION,
      initErrors = WFI.initErrors })
  end)
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, name, ...)
  if event == "ADDON_LOADED" then
    if name == ADDON then
      if WFI.loaded then return end -- ADDON_LOADED stays registered for the load-on-demand addons
      WFI.loaded = true
      WFI.OnLoad()
      self:RegisterEvent("MODIFIER_STATE_CHANGED")
      self:RegisterEvent("PLAYER_ENTERING_WORLD")
      self:RegisterEvent("PLAYER_REGEN_DISABLED")
      self:RegisterEvent("PLAYER_REGEN_ENABLED")
      self:RegisterEvent("PLAYER_LOGOUT")
      for _, blocked in ipairs(WFI.Diag.BLOCK_EVENTS) do self:RegisterEvent(blocked) end
    else
      -- Guarded like the load sequence. These run the deferred setup for the talent frame, the trainer and the
      -- raid roster; a failure in the first must not stop the second from running for the same event.
      if name == "Blizzard_AddOnList" and WFI.loaded then
        step("addonlistbutton", WFI.AddonListButton.install) -- listed after us
      end
      if WFI.LoadOnDemand then
        -- Blizzard_PlayerSpells / _TrainerUI / _RaidUI arrive later
        step("loadondemand." .. tostring(name), function() WFI.LoadOnDemand.loaded(name) end)
      end
    end
  elseif event == "ADDON_ACTION_BLOCKED" or event == "ADDON_ACTION_FORBIDDEN" then
    if WFI.Diag.onBlocked(event, name, ..., ADDON) then WFI.TaintWatch.onBlocked() end
  elseif event == "PLAYER_REGEN_DISABLED" then
    WFI.Options.setCombat(true)
  elseif event == "PLAYER_REGEN_ENABLED" then
    WFI.RevealBinding.flush() -- a modifier change made in combat
    WFI.Options.setCombat(false)
  elseif event == "PLAYER_LOGOUT" then
    WFI.VoicePlayer.stop() -- the dialog channel is saved with the logout: put it back first
    WFI.VoiceErrors.restore() -- and the error speech
  elseif event == "MODIFIER_STATE_CHANGED" then
    WFI.Modifier.refresh()
  elseif event == "PLAYER_ENTERING_WORLD" then
    local isLogin, isReload = name, ... -- PLAYER_ENTERING_WORLD(isInitialLogin, isReloadingUi)
    if isLogin or isReload then WFI.RevealBinding.apply() end -- again once bindings are loaded
    WFI.Modifier.refresh()
    local disclosed = WFI.Collector.disclose() -- once per dump, after the chat frame is up
    -- never on a zone change; time() is the client's clock [verified: forever-ui-1.60.1.70170
    -- blizzard_friendsframe/camelot/friendsframe.lua:1456]
    if isLogin or isReload then
      step("collectorremind", function()
        WFI.CollectorRemind.run(WFI_DB, time(), WFI.CollectorReminder.open, disclosed)
      end)
      step("intro", function() WFI.Intro.run(WFI_DB, WFI.IntroWindow.request) end) -- once, on a first install
    end
    -- every addon has loaded by now: another one (BugGrabber) may have replaced our error handler; and the player's
    -- name is known, so an error caught earlier loses it
    WFI.ErrorLog.checkOurs(geterrorhandler)
    WFI.ErrorLog.rescrub()
    -- Fonts the client refused before the bundled font file finished loading (a fresh launch): retry once a second
    -- until none is pending (the file can take 30 s or more to load), with a 10-minute safety stop.
    local function retry() return WFI.Render.retryFonts() + WFI.Font.retryPending() end
    local left = retry()
    if left > 0 then WFI.Font.startProbe(WFI.Compat.resolve("UIParent")) end -- make the client load the font file
    WFI.fontRetry = WFI.fontRetry or { at = GetTime(), tries = 0, left = left, timer = type(C_Timer) == "table" }
    if left > 0 and type(C_Timer) == "table" and not WFI.fontTicker then
      WFI.fontRetry.running = true
      WFI.fontTicker = C_Timer.NewTicker(1, function(ticker)
        local state = WFI.fontRetry
        state.tries = state.tries + 1
        state.left = retry()
        if state.left == 0 or state.tries >= 600 then
          WFI.Font.stopProbe()
          ticker:Cancel()
          WFI.fontTicker = nil
          state.running = false
        end
      end)
    end
  end
end)
