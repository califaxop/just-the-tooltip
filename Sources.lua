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

-- an item's source lines: { { left, right }, ... } and how many more there are (cached per item)
local cache = {}
local function Lines(id)
  if cache[id] then return cache[id][1], cache[id][2] end
  local d = Data()
  local entry = d and d.items and d.items[id]
  if not entry then cache[id] = { {}, 0 }; return cache[id][1], 0 end
  local mine = UnitFactionGroup and UnitFactionGroup("player")
  mine = (mine == "Alliance" and "A") or (mine == "Horde" and "H") or nil
  local out, more, seen = {}, 0, {}
  local function add(left, right) -- (two chests of the same name: one line)
    if seen[left] then return end
    seen[left] = true
    out[#out + 1] = { left, right or "" }
  end
  for part in (entry .. ";"):gmatch("([^;]+);") do
    local kind, rest = part:sub(1, 1), part:sub(2)
    if kind == "q" then
      for _, q in ipairs((Ids(rest))) do
        local r = Split(d.quests[q])
        if r[1] and (r[3] == "" or not mine or r[3] == mine) then add("Quest: " .. r[1], Levels(r[2])) end
      end
    elseif kind == "d" or kind == "v" then
      local ids, extra = Ids(rest)
      more = more + extra
      for _, n in ipairs(ids) do
        local r = Split(d.npcs[n])
        if r[1] then
          if kind == "d" then
            local rank = RANK[tonumber(r[4]) or 0]
            add("Drop: " .. r[1] .. (rank and (GREY .. " (" .. rank .. ")|r") or ""), Zone(r[5]))
          elseif not mine or (r[6] or ""):find(mine) then
            add("Vendor: " .. r[1], Zone(r[5]))
          end
        end
      end
    elseif kind == "w" then
      local a, b = rest:match("(%d+)%-(%d+)")
      add("World drop", Levels(a, b))
    elseif kind == "o" then
      local ids, extra = Ids(rest)
      more = more + extra
      for _, o in ipairs(ids) do
        local r = Split(d.objects[o])
        if r[1] then add("Found in: " .. r[1], Zone(r[2])) end
      end
    elseif kind == "c" then
      add("Crafted: " .. (d.skills[tonumber(rest)] or "a profession"))
    end
  end
  if #out > MAX_LINES then
    more = more + #out - MAX_LINES
    for i = #out, MAX_LINES + 1, -1 do out[i] = nil end
  end
  cache[id] = { out, more }
  return out, more
end

function S.Add(tip, id)
  if not (ns.db.sources and Readable(id) and type(id) == "number") then return end
  local lines, more = Lines(id)
  for _, l in ipairs(lines) do tip:AddDoubleLine(WHITE .. l[1] .. "|r", GREY .. l[2] .. "|r") end
  if more > 0 then tip:AddLine(GREY .. format("+%d more source%s", more, more == 1 and "" or "s") .. "|r") end
end
