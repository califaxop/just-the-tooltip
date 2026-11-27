-- Just the Tooltip!: the game's own tooltip, placed where you want it, with a few useful extras.
-- It changes Blizzard's tooltip rather than replacing it, so every addon that writes to the
-- tooltip (Equip This!, Questie, What's Training, ...) keeps working.
local ADDON, ns = ...
ns.name = ADDON

ns.isSecret = issecretvalue or function() return false end
function ns.Readable(v) return v ~= nil and not ns.isSecret(v) end
function ns.Print(...) print("|cff7fd6ffJust the Tooltip!:|r", ...) end

-- A game call that can't break the tooltip (1.6.0): missing, erroring, or answering with a secret
-- (the game can hide a unit's details from addons), each value comes back as nil. One unit detail
-- that can't be read never stops the rest of the tooltip.
local function Pack(...) return { n = select("#", ...), ... } end
function ns.Safe(fn, ...)
  if type(fn) ~= "function" then return nil end
  local r = Pack(pcall(fn, ...))
  if not r[1] then return nil end
  for i = 2, r.n do if not ns.Readable(r[i]) then r[i] = nil end end
  return unpack(r, 2, r.n)
end

-- Hooks are installed once (1.6.0): ns.Once("anchor") is true the first time only, so starting up
-- again can never add a second copy of a hook. ns.hooks lists what's in (/jtt debug).
ns.hooks = {}
function ns.Once(key)
  if ns.hooks[key] then return false end
  ns.hooks[key] = true
  return true
end

ns.DEFAULTS = {
  anchor = "default",     -- "default" (the game's spot), "cursor" (follows your mouse), "custom" (your own spot)
  scope = "all",          -- cursor: "all" (everything that uses the default spot) or "world" (units and objects in the world)
  corner = "BOTTOMRIGHT", -- cursor: which side of the cursor the tooltip sits on
  offX = 24, offY = 24,   -- cursor: how far from it
  spot = { point = "BOTTOMRIGHT", x = -90, y = 110 }, -- custom: where (tooltip corner, from that screen corner)
  look = "addon",         -- "addon" (JTT style) or "blizzard"
  colorBorder = true,     -- border in the item's quality / player's class color; class-colored player names
  colorNPC = true,        -- NPCs' border by reaction: red hostile, yellow neutral, green friendly, grey tapped
  scale = 1,
  ids = true,             -- Item ID / Spell ID
  itemLevel = true,
  sources = true,         -- where gear comes from (needs the Just the Tooltip!: Sources addon, which ships with it)
  target = true,          -- "Target: Name" on units
  healthBar = true,       -- the health bar under unit tooltips
  combatHide = false,     -- hide tooltips for things in the world during combat (Shift shows them)
  instantHide = true,     -- world tooltips vanish when you stop hovering (no fade)
  -- (1.9.0) which tooltips each line shows on: where[line][tooltip] = false turns it off there
  -- (missing = on). Tooltips: main (the game's), ref (chat links), compare (comparisons).
  where = {},
  itemOrder = { "itemLevel", "sources", "itemId" }, -- the order of JTT's lines on items
  detailKey = "none",     -- "none", "ALT", "CTRL": held, tooltips show every detail (all sources, where each was learned)
}

local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end
ns.Copy = Copy

local function Fill(t)
  for k, v in pairs(ns.DEFAULTS) do
    if t[k] == nil then t[k] = Copy(v) end
  end
  return t
end

-- Profiles (1.9.0). The settings at the top of JustTheTooltipDB are the shared ones, as in every
-- earlier version, used by every character that hasn't picked a profile. Named profiles are kept in
-- JustTheTooltipDB.profiles[name], each a full, independent set of settings. A character's choice is
-- JustTheTooltipCharDB.profile (nil: the shared settings). ns.db is whichever is in use.
function ns.LoadDB()
  JustTheTooltipDB = Fill(JustTheTooltipDB or {})
  if type(JustTheTooltipDB.profiles) ~= "table" then JustTheTooltipDB.profiles = {} end
  JustTheTooltipCharDB = type(JustTheTooltipCharDB) == "table" and JustTheTooltipCharDB or {}
  local name = JustTheTooltipCharDB.profile
  local p = type(name) == "string" and JustTheTooltipDB.profiles[name]
  if type(p) == "table" then
    ns.db = Fill(p)
  else
    JustTheTooltipCharDB.profile = nil -- (a profile deleted on another character: back to shared)
    ns.db = JustTheTooltipDB
  end
end
function ns.ProfileName() return JustTheTooltipCharDB and JustTheTooltipCharDB.profile end
function ns.ProfileNames()
  local t = {}
  for n in pairs(JustTheTooltipDB.profiles) do t[#t + 1] = n end
  table.sort(t)
  return t
end
-- after the settings in use changed (another profile): everything that follows them, again
function ns.ApplySettings()
  if ns.Anchor then ns.Anchor.PlaceSpot() end
  if ns.Sources then ns.Sources.Hold() end
  if ns.Info then ns.Info.ApplyHealthBar() end
  if ns.Look then ns.Look.Refresh() end
  if ns.RefreshOptions then ns.RefreshOptions() end
end
-- use a profile on this character (nil: the shared settings)
function ns.UseProfile(name)
  if name ~= nil and type(JustTheTooltipDB.profiles[name]) ~= "table" then return false end
  JustTheTooltipCharDB.profile = name
  ns.LoadDB()
  ns.ApplySettings()
  return true
end
-- a new profile: a copy of the settings in use, then used on this character
function ns.NewProfile(name)
  name = type(name) == "string" and name:gsub("^%s+", ""):gsub("%s+$", "") or ""
  if name == "" or JustTheTooltipDB.profiles[name] then return false end
  local t = {}
  for k in pairs(ns.DEFAULTS) do t[k] = Copy(ns.db[k]) end
  JustTheTooltipDB.profiles[name] = t
  return ns.UseProfile(name)
end
-- delete a profile; a character using it goes back to the shared settings
function ns.DeleteProfile(name)
  if type(JustTheTooltipDB.profiles[name]) ~= "table" then return false end
  JustTheTooltipDB.profiles[name] = nil
  if ns.ProfileName() == name then ns.UseProfile(nil) end
  return true
end

-- the kind of tooltip, for "where each line shows": main, ref (a chat link), compare
function ns.TipKind(tip)
  if tip == ItemRefTooltip then return "ref" end
  local name = tip and tip.GetName and tip:GetName()
  if type(name) == "string" and (name:find("^ShoppingTooltip%d") or name:find("^ItemRefShoppingTooltip%d")) then return "compare" end
  return "main"
end
function ns.ShowsOn(line, kind)
  local w = type(ns.db.where) == "table" and ns.db.where[line]
  return not (type(w) == "table" and w[kind] == false)
end
function ns.Shows(line, tip) return ns.ShowsOn(line, ns.TipKind(tip)) end
-- turn a line on or off on one kind of tooltip (off is kept as false; on, as nothing)
function ns.SetShowsOn(line, kind, on)
  if type(ns.db.where) ~= "table" then ns.db.where = {} end
  if type(ns.db.where[line]) ~= "table" then ns.db.where[line] = {} end
  if on then ns.db.where[line][kind] = nil else ns.db.where[line][kind] = false end
end

-- the item lines in the order chosen: every line once (an old, damaged or missing order still works)
ns.ITEM_LINES = { "itemLevel", "sources", "itemId" }
function ns.ItemOrder()
  local out, seen = {}, {}
  local known = {}
  for _, k in ipairs(ns.ITEM_LINES) do known[k] = true end
  for _, k in ipairs(type(ns.db.itemOrder) == "table" and ns.db.itemOrder or {}) do
    if known[k] and not seen[k] then out[#out + 1] = k; seen[k] = true end
  end
  for _, k in ipairs(ns.ITEM_LINES) do if not seen[k] then out[#out + 1] = k end end
  return out
end
function ns.MoveItemLine(key, d)
  local o = ns.ItemOrder()
  for i, k in ipairs(o) do
    if k == key then
      local j = i + d
      if j < 1 or j > #o then return false end
      o[i], o[j] = o[j], o[i]
      ns.db.itemOrder = o
      return true
    end
  end
  return false
end

-- the detail key held now (1.9.0)
function ns.Detail()
  local k = ns.db and ns.db.detailKey
  if k == "ALT" then return IsAltKeyDown and IsAltKeyDown() and true or false end
  if k == "CTRL" then return IsControlKeyDown and IsControlKeyDown() and true or false end
  return false
end

-- the tooltips we touch: the game's main ones only (never other addons' hidden scanning tooltips)
function ns.IsOurs(tip)
  if not tip then return false end
  if tip == GameTooltip or tip == ItemRefTooltip then return true end
  local name = tip.GetName and tip:GetName()
  return type(name) == "string" and (name:find("^ShoppingTooltip%d") or name:find("^ItemRefShoppingTooltip%d")) ~= nil
end
function ns.Tooltips()
  local t = { GameTooltip, ItemRefTooltip }
  for _, n in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }) do
    if _G[n] then t[#t + 1] = _G[n] end
  end
  return t
end
