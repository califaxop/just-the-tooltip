-- Start-up and slash commands.
local _, ns = ...

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ns.name then
    ns.LoadDB()
    ns.CreateOptions()
  elseif event == "PLAYER_LOGOUT" then
    ns.Sources.Release() -- (NeedRoll's setting back as it was before it's saved)
    ns.ReleaseOthers()
  elseif event == "PLAYER_LOGIN" then
    ns.Anchor.Hook()
    ns.Look.Hook()
    ns.Info.Hook()
    ns.Sources.Hold() -- (NeedRoll installed: its tooltip lines off, ours show what it knows)
    ns.HoldOthers()
    ns.Look.Refresh()
    ns.Print("loaded. Type |cffffff00/jtt|r to set it up.")
    ns.CheckOthers()
  end
end)

-- Other tooltip addons: Just the Tooltip! loads after them (OptionalDeps), so where it puts the
-- tooltip wins. Some also move or restyle it on their own every frame, so say so once.
local OTHERS = { "TipTac", "TinyTooltip", "TinyTooltip-Reforged", "ElvUI", "Tukui", "CursorTooltip" }
function ns.CheckOthers()
  local found = {}
  for _, name in ipairs(OTHERS) do
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)) or (IsAddOnLoaded and IsAddOnLoaded(name))
    if loaded then found[#found + 1] = name end
  end
  if #found > 0 then
    ns.Print("|cffff9933also loaded: " .. table.concat(found, ", ") .. ".|r Just the Tooltip! has the last say on where the tooltip goes, "
      .. "but for the cleanest result turn off that addon's tooltip options (or the addon).")
  end
end

-- Lines other addons add that the tooltip already has: Just the Tooltip! takes precedence. Auctionator's
-- "Vendor x1" repeats the game's own Sell Price, so it's turned off for the session (Auctionator's
-- auction prices stay). Your Auctionator setting is put back on logout, before it's saved, unless you
-- turned it on again in Auctionator meanwhile.
local heldVendor -- (Auctionator's vendor-tooltip setting as it was, while we hold it off)
local function AuctionatorConfig()
  local A = _G.Auctionator
  local C = type(A) == "table" and A.Config
  if type(C) == "table" and type(C.Get) == "function" and type(C.Set) == "function" and type(C.Options) == "table"
    and C.Options.VENDOR_TOOLTIPS then return C end
end
function ns.HoldOthers()
  local C = AuctionatorConfig()
  if not C then return end
  local ok, on = pcall(C.Get, C.Options.VENDOR_TOOLTIPS)
  if ok and on then
    heldVendor = true
    pcall(C.Set, C.Options.VENDOR_TOOLTIPS, false)
  end
end
function ns.ReleaseOthers()
  local C = AuctionatorConfig()
  if not (C and heldVendor) then return end
  local ok, on = pcall(C.Get, C.Options.VENDOR_TOOLTIPS)
  if ok and on == false then pcall(C.Set, C.Options.VENDOR_TOOLTIPS, true) end
  heldVendor = nil
end

-- /jtt compat (1.7.0): which addons that touch tooltips are here, what JTT does with each, and
-- whether anything moved a tooltip after JTT placed it. Detected (loaded), available (the parts
-- JTT uses work) and used (what JTT does) are told apart: INTEGRATIONS.md.
function ns.CompatLines()
  local L = {}
  local found = {}
  for _, name in ipairs(OTHERS) do
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name)) or (IsAddOnLoaded and IsAddOnLoaded(name))
    if loaded then found[#found + 1] = name end
  end
  L[#L + 1] = "other tooltip addons: " .. (#found > 0 and table.concat(found, ", ") or "none")
  local P = ns.Anchor.placement
  L[#L + 1] = format("placement: %d tooltips placed by JTT, %d moved by something else afterwards%s", P.placed, P.moved,
    P.lastBy and (" (last: anchored to " .. P.lastBy .. ")") or "")
  local names = {}
  for tip in pairs(ns.Look.adopted) do names[#names + 1] = ns.Safe(tip.GetName, tip) or "?" end
  table.sort(names)
  L[#L + 1] = format("look: %s style; styled tooltips: %s", ns.db.look == "addon" and "JTT" or "Blizzard's", table.concat(names, ", "))
  local nr = ns.Sources.NeedRollLoaded()
  L[#L + 1] = format("NeedRoll: %s; Auctionator's vendor line: %s; Questie: %s; source data: %s",
    nr and (ns.Sources.Holding() and "loaded, its lines shown JTT's way" or "loaded, its own lines") or "not loaded",
    heldVendor and "off for this session (JTT's sell price)" or (AuctionatorConfig() and "as you set it" or "Auctionator not loaded"),
    ns.Sources.QuestieState(), ns.Sources.loadState)
  return L
end

SLASH_JUSTTHETOOLTIP1, SLASH_JUSTTHETOOLTIP2 = "/jtt", "/justthetooltip"
SlashCmdList.JUSTTHETOOLTIP = function(msg)
  local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
  if cmd == "move" then
    ns.db.anchor = "custom"; ns.Anchor.Unlock(not ns.Anchor.unlocked)
  elseif cmd == "debug" then
    ns.Anchor.Debug()
  elseif cmd == "compat" then
    for _, l in ipairs(ns.CompatLines()) do ns.Print(l) end
  elseif cmd == "report" then
    ns.ShowBugReport()
  elseif cmd == "trace" then
    ns.Anchor.ToggleTrace()
  elseif cmd == "reset" then
    ns.db.anchor = "default"; ns.Anchor.ResetSpot(); ns.Print("tooltips are back at the game's spot.")
  else
    local ok, e = pcall(ns.OpenOptions)
    if not ok then ns.Print("settings error: " .. tostring(e)) end
  end
end
