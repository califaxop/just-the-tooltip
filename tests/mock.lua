-- A mock of the game client, just enough for Just the Tooltip!'s files to load and run
-- (tests/run_tests.py). Frames answer any method: CamelCase methods do nothing, Get* / Is* return
-- nil, unless listed below. MOCK.SECRET stands for a value the game hides from addons.
MOCK = { now = 100, cursor = { 500, 300 }, uiScale = 1, events = {}, units = {}, items = {} }
MOCK.SECRET = setmetatable({}, { __tostring = function() return "<secret>" end })
issecretvalue = function(v) return v == MOCK.SECRET end

local function obj(name, parent)
  local o = { _scripts = {}, _shown = true, _alpha = 1, _scale = 1, _points = {}, _name = name, _parent = parent }
  if name then _G[name] = o end
  return setmetatable(o, { __index = function(_, k)
    local m = MOCK.methods[k]
    if m then return m end
    if type(k) ~= "string" or not k:find("^%u") then return nil end
    if k:find("^Create") then return function(s) return obj(nil, s) end end
    if k:find("^Get") or k:find("^Is") then return function() return nil end end
    return function() end
  end })
end
MOCK.obj = obj
MOCK.methods = {
  Show = function(s) s._shown = true; if s._scripts.OnShow then s._scripts.OnShow(s) end end,
  Hide = function(s) s._shown = false; if s._scripts.OnHide then s._scripts.OnHide(s) end end,
  IsShown = function(s) return s._shown end, IsVisible = function(s) return s._shown end,
  SetScript = function(s, n, f)
    s._scripts[n] = f
    if n == "OnUpdate" then MOCK.updaters = MOCK.updaters or {}; table.insert(MOCK.updaters, s) end
  end,
  HookScript = function(s, n, f)
    local old = s._scripts[n]
    s._scripts[n] = old and function(...) old(...); f(...) end or f
  end,
  RegisterEvent = function(s, e) MOCK.events[e] = MOCK.events[e] or {}; table.insert(MOCK.events[e], s) end,
  GetName = function(s) return s._name end, GetParent = function(s) return s._parent end,
  SetScale = function(s, v) s._scale = v end, GetScale = function(s) return s._scale end,
  GetEffectiveScale = function(s) return s._scale * (s == UIParent and 1 or MOCK.uiScale) end,
  SetAlpha = function(s, a) s._alpha = a end, GetAlpha = function(s) return s._alpha end,
  ClearAllPoints = function(s) s._points = {} end,
  SetPoint = function(s, p, rel, rp, x, y) s._points[p] = { rel, rp, x, y }; s._lastPoint = { p, rel, rp, x, y } end,
  SetText = function(s, t) s._text = t end, GetText = function(s) return s._text end,
  SetTextColor = function(s, r, g, b) s._color = { r, g, b } end,
  GetPoint = function(s) if s._lastPoint then return unpack(s._lastPoint) end end,
  IsMouseOver = function(s) return s._over end,
  GetFrameLevel = function() return 5 end, GetWidth = function() return 1920 end, GetHeight = function() return 1080 end,
}
CreateFrame = function(kind, name, parent) return obj(name, parent) end
UIParent = obj("UIParent"); WorldFrame = obj("WorldFrame")
UIParent.GetEffectiveScale = function() return MOCK.uiScale end

-- tooltips: lines kept as fontstrings <Name>TextLeftN / TextRightN, like the game's
local function Tooltip(name)
  local t = obj(name, UIParent)
  t._n = 0
  t.NineSlice = obj(nil, t)
  function t.NumLines(s) return s._n end
  function t.AddLine(s, text) s._n = s._n + 1; local l = obj(name .. "TextLeft" .. s._n); l._text = text end
  function t.AddDoubleLine(s, a, b)
    s._n = s._n + 1
    obj(name .. "TextLeft" .. s._n)._text = a; obj(name .. "TextRight" .. s._n)._text = b
  end
  function t.ClearLines(s)
    for i = 1, s._n do _G[name .. "TextLeft" .. i] = nil; _G[name .. "TextRight" .. i] = nil end
    s._n = 0
  end
  function t.SetOwner(s, o) s._owner = o end
  function t.GetOwner(s) return s._owner end
  return t
