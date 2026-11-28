---------------------------------------------------------------------------
-- Settings windows in the game's own Settings design (shared by CalifaxOP's addons; Hereabouts 2.1.0
-- first). The same whatever UI is installed: FlareUI and EllesmereUI style the addon's own frames in
-- the world, never these windows.
-- Every Blizzard part here was seen working in WoW: Forever (Hereabouts 2.1.0's test builds): the
-- settings frame (SettingsFrameTemplate) and its art, the minimal checkbox, the slider with steppers,
-- the red buttons, the scroll frame, the search box. Source: Classic Era 1.15.9's Blizzard_SharedXML
-- and Blizzard_Settings_Shared.
---------------------------------------------------------------------------
local _, ns = ...
local UI = ns.UI

-- a template's child frame or region (its parentKey), only if it's really there
local function Part(f, key) local v = f and rawget(f, key); if type(v) == "table" or type(v) == "userdata" then return v end end

function UI.Font(parent, font, str)
  local fs = parent:CreateFontString(nil, "OVERLAY", font)
  fs:SetJustifyH("LEFT"); fs:SetText(str or "")
  return fs
end
-- a small grey note
function UI.Note(parent, str, width)
  local n = UI.Font(parent, "GameFontHighlightSmall", str)
  n:SetTextColor(0.7, 0.7, 0.7)
  if width then n:SetWidth(width) end
  return n
end

-- the settings page's divider line, across a frame at y
function UI.Divider(parent, y, left, right)
  local d = parent:CreateTexture(nil, "ARTWORK")
  d:SetAtlas("Options_HorizontalDivider"); d:SetHeight(2)
  d:SetPoint("TOPLEFT", left or 0, y); d:SetPoint("TOPRIGHT", -(right or 0), y)
  return d
end

---------------------------------------------------------------------------
-- Controls. Values are read and written through a { get, set } pair; each has .Refresh() and
-- .SetActive(on) (greyed out and unclickable when off).
---------------------------------------------------------------------------
-- the game's red button. b.tip: a tooltip. Right clicks reach onClick(self, mouse) too.
function UI.Button(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width, 22); b:SetText(text)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  b:SetScript("OnClick", function(self, mouse) if onClick then onClick(self, mouse) end end)
  b:SetScript("OnEnter", function(self)
    if self.tip then GameTooltip:SetOwner(self, "ANCHOR_TOP"); GameTooltip:SetText(self.tip, 1, 1, 1, 1, true); GameTooltip:Show() end
  end)
  b:SetScript("OnLeave", function(self) if self.tip then GameTooltip:Hide() end end)
  b.SetActive = function(on) b:SetEnabled(on) end
  return b
end

-- the settings' checkbox (SettingsCheckboxTemplate's art; the template itself needs Blizzard's
-- settings code behind it)
function UI.Check(parent, opt, onChange)
  local get, set = opt[1], opt[2]
  local b = CreateFrame("CheckButton", nil, parent)
  b:SetSize(30, 29)
  local function tex(a) local t = b:CreateTexture(); t:SetAtlas(a, true); t:SetPoint("CENTER"); return t end
  b:SetNormalTexture(tex("checkbox-minimal")); b:SetPushedTexture(tex("checkbox-minimal"))
  b:SetCheckedTexture(tex("checkmark-minimal")); b:SetDisabledCheckedTexture(tex("checkmark-minimal-disabled"))
  b:SetScript("OnClick", function(self)
    set(self:GetChecked() and true or false)
    if onChange then onChange() end
  end)
  b.Refresh = function() b:SetChecked(get() and true or false) end
  b.SetActive = function(on) b:SetEnabled(on); b:SetAlpha(on and 1 or 0.5) end
  return b
end

