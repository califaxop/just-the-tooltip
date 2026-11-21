-- Start-up and slash commands.
local _, ns = ...

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(_, event, arg1)
  if event == "ADDON_LOADED" and arg1 == ns.name then
    ns.LoadDB()
    ns.CreateOptions()
  elseif event == "PLAYER_LOGIN" then
    ns.Anchor.Hook()
    ns.Look.Hook()
    ns.Info.Hook()
    ns.Look.Refresh()
    ns.Print("loaded. Type |cffffff00/jtt|r to set it up.")
  end
end)

SLASH_JUSTTHETOOLTIP1, SLASH_JUSTTHETOOLTIP2 = "/jtt", "/justthetooltip"
SlashCmdList.JUSTTHETOOLTIP = function(msg)
  local cmd = ((msg or ""):match("^%s*(%S*)") or ""):lower()
  if cmd == "move" then
    ns.db.anchor = "custom"; ns.Anchor.Unlock(not ns.Anchor.unlocked)
  elseif cmd == "reset" then
    ns.db.anchor = "default"; ns.Anchor.ResetSpot(); ns.Print("tooltips are back at the game's spot.")
  else
    local ok, e = pcall(ns.OpenOptions)
    if not ok then ns.Print("settings error: " .. tostring(e)) end
  end
end
