-- The extra lines: Item ID / Spell ID, item level, who a unit is targeting, health numbers,
-- and hiding tooltips for things in the world during combat.
local _, ns = ...
local I = {}
ns.Info = I
local Readable = ns.Readable

local GREY, GOLD = "|cff9d9d9d", "|cffffd200"

-- another addon (or the game) may already show the ID: don't add it twice
local function HasID(tip, id)
  local name = tip:GetName()
  if not name then return false end
  local want = tostring(id)
  for i = 2, tip:NumLines() do
    local fs = _G[name .. "TextLeft" .. i]
    local t = fs and fs:GetText()
    if Readable(t) and t:find("ID") and t:find(want, 1, true) then return true end
    fs = _G[name .. "TextRight" .. i]
    t = fs and fs:GetText()
    if Readable(t) and t:find(want, 1, true) and (_G[name .. "TextLeft" .. i]:GetText() or ""):find("ID") then return true end
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

local function ItemLevel(tip, link)
  if not ns.db.itemLevel then return end
  local getInfo = C_Item and C_Item.GetItemInfo or GetItemInfo
  if not getInfo then return end
  local ok, _, _, _, level, _, _, _, _, equipLoc, _, _, classID = pcall(getInfo, link)
  if not ok or not Readable(level) or type(level) ~= "number" or level <= 1 then return end
  -- gear only (weapons 2, armor 4): bags, food and the like don't need one
  if classID ~= 2 and classID ~= 4 then return end
  if not equipLoc or equipLoc == "" or equipLoc == "INVTYPE_NON_EQUIP_IGNORE" then return end
  tip:AddLine(GOLD .. "Item level " .. level .. "|r")
end

function I.OnItem(tip, data)
  local link = ItemLink(tip, data)
  local id = type(data) == "table" and Readable(data.id) and data.id
  if not id and link then id = tonumber(link:match("item:(%d+)")) end
  if link then ItemLevel(tip, link) end
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
local function UnitOf(tip)
  if not tip.GetUnit then return nil end
  local ok, _, unit = pcall(tip.GetUnit, tip)
  if ok and Readable(unit) and type(unit) == "string" then return unit end
  if UnitExists and UnitExists("mouseover") then return "mouseover" end
end

local function NameColor(unit)
  if UnitIsPlayer(unit) then
    local _, class = UnitClass(unit)
    local c = Readable(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if c then return format("|cff%02x%02x%02x", c.r * 255, c.g * 255, c.b * 255) end
  end
  if UnitReaction then
    local r = UnitReaction(unit, "player")
    if Readable(r) and r then
      if r <= 3 then return "|cffff4040" elseif r == 4 then return "|cffffff40" else return "|cff40ff40" end
    end
  end
  return "|cffffffff"
end

local function AddTarget(tip, unit)
  if not ns.db.target then return end
  local t = unit .. "target"
  if not UnitExists(t) then return end
  local isMe = UnitIsUnit(t, "player")
  if not Readable(isMe) then return end
  if isMe then tip:AddLine("Target: |cffff4040>> You <<|r"); return end
  local name = UnitName(t)
  if not Readable(name) or not name then return end
  tip:AddLine("Target: " .. NameColor(t) .. name .. "|r")
end

function I.OnUnit(tip, data)
  if tip ~= GameTooltip then return end
  -- in combat, units in the world can be hidden (hold Shift to see them)
  if ns.db.combatHide and InCombatLockdown() and not IsShiftKeyDown() then
    local owner = tip:GetOwner()
    if owner == UIParent or owner == WorldFrame or owner == nil then tip:Hide(); return end
  end
  local unit = UnitOf(tip)
  if not unit then return end
  -- a unit in the world (whatever token the game used for it): watch for the mouse leaving it
  if ns.Anchor.InWorld(tip:GetOwner()) then ns.Anchor.WatchMouseover() end
  AddTarget(tip, unit)
  ns.Look.OnUnit(tip, unit)
  I.PaintHealth()
end

-- numbers on the health bar under unit tooltips
local healthText
local function Short(n)
  if n >= 1e6 then return format("%.1fm", n / 1e6) elseif n >= 1e4 then return format("%.1fk", n / 1e3) end
  return tostring(n)
end
function I.PaintHealth()
  local bar = GameTooltipStatusBar
  if not bar then return end
  if not healthText then
    healthText = bar:CreateFontString(nil, "OVERLAY", "TextStatusBarText")
    healthText:SetPoint("CENTER", 0, 0)
  end
  local unit = ns.db.healthText and UnitOf(GameTooltip)
  local h, m = unit and UnitHealth(unit), unit and UnitHealthMax(unit)
  if not (Readable(h) and Readable(m) and m and m > 0) then healthText:SetText(""); return end
  if m == 100 then healthText:SetText(h .. "%") -- some units only report a percent
  else healthText:SetText(Short(h) .. " / " .. Short(m)) end
end

function I.Hook()
  if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType) then return end
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
  if GameTooltipStatusBar then GameTooltipStatusBar:HookScript("OnValueChanged", I.PaintHealth) end
end
