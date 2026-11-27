-- What a tooltip is about, gathered once per tooltip (1.8.0). The item, spell or unit is read here,
-- each detail through ns.Safe, and shared by its lines (Info), its colours (Look) and its sources,
-- so no detail is asked of the game twice for one tooltip. Also here:
-- - the game functions each kind of information needs;
-- - the information categories: what each needs, how far it's verified, and its errors. They're
--   kept apart: one category failing leaves the others be.
local _, ns = ...
local F = {}
ns.Facts = F
local Safe, Readable = ns.Safe, ns.Readable

-- a game function by name; the first of several that exists ("C_Item.GetItemInfo|GetItemInfo")
function F.Resolve(names)
  for name in names:gmatch("[^|]+") do
    local t = _G
    for part in name:gmatch("[^%.]+") do t = type(t) == "table" and t[part] or nil end
    if type(t) == "function" then return t, name end
  end
end
local Resolve = F.Resolve

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------
-- { id, link, equipLoc, classID, cached, level, quality }:
-- - id and link: from the tooltip, else its data;
-- - equipLoc and classID: what the item is, from GetItemInfoInstant (no cache needed), else from
--   GetItemInfo;
-- - level and quality: from GetItemInfo, nil until the client has the item (`cached`). Quality
--   can also come from GetItemQualityByID.
-- Return positions: warcraft.wiki.gg, and Equip This!'s engine (verified in WoW: Forever).
function F.Item(tip, data)
  local it = {}
  if tip and tip.GetItem then
    local _, link = Safe(tip.GetItem, tip)
    if type(link) == "string" then it.link = link end
  end
  if type(data) == "table" then
    if not it.link and Readable(data.hyperlink) and type(data.hyperlink) == "string" then it.link = data.hyperlink end
    if Readable(data.id) and type(data.id) == "number" then it.id = data.id end
  end
  if not it.id and it.link then it.id = tonumber(it.link:match("item:(%d+)")) end
  if not it.link and it.id then it.link = "item:" .. it.id end
  if not it.link then return it end
  local _, _, _, equipLoc, _, classID = Safe(Resolve("C_Item.GetItemInfoInstant|GetItemInfoInstant"), it.link)
  it.equipLoc, it.classID = equipLoc, classID
  local name, _, quality, level, _, _, _, stack, equipLoc2, _, sellPrice, classID2 = Safe(Resolve("C_Item.GetItemInfo|GetItemInfo"), it.link)
  it.cached = name ~= nil
  it.level, it.quality, it.stack, it.sellPrice = level, quality, stack, sellPrice
  if it.equipLoc == nil then it.equipLoc = equipLoc2 end
  if it.classID == nil then it.classID = classID2 end
  if it.quality == nil then it.quality = Safe(Resolve("C_Item.GetItemQualityByID"), it.link) end
  return it
end

