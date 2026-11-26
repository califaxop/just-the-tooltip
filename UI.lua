-- The look of this addon's settings, shared with our other addons: FlareUI's dialog background,
-- bronze border, heading font and colours when FlareUI is installed,
-- otherwise a dark panel with a thin brown border. Widgets are flat and drawn in that palette.
local _, ns = ...
local UI = {}
ns.UI = UI

local W = "Interface\\Buttons\\WHITE8X8"
local DIALOG_BG = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark"
local DIVIDER = "Interface\\Common\\UI-TooltipDivider-Transparent"

-- the first of these font objects that exists and is a readable size (another addon can shrink a
-- shared one: EllesmereUI's quest tracker sets the game's tracker fonts to 1 px)
local function FontObj(...)
  for i = 1, select("#", ...) do
    local f = _G[select(i, ...)]
    if f and f.GetFont then
      local ok, path, size = pcall(f.GetFont, f)
      if ok and type(path) == "string" and type(size) == "number" and size >= 8 then return f end
    end
  end
  return _G.GameFontHighlight
end

local PALETTES = {
  -- FlareUI: bronze headings, gold titles, light-grey text
  flare = { header = { 0.80, 0.60, 0.34 }, title = { 1, 0.82, 0 }, hover = { 1, 0.92, 0.55 },
    line = { 0.85, 0.85, 0.85 }, dim = { 0.50, 0.50, 0.50 }, accent = { 0.65, 0.49, 0.27 }, box = { 0.50, 0.38, 0.21 } },
  -- plain: Blizzard gold with a brown border
  plain = { header = { 1, 0.82, 0 }, title = { 1, 0.82, 0 }, hover = { 1, 0.92, 0.55 },
    line = { 0.82, 0.82, 0.82 }, dim = { 0.50, 0.50, 0.50 }, accent = { 0.45, 0.36, 0.24 }, box = { 0.40, 0.33, 0.22 } },
}

function UI.FlareBorder()
  local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("FlareUI"))
    or (IsAddOnLoaded and IsAddOnLoaded("FlareUI"))
  if not loaded then return nil end
  local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
  local path = LSM and LSM:Fetch("border", "FlareUI Frames", true)
  return path or "Interface/AddOns/FlareUI/Media/Borders/FlareUI-Frames.tga"
end

