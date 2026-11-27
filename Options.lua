-- Settings window (/jtt), in the same style as our other addons.
local _, ns = ...
local UI = ns.UI
local W_ = 470 -- content width
local window

local function Changed() ns.Look.Refresh() end
local function S(key) return { function() return ns.db[key] end, function(v) ns.db[key] = v end } end

local function BuildPanel(panel)
  local refreshers = {}
  local function track(w) refreshers[#refreshers + 1] = w; return w end
  local function at(w, x, y) w:SetPoint("TOPLEFT", x, y); return w end

  local title = at(UI.Text(panel, "title", "Just the Tooltip!"), 26, -20)
  UI.Text(panel, "note", "The game's tooltip, where you want it."):SetPoint("LEFT", title, "RIGHT", 10, -1)

  -- Position -----------------------------------------------------------------
  at(UI.Section(panel, "Position", W_), 26, -54)
  local cursorRows, spotRows = {}, {}
  local function showRows()
    for _, w in ipairs(cursorRows) do w:SetShown(ns.db.anchor == "cursor") end
    for _, w in ipairs(spotRows) do w:SetShown(ns.db.anchor == "custom") end
    if ns.db.anchor ~= "custom" and ns.Anchor.unlocked then ns.Anchor.Unlock(false) end
  end
  track(at(UI.Selector(panel, 300, {
    { "default", "The game's spot (bottom right)" },
    { "cursor", "Follow my cursor" },
    { "custom", "My own spot" },
  }, S("anchor"), showRows, "Where tooltips go that the game would put in the bottom right corner. Tooltips beside your bags or a window stay put."), 26, -84))

  -- follow the cursor
  local corner = track(at(UI.Selector(panel, 300, {
    { "BOTTOMRIGHT", "Below and right of the cursor" },
    { "BOTTOMLEFT", "Below and left of the cursor" },
    { "TOPRIGHT", "Above and right of the cursor" },
    { "TOPLEFT", "Above and left of the cursor" },
  }, S("corner"), nil, "Which side of your cursor the tooltip sits on."), 26, -116))
  local scope = track(at(UI.Selector(panel, 300, {
    { "all", "For everything" },
    { "world", "Only for things in the world" },
  }, S("scope"), nil, "\"Only for things in the world\": units and objects follow your cursor; action bars and the like keep the game's spot."), 26, -146))
  local ox = track(at(UI.Slider(panel, "Distance sideways", 220, 0, 80, 1, S("offX"), function(v) return v .. " px" end), 26, -178))
  local oy = track(at(UI.Slider(panel, "Distance up / down", 220, 0, 80, 1, S("offY"), function(v) return v .. " px" end), 276, -178))
  cursorRows = { corner, scope, ox, oy }

  -- your own spot
  local move
  move = at(UI.Button(panel, "Move the spot", 130, function() ns.Anchor.Unlock(not ns.Anchor.unlocked) end), 26, -118)
  local resetSpot = UI.Button(panel, "Reset the spot", 130, function() ns.Anchor.ResetSpot() end)
  resetSpot:SetPoint("LEFT", move, "RIGHT", 8, 0)
  local spotNote = at(UI.Text(panel, "note", "Drag the blue box where you want tooltips, then right-click it. The tooltip grows away from the nearest screen edge."), 26, -148)
  spotNote:SetWidth(W_)
  spotRows = { move, resetSpot, spotNote }

  -- Look ---------------------------------------------------------------------
  at(UI.Section(panel, "Look", W_), 26, -232)
  track(at(UI.Selector(panel, 300, {
    { "addon", "JTT style" },
    { "blizzard", "Blizzard's" },
  }, S("look"), Changed, "JTT style: a dark panel with a bronze border (FlareUI's when it's installed)."), 26, -262))
  track(at(UI.Check(panel, "Border in the item's quality / player's class color", S("colorBorder"), W_, Changed), 26, -292))
  track(at(UI.Check(panel, "NPCs too: red hostile, yellow neutral, green friendly (grey if tapped)", S("colorNPC"), W_, Changed), 26, -316))
  track(at(UI.Slider(panel, "Size", 220, 0.6, 1.6, 0.05, S("scale"), function(v) return math.floor(v * 100 + 0.5) .. "%" end, Changed), 26, -342))

  -- Show ---------------------------------------------------------------------
  at(UI.Section(panel, "Show", W_), 26, -390)
  track(at(UI.Check(panel, "Item ID and Spell ID (spells, buffs and debuffs too)", S("ids"), W_), 26, -420))
  track(at(UI.Check(panel, "Item level on gear", S("itemLevel"), W_), 26, -444))
  local src = track(at(UI.Check(panel, "Where gear comes from (quest, drop, vendor, chest, profession)", S("sources"), W_, function() ns.Sources.Hold() end), 26, -468))
  src:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Where gear comes from", 1, 1, 1)
    GameTooltip:AddLine("Quest rewards, drops, vendors, chests and professions, for your faction. From QuestieDB's WoW: Forever data (by the Questie team, GPLv3) and the game's own tables; with NeedRoll or Questie installed, what they know too.", 0.85, 0.85, 0.85, true)
    GameTooltip:AddLine("Drops are listed likeliest first (CMaNGOS Classic-DB's loot tables, GPLv3); the chances aren't shown, since WoW: Forever's may differ.", 0.85, 0.85, 0.85, true)
    if not ns.Sources.Available() then GameTooltip:AddLine("Needs the \"Just the Tooltip!: Sources\" addon (it comes in the same download): turn it on in the AddOns list.", 1, 0.3, 0.3, true) end
    GameTooltip:Show()
  end)
  src:HookScript("OnLeave", function() GameTooltip:Hide() end)
  track(at(UI.Check(panel, "Who a unit is targeting (\">> You <<\" when it's you)", S("target"), W_), 26, -492))
  track(at(UI.Check(panel, "Health bar under unit tooltips", S("healthBar"), W_, function() ns.Info.ApplyHealthBar() end), 26, -516))
  track(at(UI.Check(panel, "Hide right away when you stop hovering something (no fade)", S("instantHide"), W_), 26, -540))
  track(at(UI.Check(panel, "In combat, hide tooltips for things in the world (hold Shift to see)", S("combatHide"), W_), 26, -564))
  local n = at(UI.Text(panel, "note", "Lines from your other addons (Equip This!, Questie, What's Training...) still show: Just the Tooltip! changes the game's tooltip rather than replacing it."), 26, -592)
  n:SetWidth(W_)

  -- hover to see where tooltips go now
  local preview = at(UI.Button(panel, "Hover to preview", 150, function() end), 26, -638)
  preview:HookScript("OnEnter", function(self)
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    GameTooltip:SetText("Just the Tooltip!")
    GameTooltip:AddLine("Tooltips that use the game's spot go here.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  preview:HookScript("OnLeave", function() GameTooltip:Hide() end)

  panel:HookScript("OnShow", function() for _, w in ipairs(refreshers) do w.Refresh() end; showRows() end)
  panel:HookScript("OnHide", function() if ns.Anchor.unlocked then ns.Anchor.Unlock(false) end end)
  showRows()
  panel.height = 684
end

function ns.CreateOptions()
  local p = CreateFrame("Frame"); p.name = "Just the Tooltip!"
  pcall(function()
    local t = p:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    t:SetPoint("TOPLEFT", 16, -16); t:SetText("Just the Tooltip!")
    local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
    b:SetSize(220, 24); b:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -12); b:SetText("Open Just the Tooltip! settings")
    b:SetScript("OnClick", function()
      if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel, true) end
      if not (window and window:IsShown()) then ns.OpenOptions() end
    end)
    if Settings and Settings.RegisterCanvasLayoutCategory then
      Settings.RegisterAddOnCategory(Settings.RegisterCanvasLayoutCategory(p, p.name))
    elseif InterfaceOptions_AddCategory then
      InterfaceOptions_AddCategory(p)
    end
  end)
