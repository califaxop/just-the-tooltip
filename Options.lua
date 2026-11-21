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
  track(at(UI.Slider(panel, "Size", 220, 0.6, 1.6, 0.05, S("scale"), function(v) return math.floor(v * 100 + 0.5) .. "%" end, Changed), 26, -318))

  -- Show ---------------------------------------------------------------------
  at(UI.Section(panel, "Show", W_), 26, -366)
  track(at(UI.Check(panel, "Item ID and Spell ID (spells, buffs and debuffs too)", S("ids"), W_), 26, -396))
  track(at(UI.Check(panel, "Item level on gear", S("itemLevel"), W_), 26, -420))
  track(at(UI.Check(panel, "Who a unit is targeting (\">> You <<\" when it's you)", S("target"), W_), 26, -444))
  track(at(UI.Check(panel, "Health numbers on the health bar", S("healthText"), W_), 26, -468))
  track(at(UI.Check(panel, "Hide right away when you stop hovering something in the world (no fade)", S("instantHide"), W_), 26, -492))
  track(at(UI.Check(panel, "In combat, hide tooltips for things in the world (hold Shift to see)", S("combatHide"), W_), 26, -516))
  local n = at(UI.Text(panel, "note", "Lines from your other addons (Equip This!, Questie, What's Training...) still show: Just the Tooltip! changes the game's tooltip rather than replacing it."), 26, -544)
  n:SetWidth(W_)

  -- hover to see where tooltips go now
  local preview = at(UI.Button(panel, "Hover to preview", 150, function() end), 26, -590)
  preview:HookScript("OnEnter", function(self)
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    GameTooltip:SetText("Just the Tooltip!")
    GameTooltip:AddLine("Tooltips that use the game's spot go here.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  preview:HookScript("OnLeave", function() GameTooltip:Hide() end)
  local fb = UI.Button(panel, "Report a bug / suggest", 170, function()
    UI.ShowLink("JustTheTooltipLinkWindow", "Just the Tooltip!: bugs and ideas", "https://github.com/califaxop/just-the-tooltip/issues/new/choose")
  end)
  fb:SetPoint("LEFT", preview, "RIGHT", 8, 0)

  panel:HookScript("OnShow", function() for _, w in ipairs(refreshers) do w.Refresh() end; showRows() end)
  panel:HookScript("OnHide", function() if ns.Anchor.unlocked then ns.Anchor.Unlock(false) end end)
  showRows()
  panel.height = 636
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

function ns.OpenOptions()
  if not window then
    window = UI.Window("JustTheTooltipOptionsWindow", 522, 636)
    window:SetPoint("CENTER")
    UI.SetHost(window) -- pop-ups (the bug / idea link) sit over this window
    local ok, e = pcall(BuildPanel, window)
    if not ok then window:Hide(); window = nil; ns.Print("settings failed: " .. tostring(e)); return end
    window:SetHeight(window.height or 636)
    window:Hide()
  end
  UI.Restyle()
  window:SetScale(math.max(0.5, math.min(1, (UIParent:GetHeight() - 40) / window:GetHeight())))
  window:SetShown(not window:IsShown())
end