-- EllesmereUI style: EllesmereUI's own skinning API (EllesmereUI.RegisterSkin, see its SKINNING_API.md)
-- paints the window shell in the player's EllesmereUI theme; our widgets take its live accent colour,
-- panel colour and UI font. It hands us S once, at login, unless the player turned skinning off for us.
function UI.HasEllesmere() return type(EllesmereUI) == "table" and EllesmereUI.RegisterSkin ~= nil end
if UI.HasEllesmere() then
  EllesmereUI.RegisterSkin("JustTheTooltip", function(S)
    UI.euiSkin = S
    -- (ns.OnLooksChanged: the addon's own frames that follow the style, beyond its windows)
    local function again() UI.Restyle(); if ns.OnLooksChanged then pcall(ns.OnLooksChanged) end end
    if S.OnLooksChanged then S.OnLooksChanged(again) end
    again()
  end)
end
function UI.EUI()
  local S = UI.euiSkin
  -- (no setting: the window follows EllesmereUI whenever it's installed and skinning us)
  if S and (not S.IsEnabled or S.IsEnabled()) then return S end
end

-- the player's EllesmereUI font, as font objects (made once per font)
local euiFonts, euiN = {}, 0
local function EUIFont(S, size)
  local ok, path, flag = pcall(S.GetFont)
  if not (ok and type(path) == "string") then return nil end
  local key = path .. size .. tostring(flag)
  if not euiFonts[key] then
    euiN = euiN + 1
    local f = CreateFont("JustTheTooltipEUIFont" .. euiN)
    f:SetFont(path, size, flag or "")
    euiFonts[key] = f
  end
  return euiFonts[key]
end

function UI.Theme()
  local S = UI.EUI()
  local flare = not S and UI.FlareBorder() ~= nil -- FlareUI's look whenever it's installed
  local th = {}
  for k, v in pairs(flare and PALETTES.flare or PALETTES.plain) do th[k] = v end
  th.flare = flare
  th.headerFont = FontObj("ObjectiveTrackerHeaderFont", "GameFontNormalMed2", "GameFontNormal")
  th.lineFont = FontObj("ObjectiveTrackerLineFont", "ObjectiveFont", "GameFontHighlight")
  if S then
    -- EllesmereUI: white text, flat dark controls with thin grey borders, its accent for what's
    -- selected or checked
    local ok, r, g, b = pcall(S.GetAccentColor)
    local acc = ok and r and { r, g, b } or { 0.047, 0.824, 0.616 }
    th.eui = true
    th.header = { 1, 1, 1 }; th.title = { 1, 1, 1 }; th.hover = acc
    th.line = { 0.82, 0.82, 0.82 }; th.dim = { 0.55, 0.55, 0.55 }
    th.accent = acc; th.box = { 0.16, 0.16, 0.16 }; th.edge = { 0.28, 0.28, 0.28 }; th.mark = acc
    th.headerFont = EUIFont(S, 14) or th.headerFont
    th.lineFont = EUIFont(S, 12) or th.lineFont
  end
  th.edge = th.edge or th.accent  -- control borders
  th.mark = th.mark or th.title   -- the tick in a checkbox
  return th
end

---------------------------------------------------------------------------
-- Every widget registers a paint function, re-run when the style changes
---------------------------------------------------------------------------
local skins = {}
function UI.Skin(fn) skins[#skins + 1] = fn; fn(UI.Theme()) end
function UI.Restyle()
  local th = UI.Theme()
  for _, fn in ipairs(skins) do fn(th) end
end
local function RGB(c, a) return c[1], c[2], c[3], a or 1 end
UI.RGB = RGB

-- The plain style's border: the game's own tooltip border, tinted the bronze of the default
-- frames' borders (its artwork is light grey, so the tint is a little brighter than the colour seen)
UI.BLIZZ_EDGE = "Interface\\Tooltips\\UI-Tooltip-Border"
UI.BLIZZ_BG = "Interface\\Tooltips\\UI-Tooltip-Background"
UI.BRONZE = { 0.86, 0.66, 0.36 }
-- the window border colour for a theme
function UI.BorderColor(th)
  th = th or UI.Theme()
  return th.flare and th.accent or UI.BRONZE
end

local shelled = setmetatable({}, { __mode = "k" }) -- windows EllesmereUI has painted
function UI.SkinWindow(f, alpha)
  local th = UI.Theme()
  if th.eui then
    -- EllesmereUI paints the shell itself (once; it keeps it in step with the player's theme)
    if not shelled[f] then
      f:SetBackdrop(nil)
      local ok = pcall(UI.euiSkin.Shell, f)
      shelled[f] = ok
      if not ok then f:SetBackdrop({ bgFile = W }); f:SetBackdropColor(0.06, 0.06, 0.06, alpha) end
    end
    return
  end
  if th.flare then
    f:SetBackdrop({ bgFile = DIALOG_BG, edgeFile = UI.FlareBorder(), tile = false, tileSize = 0, edgeSize = 16,
      insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    f:SetBackdropColor(1, 1, 1, alpha)
  else
    f:SetBackdrop({ bgFile = UI.BLIZZ_BG, edgeFile = UI.BLIZZ_EDGE, tile = true, tileSize = 16, edgeSize = 16,
      insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    f:SetBackdropColor(0.03, 0.03, 0.03, alpha)
  end
  f:SetBackdropBorderColor(RGB(UI.BorderColor(th)))
end

---------------------------------------------------------------------------
-- Text and sections
---------------------------------------------------------------------------
-- roles: "title", "header", "line", "value", "note". The font is set before any text:
-- WoW refuses SetText on a font string with no font.
function UI.Text(parent, role, str)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetJustifyH("LEFT")
  UI.Skin(function(th)
    if role == "header" then fs:SetFontObject(th.headerFont); fs:SetTextColor(RGB(th.header))
    elseif role == "title" then fs:SetFontObject(th.headerFont); fs:SetTextColor(RGB(th.title))
    elseif role == "value" then fs:SetFontObject(th.lineFont); fs:SetTextColor(RGB(th.title))
    elseif role == "note" then fs:SetFontObject("GameFontHighlightSmall"); fs:SetTextColor(RGB(th.dim))
    else fs:SetFontObject(th.lineFont); fs:SetTextColor(RGB(th.line)) end
  end)
  fs:SetText(str or "")
  return fs
end

-- a heading with a divider under it, as one frame (28 px tall) that can be moved
function UI.Section(parent, str, width)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 28)
  f.text = UI.Text(f, "header", str)
  f.text:SetPoint("TOPLEFT", 0, 0)
  local div = f:CreateTexture(nil, "ARTWORK")
  div:SetPoint("TOPLEFT", 0, -18); div:SetWidth(width)
  UI.Skin(function(th)
    if th.flare then div:SetTexture(DIVIDER); div:SetVertexColor(1, 1, 1, 1); div:SetHeight(8)
    elseif th.eui then div:SetColorTexture(RGB(th.edge, 1)); div:SetHeight(1)
    else div:SetColorTexture(RGB(th.accent, 0.7)); div:SetHeight(1) end
  end)
  return f
end

---------------------------------------------------------------------------
-- Widgets. Values are read and written through a { get, set } pair.
---------------------------------------------------------------------------
function UI.Check(parent, label, opt, width, onChange)
  local get, set = opt[1], opt[2]
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or 200, 20)
  local box = CreateFrame("Frame", nil, b, "BackdropTemplate")
  box:SetSize(14, 14); box:SetPoint("LEFT", 0, 0)
  box:SetBackdrop({ bgFile = W, edgeFile = W, edgeSize = 1 })
  local mark = box:CreateTexture(nil, "OVERLAY")
  mark:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  mark:SetSize(20, 20); mark:SetPoint("CENTER", 1, 1)
  local text = UI.Text(b, "line", label)
  text:SetPoint("LEFT", box, "RIGHT", 7, 0); text:SetPoint("RIGHT", 0, 0); text:SetWordWrap(false)
  local active, hover = true, false
  local function paint(th)
    th = th or UI.Theme()
    box:SetBackdropColor(0, 0, 0, 0.55)
    box:SetBackdropBorderColor(RGB((hover and active) and th.accent or th.edge, hover and active and 1 or 0.8))
    mark:SetVertexColor(RGB(th.mark))
    text:SetTextColor(RGB((hover and active) and th.hover or th.line))
  end
  UI.Skin(paint)
  b:SetScript("OnEnter", function() hover = true; paint() end)
  b:SetScript("OnLeave", function() hover = false; paint() end)
  b:SetScript("OnClick", function()
    if not active then return end
    set(not get()); b.Refresh()
    if onChange then onChange() end
  end)
  b.Refresh = function() mark:SetShown(get() and true or false); paint() end
  b.SetActive = function(on) active = on; b:SetAlpha(on and 1 or 0.4); paint() end
  return b
end

-- slider: name above on the left, value above on the right, thin track and gold handle.
-- factor (optional): adds a box to type an exact value (typed number = value * factor, e.g. 100 for %);
-- Enter applies it (kept within range), Esc cancels.
function UI.Slider(parent, label, width, minV, maxV, step, opt, fmt, onChange, factor)
  local get, set = opt[1], opt[2]
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 34)
  local sw = factor and (width - 56) or width
  local name = UI.Text(f, "line", label); name:SetPoint("TOPLEFT", 0, 0)
  local value = UI.Text(f, "value", ""); value:SetPoint("TOPRIGHT", f, "TOPLEFT", sw, 0); value:SetJustifyH("RIGHT")
  local s = CreateFrame("Slider", nil, f)
  s:SetPoint("TOPLEFT", 0, -18); s:SetSize(sw, 14)
  s:SetOrientation("HORIZONTAL")
  s:SetMinMaxValues(minV, maxV); s:SetValueStep(step); s:SetObeyStepOnDrag(true)
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetTexture(W); track:SetHeight(4); track:SetPoint("LEFT"); track:SetPoint("RIGHT")
  local fill = s:CreateTexture(nil, "ARTWORK")
  fill:SetTexture(W); fill:SetHeight(4); fill:SetPoint("LEFT")
  local thumb = s:CreateTexture(nil, "OVERLAY")
  thumb:SetTexture(W); thumb:SetSize(7, 14)
  s:SetThumbTexture(thumb)
  local function paintFill(v)
    local p = (maxV > minV) and (v - minV) / (maxV - minV) or 0
    fill:SetWidth(math.max(1, p * sw))
  end
  UI.Skin(function(th)
    track:SetVertexColor(RGB(th.box, 0.35)); fill:SetVertexColor(RGB(th.accent, 0.9)); thumb:SetVertexColor(RGB(th.title))
  end)
  local box
  local function apply(v)
    v = math.max(minV, math.min(maxV, v))
    v = math.floor(v / step + 0.5) * step
    if get() ~= v then set(v); if onChange then onChange() end end
    f.Refresh()
  end
  s:EnableMouseWheel(true)
  s:SetScript("OnMouseWheel", function(self, d) apply((get() or minV) + d * step) end)
  local refreshing = false
  s:SetScript("OnValueChanged", function(_, v)
    v = math.floor(v / step + 0.5) * step
    value:SetText(fmt(v)); paintFill(v)
    if box and not box:HasFocus() then box:SetText(tostring(math.floor(v * factor + 0.5))) end
    if refreshing or get() == v then return end
    set(v)
    if onChange then onChange() end
  end)
  if factor then
    box = UI.Edit(f, 46, { function() return math.floor((get() or 0) * factor + 0.5) end,
      function(t) local n = tonumber(t); if n then apply(n / factor) end end }, "", false, true)
    box:SetPoint("LEFT", s, "RIGHT", 10, 0)
  end
  f.Refresh = function()
    refreshing = true
    s:SetValue(get()); value:SetText(fmt(get())); paintFill(get())
    refreshing = false
    if box then box.Refresh() end
  end
  return f
end

-- flat bronze button
function UI.Button(parent, label, width, onClick)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(width, 22)
  b:SetBackdrop({ bgFile = W, edgeFile = W, edgeSize = 1 })
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  local fs = UI.Text(b, "line", label)
  fs:SetPoint("LEFT", 4, 0); fs:SetPoint("RIGHT", -4, 0); fs:SetJustifyH("CENTER"); fs:SetWordWrap(false)
  local hover, active = false, true
  local function paint(th)
    th = th or UI.Theme()
    if th.eui then -- flat dark, a subtle lift on hover
      b:SetBackdropColor(RGB(th.box, (hover and active) and 1 or 0.85))
      b:SetBackdropBorderColor(RGB((hover and active) and th.accent or th.edge, 1))
    else
      b:SetBackdropColor(RGB(th.box, (hover and active) and 0.55 or 0.3))
      b:SetBackdropBorderColor(RGB(th.accent, (hover and active) and 1 or 0.8))
    end
    fs:SetTextColor(RGB((hover and active) and th.hover or th.title))
  end
  UI.Skin(paint)
  b:SetScript("OnEnter", function(self)
    hover = true; paint()
    if self.tip then GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(self.tip, 1, 1, 1, 1, true); GameTooltip:Show() end
  end)
  b:SetScript("OnLeave", function() hover = false; paint(); GameTooltip:Hide() end)
  b:SetScript("OnClick", function(self, mouse) if active and onClick then onClick(self, mouse) end end)
  b.SetLabel = function(t) fs:SetText(t) end
  b.SetActive = function(on) active = on; b:SetAlpha(on and 1 or 0.4); paint() end
  return b
end

-- a button that cycles through options { value, label }: click for next, right-click for previous
function UI.Toggle(parent, width, options, opt, onChange, tip)
  local get, set = opt[1], opt[2]
  local b
  b = UI.Button(parent, "", width, function(_, mouse)
    local i = 1
    for k, o in ipairs(options) do if o[1] == get() then i = k end end
    i = (i - 1 + (mouse == "RightButton" and -1 or 1)) % #options + 1
    set(options[i][1]); b.Refresh()
    if onChange then onChange() end
  end)
  b.tip = tip
  b.Refresh = function()
    for _, o in ipairs(options) do if o[1] == get() then b.SetLabel(o[2]) end end
  end
  return b
end

-- "<  value  >": a choice that clearly looks adjustable (arrows either side of a Toggle)
function UI.Selector(parent, width, options, opt, onChange, tip)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 22)
  local mid = UI.Toggle(f, width - 56, options, opt, onChange, tip)
  mid:SetPoint("LEFT", 28, 0)
  local function stepBy(d)
    local get, set = opt[1], opt[2]
    local i = 1
    for k, o in ipairs(options) do if o[1] == get() then i = k end end
    i = (i - 1 + d) % #options + 1
    set(options[i][1]); mid.Refresh()
    if onChange then onChange() end
  end
  local prev = UI.Button(f, "<", 24, function() stepBy(-1) end); prev:SetPoint("LEFT", 0, 0)
  local nxt = UI.Button(f, ">", 24, function() stepBy(1) end); nxt:SetPoint("RIGHT", 0, 0)
  f.Refresh = mid.Refresh
  return f
end

-- text box; commit(text) on Enter or leaving it; Esc reverts. spells = accept spells dragged in.
function UI.Edit(parent, width, opt, placeholder, spells, numeric)
  local get, set = opt[1], opt[2]
  local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
  e:SetSize(width, 20); e:SetAutoFocus(false); e:SetTextInsets(6, 6, 0, 0)
  e:SetBackdrop({ bgFile = W, edgeFile = W, edgeSize = 1 })
  if numeric then e:SetJustifyH("CENTER") end
  local ph = UI.Text(e, "note", placeholder or "")
  ph:SetPoint("LEFT", 6, 0); ph:SetPoint("RIGHT", -6, 0); ph:SetWordWrap(false)
  local function paint(th)
    th = th or UI.Theme()
    e:SetFontObject(th.lineFont); e:SetTextColor(RGB(th.title))
    e:SetBackdropColor(0, 0, 0, 0.55)
    e:SetBackdropBorderColor(RGB(e:HasFocus() and (th.eui and th.accent or th.title) or th.edge, e:HasFocus() and 0.9 or 0.7))
  end
  UI.Skin(paint)
  local function showPh() ph:SetShown((e:GetText() or "") == "" and not e:HasFocus()) end
  local reverting = false
  local function commit()
    if reverting then reverting = false; return end
    set(strtrim(e:GetText() or ""))
  end
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  e:SetScript("OnEditFocusLost", function() commit(); paint(); e.Refresh() end)
  e:SetScript("OnEditFocusGained", function() paint(); showPh() end)
  e:SetScript("OnEscapePressed", function(self) reverting = true; self:ClearFocus() end)
  e:SetScript("OnTextChanged", showPh)
  if spells then
    local function drop(self)
      local kind, _, b2, spellID = GetCursorInfo()
      local n = (kind == "spell") and ns.SpellName(spellID or b2)
      if n then ClearCursor(); self:SetText(n); set(n); self:ClearFocus(); e.Refresh() end
    end
    e:SetScript("OnReceiveDrag", drop)
    e:HookScript("OnMouseDown", function(self) if GetCursorInfo() then drop(self) end end)
  end
  e.Refresh = function()
    if not e:HasFocus() then e:SetText(tostring(get() or "")) end
    showPh()
  end
  return e
end

function UI.Window(name, width, height)
  local win = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
  win:SetSize(width, height)
  win:SetFrameStrata("DIALOG")
  win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
  win:SetScript("OnDragStart", win.StartMoving)
  win:SetScript("OnDragStop", win.StopMovingOrSizing)
  win:SetClampedToScreen(true)
  tinsert(UISpecialFrames, name) -- Esc closes it
  UI.Skin(function() UI.SkinWindow(win, 0.96) end)
  -- "×" close button
  local c = CreateFrame("Button", nil, win)
  c:SetSize(22, 22); c:SetPoint("TOPRIGHT", -8, -8)
  local fs = c:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  fs:SetPoint("CENTER"); fs:SetText("\195\151")
  local hover = false
  local function paint(th) th = th or UI.Theme(); fs:SetTextColor(RGB(hover and th.hover or th.header)) end
  UI.Skin(paint)
  c:SetScript("OnEnter", function() hover = true; paint() end)
  c:SetScript("OnLeave", function() hover = false; paint() end)
  c:SetScript("OnClick", function() win:Hide() end)
  return win
end

-- A pop-up (a prompt, a Yes/No box, a link to copy): solid, not see-through, and held in the
-- middle of the window it came from (UI.host), which is dimmed and can't be clicked behind it.
local popups = {}
function UI.Popup(name, width, height)
  local win = UI.Window(name, width, height)
  win:SetFrameStrata("FULLSCREEN_DIALOG")
  win:SetMovable(false); win:SetScript("OnDragStart", nil); win:SetScript("OnDragStop", nil)
  local solid = win:CreateTexture(nil, "BACKGROUND", nil, -8)
  solid:SetPoint("TOPLEFT", 3, -3); solid:SetPoint("BOTTOMRIGHT", -3, 3)
  UI.Skin(function(th) -- solid, in EllesmereUI's panel colour when it's installed
    local ok, r, g, b = false
    if th.eui and UI.euiSkin and UI.euiSkin.GetPanelColor then ok, r, g, b = pcall(UI.euiSkin.GetPanelColor) end
    if ok and r then solid:SetColorTexture(r, g, b, 1) else solid:SetColorTexture(0.04, 0.035, 0.03, 1) end
  end)
  win.shade = CreateFrame("Frame", nil, win)
  win.shade:EnableMouse(true) -- clicks on the window behind go nowhere while this is open
  local dim = win.shade:CreateTexture(nil, "BACKGROUND")
  dim:SetAllPoints(); dim:SetColorTexture(0, 0, 0, 0.55)
  -- placed every time it opens (a new frame starts out shown, so it's hidden below until asked for)
  function win.Place(self)
    self = self or win
    local host = UI.host
    self:ClearAllPoints()
    if host and host:IsShown() then
      self:SetScale(host:GetScale())
      self:SetPoint("CENTER", host, "CENTER", 0, 40)
      self.shade:ClearAllPoints(); self.shade:SetAllPoints(host); self.shade:Show()
    else
      self:SetScale(1)
      self:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
      self.shade:Hide()
    end
    self.shade:SetFrameLevel(math.max(0, self:GetFrameLevel() - 1))
  end
  win:HookScript("OnShow", win.Place)
  win:Hide()
  popups[#popups + 1] = win
  return win
end
-- the window pop-ups belong to; they close with it
function UI.SetHost(host)
  UI.host = host
  host:HookScript("OnHide", function() for _, p in ipairs(popups) do p:Hide() end end)
end

-- A small window with a link, selected and ready to copy (addons can't open a browser).
function UI.ShowLink(name, title, url)
  local win = _G[name]
  if not win then
    win = UI.Popup(name, 400, 118)
    win.title = UI.Text(win, "title", "")
    win.title:SetPoint("TOPLEFT", 20, -18)
    local note = UI.Text(win, "note", "Press Ctrl+C to copy, then paste it into your browser.")
    note:SetPoint("TOPLEFT", 20, -44)
    win.edit = UI.Edit(win, 360, { function() return win.url end, function() end })
    win.edit:SetPoint("TOPLEFT", 20, -66)
    -- keep the link intact if someone types in the box
    win.edit:HookScript("OnTextChanged", function(self, user)
      if user and self:GetText() ~= win.url then self:SetText(win.url); self:HighlightText() end
    end)
    win.edit:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
    win.edit:HookScript("OnEscapePressed", function() win:Hide() end)
  end
  win.url = url
  win.title:SetText(title)
  win.edit:SetText(url)
  win:Place(); win:Show()
  win.edit:SetFocus()
  win.edit:HighlightText()
end