-- the slider with steppers (< and >), its value to the right. factor (optional): a box after it to
-- type an exact value (typed number = value * factor, e.g. 100 for %); Enter applies it.
function UI.Slider(parent, width, minV, maxV, step, opt, fmt, onChange, factor)
  local get, set = opt[1], opt[2]
  local M = MinimalSliderWithSteppersMixin
  local s = CreateFrame("Frame", nil, parent, "MinimalSliderWithSteppersTemplate")
  s:SetWidth(width or 250)
  local refreshing, box = false, nil
  local function snap(v) return math.floor(v / step + 0.5) * step end
  s:Init(get() or minV, minV, maxV, math.max(1, math.floor((maxV - minV) / step + 0.5)), { [M.Label.Right] = function(v) return fmt(snap(v)) end })
  s:RegisterCallback(M.Event.OnValueChanged, function(_, v)
    v = snap(v)
    if box and not box:HasFocus() then box:SetText(tostring(math.floor(v * factor + 0.5))) end
    if refreshing or get() == v then return end
    set(v)
    if onChange then onChange() end
  end, s)
  s.Refresh = function()
    refreshing = true
    s:SetValue(get()); s:FormatValue(get())
    refreshing = false
    if box then box.Refresh() end
  end
  if factor then
    box = UI.Edit(s, 46, { function() return math.floor((get() or 0) * factor + 0.5) end, function(t)
      local n = tonumber(t)
      if not n then return end
      local v = snap(math.max(minV, math.min(maxV, n / factor)))
      if get() ~= v then set(v); if onChange then onChange() end end
      s.Refresh()
    end }, "", false, true)
    box:SetPoint("LEFT", s, "RIGHT", 58, 0)
  end
  s.SetActive = function(on) s:SetEnabled(on); if box then box:SetEnabled(on) end end
  return s
end

-- a choice of options { value, label } on a red button: click for the next, right-click for the previous
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
  b.Refresh = function() for _, o in ipairs(options) do if o[1] == get() then b:SetText(o[2]) end end end
  return b
end

-- "<  value  >": the game's page arrows either side of a Toggle
function UI.Selector(parent, width, options, opt, onChange, tip)
  local f = CreateFrame("Frame", nil, parent)
  f:SetSize(width, 24)
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
  local function arrow(dir, d)
    local a = CreateFrame("Button", nil, f)
    a:SetSize(24, 24)
    a:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. dir .. "Page-Up")
    a:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. dir .. "Page-Down")
    a:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. dir .. "Page-Disabled")
    a:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
    a:SetScript("OnClick", function() stepBy(d) end)
    return a
  end
  local prev, nxt = arrow("Prev", -1), arrow("Next", 1)
  prev:SetPoint("LEFT", 0, 0); nxt:SetPoint("RIGHT", 0, 0)
  f.Refresh = mid.Refresh
  f.SetActive = function(on) mid:SetEnabled(on); prev:SetEnabled(on); nxt:SetEnabled(on) end
  return f
end

-- the game's text box; set(text) on Enter or leaving it; Esc reverts. spells: accept spells dragged
-- in ("items": items from your bags too). numeric: centred.
function UI.Edit(parent, width, opt, placeholder, spells, numeric)
  local get, set = opt[1], opt[2]
  local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
  e:SetSize(width, 20); e:SetAutoFocus(false)
  e:SetFontObject("GameFontHighlight")
  if numeric then e:SetJustifyH("CENTER") end
  local ph = UI.Font(e, "GameFontDisable", placeholder or "")
  ph:SetPoint("LEFT", 2, 0); ph:SetPoint("RIGHT", -2, 0); ph:SetWordWrap(false)
  local function showPh() ph:SetShown((e:GetText() or "") == "" and not e:HasFocus()) end
  local reverting = false
  e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  e:SetScript("OnEditFocusLost", function()
    if reverting then reverting = false else set(strtrim(e:GetText() or "")) end
    e.Refresh()
  end)
  e:SetScript("OnEditFocusGained", showPh)
  e:SetScript("OnEscapePressed", function(self) reverting = true; self:ClearFocus() end)
  e:SetScript("OnTextChanged", showPh)
  if spells then
    local function drop(self)
      local kind, b1, b2, spellID = GetCursorInfo()
      local n = (kind == "spell" and ns.SpellName and ns.SpellName(spellID or b2))
        or (spells == "items" and kind == "item" and ns.ItemName and ns.ItemName(b1)) -- (an item from your bags)
      if n then ClearCursor(); self:SetText(n); set(n); self:ClearFocus(); e.Refresh() end
    end
    e:SetScript("OnReceiveDrag", drop)
    e:HookScript("OnMouseDown", function(self) if GetCursorInfo() then drop(self) end end)
  end
  e.Refresh = function()
    if not e:HasFocus() then e:SetText(tostring(get() or "")) end
    showPh()
  end
  e.SetActive = function(on) e:SetEnabled(on); e:SetAlpha(on and 1 or 0.5) end
  return e
