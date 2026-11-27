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

-- The tooltip's lifecycle (1.7.0): everything known about the tooltip now showing is in one record,
-- S, started afresh whenever something new is put in the tooltip (SetOwner: the game's way to
-- begin every tooltip) and ended when it hides. Nothing from an earlier tooltip reaches a new one
-- (before 1.7.0, "a unit" and "a thing in the world" lasted until the tooltip hid, and the
-- interface frame under the mouse until the next unit).
--   gen          which tooltip this is (counts up; a check meant for an earlier one is dropped)
--   unit         it shows a unit (in the world, or on a unit frame)
--   thing        it shows a corpse or an object in the world
--   following    it follows the cursor
--   owner        the frame it belongs to (your player frame, a button), watched for the mouse
--   ownerSeen    the mouse has been over that frame since (only then does leaving it count)
--   awayFor      how long the mouse has been off it
--   watchUnit    checking the game's "mouseover" unit (a world unit, with "no fade")
--   watchCursor  checking what's under the cursor in the world (units, corpses, objects)
--   seenCursor   the game has said something is under the cursor since
--   startFocus   the frame under the mouse when the unit's tooltip came up (part of hovering it)
--   ghost        a world tooltip was hidden and nothing new has been put in it since
-- One small driver runs only while the tooltip is up and has something to do: follow the cursor
-- (placed again only when the mouse moved), and hide a tooltip the moment its unit, thing or frame
-- is no longer hovered (checked 20 times a second, not every frame).
local S = { gen = 0 }
A.state = S
local lastX, lastY, sinceCheck, sinceUI, sinceThing = nil, nil, 0, 0, 0
local driver = CreateFrame("Frame")
driver:Hide()
-- stop everything that watches the tooltip (the record's facts stay)
local function Stop()
  S.following, S.watchUnit, S.watchCursor, S.owner = false, false, false, nil
  driver:Hide()
end
-- (2.0.0) /jtt lifecycle: the last 20 tooltips, each { gen, at, owner, anchor, place, about, ended,
-- endedAt, ghosts }: who it was for, where JTT put it, what it showed, and what ended it and when
A.history = {}
local HISTORY = 20
local function Rec() local h = A.history; return h[#h] end
local function Name(f)
  if f == nil then return "none" end
  if type(f) ~= "table" then return tostring(f) end
  return ns.Safe(f.GetName, f) or "an unnamed frame"
end
-- what ended the tooltip now showing (JTT's reason, set just before it hides it)
function A.Ended(reason)
  local r = Rec()
  if r and not r.ended and GameTooltip:IsShown() then r.ended, r.endedAt = reason, GetTime() end
end

-- a new tooltip: a clean record
local function Fresh(_, owner, anchor)
  Stop()
  S.gen = S.gen + 1
  S.unit, S.thing, S.ghost, S.seenCursor, S.startFocus, S.ownerSeen, S.awayFor = false, false, false, false, nil, false, 0
  local h = A.history
  h[#h + 1] = { gen = S.gen, at = GetTime(), owner = Name(owner), anchor = type(anchor) == "string" and anchor or nil }
  if #h > HISTORY then table.remove(h, 1) end
end
A.Fresh = Fresh

-- /jtt trace: what the game says and what we do, with times, while you hover and leave something
local trace, t0, traced = false, nil, {}
local function Trace(msg, once)
  if not trace then return end
  if once then if traced[once] then return end traced[once] = true end
  ns.Print(format("|cff9d9d9d%.2fs|r %s", GetTime() - (t0 or GetTime()), msg))
end
A.Trace = Trace

-- The frame the mouse is over, if it's part of the interface (chat, bars, unit frames...) rather
-- than the 3D world. The game keeps the last unit under the mouse as "mouseover" while the mouse is
-- over the interface, so a world unit's tooltip would stay up until you're back over the world.
local function TopFocus()
  if GetMouseFoci then
    local ok, t = pcall(GetMouseFoci)
    return ok and type(t) == "table" and t[1] or nil
  elseif GetMouseFocus then
    local ok, f = pcall(GetMouseFocus)
    return ok and f or nil
  end
end
local function OverInterface()
  local focus = TopFocus()
  if not focus or focus == WorldFrame or focus == UIParent then return nil end
  -- only once the mouse has moved onto something else: what it was over when the tooltip came up
  -- is part of hovering the unit
  if focus == S.startFocus then return nil end
  -- (a nameplate is the unit itself, and the tooltip is no part of the interface we're leaving for)
  if focus == GameTooltip then return nil end
  -- Up its parents: inside a nameplate (FlareUI's and EllesmereUI's plates are in the game's), it's
  -- the unit; a named piece of the interface (chat, bars, unit frames, an addon's window), you've
  -- left the unit; nothing named at all (an overlay some addon shows over the world), ignored.
  local fr, named = focus, nil
  for _ = 1, 12 do
    local okN, n = pcall(fr.GetName, fr)
    n = okN and type(n) == "string" and n or nil
    if n and n:find("^NamePlate") then return nil end
    named = named or n
    local okP, p = pcall(fr.GetParent, fr)
    if not okP or not p or p == UIParent or p == WorldFrame then break end
    fr = p
  end
  if not named then
    local okD, dn = pcall(focus.GetDebugName, focus)
    Trace("mouse over an unnamed frame (" .. tostring(okD and dn or "?") .. "): ignored", "unnamed")
    return nil
  end
  return focus, named
end

-- Where the tooltip goes for the cursor at screen position x, y (GetCursorPosition's units). A
-- point's offsets are in the scale of the frame being placed (the tooltip), so the cursor's
-- position is divided by the tooltip's effective scale: its corner sits on the cursor at any
-- tooltip or UI scale (warcraft.wiki.gg, SetPoint: "increasing the Region's scale will increase
-- the offset"; What's Training places its Forever menu the same way).
-- The distance from the cursor is in the interface's units (UIParent's, like the sliders' "px"),
-- so it's the same at any tooltip size (1.6.0: before, it grew and shrank with the tooltip).
-- Returns the tooltip's point and its offsets from UIParent's bottom left.
function A.CursorPoint(x, y, tipScale, uiScale, corner, offX, offY)
  local c = CORNERS[corner] or CORNERS.BOTTOMRIGHT
  local k = uiScale / tipScale
  return c[1], x / tipScale + c[2] * offX * k, y / tipScale + c[3] * offY * k
end

local lastScale
local function FollowCursor(force)
  local tip = GameTooltip
  local x, y = GetCursorPosition()
  local s = tip:GetEffectiveScale()
  -- the mouse didn't move (and the tooltip's size didn't change): nothing to do
  if not force and x == lastX and y == lastY and s == lastScale then return end
  lastX, lastY, lastScale = x, y, s
  local point, px, py = A.CursorPoint(x, y, s, UIParent:GetEffectiveScale(), ns.db.corner, ns.db.offX, ns.db.offY)
  if force then tip:ClearAllPoints() end
  tip:SetPoint(point, UIParent, "BOTTOMLEFT", px, py)
end

-- the mouse left what a world tooltip is about: gone now ("no fade"), else the game's fade
local function Leave(reason)
  A.Ended(reason)
  S.watchCursor, S.watchUnit = false, false
  if ns.db.instantHide or not GameTooltip.FadeOut then GameTooltip:Hide() else GameTooltip:FadeOut() end
end
A.Stop = Stop

-- A tooltip for a frame (your player frame, a button): the frame hides it when the mouse leaves,
-- but if that's missed it would stay up. Only once the mouse has been over the frame (1.7.0: a
-- tooltip shown for a frame the mouse isn't on, by an addon or the keyboard, is left be): off it
-- for a moment (with "no fade": 0.1 s, else long enough for the game's fade, 1.5 s), hide it. A
-- frame that's gone (hidden) takes its tooltip with it at once. Returns true when it hid.
function A.CheckOwner(elapsed)
  local o = S.owner
  if not o then return false end
  local visible = ns.Safe(o.IsVisible, o)
  if visible == false then Trace("its frame is gone: hiding"); A.Ended("JTT: its frame was hidden"); S.owner = nil; GameTooltip:Hide(); return true end
  local over = ns.Safe(o.IsMouseOver, o)
  if over == true then S.ownerSeen, S.awayFor = true, 0
  elseif over == false and S.ownerSeen then
    S.awayFor = S.awayFor + elapsed
    if S.awayFor >= (ns.db.instantHide and 0.1 or 1.5) then
      Trace("mouse off its frame: hiding"); A.Ended("JTT: the mouse left its frame"); S.owner = nil; GameTooltip:Hide(); return true
    end
  end
  return false
end

driver:SetScript("OnUpdate", function(_, elapsed)
  if not GameTooltip:IsShown() or not (S.following or S.watchUnit or S.owner or S.watchCursor) then Stop(); return end
  if S.following then FollowCursor() end
  if A.CheckOwner(elapsed) then return end
  if (S.watchUnit or S.watchCursor) and (S.unit or S.thing) then
    -- the mouse went onto the interface: you're not hovering the unit any more (20 times a second)
    sinceUI = sinceUI + elapsed
    if sinceUI >= 0.05 then
      sinceUI = 0
      local over, name = OverInterface()
      if over then Trace("mouse over the interface (" .. name .. "): " .. (ns.db.instantHide and "hiding" or "fading")); Leave("JTT: the mouse went onto the interface (" .. name .. ")"); return end
    end
  end
  if S.watchUnit then
    sinceCheck = sinceCheck + elapsed
    if sinceCheck >= 0.05 then
      sinceCheck = 0
      local ok, exists = pcall(UnitExists, "mouseover")
      if ok and ns.Readable(exists) and not exists then S.watchUnit = false; Trace("no mouseover unit: hiding"); A.Ended("JTT: no unit under the mouse"); GameTooltip:Hide()
      elseif not ok or not ns.Readable(exists) then Trace("mouseover: can't be read now", "mo") end
    end
  end
  -- a unit, corpse or object: ask the game what's under the cursor now; once it has said something
  -- and then says nothing, the mouse has left it (the game doesn't always fade these, see below)
  if S.watchCursor then
    sinceThing = sinceThing + elapsed
    if sinceThing >= 0.1 then
      sinceThing = 0
      local ok, data = pcall(C_TooltipInfo.GetWorldCursor)
      if ok then
        if data then
          if not S.seenCursor then Trace("cursor: over something") end
          S.seenCursor = true
        elseif S.seenCursor then Trace("cursor: over nothing: " .. (ns.db.instantHide and "hiding" or "fading")); Leave("JTT: the cursor is over nothing in the world"); return
        else Trace("cursor: says nothing yet", "cn") end
      else Trace("cursor check failed", "cf") end
    end
  end
end)

-- a unit's tooltip (world or unit frame): a re-show with nothing new in it is a ghost (below)
function A.MarkUnit()
  S.unit = true
  local r = Rec(); if r then r.about = r.about or "a unit (on a frame)" end
end

-- a world unit's tooltip: hide it as soon as the mouse leaves the unit (instead of the game's fade).
-- Two checks, either one is enough: the game's "mouseover" unit gone, or nothing under the cursor
-- at all. (A corpse can stay "mouseover" after you've moved off it, and in combat the first may
-- not be readable; without "no fade" the second still starts the game's fade, which it can skip.)
function A.WatchMouseover()
  S.unit = true
  local r = Rec(); if r then r.about = "a unit in the world" end
  S.startFocus = TopFocus()
  if trace then
    t0, traced = GetTime(), {}
    Trace(format("unit tooltip shown (no fade: %s, cursor check: %s)", tostring(ns.db.instantHide),
      tostring(C_TooltipInfo and C_TooltipInfo.GetWorldCursor and true or false)))
  end
  if ns.db.instantHide then
    S.watchUnit, sinceCheck = true, 0
    driver:Show()
  end
  if C_TooltipInfo and C_TooltipInfo.GetWorldCursor then
    S.watchCursor, S.seenCursor, sinceThing = true, false, 0
    driver:Show()
  end
end

-- a corpse's or an object's tooltip in the world: hide it when the mouse leaves (these could stay up
-- until you hovered something else)
function A.WatchWorldThing()
  S.thing = true
  local r = Rec(); if r then r.about = "a corpse or object in the world" end
  S.startFocus = TopFocus()
  if C_TooltipInfo and C_TooltipInfo.GetWorldCursor then
    S.watchCursor, S.seenCursor, sinceThing = true, false, 0
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

-- /jtt debug and the bug report: what the tooltip is doing right now
function A.DebugLine()
  local tip = GameTooltip
  local owner = tip:GetOwner()
  local ok, _, unit = pcall(tip.GetUnit, tip)
  local okM, mo = pcall(UnitExists, "mouseover")
  local okD, data = pcall(tip.GetTooltipData, tip)
  local kind = okD and type(data) == "table" and data.type
  local watched = S.owner and (ns.Safe(S.owner.GetName, S.owner) or "a frame") or "none"
  return (format("shown=%s type=%s owner=%s unit=%s mouseover=%s | tooltip #%d: unit=%s thing=%s following=%s watching frame=%s (mouse seen over it: %s) mouseover=%s cursor=%s ghost=%s",
    tostring(tip:IsShown()), tostring(kind), tostring(owner and (owner.GetName and owner:GetName() or "a frame") or "none"),
    tostring(ok and ns.Readable(unit) and unit or "?"), tostring(okM and ns.Readable(mo) and mo or "?"),
    S.gen, tostring(S.unit), tostring(S.thing), tostring(S.following), tostring(watched), tostring(S.ownerSeen),
    tostring(S.watchUnit), tostring(S.watchCursor), tostring(S.ghost)))
end
function A.Debug() ns.Print(A.DebugLine()) end

-- /jtt lifecycle: the last tooltips, newest last
function A.LifecycleLines(n)
  local L, h = {}, A.history
  for i = math.max(1, #h - (n or 10) + 1), #h do
    local r = h[i]
    local life = r.endedAt and format("%.1f s", r.endedAt - r.at) or (i == #h and GameTooltip:IsShown() and "still up" or "?")
    L[#L + 1] = format("#%d for %s%s | %s | %s | %s: %s%s", r.gen, r.owner, r.anchor and (" (" .. r.anchor .. ")") or "",
      r.place or "placed by the game or an addon", r.about or "not a unit or world object", life,
      r.ended or (life == "still up" and "showing" or "not seen ending"),
      r.ghosts and format(" | came back %d time%s with nothing new: hidden again", r.ghosts, r.ghosts == 1 and "" or "s") or "")
  end
  if #L == 0 then L[1] = "no tooltips yet this session" end
  return L
end

function A.ToggleTrace()
  trace = not trace
  ns.Print(trace and "trace on: hover an enemy, move off it, then send these lines. /jtt trace again to stop." or "trace off.")
end

function A.ResetSpot()
  ns.db.spot = ns.Copy(ns.DEFAULTS.spot)
  A.PlaceSpot()
end

local function InWorld(parent)
  return parent == nil or parent == UIParent or parent == WorldFrame
end
A.InWorld = InWorld

-- Compatibility (1.7.0): after JTT places a tooltip, a frame later it checks that it's still
-- where JTT put it. Something else moving it (another tooltip addon) is counted for /jtt compat.
A.placement = { placed = 0, moved = 0 }
local function CheckPlacement(gen, rel)
  if gen ~= S.gen or not GameTooltip:IsShown() then return end
  local _, at = ns.Safe(GameTooltip.GetPoint, GameTooltip, 1)
  if at ~= nil and at ~= rel then
    A.placement.moved = A.placement.moved + 1
    A.placement.lastBy = ns.Safe(at.GetName, at) or "an unnamed frame"
    Trace("moved after JTT placed it: now anchored to " .. A.placement.lastBy)
  end
end
local function Placed(rel)
  A.placement.placed = A.placement.placed + 1
  if C_Timer and C_Timer.After then
    local gen = S.gen
    C_Timer.After(0, function() CheckPlacement(gen, rel) end)
  end
end

-- runs right after the game put the tooltip at its default spot
local function OnDefaultAnchor(tip, parent)
  if tip ~= GameTooltip or not ns.db then return end
  Stop()
  local mode = ns.db.anchor
  -- a tooltip for a frame: keep an eye on the mouse leaving it (see A.CheckOwner)
  if parent and not InWorld(parent) and parent.IsMouseOver then
    S.owner, S.ownerSeen, S.awayFor = parent, false, 0
    driver:Show()
  end
  local r = Rec()
  if r then r.place = "the game's spot" end
  if mode == "cursor" and (ns.db.scope == "all" or InWorld(parent)) then
    if r then r.place = "following the cursor" end
    S.following = true
    FollowCursor(true)
    driver:Show()
    Placed(UIParent)
  elseif mode == "custom" then
    if r then r.place = "your spot" end
    local p = ns.db.spot.point
    tip:ClearAllPoints()
    tip:SetPoint(p, spot, p)
    Placed(spot)
  end
end

function A.Hook()
  A.PlaceSpot()
  if not ns.Once("anchor") then return end
  if hooksecurefunc and GameTooltip_SetDefaultAnchor then
    hooksecurefunc("GameTooltip_SetDefaultAnchor", OnDefaultAnchor)
  end
  -- anything new put in the tooltip starts with SetOwner (a bag slot, a button, the default spot):
  -- a new tooltip, a clean record. It's also what ends a "ghost" (below).
  if hooksecurefunc then hooksecurefunc(GameTooltip, "SetOwner", Fresh) end
  GameTooltip:HookScript("OnHide", function()
    Trace("tooltip hidden")
    local r = Rec()
    if r and not r.ended then r.ended, r.endedAt = "the game (or another addon)", GetTime() end
    Stop()
    if S.unit or S.thing then S.ghost = true end
    S.unit, S.thing, S.startFocus = false, false, nil
  end)
  -- the game says when the cursor is over nothing in the world any more: a world tooltip
  -- (unit, corpse, object) still up then is left over
  local ev = CreateFrame("Frame")
  pcall(ev.RegisterEvent, ev, "UPDATE_MOUSEOVER_UNIT")
  pcall(ev.RegisterEvent, ev, "WORLD_CURSOR_TOOLTIP_UPDATE")
  ev:SetScript("OnEvent", function(_, event, anchorType)
    if not ns.db then return end
    local shownInWorld = GameTooltip:IsShown() and InWorld(GameTooltip:GetOwner())
    if event == "UPDATE_MOUSEOVER_UNIT" then
      -- the mouse moved off a unit (or onto another): with no unit under it now, a unit's tooltip goes
      local ok, e = pcall(UnitExists, "mouseover")
      local known = ok and ns.Readable(e)
      Trace("game: mouseover changed (a unit: " .. tostring(known and e or "?") .. ")")
      if known and not e and S.unit and shownInWorld then Leave("JTT: the game says no unit is under the mouse") end
      return
    end
    Trace("game: cursor " .. tostring(ns.Readable(anchorType) and anchorType or "?") .. " (0: nothing)")
    if not ns.Readable(anchorType) then return end
    local none = Enum and Enum.WorldCursorAnchorType and Enum.WorldCursorAnchorType.None or 0
    if anchorType ~= none or not (S.unit or S.thing) then return end
    if shownInWorld then Leave("JTT: the game says the cursor is over nothing") end
  end)
  -- A world unit's tooltip can come back after it was hidden, still showing that unit (without its
  -- health bar) and staying until you hover something else. Everything new in the tooltip comes
  -- with a new owner first, so a show with no new owner since is that ghost: hide it again.
  GameTooltip:HookScript("OnShow", function(tip)
    if S.ghost and ns.db.instantHide then
      local r = Rec(); if r then r.ghosts = (r.ghosts or 0) + 1 end
      tip:Hide()
    end
  end)
  -- the game fades the tooltip when you stop hovering something (units, objects, unit frames):
  -- with "no fade", hide it now
  if hooksecurefunc and GameTooltip.FadeOut then
    hooksecurefunc(GameTooltip, "FadeOut", function(tip)
      Trace("game: fade out")
      if ns.db.instantHide then A.Ended("JTT: the game started its fade (no fade: hidden at once)"); tip:Hide() end
    end)
  end
end