end

-- Report a bug (the title bar's button, /jtt report): the line to paste and its counters
local function yes(v) return v and "yes" or "no" end
local function BugReport()
  local db = ns.db
  local okB, build, number, _, toc = pcall(GetBuildInfo)
  local _, class = UnitClass("player")
  local L = { format("Just the Tooltip!; client %s (%s), interface %s; %s %d", okB and tostring(build) or "?",
    okB and tostring(number) or "?", okB and tostring(toc) or "?", tostring(class), UnitLevel("player")) }
  L[#L + 1] = format("settings: anchor %s (%s, %s %d,%d), look %s, scale %.2f, border colour %s, NPC colour %s, IDs %s, item level %s, sources %s, target %s, health bar %s, hide in combat %s, hide at once %s",
    tostring(db.anchor), tostring(db.scope), tostring(db.corner), db.offX or 0, db.offY or 0, tostring(db.look), db.scale or 1,
    yes(db.colorBorder), yes(db.colorNPC), yes(db.ids), yes(db.itemLevel), yes(db.sources), yes(db.target), yes(db.healthBar),
    yes(db.combatHide), yes(db.instantHide))
  local srcOk = ns.Sources.Available()
  L[#L + 1] = format("sources addon: %s; FlareUI: %s; EllesmereUI: %s", srcOk and "installed" or "not installed",
    yes(type(FlareUI) == "table"), yes(UI.HasEllesmere()))
  for _, l in ipairs(ns.CompatLines()) do L[#L + 1] = l end
  for _, l in ipairs(ns.Facts.InfoLines()) do L[#L + 1] = l end
  local hooks = {}
  for k in pairs(ns.hooks) do hooks[#hooks + 1] = k end
  table.sort(hooks)
  L[#L + 1] = "hooks: " .. (#hooks > 0 and table.concat(hooks, ", ") or "none")
  L[#L + 1] = "tooltip now: " .. ns.Anchor.DebugLine()
  local ANCHOR = { default = "the game's spot", cursor = "follows the cursor", custom = "your own spot" }
  return table.concat(L, " // "), {
    { "Interface\\Icons\\INV_Misc_Map_01", "Position", ANCHOR[db.anchor] or tostring(db.anchor) },
    { "Interface\\Icons\\INV_Misc_Gem_Pearl_04", "Look", db.look == "blizzard" and "the game's" or "Just the Tooltip!'s" },
    { "Interface\\Icons\\INV_Misc_Book_09", "Gear sources", db.sources and (srcOk and "on" or "on, addon missing") or "off" },
    { "Interface\\Icons\\Ability_Warrior_BattleShout", "Hide in combat", yes(db.combatHide) },
  }
end
local BUG = { name = "JustTheTooltipReportWindow", title = "Just the Tooltip! Bugs & Feedback",
  repo = "https://github.com/califaxop/just-the-tooltip/issues/new",
  included = "Included: Just the Tooltip!'s version, the game client, your class and level, its settings and what the tooltip is doing right now. Never: your name, realm, guild or other players.",
  build = BugReport }
function ns.ShowBugReport(kind)
  local get = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
  BUG.version = get and get(ns.name, "Version") or nil
  return UI.ShowBugReport(BUG, kind)
end

function ns.OpenOptions()
  if not window then
    window = UI.Window("JustTheTooltipOptionsWindow", 522, 660)
    window:SetPoint("CENTER")
    UI.SetHost(window) -- pop-ups (the bug report) sit over this window
    UI.HeaderButton(window, "Bugs & Feedback", 130, function() ns.ShowBugReport() end)
    local ok, e = pcall(BuildPanel, window)
    if not ok then window:Hide(); window = nil; ns.Print("settings failed: " .. tostring(e)); return end
    window:SetHeight(window.height or 660)
    window:Hide()
  end
  UI.Restyle()
  window:SetScale(math.max(0.5, math.min(1, (UIParent:GetHeight() - 40) / window:GetHeight())))
  window:SetShown(not window:IsShown())
end
