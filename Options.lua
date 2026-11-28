-- Settings window (/jtt), in the game's own Settings design (Settings.lua).
local _, ns = ...
local UI = ns.UI
local window

local function Changed() ns.Look.Refresh() end
local function S(key) return { function() return ns.db[key] end, function(v) ns.db[key] = v end } end
local px = function(v) return v .. " px" end

local function PagePosition(_, R)
  R:Section("Position")
  local after = {} -- (greys out what doesn't apply to the choice)
  R:Selector("Tooltips go", 300, {
    { "default", "The game's spot (bottom right)" },
    { "cursor", "Follow my cursor" },
    { "custom", "My own spot" },
  }, S("anchor"), function()
    if ns.db.anchor ~= "custom" and ns.Anchor.unlocked then ns.Anchor.Unlock(false) end
    for _, f in ipairs(after) do f() end
  end, "Where tooltips go that the game would put in the bottom right corner. Tooltips beside your bags or a window stay put.")
  local preview = R:Button("See where", "Hover to preview", 150, function() end)
  preview:HookScript("OnEnter", function()
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    GameTooltip:SetText("Just the Tooltip!")
    GameTooltip:AddLine("Tooltips that use the game's spot go here.", 1, 1, 1, true)
    GameTooltip:Show()
  end)
  preview:HookScript("OnLeave", function() GameTooltip:Hide() end)

  R:Section("Following my cursor")
  local cursor = {
    R:Selector("Side", 300, {
      { "BOTTOMRIGHT", "Below and right of the cursor" },
      { "BOTTOMLEFT", "Below and left of the cursor" },
      { "TOPRIGHT", "Above and right of the cursor" },
      { "TOPLEFT", "Above and left of the cursor" },
    }, S("corner"), nil, "Which side of your cursor the tooltip sits on."),
    R:Selector("For", 300, { { "all", "Everything" }, { "world", "Only things in the world" } }, S("scope"), nil,
      "Only things in the world: units and objects follow your cursor; action bars and the like keep the game's spot."),
    R:Slider("Distance sideways", 0, 80, 1, S("offX"), px, nil, nil, 1),
    (R:Slider("Distance up / down", 0, 80, 1, S("offY"), px, nil, nil, 1)), -- (its row isn't one of them)
  }
  R:Section("My own spot")
  local move = R:Button("The spot", "Move the spot", 130, function() ns.Anchor.Unlock(not ns.Anchor.unlocked) end,
    "Drag the blue box where you want tooltips, then right-click it. The tooltip grows away from the nearest screen edge.")
  local reset = UI.Button(move:GetParent(), "Reset the spot", 130, function() ns.Anchor.ResetSpot() end)
  reset:SetPoint("LEFT", move, "RIGHT", 8, 0)
  local spot = { move, reset }
  local function apply()
    for _, c in ipairs(cursor) do c.SetActive(ns.db.anchor == "cursor") end
    for _, b in ipairs(spot) do b:SetEnabled(ns.db.anchor == "custom") end
  end
  after[1] = apply
  R:Track({ Refresh = apply })
end

local function PageLook(_, R)
  R:Section("Look")
  R:Selector("Style", 300, { { "addon", "JTT style" }, { "blizzard", "Blizzard's" } }, S("look"), Changed,
    "JTT style: a dark panel with a bronze border (FlareUI's when it's installed, EllesmereUI's panel when it is).")
  R:Check("Border colour", S("colorBorder"), Changed, "In the item's quality / the player's class colour.")
  R:Check("NPCs too", S("colorNPC"), Changed, "Red hostile, yellow neutral, green friendly (grey if tapped).", true)
  R:Slider("Size", 0.6, 1.6, 0.05, S("scale"), function(v) return math.floor(v * 100 + 0.5) .. "%" end, Changed)
end

local function PageShow(_, R)
  R:Section("Show")
  R:Check("Item ID and Spell ID", S("ids"), nil, "Spells, buffs and debuffs too.")
  R:Check("Item level on gear", S("itemLevel"))
  R:Check("Where gear comes from", S("sources"), function() ns.Sources.Hold() end, function()
    local t = "Quest rewards, drops, vendors, chests and professions, for your faction. From QuestieDB's WoW: Forever data (by the Questie team, GPLv3) and the game's own tables; with NeedRoll or Questie installed, what they know too.\n\nDrops are listed likeliest first (CMaNGOS Classic-DB's loot tables, GPLv3); the chances aren't shown, since WoW: Forever's may differ."
    if not ns.Sources.Available() then t = t .. "\n\n|cffff4d4dNeeds the \"Just the Tooltip!: Sources\" addon (it comes in the same download): turn it on in the AddOns list.|r" end
    return t
  end)
  R:Check("Who a unit is targeting", S("target"), nil, "\">> You <<\" when it's you.")
  R:Check("Health bar under unit tooltips", S("healthBar"), function() ns.Info.ApplyHealthBar() end)
  R:Check("NPC IDs on creatures", S("npcIds"))
  R:Check("How many you have", S("itemValue"), nil, "How many of an item you have, and what they sell for.")
  R:Section("Hiding")
  R:Check("Hide right away", S("instantHide"), nil, "When you stop hovering something (no fade).")
  R:Check("Hide in combat", S("combatHide"), nil, "In combat, tooltips for things in the world are hidden (hold Shift to see them).")
  R:Note("Lines from your other addons (Equip This!, Questie, What's Training...) still show: Just the Tooltip! changes the game's tooltip rather than replacing it.")
end

local function PageLines(p, R)
  R:Section("Where each line shows")
  local COLS = { { "main", "The game's", 0 }, { "ref", "Chat links", 100 }, { "compare", "Comparisons", 200 } }
  local hy = R:Space(18)
  for _, c in ipairs(COLS) do
    local h = UI.Note(p, c[2]); h:SetPoint("TOP", p, "TOPLEFT", R.ctrl + c[3] + 15, hy)
  end
  for _, l in ipairs({ { "itemId", "Item ID" }, { "spellId", "Spell ID" }, { "itemLevel", "Item level" }, { "sources", "Where gear comes from" } }) do
    local row = R:Row(l[2])
    for _, c in ipairs(COLS) do
      if not (l[1] == "spellId" and c[1] == "compare") then -- (comparisons are items)
        local b = R:Track(UI.Check(row, { function() return ns.ShowsOn(l[1], c[1]) end,
          function(v) ns.SetShowsOn(l[1], c[1], v) end }))
        b:SetPoint("LEFT", R.ctrl + c[3], 0)
      end
    end
  end
  R:Note("The game's: bags, bars, units, everything at your cursor or spot. Chat links: items and spells you click in chat. Comparisons: the tooltips beside an item that compare it with yours. A line turned off under Show is off everywhere.")

  R:Section("Order of the lines on items")
  local NAMES = { itemLevel = "Item level", sources = "Where gear comes from", itemId = "Item ID", itemValue = "How many you have" }
  local rows = {}
  local function refreshOrder()
    local o = ns.ItemOrder()
    for i, r in ipairs(rows) do
      r.key = o[i]
      r.row.label:SetText(i .. ".  " .. (NAMES[o[i]] or o[i]))
      r.up:SetEnabled(i > 1); r.down:SetEnabled(i < #o)
    end
  end
  for i = 1, #ns.ITEM_LINES do
    local r = { row = R:Row(NAMES[ns.ITEM_LINES[i]] or ns.ITEM_LINES[i]) }
    r.up = UI.Button(r.row, "Up", 60, function() if ns.MoveItemLine(r.key, -1) then refreshOrder() end end)
    r.up:SetPoint("LEFT", R.ctrl, 0)
    r.down = UI.Button(r.row, "Down", 60, function() if ns.MoveItemLine(r.key, 1) then refreshOrder() end end)
    r.down:SetPoint("LEFT", r.up, "RIGHT", 4, 0)
    rows[i] = r
  end
  R:Track({ Refresh = refreshOrder })

  R:Section("More detail")
  R:Selector("Show every detail", 300, { { "none", "Off" }, { "ALT", "While holding Alt" }, { "CTRL", "While holding Ctrl" } },
    S("detailKey"), nil, "Hold the key over a tooltip to see every detail.")
  R:Note("Held over a tooltip: every source (not only three), each tagged with where it was learned (JTT data, Questie, NeedRoll; \"Classic order\" for drops ordered by Classic 1.12 chances) and, out in the world, where in the zone; IDs (NPCs too), item level and how many you have even where they're off; and whether you know a spell.")
end

local function PageProfiles(_, R)
  R:Section("This character")
  local function current() return ns.ProfileName() end
  local function list()
    local t = { { "", "Shared (every character's)" } }
    for _, n in ipairs(ns.ProfileNames()) do t[#t + 1] = { n, n } end
    return t
  end
  -- (the options change as profiles come and go: a Selector over a live list)
  local options = list()
  local sel = R:Selector("Uses", 300, options, { function() return current() or "" end, function(v) ns.UseProfile(v ~= "" and v or nil) end }, nil,
    "Shared: the settings every character uses unless it picks a profile. Each profile is a whole set of settings of its own.")
  local newName = ""
  local edit, erow = R:Edit("New profile", 200, { function() return newName end, function(v) newName = v end }, "Its name",
    "A new profile starts as a copy of the settings in use, and this character uses it.")
  UI.Button(erow, "Create", 90, function()
    newName = edit:GetText() or newName
    if ns.NewProfile(newName) then newName = ""; edit:SetText("")
    else ns.Print("give the new profile a name that isn't taken.") end
  end):SetPoint("LEFT", edit, "RIGHT", 10, 0)
  local del = R:Button("Delete this profile", "Delete", 96, function()
    local n = current()
    if n then ns.DeleteProfile(n); ns.Print("profile \"" .. n .. "\" deleted; this character uses the shared settings.") end
  end, "This character goes back to the shared settings.")
  R:Track({ Refresh = function()
    wipe(options); for _, o in ipairs(list()) do options[#options + 1] = o end
    sel.Refresh(); del:SetEnabled(current() ~= nil)
  end })
end

local function PageStatus(_, R)
  R:Section("Commands")
  R:Note("/jtt info: each kind of information and its state.  /jtt compat: other addons.  /jtt lifecycle: the last tooltips.  /jtt api: the game functions used.  /jtt source <item>: where an item comes from.  /jtt report: the bug report.")
  R:Section("Reset")
  R:Button("Tooltip position", "Reset", 96, function()
    ns.db.anchor = "default"; ns.Anchor.ResetSpot(); window.Refresh(); ns.Print("tooltips are back at the game's spot.")
  end, "Tooltips back at the game's spot.")
end

local function BuildWindow()
  window = UI.Settings({ name = "JustTheTooltipOptionsWindow", title = "Just the Tooltip!",
    bug = function() ns.ShowBugReport() end,
    pages = {
      { "Position", "Where tooltips go: the game's spot, your cursor, or your own spot.", PagePosition },
      { "Look", "The tooltip's style, border colours and size.", PageLook },
      { "Show", "What's added to tooltips, and when they hide.", PageShow },
      { "Lines", "Where each line shows, their order on items, and more detail.", PageLines },
      { "Profiles", "Sets of settings per character.", PageProfiles },
      { "Status", "The commands, and putting tooltips back.", PageStatus },
    },
    categories = { { "Just the Tooltip!", { 1, 2, 3, 4, 5 } }, { "Help", { 6 } } } })
  ns.RefreshOptions = function() if window:IsShown() then window.Refresh() end end
  window:HookScript("OnHide", function() if ns.Anchor.unlocked then ns.Anchor.Unlock(false) end end)
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
  local off = {}
  for line, w in pairs(type(db.where) == "table" and db.where or {}) do
    for kind, v in pairs(type(w) == "table" and w or {}) do if v == false then off[#off + 1] = line .. "/" .. kind end end
  end
  table.sort(off)
  L[#L + 1] = format("profile: %s; item line order: %s; detail key: %s; lines turned off on: %s", ns.ProfileName() or "shared",
    table.concat(ns.ItemOrder(), ", "), tostring(db.detailKey), #off > 0 and table.concat(off, ", ") or "none")
  local srcOk = ns.Sources.Available()
  L[#L + 1] = format("sources addon: %s; FlareUI: %s; EllesmereUI: %s", srcOk and "installed" or "not installed",
    yes(type(FlareUI) == "table"), yes(UI.HasEllesmere()))
  for _, l in ipairs(ns.CompatLines()) do L[#L + 1] = l end
  for _, l in ipairs(ns.Facts.InfoLines()) do L[#L + 1] = l end
  L[#L + 1] = ns.Facts.ApiLines()[1]
  for _, l in ipairs(ns.Anchor.LifecycleLines(5)) do L[#L + 1] = "tooltip " .. l end
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

-- the settings window, built the first time it's asked for
local function GetWindow()
  if not window then
    local ok, e = pcall(BuildWindow)
    if not ok then if window then window:Hide() end; window = nil; ns.Print("settings failed: " .. tostring(e)); return end
  end
  return window
end
function ns.OpenOptions()
  local w = GetWindow()
  if w then UI.ToggleWindow(w) end
  return w
end
UI.JoinSuite("Just the Tooltip!", "The game's tooltip, where you want it.",
  "Interface\\AddOns\\JustTheTooltip\\media\\Logo", 6, GetWindow)
