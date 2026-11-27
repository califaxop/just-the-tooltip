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

local function AddID(tip, label, id)
  if not (ns.db.ids and Readable(id) and type(id) == "number" and id > 0) then return end
  if HasID(tip, id) then return end
  tip:AddLine(GREY .. label .. ": " .. id .. "|r")
end

-- the item a tooltip shows, as a link
local function ItemLink(tip, data)
  if tip.GetItem then
    local ok, _, link = pcall(tip.GetItem, tip)
    if ok and Readable(link) and type(link) == "string" then return link end
  end
  if type(data) == "table" then
    if Readable(data.hyperlink) and type(data.hyperlink) == "string" then return data.hyperlink end
    if Readable(data.id) and type(data.id) == "number" then return "item:" .. data.id end
  end
end

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

local function ItemLevel(tip, link)
  if not ns.db.itemLevel then return end
  -- (not loaded yet: nothing now; the game shows the tooltip again once the item's data arrives)
  local _, _, _, level, _, _, _, _, equipLoc, _, _, classID = ns.Safe(C_Item and C_Item.GetItemInfo or GetItemInfo, link)
  level = I.GearLevel(level, equipLoc, classID)
  if level then tip:AddLine(GOLD .. "Item level " .. level .. "|r") end
end

function I.OnItem(tip, data)
  local link = ItemLink(tip, data)
  local id = type(data) == "table" and Readable(data.id) and data.id
  if not id and link then id = tonumber(link:match("item:(%d+)")) end
  if link then ItemLevel(tip, link) end
  if ns.Sources then ns.Sources.Add(tip, id) end
  AddID(tip, "Item ID", id)
  ns.Look.OnItem(tip, link)
end

function I.OnSpell(tip, data)
  local id = type(data) == "table" and data.id
  AddID(tip, "Spell ID", id)
end

---------------------------------------------------------------------------
-- Units
---------------------------------------------------------------------------
-- (unit details through ns.Safe, 1.6.0: one that can't be read leaves the rest of the tooltip be)
local Safe = ns.Safe
local function UnitOf(tip)
  if not tip.GetUnit then return nil end
  local _, unit = Safe(tip.GetUnit, tip)
  if type(unit) == "string" then return unit end
  -- (the game can keep who's under the mouse secret: then there's no unit to name)
  if Safe(UnitExists, "mouseover") == true then return "mouseover" end
end

local function NameColor(unit)
  if Safe(UnitIsPlayer, unit) == true then
    local _, class = Safe(UnitClass, unit)
    local c = type(class) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
  end
  local r = Safe(UnitReaction, unit, "player")
  if type(r) == "number" then
    if r <= 3 then return "|cffff4040" elseif r == 4 then return "|cffffff40" else return "|cff40ff40" end
  end
  return "|cffffffff"
end

local function AddTarget(tip, unit)
  if not ns.db.target then return end
  local t = unit .. "target"
  if Safe(UnitExists, t) ~= true then return end
  local isMe = Safe(UnitIsUnit, t, "player")
  if isMe == nil then return end -- (can't tell who it is: no line rather than a wrong one)
  if isMe then tip:AddLine("Target: |cffff4040>> You <<|r"); return end
  local name = Safe(UnitName, t)
  if type(name) ~= "string" or name == "" then return end
  tip:AddLine("Target: " .. NameColor(t) .. name .. "|r")
end

function I.OnUnit(tip, data)
  if tip ~= GameTooltip then return end
  -- in combat, units in the world can be hidden (hold Shift to see them)
  if ns.db.combatHide and InCombatLockdown() and not IsShiftKeyDown() then
    local owner = tip:GetOwner()
    if owner == UIParent or owner == WorldFrame or owner == nil then tip:Hide(); return end
  end
  -- a unit in the world (whatever token the game used for it): watch for the mouse leaving it. First,
  -- before anything that needs to know who it is: the game may keep that secret, and the tooltip
  -- must still go when you move off.
  if ns.Anchor.InWorld(tip:GetOwner()) then ns.Anchor.WatchMouseover() else ns.Anchor.MarkUnit() end
  local unit = UnitOf(tip)
  if not unit then return end
  AddTarget(tip, unit)
  ns.Look.OnUnit(tip, unit)
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
      if ns.db and ns.IsOurs(tip) then fn(tip, data) end
    end)
  end
  on(T.Item, I.OnItem)
  on(T.Spell, I.OnSpell)
  on(T.UnitAura, I.OnSpell)   -- buffs and debuffs: their spell ID
  on(T.Unit, I.OnUnit)
  on(T.Corpse, I.OnWorldThing)
  on(T.Object, I.OnWorldThing)
  if GameTooltipStatusBar then
    -- the game shows the bar for every unit: keep it hidden when it's turned off
    GameTooltipStatusBar:HookScript("OnShow", function(bar) if not ns.db.healthBar then bar:Hide() end end)
  end
end
