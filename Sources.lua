-- Where gear comes from, under a "Source:" heading naming the kinds (Quest, Dungeon, Raid, Boss,
-- Enemy, Vendor, Crafted, Chest, World Drop, Random Chests), one line each with its icon:
--   Source: Dungeon, Quest          (one source: on this line, "Source: [chest] Random chests and containers")
--     [portal] Herod - Scarlet Monastery
--     [!] In the Name of the Light            Level 40
-- The data is a separate addon (JustTheTooltip_Sources), loaded the first time you hover gear with
-- this option on, so it costs nothing until it's needed. Quest and vendor lines are for your
-- faction only.
local _, ns = ...
local S = {}
ns.Sources = S
local Readable = ns.Readable

local WHITE, GREY, GOLD = "|cffffffff", "|cff9d9d9d", "|cffffd100"
local MAX_LINES = 3 -- the rest: "+N more sources"
local RANK = { [1] = "Elite", [2] = "Rare Elite", [3] = "Boss", [4] = "Rare" }

-- The companion's data, loaded the first time it's needed. Tried once a session: a load the game
-- refuses (disabled, missing, out of date) stays refused until a reload. Why is kept for /jtt debug.
local data, tried
S.loadState = "not asked yet"
local function Data()
  if data or tried then return data end
  tried = true
  if type(JustTheTooltipSources) ~= "table" then
    local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    local ok, loaded, reason = false, nil, nil
    if load then ok, loaded, reason = pcall(load, "JustTheTooltip_Sources") end
    if not (ok and loaded) then S.loadState = "not loaded (" .. tostring(ok and reason or (load and "error" or "no LoadAddOn")) .. ")" end
  end
  data = type(JustTheTooltipSources) == "table" and JustTheTooltipSources or nil
  if data then S.loadState = "loaded" end
  return data
end
-- installed (and not disabled): for the option's note
function S.Available()
  if type(JustTheTooltipSources) == "table" then return true end
  local get = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
  if not get then return false end
  local ok, name, _, _, _, reason = pcall(get, "JustTheTooltip_Sources")
  return ok and name ~= nil and reason ~= "MISSING" and reason ~= "DISABLED"
end

local zones = {}
local function Zone(id)
  id = tonumber(id)
  if not id or id == 0 then return "" end
  if zones[id] == nil then
    local name
    if C_Map and C_Map.GetAreaInfo then
      local ok, n = pcall(C_Map.GetAreaInfo, id)
      if ok and Readable(n) and type(n) == "string" then name = n end
    end
    zones[id] = name or ""
  end
  return zones[id]
end

