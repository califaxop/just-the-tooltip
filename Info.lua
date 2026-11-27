-- The extra lines: Item ID / Spell ID, item level, who a unit is targeting; the health bar
-- on or off; and hiding tooltips for things in the world during combat.
local _, ns = ...
local I = {}
ns.Info = I
local Readable = ns.Readable

local GREY, GOLD = "|cff9d9d9d", "|cffffd200"

-- a tooltip line's text, or nil (no such line, an error, a secret, or empty)
local function LineText(name, side, i)
  local fs = _G[name .. "Text" .. side .. i]
  if not (fs and fs.GetText) then return nil end
  local ok, t = pcall(fs.GetText, fs)
  if ok and Readable(t) and type(t) == "string" and t ~= "" then return t end
end

-- Is this line an ID line naming `id`? (1.6.0) The label is matched loosely, since addons write it
-- their own way ("Item ID: 123", "ItemID 123", "ID: 123", "Spell ID" with the number on the
-- right), but the number must be the whole of one: Item ID 1234 isn't ID 123. Colours and icons
-- are taken out first (their codes have digits in them).
local function Plain(t) return (t:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")) end
function I.NamesID(left, right, id)
  if type(left) ~= "string" or type(id) ~= "number" then return false end
  local label = Plain(left):lower()
  if not (label:find("%f[%a]id%f[%A]") or label:find("itemid", 1, true) or label:find("spellid", 1, true)) then return false end
  local all = label .. " " .. (type(right) == "string" and Plain(right) or "")
  for n in all:gmatch("%d+") do
    if tonumber(n) == id then return true end
  end
  return false
end

-- another addon (or the game) may already show the ID: don't add it twice
local function HasID(tip, id)
  local name = tip.GetName and tip:GetName()
  if type(name) ~= "string" then return false end
  local ok, n = pcall(tip.NumLines, tip)
  for i = 2, (ok and type(n) == "number") and n or 0 do
    if I.NamesID(LineText(name, "Left", i), LineText(name, "Right", i), id) then return true end
  end
  return false
end

local function AddID(tip, label, id, detail)
  if not ((ns.db.ids or detail) and Readable(id) and type(id) == "number" and id > 0) then return end
  if HasID(tip, id) then return end
  tip:AddLine(GREY .. label .. ": " .. id .. "|r")
end

-- Any line already saying this? (1.8.0) Each of JTT's lines is checked against the tooltip's text
-- before it's added: JTT's own (a second post-call for the same tooltip) or another addon's.
-- `test(plainLowerText)` -> true when found.
local function Says(tip, test)
  local name = tip.GetName and tip:GetName()
  if type(name) ~= "string" then return false end
  local ok, n = pcall(tip.NumLines, tip)
  for i = 1, (ok and type(n) == "number") and n or 0 do
    local l, r = LineText(name, "Left", i), LineText(name, "Right", i)
    if l and test(Plain(l):lower(), r and Plain(r):lower() or "") then return true end
  end
  return false
end
I.Says = Says
-- an item level line naming this level ("Item level 45", "Item Level: 45", "iLvl 45")
function I.NamesLevel(left, right, level)
  local text = left .. " " .. right
  if not (text:find("item level", 1, true) or text:find("ilvl", 1, true)) then return false end
  for n in text:gmatch("%d+") do if tonumber(n) == level then return true end end
  return false
end
-- a target line ("Target: Name", "Targeting: Name", "Target: >> You <<")
function I.NamesTarget(left) return left:find("^%s*target") ~= nil end

-- The item level to show, or nil: gear only, by what the item is (weapons, class 2; armor, class
-- 4) and where it's worn, never by its level alone. (GetItemInfo's returns, in order: name, link,
-- quality, item level, required level, type, subtype, stack size, equip location, icon, sell
-- price, class ID, subclass ID...: the positions Equip This! reads too, verified in WoW: Forever.)
local NOT_WORN = { [""] = true, INVTYPE_NON_EQUIP = true, INVTYPE_NON_EQUIP_IGNORE = true, INVTYPE_BAG = true, INVTYPE_QUIVER = true }
function I.GearLevel(level, equipLoc, classID)
  if type(level) ~= "number" or level <= 1 then return nil end
  if classID ~= 2 and classID ~= 4 then return nil end
  if type(equipLoc) ~= "string" or NOT_WORN[equipLoc] then return nil end
  return level
