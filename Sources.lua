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

local data, tried
local function Data()
  if data or tried then return data end
  tried = true
  if type(JustTheTooltipSources) ~= "table" then
    local load = (C_AddOns and C_AddOns.LoadAddOn) or LoadAddOn
    if load then pcall(load, "JustTheTooltip_Sources") end
  end
  data = type(JustTheTooltipSources) == "table" and JustTheTooltipSources or nil
  return data
end
-- installed (and not disabled): for the option's note
function S.Available()
  if type(JustTheTooltipSources) == "table" then return true end
  local get = C_AddOns and C_AddOns.GetAddOnInfo or GetAddOnInfo
  if not get then return false end
  local ok, name, _, _, loadable, reason = pcall(get, "JustTheTooltip_Sources")
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
local function Ids(s)
  local list, more = s:match("^([%d,]*)%+?(%d*)$")
  local t = {}
  for id in (list or ""):gmatch("%d+") do t[#t + 1] = tonumber(id) end
  return t, tonumber(more) or 0
end

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

-- an item's sources from `entry` (our data's format, looked up in `d`): { { kind, text, right,
-- prio, order, name, zone, skill }, ... } and how many more of each kind there are past those named
local function Build(d, entry)
  local mine = UnitFactionGroup and UnitFactionGroup("player")
  mine = (mine == "Alliance" and "A") or (mine == "Horde" and "H") or nil
  local instances = d.instances or {}
  local out, more, seen = {}, {}, {}
  -- most useful first: quests, dungeon and boss drops, drops, vendors, professions, world drops, chests
  local function add(kind, text, right, prio, name, zone, skill) -- (two chests of the same name: one line)
    if seen[kind .. text] then return {} end
    seen[kind .. text] = true
    local l = { kind = kind, text = text, right = right or "", prio = prio, order = #out, name = name, zone = zone or "", skill = skill }
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
      local ids, extra = Ids(rest)
      more[kind] = (more[kind] or 0) + extra
      for _, n in ipairs(ids) do
        local r = Split(d.npcs[n])
        if r[1] then
          local zone = Zone(r[5])
          if kind == "d" then
            local inst = instances[tonumber(r[5]) or 0]
            local rankN = tonumber(r[4]) or 0
            if inst then -- in a dungeon or raid: "Herod - Scarlet Monastery"
              add(inst == 2 and "Raid" or "Dungeon", r[1] .. (zone ~= "" and (" - " .. zone) or ""), nil, 2, r[1], zone)
            else -- out in the world: the creature, its rank, and where
              local rank = RANK[rankN]
              add(rankN == 3 and "Boss" or "Enemy", r[1] .. ((rank and rankN ~= 3) and (GREY .. " (" .. rank .. ")|r") or ""),
                zone, rank and 2 or 3, r[1], zone)
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
  table.sort(out, function(a, b) if a.prio ~= b.prio then return a.prio < b.prio end return a.order < b.order end)
  return out, more
end

-- Items our data doesn't have yet (new since it was built): asked of Questie, if it's installed, in
-- the same form (its database is where ours comes from).
local QDB
-- Questie's database once Questie says it's ready (its API), or once its quest list exists
local function QuestieReady()
  local api = type(Questie) == "table" and Questie.API
  if api and api.isReady ~= nil then return api.isReady and true or false end
  return QDB and QDB.QuestPointers ~= nil or false
end
local function QuestieDB()
  if QDB == nil then
    if not (QuestieLoader and QuestieLoader.ImportModule) then return nil end -- (not loaded: ask later)
    local ok, db = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
    QDB = ok and type(db) == "table" and db.QueryItemSingle and db or false
  end
  if QDB and not QuestieReady() then return nil end
  return QDB or nil
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

local cache = {}
local function Lines(id)
  if cache[id] then return cache[id][1], cache[id][2] end
  local d = Data()
  local entry = d and d.items and d.items[id]
  if not entry then
    local qd, qentry = FromQuestie(id)
    if not qd then
      if QDB == nil or (QDB and not QuestieReady()) then return {}, {} end -- (Questie not ready yet: ask again next time)
      cache[id] = { {}, {} }; return cache[id][1], cache[id][2]
    end
    d, entry = qd, qentry
  end
  local out, more = Build(d, entry)
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

function S.Add(tip, id)
  if not (ns.db.sources and Readable(id) and type(id) == "number") then return end
  local lines, extra = Lines(id)
  local text, nr = Already(tip)
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
    for _, l in ipairs(lines) do
      local isDrop = l.kind == "Dungeon" or l.kind == "Raid" or l.kind == "Boss" or l.kind == "Enemy"
      if not (isDrop and coveredAny and (l.zone == "" or inCovered(l.zone))) then
        merged[#merged + 1] = l
        if l.kind == "Quest" then quests[l.name:lower()] = true end
      end
    end
    for _, l in ipairs(nrRes.lines) do
      if not (l.kind == "Quest" and quests[l.name:lower()]) then merged[#merged + 1] = l end
    end
    table.sort(merged, function(a, b)
      if a.prio ~= b.prio then return a.prio < b.prio end
      if (a.nr or false) ~= (b.nr or false) then return b.nr or false end
      return a.order < b.order
    end)
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
    elseif #show < MAX_LINES then
      show[#show + 1] = l
    else
      more = more + 1
    end
  end
  for k, n in pairs(extra) do
    if not (nrDrops and k == "d") then more = more + n end -- (NeedRoll counts its own drops)
  end
  if #show == 0 and more == 0 then return end
  -- just one: on the heading line ("Source: [chest] Random chests and containers")
  if #show == 1 and more == 0 then
    local l = show[1]
    tip:AddDoubleLine(GOLD .. "Source:|r " .. Icon(l.kind, l.skill) .. " " .. WHITE .. l.text .. "|r", GREY .. l.right .. "|r")
    return
  end
  -- "Source: Dungeon, Quest", then a line for each
  local kinds, named = {}, {}
  for _, l in ipairs(show) do
    if not named[l.kind] then named[l.kind] = true; kinds[#kinds + 1] = l.kind end
  end
  tip:AddLine(GOLD .. "Source:|r " .. WHITE .. (#kinds > 0 and table.concat(kinds, ", ") or "More") .. "|r")
  for _, l in ipairs(show) do
    tip:AddDoubleLine("  " .. Icon(l.kind, l.skill) .. " " .. WHITE .. l.text .. "|r", GREY .. l.right .. "|r")
  end
  if more > 0 then tip:AddLine("  " .. GREY .. format("+%d more source%s", more, more == 1 and "" or "s") .. "|r") end
end
