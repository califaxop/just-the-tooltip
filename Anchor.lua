-- Where the tooltip goes. Only tooltips the game puts at its default spot (bottom right) are
-- moved; ones that sit beside a bag slot or a button stay where the game puts them.
local _, ns = ...
local A = {}
ns.Anchor = A

-- cursor corner -> the tooltip's point that touches the cursor, and which way the offsets go
local CORNERS = {
  BOTTOMRIGHT = { "TOPLEFT", 1, -1 },   -- below and right of the cursor
  BOTTOMLEFT  = { "TOPRIGHT", -1, -1 },
  TOPRIGHT    = { "BOTTOMLEFT", 1, 1 },
  TOPLEFT     = { "BOTTOMRIGHT", -1, 1 },
}
A.CORNERS = CORNERS

local following = false
local driver = CreateFrame("Frame")
driver:Hide()

local function FollowCursor()
  local tip = GameTooltip
  local c = CORNERS[ns.db.corner] or CORNERS.BOTTOMRIGHT
  local x, y = GetCursorPosition()
  local s = tip:GetEffectiveScale()
  tip:ClearAllPoints()
  tip:SetPoint(c[1], UIParent, "BOTTOMLEFT", x / s + c[2] * ns.db.offX, y / s + c[3] * ns.db.offY)
end
driver:SetScript("OnUpdate", function()
  if following and GameTooltip:IsShown() then FollowCursor() else following = false; driver:Hide() end
end)

local function Stop() following = false; driver:Hide() end

-- your own spot: an invisible frame the tooltip hangs from, dragged into place from the settings
local spot = CreateFrame("Frame", "JustTheTooltipSpot", UIParent, "BackdropTemplate")
spot:SetSize(180, 70)
spot:SetFrameStrata("TOOLTIP")
spot:SetClampedToScreen(true)
spot:SetMovable(true); spot:EnableMouse(false)
spot:Hide()
A.spot = spot

function A.PlaceSpot()
  local s = ns.db.spot
  spot:ClearAllPoints()
  spot:SetPoint(s.point, UIParent, s.point, s.x, s.y)
end

-- after a drag: the screen corner nearest the box becomes its anchor, so the tooltip grows away
-- from the screen edge (put it top left and it grows down and right)
local function SaveSpot()
  local cx, cy = spot:GetCenter()
  local w, h = UIParent:GetWidth(), UIParent:GetHeight()
  local v = cy > h / 2 and "TOP" or "BOTTOM"
  local hz = cx > w / 2 and "RIGHT" or "LEFT"
  local point = v .. hz
  local x = hz == "LEFT" and spot:GetLeft() or (spot:GetRight() - w)
  local y = v == "BOTTOM" and spot:GetBottom() or (spot:GetTop() - h)
  ns.db.spot = { point = point, x = math.floor(x + 0.5), y = math.floor(y + 0.5) }
  A.PlaceSpot()
end

-- show the box to drag it (from the settings); right-click or the button again to finish
local built = false
function A.Unlock(on)
  if on then
    if not built then
      built = true
      spot:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
      spot:SetBackdropColor(0.1, 0.5, 1, 0.35); spot:SetBackdropBorderColor(0.4, 0.75, 1, 1)
      spot.label = spot:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      spot.label:SetPoint("CENTER"); spot.label:SetWidth(170)
      spot.label:SetText("Tooltip spot\n|cffaaaaaaDrag me. Right-click when done.|r")
      spot:RegisterForDrag("LeftButton")
      spot:SetScript("OnDragStart", spot.StartMoving)
      spot:SetScript("OnDragStop", function() spot:StopMovingOrSizing(); SaveSpot() end)
      spot:SetScript("OnMouseUp", function(_, b) if b == "RightButton" then A.Unlock(false) end end)
    end
    A.PlaceSpot()
    spot:EnableMouse(true); spot:Show()
  else
    spot:EnableMouse(false); spot:Hide()
  end
  A.unlocked = on
  if A.onUnlock then A.onUnlock(on) end
end

function A.ResetSpot()
  ns.db.spot = ns.Copy(ns.DEFAULTS.spot)
  A.PlaceSpot()
end

local function InWorld(parent)
  return parent == nil or parent == UIParent or parent == WorldFrame
end

-- runs right after the game put the tooltip at its default spot
local function OnDefaultAnchor(tip, parent)
  if tip ~= GameTooltip or not ns.db then return end
  Stop()
  local mode = ns.db.anchor
  if mode == "cursor" and (ns.db.scope == "all" or InWorld(parent)) then
    following = true
    FollowCursor()
    driver:Show()
  elseif mode == "custom" then
    local p = ns.db.spot.point
    tip:ClearAllPoints()
    tip:SetPoint(p, spot, p)
  end
end

function A.Hook()
  A.PlaceSpot()
  if hooksecurefunc and GameTooltip_SetDefaultAnchor then
    hooksecurefunc("GameTooltip_SetDefaultAnchor", OnDefaultAnchor)
  end
  -- anything else placing the tooltip (a bag slot, a button) takes over: stop following
  if hooksecurefunc then hooksecurefunc(GameTooltip, "SetOwner", function() Stop() end) end
  GameTooltip:HookScript("OnHide", Stop)
end