local function Split(s)
  local t = {}
  for p in ((s or "") .. "|"):gmatch("(.-)|") do t[#t + 1] = p end
  return t
end
local function Levels(a, b)
  a, b = tonumber(a) or 0, tonumber(b) or 0
  if a == 0 then return "" end
  if b ~= 0 and b ~= a then return format("Level %d-%d", a, b) end
  return "Level " .. a
end
-- "12,34:15,56+3": the IDs, how many more, and drop chances (percent) where given ("34:15")
local function Ids(s)
  local list, more = s:match("^([%d,:%.]*)%+?(%d*)$")
  local t, chance = {}, {}
  for id, c in (list or ""):gmatch("(%d+):?([%d%.]*)") do
    t[#t + 1] = tonumber(id)
    if c ~= "" then chance[tonumber(id)] = tonumber(c) end
  end
  return t, tonumber(more) or 0, chance
end
-- (Drop chances aren't shown: they're Classic's loot tables, and WoW: Forever's may differ. They
-- only decide which drops are listed first, so "+N more" holds the least likely.)

-- Icons: the game's own (the world map's dungeon and raid portals, the quest marker), each with an
-- older texture to fall back on where the client lacks the atlas.
local ICON = 14
local ICONS = {
  Quest = { atlas = "Crosshair_Quest_96", file = "Interface\\GossipFrame\\AvailableQuestIcon" },
  Dungeon = { atlas = "Dungeon", file = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" },
  Raid = { atlas = "Raid", file = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" },
  Boss = { file = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" },
  Enemy = { file = "Interface\\TargetingFrame\\UI-TargetingFrame-Skull" },
  Vendor = { file = "Interface\\GossipFrame\\VendorGossipIcon" },
  Chest = { atlas = "VignetteLoot", file = "Interface\\Icons\\INV_Box_02", crop = true },
  ["World Drop"] = { atlas = "VignetteLoot", file = "Interface\\Icons\\INV_Box_02", crop = true },
  ["Random Chests"] = { atlas = "VignetteLoot", file = "Interface\\Icons\\INV_Box_02", crop = true },
  Crafted = { atlas = "Professions-up-c60", file = "Interface\\Icons\\Trade_BlackSmithing", crop = true },
}
-- a profession's own icon (by skill line), before the generic one
local PROFESSION_ICONS = {
  [164] = "Trade_BlackSmithing", [165] = "INV_Misc_ArmorKit_17", [197] = "Trade_Tailoring",
  [202] = "Trade_Engineering", [333] = "Trade_Engraving", [171] = "Trade_Alchemy",
  [185] = "INV_Misc_Food_15", [129] = "Spell_Holy_SealOfSacrifice", [356] = "Trade_Fishing",
  [186] = "Trade_Mining", [182] = "Spell_Nature_NatureTouchGrow", [393] = "INV_Misc_Pelt_Wolf_01",
}
local icons = {}
local function HasAtlas(a)
  if not (a and C_Texture and C_Texture.GetAtlasInfo) then return false end
  local ok, info = pcall(C_Texture.GetAtlasInfo, a)
  return ok and info ~= nil
end
local function FileIcon(file, crop)
  if crop then return format("|T%s:%d:%d:0:0:64:64:5:59:5:59|t", file, ICON, ICON) end -- (an icon's own border cut off)
  return format("|T%s:%d:%d|t", file, ICON, ICON)
end
local function Icon(kind, skill)
  if kind == "Crafted" and skill and PROFESSION_ICONS[skill] then
    return FileIcon("Interface\\Icons\\" .. PROFESSION_ICONS[skill], true)
  end
  if icons[kind] == nil then
    local i = ICONS[kind]
    if not i then icons[kind] = ""
    elseif HasAtlas(i.atlas) then icons[kind] = format("|A:%s:%d:%d|a", i.atlas, ICON, ICON)
    else icons[kind] = FileIcon(i.file, i.crop) end
  end
  return icons[kind]
end

-- most useful first: quests, drops (the likeliest first), vendors, professions, world drops, chests
local function Sort(t)
  table.sort(t, function(a, b)
    if a.prio ~= b.prio then return a.prio < b.prio end
    local ca, cb = a.chance or 0, b.chance or 0
    if ca ~= cb then return ca > cb end
    if (a.nr or false) ~= (b.nr or false) then return b.nr or false end
    return a.order < b.order
  end)
end

-- Provenance (1.8.0): each line says where it came from (`from`) and how far to trust it
-- (`trust`). Ordinary tooltips don't show this: /jtt source <item> does (SOURCE_DATA.md).
local FROM = {
  data = "JTT's data (QuestieDB, WoW: Forever)", questie = "Questie, in game", needroll = "NeedRoll, in game",
}
local TRUST = {
  Quest = "database", Vendor = "database (your faction)", Chest = "database", ["World Drop"] = "database (many creatures)",
  ["Random Chests"] = "database (random loot)", Crafted = "the game client's tables",
}
S.FROM = FROM
-- a drop's trust: database; its place in the list from Classic 1.12's loot tables when known
local function DropTrust(chance)
  return chance and "database; listed by Classic 1.12 drop chance (not Forever's)" or "database"
end

-- an item's sources from `entry` (our data's format, looked up in `d`): { { kind, text, right,
-- prio, order, name, zone, skill, from, trust }, ... } and how many more of each kind there are past
-- those named. `origin`: "data" (ours) or "questie".
local function Build(d, entry, origin)
  local mine = UnitFactionGroup and UnitFactionGroup("player")
  mine = (mine == "Alliance" and "A") or (mine == "Horde" and "H") or nil
  local instances = d.instances or {}
  local out, more, seen = {}, {}, {}
  -- most useful first: quests, dungeon and boss drops, drops, vendors, professions, world drops, chests
  local function add(kind, text, right, prio, name, zone, skill) -- (two chests of the same name: one line)
    if seen[kind .. text] then return {} end
    seen[kind .. text] = true
    local l = { kind = kind, text = text, right = right or "", prio = prio, order = #out, name = name, zone = zone or "", skill = skill,
      from = FROM[origin or "data"], trust = TRUST[kind] or "database" }
    out[#out + 1] = l
    return l
  end
  local randomChests = false
  for part in (entry .. ";"):gmatch("([^;]+);") do
    local kind, rest = part:sub(1, 1), part:sub(2)
    if kind == "q" then
      for _, q in ipairs((Ids(rest))) do
        local r = Split(d.quests[q])
        if r[1] and (r[3] == "" or not mine or r[3] == mine) then add("Quest", r[1], Levels(r[2]), 1, r[1]) end
      end
    elseif kind == "d" or kind == "v" then
      local ids, extra, chance = Ids(rest)
      more[kind] = (more[kind] or 0) + extra
      for _, n in ipairs(ids) do
        local r = Split(d.npcs[n])
        if r[1] then
          local zone = Zone(r[5])
          if kind == "d" then
            local inst = instances[tonumber(r[5]) or 0]
            local rankN = tonumber(r[4]) or 0
            -- (all drops together, the likeliest first: see Sort)
            if inst then -- in a dungeon or raid: "Herod - Scarlet Monastery"
              local l = add(inst == 2 and "Raid" or "Dungeon", r[1] .. (zone ~= "" and (" - " .. zone) or ""), nil, 2, r[1], zone)
              l.chance = chance[n]; if l.kind then l.trust = DropTrust(l.chance) end
            else -- out in the world: the creature, its rank, and where
              local rank = RANK[rankN]
              local l = add(rankN == 3 and "Boss" or "Enemy", r[1] .. ((rank and rankN ~= 3) and (GREY .. " (" .. rank .. ")|r") or ""),
                zone, 2, r[1], zone)
              l.chance = chance[n]; if l.kind then l.trust = DropTrust(l.chance) end
            end
          elseif not mine or (r[6] or ""):find(mine) then
            add("Vendor", r[1], zone, 4, r[1], zone)
          end
        end
      end
    elseif kind == "w" then
      local a, b = rest:match("(%d+)%-(%d+)")
      add("World Drop", "World drop", Levels(a, b), 6)
    elseif kind == "o" then
      local ids, extra = Ids(rest)
      more.o = (more.o or 0) + extra
      for _, o in ipairs(ids) do
        local r = Split(d.objects[o])
        -- (an "Alliance Chest" when you're Horde: not yours to open)
        local other = (mine == "A" and "^Horde ") or (mine == "H" and "^Alliance ") or nil
        if r[1] and not (other and r[1]:find(other)) then add("Chest", r[1], Zone(r[2]), 7, r[1], Zone(r[2])) end
      end
    elseif kind == "c" then
      local skill = tonumber(rest)
      add("Crafted", (d.skills or {})[skill] or "A profession", nil, 5, nil, nil, skill)
    elseif kind == "r" then
      randomChests = true
    end
  end
  -- random-loot chests ("Solid Chest"): only when there's nothing better to say
  if #out == 0 and randomChests then add("Random Chests", "Random chests and containers", nil, 8) end
  Sort(out)
  return out, more
end

-- Items our data doesn't have yet (new since it was built): asked of Questie, if it's installed, in
-- the same form (its database is where ours comes from).
-- (1.6.0) Questie's state, asked each time until it's settled, so nothing that's only true for a
-- moment is kept for the session:
--   "absent"    not loaded (maybe later: asked again)
--   "loading"   loaded, its database not ready yet (asked again; nothing about any item is kept)
--   "ready"     its item lookup works
--   "unusable"  ready by its own word, but without the item lookup (kept: it won't change)
-- Questie 12.9 and later bind QueryItemSingle as QuestieDB loads and say when they're ready
-- (Questie.API.isReady, verified by source); older ones bound it while starting up, which is why a
-- missing lookup only counts once Questie says it's ready.
local QDB
local function ApiReady()
  local api = type(Questie) == "table" and type(Questie.API) == "table" and Questie.API
  if api and api.isReady ~= nil then return api.isReady == true end
  return nil -- (no API: an older Questie; see below)
end
function S.QuestieState()
  if QDB == false then return "unusable" end
  if not QDB then
    if not (QuestieLoader and type(QuestieLoader.ImportModule) == "function") then return "absent" end
    local ok, db = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
    if ok and type(db) == "table" and type(db.QueryItemSingle) == "function" then
      QDB = db
    else
      if ApiReady() == true then QDB = false; return "unusable" end
      return "loading"
    end
  end
  local ready = ApiReady()
  if ready == nil then ready = QDB.QuestPointers ~= nil end -- (no API: once its quest list exists)
  return ready and "ready" or "loading"
end
local function QuestieDB()
  return S.QuestieState() == "ready" and QDB or nil
end
local function Ask(fn, id, key)
  if not fn then return nil end
  local ok, v = pcall(fn, id, key)
  if ok then return v end
end
local ALLIANCE, HORDE = 1 + 4 + 8 + 64, 2 + 16 + 32 + 128
local function FromQuestie(id)
  local db = QuestieDB()
  if not db then return nil end
  local function list(key)
    local t = Ask(db.QueryItemSingle, id, key)
    local out = {}
    if type(t) == "table" then for _, v in ipairs(t) do if type(v) == "number" then out[#out + 1] = v end end end
    return out
  end
  local quests, drops, vendors, objects = list("questRewards"), list("npcDrops"), list("vendors"), list("objectDrops")
  if #quests + #drops + #vendors + #objects == 0 then return nil end
  local band = bit and bit.band
  local d = { quests = {}, npcs = {}, objects = {}, instances = (Data() or {}).instances }
  local function npc(n)
    local name = Ask(db.QueryNPCSingle, n, "name")
    if type(name) ~= "string" then return false end
    d.npcs[n] = table.concat({ name, Ask(db.QueryNPCSingle, n, "minLevel") or 0, Ask(db.QueryNPCSingle, n, "maxLevel") or 0,
      Ask(db.QueryNPCSingle, n, "rank") or 0, Ask(db.QueryNPCSingle, n, "zoneID") or 0,
      Ask(db.QueryNPCSingle, n, "friendlyToFaction") or "" }, "|")
    return true
  end
  local parts = {}
  local function ids(prefix, t, max)
    local keep = {}
    for i = 1, math.min(#t, max) do keep[#keep + 1] = t[i] end
    parts[#parts + 1] = prefix .. table.concat(keep, ",") .. (#t > max and ("+" .. (#t - max)) or "")
  end
  local q = {}
  for _, id2 in ipairs(quests) do
    local name = Ask(db.QueryQuestSingle, id2, "name")
    if type(name) == "string" then
      local races = tonumber(Ask(db.QueryQuestSingle, id2, "requiredRaces")) or 0
      local fac = ""
      if band and races ~= 0 and not (band(races, ALLIANCE) ~= 0 and band(races, HORDE) ~= 0) then
        fac = band(races, ALLIANCE) ~= 0 and "A" or "H"
      end
      d.quests[id2] = table.concat({ name, Ask(db.QueryQuestSingle, id2, "questLevel") or 0, fac }, "|")
      q[#q + 1] = id2
    end
  end
  if #q > 0 then ids("q", q, 6) end
  local dr = {}
  for _, n in ipairs(drops) do if npc(n) then dr[#dr + 1] = n end end
  if #dr > 12 then -- (dropped by many creatures: a world drop)
    local lo, hi = nil, 0
    for _, n in ipairs(dr) do
      local r = Split(d.npcs[n]); local a, b = tonumber(r[2]) or 0, tonumber(r[3]) or 0
      if a > 0 then lo = math.min(lo or a, a) end; hi = math.max(hi, b)
    end
    parts[#parts + 1] = format("w%d-%d", lo or 0, hi)
  elseif #dr > 0 then ids("d", dr, 6) end
  local ve = {}
  for _, n in ipairs(vendors) do if npc(n) then ve[#ve + 1] = n end end
  if #ve > 0 then ids("v", ve, 6) end
  local ob = {}
  for _, o in ipairs(objects) do
    local name = Ask(db.QueryObjectSingle, o, "name")
    if type(name) == "string" then d.objects[o] = name .. "|" .. (Ask(db.QueryObjectSingle, o, "zoneID") or 0); ob[#ob + 1] = o end
  end
  if #ob > 0 then ids("o", ob, 6) end
  if #parts == 0 then return nil end
  return d, table.concat(parts, ";")
end

-- An item's lines, kept for the session once they're final: from our data, or from Questie once
-- it's ready (an item it doesn't know is final then too). While Questie is absent or loading,
-- nothing is kept, so its answer is used as soon as there is one.
local cache = {}
S.cache = cache -- (for checks)
local function Lines(id)
  if cache[id] then return cache[id][1], cache[id][2] end
  local d = Data()
  local entry = d and d.items and d.items[id]
  if not entry then
    local qd, qentry = FromQuestie(id)
    if not qd then
      local state = S.QuestieState()
      if state == "absent" or state == "loading" then return {}, {} end -- (ask again next time)
      cache[id] = { {}, {} }; return cache[id][1], cache[id][2]
    end
    d, entry = qd, qentry
  end
  local out, more = Build(d, entry, d == Data() and "data" or "questie")
  cache[id] = { out, more }
  return out, more
end

-- NeedRoll (a loot browser for Forever) lists, on item tooltips, the dungeon and raid bosses (and
-- trash) that drop an item and the dungeon quests that reward it, from newer loot tables than
-- ours: "<icon> Ragglesnout - Razorfen Downs". It adds them first (it hooks tooltips as it loads,
-- we at login), so we leave out our drops in a dungeon it names, and any boss, quest, vendor or
-- chest already named; open-world drops, vendors, crafting and chests it doesn't cover stay.
local needRoll = false
local function NeedRollLoaded()
  if not needRoll then -- (asked each time until it is: it may load after us)
    local loaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    for _, name in ipairs({ "NeedRoll", "Needroll", "needroll" }) do
      local ok, on = false, nil
      if loaded then ok, on = pcall(loaded, name) end
      if ok and on then needRoll = true; break end
    end
  end
  return needRoll
end

-- With NeedRoll installed, Just the Tooltip! draws all the sources: NeedRoll's own tooltip lines are
-- off for the session (its "tooltip lines" setting, put back as it was on logout or when our
-- sources are turned off, so its saved setting doesn't change), and what NeedRoll knows is read
-- from a hidden tooltip and shown our way. Its dungeon and raid loot is newer than ours: where it
-- names a dungeon, its drops there replace ours.
local held, heldValue = false, nil
local function CanHold() return NeedRollLoaded() and type(NeedRollDB) == "table" end
local scanTip
function S.Hold() -- at login, and when our sources are turned on or off
  if ns.db and ns.db.sources and CanHold() then
    if not held then held, heldValue = true, NeedRollDB.tooltipSources end
    NeedRollDB.tooltipSources = false
  else
    S.Release()
  end
end
function S.Holding() return held end
function S.NeedRollLoaded() return NeedRollLoaded() end
function S.Release() -- logout (before NeedRoll's setting is saved), and our sources turned off
  -- (still off as we left it: back as it was; turned on in NeedRoll's own settings since: kept)
  if held and type(NeedRollDB) == "table" and NeedRollDB.tooltipSources == false then NeedRollDB.tooltipSources = heldValue end
  held = false
end

local nrCache = {}
local raidNames
local function IsRaid(where)
  if not raidNames then
    raidNames = { ["molten core"] = true, ["onyxia's lair"] = true, ["blackwing lair"] = true, ["zul'gurub"] = true,
      ["ruins of ahn'qiraj"] = true, ["temple of ahn'qiraj"] = true, ["naxxramas"] = true }
    local d = Data()
    for z, t in pairs(d and d.instances or {}) do
      if t == 2 then local n = Zone(z); if n ~= "" then raidNames[n:lower()] = true end end
    end
  end
  return raidNames[where:lower()] or false
end
-- NeedRoll's sources for item `id`, our way: { lines, more }
local function FromNeedRoll(id)
  if nrCache[id] then return nrCache[id] end
  local res = { lines = {}, more = 0 }
  if not scanTip then
    scanTip = CreateFrame("GameTooltip", "JustTheTooltipNeedRollScan", nil, "GameTooltipTemplate")
  end
  local before = NeedRollDB.tooltipSources
  NeedRollDB.tooltipSources = nil -- (on, for this hidden tooltip only)
  scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
  local ok = pcall(scanTip.SetItemByID, scanTip, id)
  NeedRollDB.tooltipSources = before
  if ok then
    local afterNR = false
    for i = 2, scanTip:NumLines() do
      local fs = _G["JustTheTooltipNeedRollScanTextLeft" .. i]
      local okT, t = false, nil
      if fs then okT, t = pcall(fs.GetText, fs) end
      if okT and Readable(t) and type(t) == "string" then
        if t:find("^|[TA]") and t:find(" %- ") then
          local quest = t:find("Crosshair_Quest", 1, true) ~= nil
          local plain = t:gsub("^|T.-|t%s*", ""):gsub("^|A.-|a%s*", ""):gsub("%s*|A.-|a%s*$", ""):gsub("%s*|T.-|t%s*$", "")
          local who, where = plain:match("^(.*) %- (.-)$")
          if who and where then
            local l = quest and { kind = "Quest", text = who, right = where, prio = 1, name = who, zone = where }
              or { kind = IsRaid(where) and "Raid" or "Dungeon", text = who .. " - " .. where, right = "", prio = 2,
                name = who ~= "Trash" and who or nil, zone = where }
            l.from, l.trust = FROM.needroll, quest and "NeedRoll's dungeon quests" or "NeedRoll's loot tables (newer than JTT's)"
            l.order, l.nr = #res.lines, true
            res.lines[#res.lines + 1] = l
            afterNR = true
          end
        else
          -- its "+2 more", right under its lines (not an item's "+11 Stamina")
          local n = afterNR and t:match("^%+(%d+)")
          if n then res.more = res.more + tonumber(n) end
          afterNR = false
        end
      else
        afterNR = false
      end
    end
  end
  scanTip:Hide()
  nrCache[id] = res
  return res
end

-- /jtt source <item>: every source known for an item (not only the first three), each with where
-- it came from and how far to trust it; NeedRoll's too while JTT shows them its way. Lines of text.
function S.Explain(id)
  local L = {}
  if type(id) ~= "number" then return { "give an item ID or shift-click an item: /jtt source <item>" } end
  local lines, more = Lines(id)
  local all = {}
  for _, l in ipairs(lines) do all[#all + 1] = l end
  local nrZones = {}
  if held and CanHold() then
    for _, l in ipairs(FromNeedRoll(id).lines) do
      all[#all + 1] = l
      if l.kind ~= "Quest" then nrZones[#nrZones + 1] = l.zone:lower() end
    end
  end
  -- (1.9.0) JTT's drops in a dungeon NeedRoll names: NeedRoll's line is the one the tooltip shows
  local function Replaced(l)
    if l.from == FROM.needroll or #nrZones == 0 then return false end
    if not (l.kind == "Dungeon" or l.kind == "Raid" or l.kind == "Boss" or l.kind == "Enemy") then return false end
    local z = (l.zone or ""):lower()
    if z == "" then return true end
    for _, c in ipairs(nrZones) do if c:find(z, 1, true) or z:find(c, 1, true) then return true end end
    return false
  end
  L[1] = format("item %d: %d source%s known%s (data: %s; Questie: %s)", id, #all, #all == 1 and "" or "s",
    (function() local n = 0 for _, v in pairs(more) do n = n + v end return n > 0 and format(", +%d more not named", n) or "" end)(),
    S.loadState, S.QuestieState())
  for _, l in ipairs(all) do
    local plain = (l.text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
    L[#L + 1] = format("  %s: %s%s | from %s | %s%s%s", l.kind, plain, l.right ~= "" and (" (" .. l.right .. ")") or "",
      l.from or "?", l.trust or "?", l.chance and format(" | Classic 1.12 chance %s%%", l.chance) or "",
      Replaced(l) and " | not on the tooltip: NeedRoll's newer line for this dungeon replaces it" or "")
  end
  return L
end

-- what the tooltip already says (lower case), and NeedRoll's lines in it (an icon, then
-- "Boss - Instance")
local function Already(tip)
  local text, nr = {}, {}
  local name = tip.GetName and tip:GetName()
  if not name then return text, nr end
  local check = NeedRollLoaded()
  for i = 1, tip:NumLines() do
    for _, side in ipairs({ "TextLeft", "TextRight" }) do
      local fs = _G[name .. side .. i]
      local ok, t = false, nil
      if fs and fs.GetText then ok, t = pcall(fs.GetText, fs) end
      if ok and Readable(t) and type(t) == "string" and t ~= "" then
        text[#text + 1] = t:lower()
        if check and side == "TextLeft" and t:find("^|[TA]") and t:find(" %- ") then nr[#nr + 1] = t:lower() end
      end
    end
  end
  return text, nr
end
local function Says(text, what)
  what = what:lower()
  for _, t in ipairs(text) do if t:find(what, 1, true) then return true end end
  return false
end

-- With the detail key held (1.9.0): every source (no "+N more"), each tagged with where it was learned.
local function Tag(l)
  local t = l.from == FROM.needroll and "NeedRoll" or l.from == FROM.questie and "Questie" or "JTT data"
  if l.chance then t = t .. ", Classic order" end
  return " " .. GREY .. "(" .. t .. ")|r"
end
function S.Add(tip, id, detail)
  if not ((ns.db.sources or detail) and Readable(id) and type(id) == "number") then return end
  local lines, extra = Lines(id)
  local text, nr = Already(tip)
  -- JTT's own heading already there (the same tooltip written to twice): not again (1.8.0)
  for _, t in ipairs(text) do if t:find("^|cffffd100source:|r") then return end end
  -- NeedRoll's lines off: show what it knows our way. (Turned back on in its own settings, so they're
  -- in the tooltip: leave them, and add only what they don't say, below.)
  local nrRes = held and CanHold() and #nr == 0 and FromNeedRoll(id) or nil
  if nrRes and #nrRes.lines > 0 then
    -- NeedRoll's dungeons replace our drops there; its quests join ours (one line per quest)
    local covered, quests, merged, coveredAny = {}, {}, {}, false
    for _, l in ipairs(nrRes.lines) do
      if l.kind ~= "Quest" then covered[#covered + 1] = l.zone:lower(); coveredAny = true end
    end
    local function inCovered(zone)
      zone = zone:lower()
      for _, c in ipairs(covered) do if c:find(zone, 1, true) or zone:find(c, 1, true) then return true end end
      return false
    end
    local chanceOf = {} -- (our drop chances, to place NeedRoll's lines naming the same creature)
    for _, l in ipairs(lines) do if l.chance and l.name then chanceOf[l.name:lower()] = l.chance end end
    for _, l in ipairs(lines) do
      local isDrop = l.kind == "Dungeon" or l.kind == "Raid" or l.kind == "Boss" or l.kind == "Enemy"
      if not (isDrop and coveredAny and (l.zone == "" or inCovered(l.zone))) then
        merged[#merged + 1] = l
        if l.kind == "Quest" then quests[l.name:lower()] = true end
      end
    end
    for _, l in ipairs(nrRes.lines) do
      if not (l.kind == "Quest" and quests[l.name:lower()]) then
        local c = l.kind ~= "Quest" and l.name and chanceOf[l.name:lower()]
        if c then l = setmetatable({ chance = c }, { __index = l }) end -- (ours for that creature: for the order)
        merged[#merged + 1] = l
      end
    end
    Sort(merged)
    local e = {}
    for k, n in pairs(extra) do if not (coveredAny and k == "d") then e[k] = n end end
    e.nr = nrRes.more
    lines, extra = merged, e
  end
  if #lines == 0 then return end
  -- NeedRoll's drop lines (its quest lines have the quest marker)
  local nrDropLines = {}
  for _, t in ipairs(nr) do if not t:find("crosshair_quest", 1, true) then nrDropLines[#nrDropLines + 1] = t end end
  local show, more, nrDrops = {}, 0, false
  for _, l in ipairs(lines) do
    local isDrop = l.kind == "Dungeon" or l.kind == "Raid" or l.kind == "Boss" or l.kind == "Enemy"
    if isDrop and #nrDropLines > 0 and (l.zone == "" or Says(nrDropLines, l.zone)) then
      -- NeedRoll lists this dungeon's drops (and is more up to date). Ours with no zone are
      -- dungeon creatures too (our data places the ones out in the world).
      nrDrops = true
    elseif l.name and Says(text, l.name) then
      -- already in the tooltip (another addon named this boss, quest, vendor or chest)
    elseif #show < (detail and 99 or MAX_LINES) then
      show[#show + 1] = l
    else
      more = more + 1
    end
  end
  local unnamedData, unnamedNR = 0, 0 -- (sources only counted: the data's and NeedRoll's)
  for k, n in pairs(extra) do
    if not (nrDrops and k == "d") then -- (NeedRoll counts its own drops)
      more = more + n
      if k == "nr" then unnamedNR = unnamedNR + n else unnamedData = unnamedData + n end
    end
  end
  if #show == 0 and more == 0 then return end
  -- just one: on the heading line ("Source: [chest] Random chests and containers")
  if #show == 1 and more == 0 then
    local l = show[1]
    tip:AddDoubleLine(GOLD .. "Source:|r " .. Icon(l.kind, l.skill) .. " " .. WHITE .. l.text .. "|r" .. (detail and Tag(l) or ""), GREY .. l.right .. "|r")
    return
  end
  -- "Source: Dungeon, Quest", then a line for each
  local kinds, named = {}, {}
  for _, l in ipairs(show) do
    if not named[l.kind] then named[l.kind] = true; kinds[#kinds + 1] = l.kind end
  end
  tip:AddLine(GOLD .. "Source:|r " .. WHITE .. (#kinds > 0 and table.concat(kinds, ", ") or "More") .. "|r")
  for _, l in ipairs(show) do
    tip:AddDoubleLine("  " .. Icon(l.kind, l.skill) .. " " .. WHITE .. l.text .. "|r" .. (detail and Tag(l) or ""), GREY .. l.right .. "|r")
  end
  if more > 0 then
    if detail then
      -- (1.9.0) every named source is shown: what's left is only counted where it came from
      local why = {}
      if unnamedData > 0 then why[#why + 1] = format("%d not named (Just the Tooltip! names up to 6 of each kind)", unnamedData) end
      if unnamedNR > 0 then why[#why + 1] = format("%d NeedRoll counts but doesn't name (it names 3)", unnamedNR) end
      tip:AddLine("  " .. GREY .. format("+%d more: %s", more, table.concat(why, "; ")) .. "|r", nil, nil, nil, true)
    else
      tip:AddLine("  " .. GREY .. format("+%d more source%s", more, more == 1 and "" or "s") .. "|r")
    end
  end
end
