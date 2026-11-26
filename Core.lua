-- Just the Tooltip!: the game's own tooltip, placed where you want it, with a few useful extras.
-- It changes Blizzard's tooltip rather than replacing it, so every addon that writes to the
-- tooltip (Equip This!, Questie, What's Training, ...) keeps working.
local ADDON, ns = ...
ns.name = ADDON

ns.isSecret = issecretvalue or function() return false end
function ns.Readable(v) return v ~= nil and not ns.isSecret(v) end
function ns.Print(...) print("|cff7fd6ffJust the Tooltip!:|r", ...) end

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
  combatHide = false,
  instantHide = true,     -- world tooltips vanish when you stop hovering (no fade)     -- hide tooltips for things in the world during combat (Shift shows them)
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
