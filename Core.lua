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
}

local function Copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = Copy(x) end
  return t
end
ns.Copy = Copy

function ns.LoadDB()
  JustTheTooltipDB = JustTheTooltipDB or {}
  for k, v in pairs(ns.DEFAULTS) do
    if JustTheTooltipDB[k] == nil then JustTheTooltipDB[k] = Copy(v) end
  end
  ns.db = JustTheTooltipDB
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
