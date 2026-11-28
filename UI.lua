-- The tooltip's own look (Look.lua's "JTT style"): FlareUI's dialog background and bronze border
-- when FlareUI is installed, EllesmereUI's flat panel when it is, otherwise a dark panel with the
-- game's tooltip border tinted bronze. The settings windows are always the game's own Settings
-- design (Settings.lua).
local _, ns = ...
local UI = {}
ns.UI = UI

local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
local FLARE_BRONZE = { 0.65, 0.49, 0.27 }
-- the plain style's border: the game's own tooltip border, tinted the bronze of the default frames'
-- borders (its artwork is light grey, so the tint is a little brighter than the colour seen)
local BLIZZ_EDGE, BLIZZ_BG = "Interface\\Tooltips\\UI-Tooltip-Border", "Interface\\Tooltips\\UI-Tooltip-Background"
local BRONZE = { 0.86, 0.66, 0.36 }

function UI.FlareBorder()
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("FlareUI"))
    or (IsAddOnLoaded and IsAddOnLoaded("FlareUI"))
  if not loaded then return nil end
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  local path = LSM and LSM:Fetch("border", "FlareUI Frames", true)
  return path or "Interface/AddOns/FlareUI/Media/Borders/FlareUI-Frames.tga"
end

-- EllesmereUI style: EllesmereUI's own skinning API (EllesmereUI.RegisterSkin, see its SKINNING_API.md)
-- hands us S once, at login, unless the player turned skinning off for us: the tooltip takes its
-- panel colour.
function UI.HasEllesmere() return type(EllesmereUI) == "table" and EllesmereUI.RegisterSkin ~= nil end
if UI.HasEllesmere() then
  EllesmereUI.RegisterSkin("JustTheTooltip", function(S)
    UI.euiSkin = S
    -- (ns.OnLooksChanged: the tooltip repaints when the player's EllesmereUI look changes)
    local function again() if ns.OnLooksChanged then pcall(ns.OnLooksChanged) end end
    if S.OnLooksChanged then S.OnLooksChanged(again) end
    again()
  end)
end
function UI.EUI()
  local S = UI.euiSkin
  -- (no setting: the tooltip follows EllesmereUI whenever it's installed and skinning us)
  if S and (not S.IsEnabled or S.IsEnabled()) then return S end
end

-- the panel's border colour: FlareUI's bronze, else the default frames' bronze
function UI.BorderColor() return UI.FlareBorder() and FLARE_BRONZE or BRONZE end

-- a panel behind the tooltip: FlareUI's dialog background and border, else the game's tooltip art
function UI.SkinPanel(f, alpha)
  local flare = UI.FlareBorder()
  if flare then
    f:SetBackdrop({ bgFile = DIALOG_BG, edgeFile = flare, tile = false, tileSize = 0, edgeSize = 16,
      insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(1, 1, 1, alpha)
  else
    f:SetBackdrop({ bgFile = BLIZZ_BG, edgeFile = BLIZZ_EDGE, tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    f:SetBackdropColor(0.03, 0.03, 0.03, alpha)
  end
end