---------------------------------------------------------------------------
-- Spells (spells, buffs and debuffs: the tooltip's data carries the spell ID)
---------------------------------------------------------------------------
function F.Spell(data)
  local id = type(data) == "table" and data.id
  return { id = Readable(id) and type(id) == "number" and id or nil }
end
-- (1.10.0) whether you know it: true, false, or nil (can't tell). C_SpellBook.IsSpellKnown, else the
-- older IsPlayerSpell (deprecated in 11.2; warcraft.wiki.gg)
function F.Known(id)
  if type(id) ~= "number" then return nil end
  local k = Safe(Resolve("C_SpellBook.IsSpellKnown|IsPlayerSpell"), id)
  if type(k) == "boolean" then return k end
end

-- (1.10.0) how many of an item you have (bags, and the bank once seen), or nil
function F.Count(id)
  if type(id) ~= "number" then return nil end
  local n = Safe(Resolve("C_Item.GetItemCount|GetItemCount"), id, true)
  if type(n) == "number" then return n end
end

---------------------------------------------------------------------------
-- Units
---------------------------------------------------------------------------
-- the unit a tooltip shows, as a token, or nil (the game can keep who's under the mouse secret)
function F.UnitOf(tip)
  if not (tip and tip.GetUnit) then return nil end
  local _, unit = Safe(tip.GetUnit, tip)
  if type(unit) == "string" then return unit end
  if Safe(UnitExists, "mouseover") == true then return "mouseover" end
end

-- { token, isPlayer, class, reaction, tapped }: each nil when the game doesn't say (isPlayer:
-- true, false, or nil when it can't be told, so nothing is guessed from it)
function F.Unit(token)
  if type(token) ~= "string" then return nil end
  local u = { token = token }
  u.isPlayer = Safe(UnitIsPlayer, token)
  if u.isPlayer == true then
    local _, class = Safe(UnitClass, token)
    if type(class) == "string" then u.class = class end
  end
  local r = Safe(UnitReaction, token, "player")
  if type(r) == "number" then u.reaction = r end
  u.tapped = Safe(UnitIsTapDenied, token)
  return u
end

-- (1.10.0) a creature's NPC ID, from its GUID ("Creature-0-[server]-[instance]-[zone]-[npcID]-[spawn]";
-- "Vehicle" the same). WoW: Forever 1.60.1 scrambles the server and spawn parts only, the format is
-- unchanged (warcraft.wiki.gg, UnitGUID). Players, pets and anything else: nil.
function F.NpcFromGUID(guid)
  if type(guid) ~= "string" then return nil end
  local kind, id = guid:match("^(%a+)%-[^-]*%-[^-]*%-[^-]*%-[^-]*%-(%d+)%-")
  if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
end
function F.NpcID(token)
  if type(token) ~= "string" then return nil end
  return F.NpcFromGUID(Safe(UnitGUID, token))
end

-- who `token` is targeting: the unit facts plus isMe and name, or nil (no target, or can't tell)
function F.Target(token)
  if type(token) ~= "string" then return nil end
  local t = token .. "target"
  if Safe(UnitExists, t) ~= true then return nil end
  local u = F.Unit(t)
  u.isMe = Safe(UnitIsUnit, t, "player")
  local name = Safe(UnitName, t)
  if type(name) == "string" and name ~= "" then u.name = name end
  return u
end

---------------------------------------------------------------------------
-- Information categories
---------------------------------------------------------------------------
-- key, name, the setting that turns it on, the game functions it needs, and how far it's verified
-- (API_COMPATIBILITY.md). A category whose functions are missing is skipped, never an error.
local VERIFIED = "Verified in WoW Forever"
F.CATEGORIES = {
  { key = "itemId", name = "Item ID", setting = "ids", needs = {}, status = VERIFIED },
  { key = "spellId", name = "Spell ID (spells, buffs, debuffs)", setting = "ids", needs = {}, status = VERIFIED },
  { key = "itemLevel", name = "Item level", setting = "itemLevel", needs = { "C_Item.GetItemInfo|GetItemInfo" }, status = VERIFIED },
  { key = "sources", name = "Where gear comes from", setting = "sources", needs = {}, status = VERIFIED },
  { key = "target", name = "Target line", setting = "target", needs = { "UnitExists", "UnitIsUnit", "UnitName" }, status = VERIFIED },
  { key = "look", name = "Look, borders and name colours", setting = "look", needs = {}, status = VERIFIED },
  -- (1.10.0)
  { key = "npcId", name = "NPC ID", setting = "npcIds", needs = { "UnitGUID" },
    status = VERIFIED },
  { key = "itemValue", name = "How many you have, and what they sell for", setting = "itemValue",
    needs = { "C_Item.GetItemCount|GetItemCount" }, status = VERIFIED },
  { key = "spellKnown", name = "Whether you know a spell (with the detail key)", setting = "detailKey",
    needs = { "C_SpellBook.IsSpellKnown|IsPlayerSpell" }, status = VERIFIED },
}
local byKey = {}
for _, c in ipairs(F.CATEGORIES) do byKey[c.key] = c end
F.errors = {} -- key -> { n, msg }

-- the functions a category needs that this client doesn't have (worked out once)
function F.Missing(key)
  local c = byKey[key]
  if not c then return {} end
  if not c.missing then
    c.missing = {}
    for _, n in ipairs(c.needs) do if not Resolve(n) then c.missing[#c.missing + 1] = n end end
  end
  return c.missing
end

-- Run one category's work. Skipped when the client lacks what it needs. An error is kept for
-- /jtt info and said once in chat, and the tooltip's other categories carry on.
function F.Run(key, fn, ...)
  if #F.Missing(key) > 0 then return end
  local ok, e = pcall(fn, ...)
  if ok then return end
  local r = F.errors[key]
  if not r then
    r = { n = 0 }
    F.errors[key] = r
    ns.Print(format("|cffff6060an error in \"%s\"|r (the rest of the tooltip still works): %s. /jtt info lists it; /jtt report sends it.",
      byKey[key] and byKey[key].name or key, tostring(e)))
  end
  r.n, r.msg = r.n + 1, tostring(e)
end

-- /jtt info: each category, whether it's on, whether this client can do it, how far it's verified,
-- and its errors
function F.InfoLines()
  local L = {}
  for _, c in ipairs(F.CATEGORIES) do
    local setting = ns.db and ns.db[c.setting]
    local on = c.key == "look" and "on" or c.key == "spellKnown" and (setting ~= "none" and "on" or "off") or (setting and "on" or "off")
    local missing = F.Missing(c.key)
    local e = F.errors[c.key]
    L[#L + 1] = format("%s: %s; %s; %s%s", c.name, on,
      #missing == 0 and "available" or ("not on this client (" .. table.concat(missing, ", ") .. ")"), c.status,
      e and format("; errors: %d (last: %s)", e.n, e.msg) or "")
  end
  return L
end
