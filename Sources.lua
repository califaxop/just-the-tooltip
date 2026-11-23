-- Where gear comes from: quest reward, creature drop, vendor, chest, profession. The data is a
-- separate addon (JustTheTooltip_Sources), loaded the first time you hover gear with this option
-- on, so it costs nothing until it's needed. Quest and vendor lines are for your faction only.
local _, ns = ...
local S = {}
ns.Sources = S
local Readable = ns.Readable

local WHITE, GREY = "|cffffffff", "|cff9d9d9d"
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

-- an item's source lines: { { left, right, prio, order, kind, name }, ... } and how many more of
-- each kind there are past those named (cached per item)
local cache = {}
local function Lines(id)
  if cache[id] then return cache[id][1], cache[id][2] end
  local d = Data()
  local entry = d and d.items and d.items[id]
  if not entry then cache[id] = { {}, {} }; return cache[id][1], cache[id][2] end
  local mine = UnitFactionGroup and UnitFactionGroup("player")
  mine = (mine == "Alliance" and "A") or (mine == "Horde" and "H") or nil
  local out, more, seen = {}, {}, {}
  -- most useful first: quests, boss and elite drops, drops, vendors, professions, world drops, chests
  local function add(left, right, prio, kind, name) -- (two chests of the same name: one line)
    if seen[left] then return end
    seen[left] = true
    out[#out + 1] = { left, right or "", prio, #out, kind, name }
  end
  local randomChests = false
  for part in (entry .. ";"):gmatch("([^;]+);") do
    local kind, rest = part:sub(1, 1), part:sub(2)
    if kind == "q" then
      for _, q in ipairs((Ids(rest))) do
        local r = Split(d.quests[q])
        if r[1] and (r[3] == "" or not mine or r[3] == mine) then add("Quest: " .. r[1], Levels(r[2]), 1, "q", r[1]) end
      end
    elseif kind == "d" or kind == "v" then
      local ids, extra = Ids(rest)
      more[kind] = (more[kind] or 0) + extra
      for _, n in ipairs(ids) do
        local r = Split(d.npcs[n])
        if r[1] then
          if kind == "d" then
            local rank = RANK[tonumber(r[4]) or 0]
            add("Drop: " .. r[1] .. (rank and (GREY .. " (" .. rank .. ")|r") or ""), Zone(r[5]), rank and 2 or 3, "d", r[1])
          elseif not mine or (r[6] or ""):find(mine) then
            add("Vendor: " .. r[1], Zone(r[5]), 4, "v", r[1])
          end
        end
      end
    elseif kind == "w" then
      local a, b = rest:match("(%d+)%-(%d+)")
      add("World drop", Levels(a, b), 6, "w")
    elseif kind == "o" then
      local ids, extra = Ids(rest)
      more.o = (more.o or 0) + extra
      for _, o in ipairs(ids) do
        local r = Split(d.objects[o])
        -- (an "Alliance Chest" when you're Horde: not yours to open)
        local other = (mine == "A" and "^Horde ") or (mine == "H" and "^Alliance ") or nil
        if r[1] and not (other and r[1]:find(other)) then add("Found in: " .. r[1], Zone(r[2]), 7, "o", r[1]) end
      end
    elseif kind == "c" then
      add("Crafted: " .. (d.skills[tonumber(rest)] or "a profession"), nil, 5, "c")
    elseif kind == "r" then
      randomChests = true
    end
  end
  -- random-loot chests ("Solid Chest"): only when there's nothing better to say
  if #out == 0 and randomChests then add("Random chests and containers", nil, 8, "r") end
  table.sort(out, function(a, b) if a[3] ~= b[3] then return a[3] < b[3] end return a[4] < b[4] end)
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
  local shown, more, nrDrops = 0, 0, false
  for _, l in ipairs(lines) do
    local kind, name, zone = l[5], l[6], l[2]
    if kind == "d" and zone ~= "" and #nr > 0 and Says(nr, zone) then
      nrDrops = true -- NeedRoll lists this dungeon's drops (and is more up to date)
    elseif name and Says(text, name) then
      -- already in the tooltip (another addon named this boss, quest, vendor or chest)
    elseif shown < MAX_LINES then
      tip:AddDoubleLine(WHITE .. l[1] .. "|r", GREY .. l[2] .. "|r")
      shown = shown + 1
    else
      more = more + 1
    end
  end
  for k, n in pairs(extra) do
    if not (nrDrops and k == "d") then more = more + n end -- (NeedRoll counts its own drops)
  end
  if more > 0 then tip:AddLine(GREY .. format("+%d more source%s", more, more == 1 and "" or "s") .. "|r") end
end
