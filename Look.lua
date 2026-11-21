-- How the tooltip looks: JTT style (a dark panel with a bronze border, FlareUI's when
-- installed) or Blizzard's own, a border in the item's quality or player's class color, and size.
local _, ns = ...
local L = {}
ns.Look = L
local Readable = ns.Readable

local skins = {}
local colors = {} -- [tooltip] = { r, g, b } for what it shows now (quality / class), or nil

-- our panel sits just under the tooltip's own text (a lower frame level), and the game's border
-- (NineSlice) is faded out while it shows
local function Skin(tip)
  local s = skins[tip]
  if not s then
    s = CreateFrame("Frame", nil, tip, "BackdropTemplate")
    s:SetAllPoints()
    skins[tip] = s
  end
  s:SetFrameLevel(math.max(0, tip:GetFrameLevel() - 1))
  return s
end

local function Paint(tip)
  if not ns.db then return end
  local c = ns.db.colorBorder and colors[tip]
  local r, g, b = c and c[1], c and c[2], c and c[3]
  local ui = ns.UI
  if ns.db.look == "addon" then
    local s = Skin(tip)
    -- the panel's artwork is set once per settings change, not on every show
    if s.stamp ~= L.stamp then ui.SkinWindow(s, 0.92); s.stamp = L.stamp; s.accent = ui.Theme().accent end
    if r then s:SetBackdropBorderColor(r, g, b, 1) else s:SetBackdropBorderColor(ui.RGB(s.accent)) end
    s:Show()
    if tip.NineSlice then tip.NineSlice:SetAlpha(0) end
  else
    if skins[tip] then skins[tip]:Hide() end
    if tip.NineSlice then
      tip.NineSlice:SetAlpha(1)
      if r and tip.NineSlice.SetBorderColor then tip.NineSlice:SetBorderColor(r, g, b, 1)
      elseif tip.NineSlice.SetBorderColor and TOOLTIP_DEFAULT_COLOR then
        tip.NineSlice:SetBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b, 1)
      end
    end
  end
  if tip:GetScale() ~= ns.db.scale then tip:SetScale(ns.db.scale) end
end
L.Paint = Paint

-- the border color for what the tooltip shows (nil = the style's own)
local function QualityColor(link)
  local q
  if C_Item and C_Item.GetItemQualityByID then
    local ok, v = pcall(C_Item.GetItemQualityByID, link)
    if ok then q = v end
  end
  if not Readable(q) or q < 2 then return nil end -- grey / white items keep the plain border
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return c.r, c.g, c.b end
end

local function ClassColor(unit)
  if not (unit and UnitIsPlayer and UnitIsPlayer(unit)) then return nil end
  local _, class = UnitClass(unit)
  local c = Readable(class) and (C_ClassColor and C_ClassColor.GetClassColor and C_ClassColor.GetClassColor(class)
    or RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
  if c then return c.r, c.g, c.b end
end

L.stamp = 0

local function SetColor(tip, r, g, b) colors[tip] = r and { r, g, b } or nil end

function L.OnItem(tip, link)
  SetColor(tip, QualityColor(link))
  Paint(tip)
end

function L.OnUnit(tip, unit)
  local r, g, b = ClassColor(unit)
  SetColor(tip, r, g, b)
  if r and ns.db.colorBorder then -- the player's name in their class color too
    local line = _G[tip:GetName() .. "TextLeft1"]
    if line then line:SetTextColor(r, g, b) end
  end
  Paint(tip)
end

-- every tooltip we touch: styled whenever it shows; its color forgotten when it's cleared
function L.Hook()
  for _, tip in ipairs(ns.Tooltips()) do
    tip:HookScript("OnShow", Paint)
    pcall(tip.HookScript, tip, "OnTooltipCleared", function(t) colors[t] = nil end)
  end
end

-- re-paint every tooltip now (after a settings change)
function L.Refresh()
  L.stamp = L.stamp + 1
  for _, tip in ipairs(ns.Tooltips()) do Paint(tip) end
end
