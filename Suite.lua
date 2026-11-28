---------------------------------------------------------------------------
-- CalifaxOP's addons together (the same file in each): every installed one's settings window shows
-- all of them as icon tabs at its top left. Clicking another opens that addon's settings in the
-- same place. They find each other through one shared list (CalifaxOPAddons), which holds only
-- each addon's name, icon, tagline and how to get its settings window.
---------------------------------------------------------------------------
local _, ns = ...
local REG = type(_G.CalifaxOPAddons) == "table" and _G.CalifaxOPAddons or {}
_G.CalifaxOPAddons = REG
local Suite = {}
ns.Suite = Suite

local SIZE, GAP = 34, 6 -- the icon tabs

-- e: { key, name, tagline, icon, order, window = function() return the settings window (built if needed) end }
function Suite.Register(e)
  for i, x in ipairs(REG) do if x.key == e.key then REG[i] = e; return end end
  REG[#REG + 1] = e
end

-- puts window w where window at is (the same centre and scale)
function Suite.Place(w, at)
  local x, y = at:GetCenter()
  if not x then return end
  local s = at:GetEffectiveScale()
  w:SetScale(at:GetScale())
  local ws = w:GetEffectiveScale()
  w:ClearAllPoints(); w:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x * s / ws, y * s / ws)
end

-- the tab row on settings window w (key: its own addon's), at x, y from its top left; with the
-- addon's tagline after it. Refreshed every time w shows (another addon may have loaded since).
function Suite.Tabs(w, key, x, y)
  local tabs = {}
  local tagline = w:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  local function Tab(i)
    local b = CreateFrame("Button", nil, w)
    b:SetSize(SIZE, SIZE); b:SetPoint("TOPLEFT", x + (i - 1) * (SIZE + GAP), y)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints()
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    -- the selected one: a gold frame round it
    b.sel = {}
    for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", 0, 2 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, -2 },
      { "TOPLEFT", "BOTTOMLEFT", -2, 0 }, { "TOPRIGHT", "BOTTOMRIGHT", 2, 0 } }) do
      local t = b:CreateTexture(nil, "OVERLAY")
      t:SetColorTexture(1, 0.82, 0, 1)
      t:SetPoint(side[1], b, side[1], side[3], side[4]); t:SetPoint(side[2], b, side[2], side[3], side[4])
      if side[3] == 0 then t:SetHeight(2) else t:SetWidth(2) end
      b.sel[#b.sel + 1] = t
    end
    b:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT"); GameTooltip:SetText(self.entry.name, 1, 1, 1)
      GameTooltip:AddLine(self.entry.tagline, nil, nil, nil, true)
      if self.entry.key ~= key then GameTooltip:AddLine("Click for its settings.", 0.6, 0.6, 0.6) end
      GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self)
      if self.entry.key == key then return end
      local ok, other = pcall(self.entry.window)
      if not (ok and other) then return end
      Suite.Place(other, w)
      other:Show(); w:Hide()
    end)
    return b
  end
  local function refresh()
    local list = {}
    for _, e in ipairs(REG) do list[#list + 1] = e end
    table.sort(list, function(a, b) return (a.order or 99) < (b.order or 99) end)
    for i, e in ipairs(list) do
      tabs[i] = tabs[i] or Tab(i)
      local b, on = tabs[i], e.key == key
      b.entry = e
      b.icon:SetTexture(e.icon); b.icon:SetAlpha((on or #list == 1) and 1 or 0.75)
      for _, t in ipairs(b.sel) do t:SetShown(on and #list > 1) end
      b:Show()
      if on then tagline:SetText(e.tagline) end
    end
    for i = #list + 1, #tabs do tabs[i]:Hide() end
    tagline:ClearAllPoints()
    tagline:SetPoint("LEFT", w, "TOPLEFT", x + #list * (SIZE + GAP) + 6, y - SIZE / 2)
  end
  w:HookScript("OnShow", refresh)
  refresh()
end