end

-- a colour square: click for the game's colour picker (Cancel puts the old colour back).
-- color(): the { r, g, b } table to change; onChange after each change.
function UI.Swatch(parent, color, onChange)
  local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
  b:SetSize(20, 20)
  b:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
  b:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  b.Refresh = function() local c = color(); if c then b:SetBackdropColor(c[1], c[2], c[3], 1) end end
  b:SetScript("OnClick", function()
    local c = color()
    local r, g, bl = c[1], c[2], c[3]
    local function apply()
      c[1], c[2], c[3] = ColorPickerFrame:GetColorRGB()
      b.Refresh(); onChange()
    end
    local function cancel() c[1], c[2], c[3] = r, g, bl; b.Refresh(); onChange() end
    if ColorPickerFrame.SetupColorPickerAndShow then
      ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = bl, hasOpacity = false, swatchFunc = apply, cancelFunc = cancel })
    else
      ColorPickerFrame.func, ColorPickerFrame.cancelFunc = apply, cancel
      ColorPickerFrame.hasOpacity, ColorPickerFrame.previousValues = false, { r = r, g = g, b = bl }
      ColorPickerFrame:SetColorRGB(r, g, bl); ColorPickerFrame:Show()
    end
  end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText("Click to change the colour", 1, 1, 1); GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

---------------------------------------------------------------------------
-- Windows
---------------------------------------------------------------------------
-- a window: Blizzard's settings frame (its title bar, close button and background)
function UI.Window(name, width, height, title)
  local f = CreateFrame("Frame", name, UIParent, "SettingsFrameTemplate")
  f:SetSize(width, height)
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  -- the one opened or clicked last comes to the front, whole (never interleaved with another)
  f:SetToplevel(true)
  f:HookScript("OnShow", function(self) self:Raise() end)
  tinsert(UISpecialFrames, name) -- Esc closes it
  f.SetTitle = function(_, t) local text = Part(Part(f, "NineSlice"), "Text"); if text then text:SetText(t) end end
  f:SetTitle(title or "")
  return f
end

-- A pop-up (a prompt, a Yes/No box, a link to copy): held in the middle of the window it came from
-- (UI.host), which is dimmed and can't be clicked behind it.
local popups = {}
function UI.Popup(name, width, height, title)
  local win = UI.Window(name, width, height, title)
  win:SetFrameStrata("FULLSCREEN_DIALOG")
  win:SetMovable(false); win:SetScript("OnDragStart", nil); win:SetScript("OnDragStop", nil)
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
    self:Raise() -- (the newest pop-up on top of any other)
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

