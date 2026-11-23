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
  elseif event == "PLAYER_LOGIN" then
    ns.Anchor.Hook()
    ns.Look.Hook()
    ns.Info.Hook()
    ns.Sources.Hold() -- (NeedRoll installed: its tooltip lines off, ours show what it knows)
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

SLASH_JUSTTHETOOLTIP1, SLASH_JUSTTHETOOLTIP2 = "/jtt", "/justthetooltip"
SlashCmdList.JUSTTHETOOLTIP = function(msg)
  local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
  if cmd == "move" then
    ns.db.anchor = "custom"; ns.Anchor.Unlock(not ns.Anchor.unlocked)
  elseif cmd == "debug" then
    ns.Anchor.Debug()
  elseif cmd == "trace" then
    ns.Anchor.ToggleTrace()
  elseif cmd == "reset" then
    ns.db.anchor = "default"; ns.Anchor.ResetSpot(); ns.Print("tooltips are back at the game's spot.")
  else
    local ok, e = pcall(ns.OpenOptions)
    if not ok then ns.Print("settings error: " .. tostring(e)) end
  end
end
