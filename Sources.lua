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

-- an item's sources: { { kind, text, right, prio, order, name, zone, skill }, ... } and how many
-- more of each kind there are past those named (cached per item)
local cache = {}
local function Lines(id)
  if cache[id] then return cache[id][1], cache[id][2] end
  local d = Data()
  local entry = d and d.items and d.items[id]
  if not entry then cache[id] = { {}, {} }; return cache[id][1], cache[id][2] end
  local mine = UnitFactionGroup and UnitFactionGroup("player")
  mine = (mine == "Alliance" and "A") or (mine == "Horde" and "H") or nil
  local instances = d.instances or {}
  local out, more, seen = {}, {}, {}
  -- most useful first: quests, dungeon and boss drops, drops, vendors, professions, world drops, chests
  local function add(kind, text, right, prio, name, zone, skill) -- (two chests of the same name: one line)
    if seen[kind .. text] then return end
    seen[kind .. text] = true
    out[#out + 1] = { kind = kind, text = text, right = right or "", prio = prio, order = #out, name = name, zone = zone or "", skill = skill }
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
      add("Crafted", d.skills[skill] or "A profession", nil, 5, nil, nil, skill)
    elseif kind == "r" then
      randomChests = true
    end
  end
  -- random-loot chests ("Solid Chest"): only when there's nothing better to say
  if #out == 0 and randomChests then add("Random Chests", "Random chests and containers", nil, 8) end
  table.sort(out, function(a, b) if a.prio ~= b.prio then return a.prio < b.prio end return a.order < b.order end)
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
  if #lines == 0 then return end
  local text, nr = Already(tip)
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