-- The bug report window (like Questie's trace export): the form's link to copy at the top, what to
-- do, the report line to copy, what's in it (counters), what's included. Addons can't open a
-- browser: both are boxes, selected and ready for Ctrl+C.
-- cfg: { name, title, repo (".../issues/new"), version, included,
--        build = function() return line, { { icon, label, value }, ... up to 6 } end }
-- kind: "bug" (default) or "idea" (the ideas form's link; no line needed)
local BUG_NOTE = "Found a bug? Open the link above in your browser (needs a GitHub account), say what happened and paste the line below into \"Debug output\" "
  .. "(open this window again for each report). Feedback or a feature request? Click \"Feedback / feature request\" below."
local IDEA_NOTE = "Feedback, an idea or a feature you'd like? Open the link above in your browser (needs a GitHub account) and tell us. The line below isn't needed for this."
local function CopyBox(win, key)
  local e = UI.Edit(win, 540, { function() return win[key] or "" end, function() end })
  e:SetMaxLetters(0)
  e:HookScript("OnTextChanged", function(self, user) if user and self:GetText() ~= win[key] then self:SetText(win[key] or ""); self:HighlightText() end end)
  e:HookScript("OnEditFocusGained", function(self) self:HighlightText() end)
  e:HookScript("OnEscapePressed", function() win:Hide() end)
  return e
end
local reportWindows = {}
function UI.ShowBugReport(cfg, kind)
  local w = reportWindows[cfg.name]
  if not w then
    w = UI.Popup(cfg.name, 600, 356, cfg.title)
    reportWindows[cfg.name] = w
    w.urlBox = CopyBox(w, "url")
    w.urlBox:SetPoint("TOP", 0, -42)
    w.note = UI.Font(w, "GameFontHighlightSmall")
    w.note:SetPoint("TOP", 0, -72); w.note:SetWidth(540); w.note:SetJustifyH("CENTER")
    w.lineBox = CopyBox(w, "line")
    w.lineBox:SetPoint("TOP", 0, -132)
    UI.Divider(w, -162, 30, 30)
    w.stats = {}
    for i = 1, 6 do
      local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
      local icon = w:CreateTexture(nil, "ARTWORK")
      icon:SetSize(18, 18)
      icon:SetPoint("TOPLEFT", 40 + col * 290, -174 - row * 24)
      local t = UI.Font(w, "GameFontNormal")
      t:SetPoint("LEFT", icon, "RIGHT", 8, 0)
      t:SetWidth(255); t:SetWordWrap(false) -- (cut short, never into the next column)
      w.stats[i] = { icon = icon, text = t }
    end
    w.inc = UI.Font(w, "GameFontHighlightSmall")
    w.inc:SetPoint("TOP", 0, -252); w.inc:SetWidth(540); w.inc:SetJustifyH("CENTER")
    w.kindBtn = UI.Button(w, "", 190, function() UI.ShowBugReport(w.cfg, w.kind == "bug" and "idea" or "bug") end)
    w.kindBtn:SetPoint("BOTTOMLEFT", 18, 16)
    local close = UI.Button(w, CLOSE or "Close", 110, function() w:Hide() end)
    close:SetPoint("BOTTOMRIGHT", -16, 16)
  end
  w.cfg, w.kind = cfg, kind == "idea" and "idea" or "bug"
  local ok, line, stats = pcall(cfg.build)
  if not ok then line, stats = "(the report failed: " .. tostring(line) .. ")", {} end
  w.line = tostring(line):gsub("|", "||") -- (a | as typed, not the start of a colour code)
  w.url = cfg.repo .. (w.kind == "idea" and "?template=feature_request.yml"
    or ("?template=bug_report.yml" .. (cfg.version and ("&version=" .. cfg.version) or "")))
  w.urlBox:SetText(w.url); w.urlBox:SetCursorPosition(0)
  w.lineBox:SetText(w.line)
  w.note:SetText(w.kind == "bug" and BUG_NOTE or IDEA_NOTE)
  w.inc:SetText(cfg.included or "")
  for i, st in ipairs(w.stats) do
    local v = stats and stats[i]
    st.icon:SetShown(v ~= nil); st.text:SetShown(v ~= nil)
    if v then st.icon:SetTexture(v[1]); st.text:SetText(v[2] .. ": |cffffffff" .. tostring(v[3]) .. "|r") end
  end
  w.kindBtn:SetText(w.kind == "bug" and "Feedback / feature request" or "Report a bug instead")
  w:Place(); w:Show(); w:Raise()
  local focus = w.kind == "bug" and w.lineBox or w.urlBox
  focus:SetFocus(); focus:HighlightText()
  return w
end

---------------------------------------------------------------------------
-- A page's rows: white section headings, then a gold name on the left and its control on the right.
-- R = UI.Rows(parent, opts): opts.width (the page's), opts.label (x of names), opts.control (x of
-- controls), opts.index (the search index to add to, with opts.page).
-- Every control made through R is in R.items (refreshed together).
---------------------------------------------------------------------------
local ROW = 30
function UI.Rows(p, opts)
  opts = opts or {}
  local WIDTH, LABEL_X, CTRL_X = opts.width or 640, opts.label or 37, opts.control or 250
  local R = { y = opts.y or 0, n = 0, items = {}, ctrl = CTRL_X }
  local function Index(label, frame, y)
    if opts.index and type(label) == "string" and label ~= "" then
      opts.index[#opts.index + 1] = { label = label, page = opts.page, frame = frame, y = y }
    end
  end
  function R.Track(_, x) R.items[#R.items + 1] = x; return x end
  function R.Section(_, title)
    R.y = R.y - (R.n > 0 and 8 or 0)
    local t = UI.Font(p, "GameFontHighlightLarge", title)
    t:SetPoint("TOPLEFT", 7, R.y - 10)
    Index(title, t, R.y)
    R.y = R.y - 36
    return t
  end
  -- a row with its name (and a tooltip on hover); returns the row frame
  function R.Row(_, label, tip, indent, height)
    local row = CreateFrame("Frame", nil, p)
    row:SetPoint("TOPLEFT", 0, R.y); row:SetSize(WIDTH, height or ROW)
    local l = UI.Font(row, "GameFontNormal", label)
    l:SetPoint("LEFT", LABEL_X + (indent and 20 or 0), 0); l:SetPoint("RIGHT", row, "LEFT", CTRL_X - 10, 0)
    l:SetWordWrap(true); l:SetMaxLines(2)
    row.label = l
    local hover = row:CreateTexture(nil, "BACKGROUND")
    hover:SetAllPoints(); hover:SetColorTexture(1, 1, 1, 0.05); hover:Hide()
    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
      hover:Show()
      local t = type(tip) == "function" and tip() or tip
      if t then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(l:GetText() or "", 1, 1, 1)
        GameTooltip:AddLine(t, nil, nil, nil, true); GameTooltip:Show()
      end
    end)
    row:SetScript("OnLeave", function() hover:Hide(); GameTooltip:Hide() end)
    Index(label, row, R.y)
    R.y, R.n = R.y - (height or ROW), R.n + 1
    return row
  end
  -- a row's control, greying its name with it
  local function Place(row, c, x)
    R:Track(c)
    c:SetPoint("LEFT", x or CTRL_X, 0)
    local sa = c.SetActive
    c.SetActive = function(on) if sa then sa(on) end; row.label:SetFontObject(on and "GameFontNormal" or "GameFontDisable") end
    return c, row
  end
  function R.Check(_, label, opt, onChange, tip, indent)
    local row = R:Row(label, tip, indent)
    return Place(row, UI.Check(row, opt, onChange))
  end
  function R.Slider(_, label, minV, maxV, step, opt, fmt, onChange, tip, factor, width)
    local row = R:Row(label, tip)
    return Place(row, UI.Slider(row, width or 250, minV, maxV, step, opt, fmt, onChange, factor))
  end
  function R.Toggle(_, label, width, options, opt, onChange, tip)
    local row = R:Row(label, tip)
    return Place(row, UI.Toggle(row, width, options, opt, onChange, "Click for the next, right-click for the previous."))
  end
  function R.Selector(_, label, width, options, opt, onChange, tip)
    local row = R:Row(label, tip)
    return Place(row, UI.Selector(row, width, options, opt, onChange))
  end
  function R.Edit(_, label, width, opt, placeholder, tip, spells)
    local row = R:Row(label, tip)
    return Place(row, UI.Edit(row, width, opt, placeholder, spells), CTRL_X + 6)
  end
  function R.Swatch(_, label, color, onChange, tip)
    local row = R:Row(label, tip)
    return Place(row, UI.Swatch(row, color, onChange), CTRL_X + 5)
  end
  -- a button (not refreshed: nothing to read)
  function R.Button(_, label, text, width, onClick, tip)
    local row = R:Row(label, tip)
    local b = UI.Button(row, text, width, onClick)
    b:SetPoint("LEFT", CTRL_X, 0)
    return b, row
  end
  -- a short grey note under the rows above
  function R.Note(_, text)
    local n = UI.Note(p, text, WIDTH - LABEL_X - 30)
    n:SetPoint("TOPLEFT", LABEL_X, R.y + 2)
    R.y = R.y - math.max(16, (n:GetStringHeight() or 12) + 10)
    return n
  end
  -- room for something laid out by hand: returns its top y
  function R.Space(_, h) local y = R.y; R.y = R.y - h; return y end
  function R.Refresh() for _, x in ipairs(R.items) do if x.Refresh then x.Refresh() end end end
  function R.Height() return -R.y + 20 end
  return R
end

---------------------------------------------------------------------------
-- The settings window: the game's Settings frame and art, the pages listed down the left under
-- category headings, each page scrolling in Blizzard's scroll frame under its title and divider,
-- a search box (any setting; pick one to go to it, flashing), Bugs & Feedback, Close.
-- cfg: { name, title, tagline, logo, bug = fn,
--   pages = { { name, what it's for (tooltip), build(child, R) }, ... },
--   categories = { { heading, { page numbers } }, ... } }
-- Returns the window; window.Refresh() refreshes every page's controls (also on show);
-- window.index is the search index.
---------------------------------------------------------------------------
local WIN_W, WIN_H = 920, 724        -- Blizzard's settings window (its inner frame's art)
local LIST_X, LIST_W = 18, 186       -- the pages: up to the inner frame's divider (x 212, measured in game)
local CONT_X = 230                   -- the page: right of that divider
UI.PAGE_W = WIN_W - CONT_X - 22 - 30 -- a page's width (inside its scroll frame)

function UI.Settings(cfg)
  local window = UI.Window(cfg.name, WIN_W, WIN_H, cfg.title)
  window:SetPoint("CENTER")
  local inner = window:CreateTexture(nil, "BACKGROUND")
  inner:SetAtlas("Options_InnerFrame", true); inner:SetPoint("TOPLEFT", 17, -64)
  UI.SetHost(window) -- pop-ups (the bug report) sit over this window
  local index, pagesR = {}, {}
  window.index = index

  -- top left: the logo and what the addon is
  local x = 30
  if cfg.logo then
    local logo = window:CreateTexture(nil, "ARTWORK")
    logo:SetSize(28, 28); logo:SetPoint("TOPLEFT", 30, -30); logo:SetTexture(cfg.logo)
    x = 66
  end
  UI.Font(window, "GameFontHighlight", cfg.tagline):SetPoint("TOPLEFT", x, -38)

  -- the page
  local container = CreateFrame("Frame", nil, window)
  container:SetPoint("TOPLEFT", CONT_X, -76); container:SetPoint("BOTTOMRIGHT", -22, 46)
  local title = UI.Font(container, "GameFontHighlightHuge")
  title:SetPoint("TOPLEFT", 7, -22)
  UI.Divider(container, -50, 7, 26)
  if cfg.bug then
    local bug = UI.Button(container, "Bugs & Feedback", 140, cfg.bug)
    bug:SetPoint("TOPRIGHT", -26, -16)
  end
  local close = UI.Button(window, CLOSE or "Close", 96, function() window:Hide() end)
  close:SetPoint("BOTTOMRIGHT", -16, 16)

  -- the pages, down the left
  local pages, items, current = {}, {}, 1
  local function paintItems()
    for i, it in pairs(items) do
      local on, over = i == current, it.over
      it.label:SetFontObject(on and "GameFontHighlight" or "GameFontNormal")
      it.tex:SetShown(on or over)
      if on or over then it.tex:SetAtlas(on and "Options_List_Active" or "Options_List_Hover") end
    end
  end
  local function Select(i)
    current = i
    for k, pg in ipairs(pages) do pg.scroll:SetShown(k == i) end
    title:SetText(cfg.pages[i][1])
    paintItems()
  end
  window.Select = Select
  local y = -76
  for h, cat in ipairs(cfg.categories) do
    local head = CreateFrame("Frame", nil, window)
    head:SetSize(LIST_W, 30); head:SetPoint("TOPLEFT", LIST_X, y)
    -- the header band: its art is taller than the band, which is at its top (seen in game), so
    -- it's placed by its top at its own height, as wide as the list
    local bg = head:CreateTexture(nil, "ARTWORK")
    bg:SetAtlas("Options_CategoryHeader_" .. math.min(h, 2), true); bg:SetWidth(LIST_W); bg:SetPoint("TOPLEFT")
    UI.Font(head, "GameFontHighlightMedium", cat[1]):SetPoint("LEFT", 20, -1)
    y = y - 32
    for _, i in ipairs(cat[2]) do
      local b = CreateFrame("Button", nil, window)
      b:SetSize(LIST_W, 20); b:SetPoint("TOPLEFT", LIST_X, y)
      b.tex = b:CreateTexture(nil, "BACKGROUND"); b.tex:SetAllPoints()
      b.label = UI.Font(b, "GameFontNormal", cfg.pages[i][1])
      b.label:SetPoint("TOPLEFT", 36, 1); b.label:SetPoint("BOTTOMRIGHT")
      b:SetScript("OnClick", function() Select(i) end)
      b:SetScript("OnEnter", function(self)
        self.over = true; paintItems()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT"); GameTooltip:SetText(cfg.pages[i][1], 1, 1, 1)
        GameTooltip:AddLine(cfg.pages[i][2], nil, nil, nil, true); GameTooltip:Show()
      end)
      b:SetScript("OnLeave", function(self) self.over = false; paintItems(); GameTooltip:Hide() end)
      items[i] = b
      y = y - 22
    end
    y = y - 18
  end

  -- each page in Blizzard's scroll frame (its minimal scroll bar)
  for i, def in ipairs(cfg.pages) do
    local scroll = CreateFrame("ScrollFrame", nil, container, "ScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 0, -56); scroll:SetPoint("BOTTOMRIGHT", -26, 0)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(UI.PAGE_W)
    scroll:SetScrollChild(child)
    local R = UI.Rows(child, { width = UI.PAGE_W, index = index, page = i })
    def[3](child, R)
    child:SetHeight(math.max(1, R.Height()))
    pagesR[i] = R
    function scroll.ScrollTo(v)
      local max = math.max(0, child:GetHeight() - scroll:GetHeight())
      scroll:SetVerticalScroll(math.max(0, math.min(max, v)))
    end
    scroll:Hide()
    pages[i] = { scroll = scroll, child = child }
  end

  -- search (Blizzard's search box): any setting by name; pick one to go to it and see it flash
  local search = CreateFrame("EditBox", nil, window, "SearchBoxTemplate")
  search:SetSize(260, 20); search:SetAutoFocus(false)
  search:SetPoint("BOTTOMRIGHT", container, "TOPRIGHT", 4, 20)
  local results = CreateFrame("Frame", nil, window, "BackdropTemplate")
  results:SetPoint("TOPRIGHT", search, "BOTTOMRIGHT", 0, -2); results:SetWidth(320)
  results:SetFrameLevel(window:GetFrameLevel() + 40)
  results:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
  results:SetBackdropColor(0.05, 0.05, 0.05, 0.97); results:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
  results:Hide()
  local lines = {}
  local function Flash(f)
    local t = 0
    local holder = CreateFrame("Frame")
    holder:SetScript("OnUpdate", function(self, dt)
      t = t + dt
      f:SetAlpha(0.35 + 0.65 * math.abs(math.cos(t * 6)))
      if t > 1.6 then f:SetAlpha(1); self:SetScript("OnUpdate", nil) end
    end)
  end
  local function Go(e)
    results:Hide(); search:SetText(""); search:ClearFocus()
    Select(e.page)
    pages[e.page].scroll.ScrollTo(-e.y - 40)
    Flash(e.frame)
  end
  local function Find(text)
    local q, found = (text or ""):lower(), {}
    if #q < 2 then return found end
    for _, e in ipairs(index) do
      if e.label:lower():find(q, 1, true) then found[#found + 1] = e end
      if #found >= 10 then break end
    end
    return found
  end
  search:HookScript("OnTextChanged", function(self)
    local found = Find(self:GetText())
    for i = 1, math.max(#found, #lines) do
      local e, b = found[i], lines[i]
      if e and not b then
        b = CreateFrame("Button", nil, results)
        b:SetSize(308, 20); b:SetPoint("TOPLEFT", 6, -6 - (i - 1) * 20)
        b.text = UI.Font(b, "GameFontNormal")
        b.text:SetPoint("LEFT", 4, 0); b.text:SetPoint("RIGHT", -4, 0); b.text:SetWordWrap(false)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        lines[i] = b
      end
      if b then
        b:SetShown(e ~= nil)
        if e then
          b.text:SetText(e.label .. "  |cff9d9d9d" .. cfg.pages[e.page][1] .. "|r")
          b:SetScript("OnClick", function() Go(e) end)
        end
      end
    end
    results:SetHeight(#found * 20 + 12)
    results:SetShown(#found > 0)
  end)
  search:HookScript("OnEnterPressed", function(self)
    local e = Find(self:GetText())[1]
    if e then Go(e) else self:ClearFocus() end
  end)
  window:HookScript("OnHide", function() results:Hide() end)

  function window.Refresh() for _, R in ipairs(pagesR) do R.Refresh() end end
  Select(1)
  window:HookScript("OnShow", function() window.Refresh() end)
  window:Hide()
  return window
end

-- opens or closes a settings window, shrunk to fit smaller screens
function UI.ToggleWindow(w)
  w:SetScale(math.max(0.5, math.min(1, (UIParent:GetHeight() - 40) / w:GetHeight())))
  if w:IsShown() then w:Hide() else w:Show() end
end