end

local function ItemLevel(tip, it, detail)
  if not (ns.db.itemLevel or detail) then return end
  -- (not loaded yet: nothing now; the game shows the tooltip again once the item's data arrives)
  local level = I.GearLevel(it.level, it.equipLoc, it.classID)
  if not level or Says(tip, function(l, r) return I.NamesLevel(l, r, level) end) then return end
  tip:AddLine(GOLD .. "Item level " .. level .. "|r")
end

-- money as text: "1g 20s 5c", in the game's coin colours
local function Money(c)
  c = math.floor(c or 0)
  local g, si, co = math.floor(c / 10000), math.floor(c / 100) % 100, c % 100
  local t = {}
  if g > 0 then t[#t + 1] = g .. "|cffffd700g|r" end
  if si > 0 then t[#t + 1] = si .. "|cffc7c7cfs|r" end
  if co > 0 or #t == 0 then t[#t + 1] = co .. "|cffeda55fc|r" end
  return table.concat(t, " ")
end
I.Money = Money

-- (1.10.0) how many you have (bags, and the bank once you've opened it) and what they sell for
-- together; with the detail key, "You have none" too
function I.ValueText(count, sellPrice, detail)
  if type(count) ~= "number" then return nil end
  if count <= 0 then return detail and "You have none" or nil end
  local t = "You have " .. count
  if type(sellPrice) == "number" and sellPrice > 0 then t = t .. " (sell for " .. Money(sellPrice * count) .. ")" end
  return t
end
local function ItemValue(tip, it, detail)
  if not (ns.db.itemValue or detail) then return end
  local t = I.ValueText(ns.Facts.Count(it.id), it.sellPrice, detail)
  if not t or Says(tip, function(l) return l:find("^%s*you have") ~= nil end) then return end
  tip:AddLine(GREY .. t .. "|r")
end

-- (1.8.0) The item's facts gathered once (Facts.lua) and handed to each category; each category
-- runs on its own (Facts.Run), so one failing leaves the rest.
-- (1.9.0) In the order chosen (ns.ItemOrder), on the tooltips chosen (ns.Shows: the game's,
-- chat links, comparisons); with the detail key held, everything, on every tooltip.
local Run = ns.Facts.Run
local ITEM_LINE = {
  itemLevel = function(tip, it, detail) ItemLevel(tip, it, detail) end,
  sources = function(tip, it, detail) if ns.Sources then ns.Sources.Add(tip, it.id, detail) end end,
  itemId = function(tip, it, detail) AddID(tip, "Item ID", it.id, detail) end,
  itemValue = ItemValue,
}
function I.OnItem(tip, data)
  local it = ns.Facts.Item(tip, data)
  local detail = ns.Detail()
  for _, key in ipairs(ns.ItemOrder()) do
    if detail or ns.Shows(key, tip) then Run(key, ITEM_LINE[key], tip, it, detail) end
  end
  Run("look", ns.Look.OnItem, tip, it)
end

-- (1.10.0) with the detail key, whether you know the spell (not on buffs and debuffs)
local function Known(tip, id)
  local k = ns.Facts.Known(id)
  if k == nil or Says(tip, function(l) return l:find("you know this spell", 1, true) or l:find("not learned", 1, true) end) then return end
  tip:AddLine(k and "|cff40ff40You know this spell|r" or (GREY .. "Not learned|r"))
end
function I.OnSpell(tip, data, aura)
  local detail = ns.Detail()
  local id = ns.Facts.Spell(data).id
  if detail or ns.Shows("spellId", tip) then Run("spellId", AddID, tip, "Spell ID", id, detail) end
  if detail and not aura then Run("spellKnown", Known, tip, id) end
end
function I.OnAura(tip, data) I.OnSpell(tip, data, true) end

---------------------------------------------------------------------------
-- Units
---------------------------------------------------------------------------
-- (unit facts from Facts.lua: each detail read once, safely; one that can't be read leaves the rest)
local UnitOf = ns.Facts.UnitOf

local function NameColor(u)
  if u.isPlayer == true and u.class then
    local c = RAID_CLASS_COLORS and RAID_CLASS_COLORS[u.class]
    if c then return format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
  end
  local r = u.reaction
  if r then
    if r <= 3 then return "|cffff4040" elseif r == 4 then return "|cffffff40" else return "|cff40ff40" end
  end
  return "|cffffffff"
end

local function AddTarget(tip, unit)
  if not ns.db.target then return end
  local t = ns.Facts.Target(unit)
  if not t or t.isMe == nil then return end -- (no target, or can't tell who: no line rather than a wrong one)
  if Says(tip, I.NamesTarget) then return end -- (already one: JTT's own or another addon's)
  if t.isMe then tip:AddLine("Target: |cffff4040>> You <<|r"); return end
  if not t.name then return end
  tip:AddLine("Target: " .. NameColor(t) .. t.name .. "|r")
end

function I.OnUnit(tip, data)
  if tip ~= GameTooltip then return end
  -- in combat, units in the world can be hidden (hold Shift to see them)
  if ns.db.combatHide and InCombatLockdown() and not IsShiftKeyDown() then
    local owner = tip:GetOwner()
    if owner == UIParent or owner == WorldFrame or owner == nil then
      ns.Anchor.Ended("JTT: in combat, things in the world are hidden (Shift shows them)"); tip:Hide(); return
    end
  end
  -- a unit in the world (whatever token the game used for it): watch for the mouse leaving it. First,
  -- before anything that needs to know who it is: the game may keep that secret, and the tooltip
  -- must still go when you move off.
  if ns.Anchor.InWorld(tip:GetOwner()) then ns.Anchor.WatchMouseover() else ns.Anchor.MarkUnit() end
  local unit = UnitOf(tip)
  if not unit then return end
  Run("target", AddTarget, tip, unit)
  -- (1.10.0) a creature's NPC ID (turned on, or with the detail key)
  if ns.db.npcIds or ns.Detail() then Run("npcId", AddID, tip, "NPC ID", ns.Facts.NpcID(unit), true) end
  Run("look", ns.Look.OnUnit, tip, ns.Facts.Unit(unit))
end

-- a corpse or an object in the world: watch for the mouse leaving it too
function I.OnWorldThing(tip)
  if tip ~= GameTooltip then return end
  if ns.Anchor.InWorld(tip:GetOwner()) then ns.Anchor.WatchWorldThing() end
end

-- the health bar under unit tooltips can be turned off
function I.ApplyHealthBar()
  local bar = GameTooltipStatusBar
  if not bar then return end
  if not ns.db.healthBar then bar:Hide() elseif GameTooltip:IsShown() and UnitOf(GameTooltip) then bar:Show() end
end

function I.Hook()
  if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType) then return end
  if not ns.Once("info") then return end
  local T = Enum.TooltipDataType
  local function on(kind, fn)
    if kind == nil then return end
    TooltipDataProcessor.AddTooltipPostCall(kind, function(tip, data)
      if ns.db and ns.IsOurs(tip) then
        ns.Look.Adopt(tip) -- (one made after login: styled from now on)
        fn(tip, data)
      end
    end)
  end
  on(T.Item, I.OnItem)
  on(T.Spell, I.OnSpell)
  on(T.UnitAura, I.OnAura)    -- buffs and debuffs: their spell ID
  on(T.Unit, I.OnUnit)
  on(T.Corpse, I.OnWorldThing)
  on(T.Object, I.OnWorldThing)
  -- (1.9.0) the detail key pressed or let go over a tooltip: shown again with or without the details
  local mod = CreateFrame("Frame")
  pcall(mod.RegisterEvent, mod, "MODIFIER_STATE_CHANGED")
  mod:SetScript("OnEvent", function(_, _, key)
    local want = ns.db and ns.db.detailKey
    if not (want == "ALT" or want == "CTRL") or type(key) ~= "string" or not key:find(want, 1, true) then return end
    for _, tip in ipairs(ns.Tooltips()) do
      if tip:IsShown() and tip.RefreshData then ns.Safe(tip.RefreshData, tip) end
    end
  end)
  if GameTooltipStatusBar then
    -- the game shows the bar for every unit: keep it hidden when it's turned off
    GameTooltipStatusBar:HookScript("OnShow", function(bar) if not ns.db.healthBar then bar:Hide() end end)
  end
end
