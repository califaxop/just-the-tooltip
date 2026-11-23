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

-- One small driver, running only while the tooltip is up and has something to do: follow the
-- cursor (re-placed only when the mouse actually moved), and/or hide a world tooltip the moment
-- you stop hovering what it's about (checked 20 times a second, not every frame).
local following, watching = false, false
local worldUnit = false -- the tooltip shows a unit (in the world, or on a unit frame)
local owner, awayFor = nil, 0 -- a frame the tooltip belongs to (your player frame, a button), and how long the mouse has been off it
local ghost = false     -- a world unit's tooltip was hidden and nothing new has been put in it since
local worldThing = false -- the tooltip shows something in the world that isn't a unit (a corpse, an object)
local thingWatch, seenCursor, sinceThing = false, false, 0
local lastX, lastY, sinceCheck = nil, nil, 0
local driver = CreateFrame("Frame")
driver:Hide()

local function FollowCursor(force)
  local tip = GameTooltip
  local x, y = GetCursorPosition()
  if not force and x == lastX and y == lastY then return end -- the mouse didn't move: nothing to do
  lastX, lastY = x, y
  local c = CORNERS[ns.db.corner] or CORNERS.BOTTOMRIGHT
  local s = tip:GetEffectiveScale()
  if force then tip:ClearAllPoints() end
  tip:SetPoint(c[1], UIParent, "BOTTOMLEFT", x / s + c[2] * ns.db.offX, y / s + c[3] * ns.db.offY)
end

local function Stop() following, watching, owner, thingWatch = false, false, nil, false; driver:Hide() end

-- the mouse left what a world tooltip is about: gone now ("no fade"), else the game's fade
local function Leave()
  thingWatch, watching = false, false
  if ns.db.instantHide or not GameTooltip.FadeOut then GameTooltip:Hide() else GameTooltip:FadeOut() end
end
A.Stop = Stop

driver:SetScript("OnUpdate", function(_, elapsed)
  if not GameTooltip:IsShown() or not (following or watching or owner or thingWatch) then Stop(); return end
  if following then FollowCursor() end
  -- a tooltip for a frame (your player frame, a button): the frame hides it when the mouse leaves,
  -- but if that's missed it would stay up. Off the frame for a moment (with "no fade": 0.1 s,
  -- else long enough for the game's fade, 1.5 s): hide it.
  if owner then
    local ok, over = pcall(owner.IsMouseOver, owner)
    if ok and ns.Readable(over) and not over then
      awayFor = awayFor + elapsed
      if awayFor >= (ns.db.instantHide and 0.1 or 1.5) then owner = nil; GameTooltip:Hide(); return end
    else
      awayFor = 0
    end
  end
  if watching then
    sinceCheck = sinceCheck + elapsed
    if sinceCheck >= 0.05 then
      sinceCheck = 0
      local ok, exists = pcall(UnitExists, "mouseover")
      if ok and ns.Readable(exists) and not exists then watching = false; GameTooltip:Hide() end
    end
  end
  -- a corpse or object: ask the game what's under the cursor now; once it has said something and
  -- then says nothing, the mouse has left it (the game doesn't always fade these, see below)
  if thingWatch then
    sinceThing = sinceThing + elapsed
    if sinceThing >= 0.1 then
      sinceThing = 0
      local ok, data = pcall(C_TooltipInfo.GetWorldCursor)
      if ok then
        if data then seenCursor = true elseif seenCursor then Leave(); return end
      end
    end
  end
end)

-- a unit's tooltip (world or unit frame): a re-show with nothing new in it is a ghost (below)
function A.MarkUnit() worldUnit = true end

-- a world unit's tooltip: hide it as soon as the mouse leaves the unit (instead of the game's fade)
function A.WatchMouseover()
  worldUnit = true
  if not ns.db.instantHide then return end
  watching, sinceCheck = true, 0
  driver:Show()
end