end
MOCK.Tooltip = Tooltip
GameTooltip = Tooltip("GameTooltip"); ItemRefTooltip = Tooltip("ItemRefTooltip")
GameTooltipStatusBar = obj("GameTooltipStatusBar")

MOCK.timers = {}
C_Timer = { After = function(_, fn) table.insert(MOCK.timers, fn) end }
function MOCK.RunTimers() local t = MOCK.timers; MOCK.timers = {}; for _, fn in ipairs(t) do fn() end end
GetCursorPosition = function() return MOCK.cursor[1], MOCK.cursor[2] end
GetTime = function() return MOCK.now end
InCombatLockdown = function() return false end
IsShiftKeyDown = function() return false end
IsAltKeyDown = function() return MOCK.alt or false end
IsControlKeyDown = function() return MOCK.ctrl or false end

-- units: MOCK.units[token] = { exists, isPlayer, class, reaction, name, isMe, err }
local function U(token, key)
  local u = MOCK.units[token]
  if u and u.err then error("bad unit " .. token) end
  return u and u[key]
end
UnitExists = function(t) return U(t, "exists") or false end
UnitIsPlayer = function(t) return U(t, "isPlayer") or false end
UnitClass = function(t) local c = U(t, "class"); return c, c end
UnitReaction = function(t) return U(t, "reaction") end
UnitName = function(t) return U(t, "name") end
UnitIsUnit = function(t) return U(t, "isMe") or false end
RAID_CLASS_COLORS = { WARRIOR = { r = 0.78, g = 0.61, b = 0.43 }, MAGE = { r = 0.25, g = 0.78, b = 0.92 } }

-- items: MOCK.items[id] = { level, equipLoc, classID, quality }
local function Item(link)
  local id = type(link) == "number" and link or tonumber(tostring(link):match("item:(%d+)"))
  return MOCK.items[id]
end
C_Item = {
  GetItemInfo = function(link)
    local i = Item(link)
    if not i then return nil end
    return "Item", "link", i.quality or 2, i.level, 1, "Type", "Sub", 1, i.equipLoc, 0, 10, i.classID, 0
  end,
  GetItemQualityByID = function(link) local i = Item(link); return i and i.quality end,
  -- what the item is, without the cache (MOCK.instant: items the client knows the kind of only)
  GetItemInfoInstant = function(link)
    local id = type(link) == "number" and link or tonumber(tostring(link):match("item:(%d+)"))
    local i = MOCK.items[id] or (MOCK.instant or {})[id]
    if not i then return nil end
    return id, "Type", "Sub", i.equipLoc, 0, i.classID, 0
  end,
}

-- the rest
format = string.format; tinsert = table.insert
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
hooksecurefunc = function(t, name, fn)
  if type(t) == "string" then t, name, fn = _G, t, name end
  local old = t[name] or function() end
  t[name] = function(...) local r = { old(...) }; fn(...); return unpack(r) end
end
GameTooltip_SetDefaultAnchor = function(tip, parent) tip:SetOwner(parent) end
SlashCmdList = {}; UISpecialFrames = {}
PRINTS = {}
print = function(...) local t = {} for i = 1, select("#", ...) do t[i] = tostring(select(i, ...)) end PRINTS[#PRINTS + 1] = table.concat(t, " ") end
TooltipDataProcessor = { calls = {}, AddTooltipPostCall = function(kind, fn)
  TooltipDataProcessor.calls[kind] = TooltipDataProcessor.calls[kind] or {}
  table.insert(TooltipDataProcessor.calls[kind], fn)
end }
Enum = { TooltipDataType = { Item = 0, Spell = 1, Unit = 2, Corpse = 3, Object = 4, UnitAura = 7 } }
function MOCK.Post(kind, tip, data) for _, fn in ipairs(TooltipDataProcessor.calls[kind] or {}) do fn(tip, data) end end
function MOCK.Update(dt) for _, f in ipairs(MOCK.updaters or {}) do if f._shown and f._scripts.OnUpdate then f._scripts.OnUpdate(f, dt or 0.05) end end end
function MOCK.Fire(event, ...)
  for _, f in ipairs(MOCK.events[event] or {}) do if f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end end
end
