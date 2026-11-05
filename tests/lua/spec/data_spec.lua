-- Core/Data + the generated layout.
local H = require("tests.lua.spec.helpers")
local Stub = require("tests.lua.spec.wow_stub")
local Loader = require("tests.lua.spec.loader")

local function coreNS()
  H.coreStub()
  local ns = {}
  H.loadChunk("Core/Const.lua", "WoWForeverItalian", ns)
  H.loadPure("Core/Data.lua", "WoWForeverItalian", ns)
  H.loadPure("Core/Lookup.lua", "WoWForeverItalian", ns)
  return ns
end

describe("Core/Data.add", function()
  it("loads Data and Lookup under a std-lib-only environment (pure)", function()
    local ns = coreNS()
    assert.is_function(ns.Data.add)
    assert.is_function(ns.Lookup.get)
  end)

  it("copies rows in by id and counts them", function()
    local ns = coreNS()
    ns.Data.add("quest", { [2] = { "a" }, [5] = { "b" } })
    ns.Data.add("quest", { [7] = { "c" } })
    assert.are.equal("a", ns.Data.quest[2][1])
    assert.are.equal(3, ns.Data.count("quest"))
    assert.are.equal(0, ns.Data.count("gossip"))
  end)

  it("raises on a duplicate id and on an unknown type", function()
    local ns = coreNS()
    ns.Data.add("item", { [117] = { "x", 0x1, "u" } })
    assert.has_error(function() ns.Data.add("item", { [117] = { "y", 0x1, "u" } }) end)
    assert.has_error(function() ns.Data.add("unit", { [1] = { "x" } }) end)
  end)

  it("round-trips the escaping fixture written by the Python writer", function()
    local ns = coreNS()
    local chunk = assert(loadfile(H.ROOT .. "/tests/fixtures/lua/escape_fixture.lua"))
    chunk("WoWForeverItalian", ns)
    local row = ns.Data.quest[1]
    assert.are.equal('He said "hi"\\ok\n[tag] |cffff0000red|r\ttab\001end\r', row[1])
    assert.is_nil(row[2])
    assert.are.equal("改行\nあり", row[3])
    assert.are.equal(0xd311f9a5, row[6])
    assert.are.equal(".msmm", row[11])
    assert.are.equal("[[]]", ns.Data.quest[2][2])
    assert.are.equal("m.mmm", ns.Data.quest[2][11])
  end)
end)

describe("generated layout matches Core/Const.lua", function()
  local WFI
  setup(function()
    Stub.install(H.ADDON_DIR .. "/WoWForeverItalian.toc")
    WFI = Loader.load("WoWForeverItalian")
  end)

  it("Meta.fields equals SLOTS.fields for every type, and rows have the status slot", function()
    assert.is_table(WFI.Data.meta)
    for _, t in ipairs({ "quest", "item", "spell" }) do
      assert.are.same(WFI.SLOTS[t].fields, WFI.Data.meta.fields[t], t)
      assert.are.equal(WFI.Data.meta.counts[t], WFI.Data.count(t), t)
      local _, row = next(WFI.Data[t])
      if row or t == "quest" then -- items and spells ship from phase 3
        assert.is_string(row[WFI.SLOTS[t].status], t)
        assert.are.equal(#WFI.SLOTS[t].fields, #row[WFI.SLOTS[t].status], t)
      end
    end
    assert.are.equal(11, WFI.SLOTS.quest.female) -- twin of schema.SLOTS["quest"]["female"]
    assert.is_nil(WFI.SLOTS.item.female); assert.is_nil(WFI.SLOTS.spell.female)
    assert.are.equal(1, WFI.Data.meta.schema)
    assert.are.equal(WFI.SCHEMA, WFI.Data.meta.schema)
    assert.is_string(WFI.Data.meta.english.collector) -- the English the shipped rows were checked against
  end)

  it("area is laid out as objective is ({ text, h1, status }), in Meta and Const alike", function()
    for _, t in ipairs({ "objective", "area" }) do
      assert.are.same({ fields = { "text" }, hash = 1, status = 3, index = { text = 1 } }, WFI.SLOTS[t], t)
      assert.are.same(WFI.SLOTS[t].fields, WFI.Data.meta.fields[t], t)
      assert.are.equal(WFI.Data.meta.counts[t], WFI.Data.count(t), t)
    end
  end)

  it("ui rows are { text, h1, status } keyed by global-string name, counted in Meta", function()
    assert.are.same({ fields = { "text" }, hash = 1, status = 3, index = { text = 1 } }, WFI.SLOTS.ui)
    assert.are.equal(WFI.Data.meta.counts.ui, WFI.Data.count("ui"))
    -- the interface ships from phase 3: a stand-in row in the shipped layout
    WFI.Data.add("ui", { ACCEPT = { "Accetta", 0x12345678, "." } })
    local row = WFI.Data.ui.ACCEPT
    assert.are.equal(3, #row)
    assert.is_string(row[1]); assert.is_number(row[2]); assert.are.equal(".", row[3])
    local e = WFI.Lookup.get("ui", "ACCEPT")
    assert.are.same({ ja = row[1], status = ".", h1 = row[2] }, e)
    assert.is_nil(WFI.Lookup.get("ui", "NOT_A_KEY"))
  end)

  it("ships the hash vectors and every case passes in-client (debug hash data)", function()
    local V = WFI.Data.vectors
    assert.is_table(V)
    assert.are.equal(#H.vectors().cases, #V.cases)
    for _, c in ipairs(V.cases) do
      assert.are.equal(c.key, WFI.Hash.keyOf(c.raw, c.player), c.id)
    end
  end)
end)