-- a corpse's or an object's tooltip in the world: hide it when the mouse leaves (these could stay up
-- until you hovered something else)
function A.WatchWorldThing()
  worldThing = true
  if C_TooltipInfo and C_TooltipInfo.GetWorldCursor then
    thingWatch, seenCursor, sinceThing = true, false, 0
    driver:Show()
  end
end

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

-- /jtt debug: what the tooltip is doing right now
function A.Debug()
  local tip = GameTooltip
  local owner = tip:GetOwner()
  local ok, _, unit = pcall(tip.GetUnit, tip)
  local okM, mo = pcall(UnitExists, "mouseover")
  local okD, data = pcall(tip.GetTooltipData, tip)
  local kind = okD and type(data) == "table" and data.type
  ns.Print(format("shown=%s type=%s owner=%s unit=%s mouseover=%s following=%s watching=%s worldUnit=%s worldThing=%s ghost=%s",
    tostring(tip:IsShown()), tostring(kind), tostring(owner and (owner.GetName and owner:GetName() or "a frame") or "none"),
    tostring(ok and ns.Readable(unit) and unit or "?"), tostring(okM and ns.Readable(mo) and mo or "?"),
    tostring(following), tostring(watching), tostring(worldUnit), tostring(worldThing), tostring(ghost)))
end

function A.ResetSpot()
  ns.db.spot = ns.Copy(ns.DEFAULTS.spot)
  A.PlaceSpot()
end

local function InWorld(parent)
  return parent == nil or parent == UIParent or parent == WorldFrame
end
A.InWorld = InWorld

-- runs right after the game put the tooltip at its default spot
local function OnDefaultAnchor(tip, parent)
  if tip ~= GameTooltip or not ns.db then return end
  Stop()
  local mode = ns.db.anchor
  -- a tooltip for a frame: keep an eye on the mouse leaving it (see the driver)
  if parent and not InWorld(parent) and parent.IsMouseOver then
    owner, awayFor = parent, 0
    driver:Show()
  end
  if mode == "cursor" and (ns.db.scope == "all" or InWorld(parent)) then
    following = true
    FollowCursor(true)
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
  -- anything else placing the tooltip (a bag slot, a button) takes over: stop following. It's
  -- also how anything new is put in the tooltip, so it ends a "ghost" (below)
  if hooksecurefunc then hooksecurefunc(GameTooltip, "SetOwner", function() Stop(); ghost = false end) end
  GameTooltip:HookScript("OnHide", function()
    Stop()
    if worldUnit or worldThing then ghost = true end
    worldUnit, worldThing = false, false
  end)
  -- the game says when the cursor is over nothing in the world any more: a world tooltip
  -- (unit, corpse, object) still up then is left over
  local ev = CreateFrame("Frame")
  if pcall(ev.RegisterEvent, ev, "WORLD_CURSOR_TOOLTIP_UPDATE") then
    ev:SetScript("OnEvent", function(_, _, anchorType)
      if not ns.db or not ns.Readable(anchorType) then return end
      local none = Enum and Enum.WorldCursorAnchorType and Enum.WorldCursorAnchorType.None or 0
      if anchorType ~= none or not (worldUnit or worldThing) then return end
      if GameTooltip:IsShown() and InWorld(GameTooltip:GetOwner()) then Leave() end
    end)
  end
  -- A world unit's tooltip can come back after it was hidden, still showing that unit (without its
  -- health bar) and staying until you hover something else. Everything new in the tooltip comes
  -- with a new owner first, so a show with no new owner since is that ghost: hide it again.
  GameTooltip:HookScript("OnShow", function(tip)
    if ghost and ns.db.instantHide then tip:Hide() end
  end)
  -- the game fades the tooltip when you stop hovering something (units, objects, unit frames):
  -- with "no fade", hide it now
  if hooksecurefunc and GameTooltip.FadeOut then
    hooksecurefunc(GameTooltip, "FadeOut", function(tip)
      if ns.db.instantHide then tip:Hide() end
    end)
  end
end
