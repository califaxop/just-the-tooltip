-- How the tooltip looks: JTT style (a dark panel with a bronze border, FlareUI's when
-- installed) or Blizzard's own, a border in the item's quality or player's class color, and size.
local _, ns = ...
local L = {}
ns.Look = L
local Safe = ns.Safe

local skins = {}
L.skins = skins -- (for checks)
-- (1.7.0) Each tooltip's own look before JTT first touched it: its border's (NineSlice) alpha and
-- colour. Blizzard style puts these back rather than assuming them (another addon may keep the
-- border faded or tinted).
local orig = {}
L.orig = orig
local function Remember(tip)
  if orig[tip] then return orig[tip] end
  local o = {}
  local n = tip.NineSlice
  if n then
    o.alpha = ns.Safe(n.GetAlpha, n)
    local r, g, b = ns.Safe(n.GetBorderColor, n)
    if type(r) == "number" then o.border = { r, g, b } end
  end
  orig[tip] = o
  return o
end
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
  local o = Remember(tip)
  local c = colors[tip] -- set only when that colouring is turned on
  local r, g, b = c and c[1], c and c[2], c and c[3]
  local ui = ns.UI
  if ns.db.look == "addon" then
    local s = Skin(tip)
    -- the panel's artwork is set once per settings change, not on every show
    if s.stamp ~= L.stamp then
      local S = ui.EUI and ui.EUI()
      if S then
        -- EllesmereUI style: its flat panel colour and a thin border (a window shell would add a title strip)
        s:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1,
          insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        local okP, pr, pg, pb = pcall(S.GetPanelColor)
        if not (okP and pr) then pr, pg, pb = 0.07, 0.07, 0.08 end
        s:SetBackdropColor(pr, pg, pb, 0.94)
        s.accent = { 0.28, 0.28, 0.28 }
      else
        ui.SkinWindow(s, 0.92); s.accent = ui.BorderColor()
      end
      s.stamp = L.stamp
    end
    if r then s:SetBackdropBorderColor(r, g, b, 1) else s:SetBackdropBorderColor(ui.RGB(s.accent)) end
    s:Show()
    if tip.NineSlice then tip.NineSlice:SetAlpha(0) end
  else
    if skins[tip] then skins[tip]:Hide() end
    local n = tip.NineSlice
    if n then
      n:SetAlpha(type(o.alpha) == "number" and o.alpha or 1)
      if r and n.SetBorderColor then n:SetBorderColor(r, g, b, 1)
      elseif n.SetBorderColor then
        local d = o.border or (TOOLTIP_DEFAULT_COLOR and { TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b })
        if d then n:SetBorderColor(d[1], d[2], d[3], 1) end
      end
    end
  end
  if tip:GetScale() ~= ns.db.scale then tip:SetScale(ns.db.scale) end
end
L.Paint = Paint

-- the border color for what the tooltip shows (nil = the style's own)
local function QualityColor(q)
  if type(q) ~= "number" or q < 2 then return nil end -- grey / white items keep the plain border
  local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
  if c then return c.r, c.g, c.b end
end

-- (unit facts from Facts.lua, 1.8.0: read once; unreadable ones give no colour, never an error)
local function ClassColor(u)
  if not u or u.isPlayer ~= true or not u.class then return nil end
  local class = u.class
  local c = Safe(C_ClassColor and C_ClassColor.GetClassColor, class) or (RAID_CLASS_COLORS and RAID_CLASS_COLORS[class])
  if type(c) == "table" and type(c.r) == "number" then return c.r, c.g, c.b end
end

L.stamp = 0
-- EllesmereUI's looks changed: repaint the panels on their next show
function ns.OnLooksChanged() L.stamp = L.stamp + 1 end

local function SetColor(tip, r, g, b) colors[tip] = r and { r, g, b } or nil end

function L.OnItem(tip, it)
  if ns.db.colorBorder then SetColor(tip, QualityColor(it.quality)) else SetColor(tip) end
  Paint(tip)
end

-- an NPC's border: how it feels about you (the game's own reaction colours), grey when someone
-- else has tagged it
local REACTION = {
  hostile = { 0.95, 0.20, 0.20 }, neutral = { 1.00, 0.85, 0.10 }, friendly = { 0.20, 0.85, 0.25 }, tapped = { 0.55, 0.55, 0.55 },
}
local function ReactionColor(u)
  if not (ns.db.colorNPC and u) or u.isPlayer ~= false then return nil end -- (players, or can't tell)
  if u.tapped == true then return unpack(REACTION.tapped) end
  local r = u.reaction
  if type(r) ~= "number" then return nil end
  local c = r <= 3 and REACTION.hostile or r == 4 and REACTION.neutral or REACTION.friendly
  return c[1], c[2], c[3]
end

function L.OnUnit(tip, u)
  local r, g, b
  if ns.db.colorBorder then r, g, b = ClassColor(u) end
  local isPlayer = r ~= nil
  if not r then r, g, b = ReactionColor(u) end
  SetColor(tip, r, g, b)
  local name = tip.GetName and tip:GetName()
  if isPlayer and ns.db.colorBorder and type(name) == "string" then -- the player's name in their class color too
    local line = _G[name .. "TextLeft1"]
    if line then line:SetTextColor(r, g, b) end
  end
  Paint(tip)
end

-- Every tooltip we touch: styled whenever it shows; its colour forgotten when it's cleared. The
-- game's main ones at login; any other of ours (a shopping tooltip made later) the first time JTT
-- writes to it (1.7.0: before, those kept the game's look). Each tooltip once (L.adopted).
local adopted = {}
L.adopted = adopted
function L.Adopt(tip)
  if not tip or adopted[tip] or not ns.IsOurs(tip) then return end
  adopted[tip] = true
  tip:HookScript("OnShow", Paint)
  pcall(tip.HookScript, tip, "OnTooltipCleared", function(t) colors[t] = nil end)
  if tip:IsShown() then Paint(tip) end
end
function L.Hook()
  if not ns.Once("look") then return end
  for _, tip in ipairs(ns.Tooltips()) do L.Adopt(tip) end
end

-- re-paint every tooltip now (after a settings change)
function L.Refresh()
  L.stamp = L.stamp + 1
  for tip in pairs(adopted) do Paint(tip) end
end
