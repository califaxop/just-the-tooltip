#!/usr/bin/env python3
"""Just the Tooltip! offline tests: python3 tests/run_tests.py  (needs: pip install lupa)

Loads the addon's files (the toc's order) against a mock of the game client (tests/mock.lua) and
checks the logic: ID matching, which items get an item level, where the tooltip goes for the
cursor at any scale, safe unit details, hooks installed once, and when source lookups are kept.
What the real client does is checked in game (DEVELOPMENT.md, "In-game checklist"), never
claimed from these.
"""
import os, sys
from lupa.lua51 import LuaRuntime

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
FILES = [l.strip() for l in open(os.path.join(ROOT, 'JustTheTooltip.toc')) if l.strip().endswith('.lua') and not l.startswith('#')]


def load(pre=None, login=True):
    L = LuaRuntime()
    L.execute(open(os.path.join(HERE, 'mock.lua')).read())
    if pre:
        L.execute(pre)
    ns = L.eval('{}')
    run = L.eval('function(src, n, ns) return assert(loadstring(src, "@" .. n))("JustTheTooltip", ns) end')
    for f in FILES:
        run(open(os.path.join(ROOT, f)).read(), f, ns)
    L.globals().NS = ns
    L.execute('MOCK.Fire("ADDON_LOADED", "JustTheTooltip")')
    if login:
        L.execute('MOCK.Fire("PLAYER_LOGIN")')
    return L


failures, count = [], 0


def test(name, pre=None, login=True):
    def wrap(fn):
        global count
        count += 1
        try:
            L = load(pre, login)
            L.execute(fn.__doc__)
            print('ok   ', name)
        except Exception as e:  # noqa
            failures.append(name); print('FAIL ', name, '\n     ', str(e).replace('\n', '\n      '))
        return fn
    return wrap


@test("loads: every file runs against the mock, settings are set up")
def _():
    """
    assert(NS.db and NS.db.anchor == "default" and NS.db.ids == true)
    """

# ---------------------------------------------------------------------------------------------
# IDs
# ---------------------------------------------------------------------------------------------
@test("IDs: matched as whole numbers, in other addons' wordings; never a part of another number")
def _():
    """
    local N = NS.Info.NamesID
    assert(N("Item ID: 1234", nil, 1234) and N("|cff9d9d9dItem ID: 1234|r", nil, 1234), "ours")
    assert(not N("Item ID: 1234", nil, 123) and not N("Item ID: 1234", nil, 234), "1234 isn't 123 or 234 (1.5.0: it was)")
    assert(N("ItemID 1234", nil, 1234) and N("ID: 1234", nil, 1234) and N("Spell ID", "1234", 1234), "others' wordings")
    assert(N("SpellID: 5 | ItemID: 1234", nil, 1234), "a line with several")
    assert(not N("Equip: Increases damage by 1234.", nil, 1234), "not an ID line")
    assert(not N("Provides 1234 armor", nil, 1234), "'id' inside a word isn't an ID label")
    assert(not N("|T134400:14|t Item ID", "99", 134400), "an icon's file number isn't the ID")
    assert(not N(nil, "1234", 1234) and not N("Item ID: 1234", nil, nil), "nothing to match")
    """

@test("IDs: added once; no error from missing lines, secret text, or a line other than text")
def _():
    """
    local T = GameTooltip
    T:ClearLines(); T:AddLine("Thunderfury"); T:AddLine("Item ID: 12345")
    NS.db.ids = true
    MOCK.Post(Enum.TooltipDataType.Spell, T, { id = 1234 })
    assert(T:NumLines() == 3 and GameTooltipTextLeft3._text:find("Spell ID: 1234", 1, true), "1234 isn't 12345: added")
    MOCK.Post(Enum.TooltipDataType.Spell, T, { id = 1234 })
    assert(T:NumLines() == 3, "not twice")
    -- a line whose left text is gone, one with a secret, one that errors
    T:ClearLines(); T:AddLine("A"); T:AddLine("x"); T:AddLine("y"); T:AddLine("z")
    GameTooltipTextLeft2 = nil
    GameTooltipTextLeft3._text = MOCK.SECRET
    GameTooltipTextLeft4.GetText = function() error("boom") end
    MOCK.Post(Enum.TooltipDataType.Spell, T, { id = 77 })
    assert(T:NumLines() == 5 and GameTooltipTextLeft5._text:find("Spell ID: 77", 1, true))
    """

# ---------------------------------------------------------------------------------------------
# Item level
# ---------------------------------------------------------------------------------------------
@test("item level: weapons, armor, shields and jewelry; never bags, quivers, food, or by level alone")
def _():
    """
    local G = NS.Info.GearLevel
    assert(G(45, "INVTYPE_2HWEAPON", 2) == 45 and G(30, "INVTYPE_WEAPONMAINHAND", 2) == 30, "weapons")
    assert(G(40, "INVTYPE_CHEST", 4) == 40 and G(40, "INVTYPE_SHIELD", 4) == 40, "armor, shields")
    assert(G(52, "INVTYPE_FINGER", 4) == 52 and G(52, "INVTYPE_NECK", 4) == 52 and G(60, "INVTYPE_TRINKET", 4) == 60, "jewelry")
    assert(G(45, "INVTYPE_RANGED", 2) == 45, "bows")
    assert(not G(35, "INVTYPE_BAG", 1) and not G(35, "INVTYPE_QUIVER", 11) and not G(35, "INVTYPE_BAG", 4), "bags and quivers")
    assert(not G(45, "", 0) and not G(45, "", 4) and not G(45, "INVTYPE_NON_EQUIP_IGNORE", 4), "food; an armor-class item not worn")
    assert(not G(1, "INVTYPE_CHEST", 4) and not G(nil, "INVTYPE_CHEST", 4) and not G(40, nil, 4) and not G(40, "INVTYPE_CHEST", nil), "incomplete")
    -- on the tooltip: from GetItemInfo's returns in their verified places; uncached: nothing
    MOCK.items[19019] = { level = 80, equipLoc = "INVTYPE_WEAPONMAINHAND", classID = 2, quality = 5 }
    local T = GameTooltip; T:ClearLines(); T:AddLine("Thunderfury")
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 19019 })
    assert(GameTooltipTextLeft2._text:find("Item level 80", 1, true), tostring(GameTooltipTextLeft2._text))
    T:ClearLines(); T:AddLine("Not cached")
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 4444 })
    assert(not GameTooltipTextLeft2._text:find("Item level", 1, true), "no level for an item the client doesn't have yet")
    MOCK.items[5555] = { level = MOCK.SECRET, equipLoc = "INVTYPE_CHEST", classID = 4 }
    T:ClearLines(); T:AddLine("Hidden")
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 5555 })
    assert(not GameTooltipTextLeft2._text:find("Item level", 1, true), "a hidden level: none")
    """

# ---------------------------------------------------------------------------------------------
# Cursor
# ---------------------------------------------------------------------------------------------
@test("cursor: the tooltip's corner on the cursor and the same distance from it at every tooltip and UI scale, all corners")
def _():
    """
    local P = NS.Anchor.CursorPoint
    local DIR = { BOTTOMRIGHT = { "TOPLEFT", 1, -1 }, BOTTOMLEFT = { "TOPRIGHT", -1, -1 },
                  TOPRIGHT = { "BOTTOMLEFT", 1, 1 }, TOPLEFT = { "BOTTOMRIGHT", -1, 1 } }
    for _, ui in ipairs({ 0.64, 0.8, 1, 1.15 }) do
      for _, tipScale in ipairs({ 0.6, 0.8, 1, 1.4 }) do
        for corner, d in pairs(DIR) do
          for _, off in ipairs({ 0, 12, 24, 80 }) do
            local x, y = 812, 433 -- the cursor, in screen units
            local tipEff = tipScale * ui
            local point, px, py = P(x, y, tipEff, ui, corner, off, off)
            assert(point == d[1], corner)
            -- the corner's place on screen (offsets are in the tooltip's scale) vs the cursor
            local sx, sy = px * tipEff, py * tipEff
            local gx, gy = (sx - x) / ui, (sy - y) / ui -- the gap, in the interface's units
            assert(math.abs(gx - d[2] * off) < 1e-6 and math.abs(gy - d[3] * off) < 1e-6,
              string.format("%s ui %.2f tip %.2f off %d: gap %.3f,%.3f", corner, ui, tipScale, off, gx, gy))
          end
        end
      end
    end
    """

@test("cursor: following places the tooltip from the cursor; a changed tooltip size is followed even with the mouse still")
def _():
    """
    NS.db.anchor, NS.db.corner, NS.db.offX, NS.db.offY = "cursor", "BOTTOMRIGHT", 24, 24
    MOCK.uiScale, MOCK.cursor = 1, { 500, 300 }
    GameTooltip:SetScale(1)
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    local p = GameTooltip._lastPoint
    assert(p[1] == "TOPLEFT" and p[2] == UIParent and p[4] == 524 and p[5] == 276, table.concat({ tostring(p[4]), tostring(p[5]) }, ","))
    -- the tooltip made bigger (settings) while the mouse is still: placed again, same gap
    GameTooltip:SetScale(2)
    MOCK.Update()
    p = GameTooltip._lastPoint
    assert(p[4] == 524 / 2 and p[5] == 276 / 2, "placed again at the new size: " .. p[4] .. "," .. p[5])
    -- and the gap stays 24 interface units at the new size: (offset * tooltip scale) - cursor
    assert(p[4] * 2 - 500 == 24 and 300 - p[5] * 2 == 24)
    """

# ---------------------------------------------------------------------------------------------
# Units
# ---------------------------------------------------------------------------------------------
@test("units: a detail that errors or is hidden is left out; the rest of the tooltip still comes")
def _():
    """
    local T = GameTooltip
    T.GetUnit = function() return "Kurran", "mouseover" end
    MOCK.units.mouseover = { exists = true, isPlayer = true, class = "WARRIOR", reaction = 5 }
    MOCK.units.mouseovertarget = { exists = true, isMe = true }
    T:ClearLines(); T:AddLine("Kurran"); T:SetOwner(UIParent)
    MOCK.Post(Enum.TooltipDataType.Unit, T, {})
    assert(GameTooltipTextLeft2._text:find(">> You <<", 1, true), "target line")
    assert(GameTooltipTextLeft1._color and math.abs(GameTooltipTextLeft1._color[1] - 0.78) < 0.01, "class colour on the name")
    -- the class hidden, the target's identity hidden: no colour, no target line, no error
    MOCK.units.mouseover = { exists = true, isPlayer = true, class = MOCK.SECRET }
    MOCK.units.mouseovertarget = { exists = true, isMe = MOCK.SECRET }
    T:ClearLines(); T:AddLine("Kurran")
    MOCK.Post(Enum.TooltipDataType.Unit, T, {})
    assert(T:NumLines() == 1, "no target line when it can't tell who")
    -- a target whose details error: still no error
    MOCK.units.mouseovertarget = { err = true }
    T:ClearLines(); T:AddLine("Kurran")
    MOCK.Post(Enum.TooltipDataType.Unit, T, {})
    -- an NPC whose player-ness is hidden: no reaction colour guessed
    MOCK.units.mouseover = { exists = true, isPlayer = MOCK.SECRET, reaction = 2 }
    T:ClearLines(); T:AddLine("Defias")
    MOCK.Post(Enum.TooltipDataType.Unit, T, {})
    """

@test("safe calls: missing functions, errors and secrets give nil; every value kept, false included")
def _():
    """
    local S = NS.Safe
    assert(S(nil) == nil and S(function() error("x") end) == nil)
    local a, b, c = S(function() return false, MOCK.SECRET, 3 end)
    assert(a == false and b == nil and c == 3)
    local r = { S(function() return 1,2,3,4,5,6,7,8,9,10,11,12 end) }
    assert(#r == 12 and r[12] == 12, "all twelve (GetItemInfo's class ID is the 12th)")
    """

# ---------------------------------------------------------------------------------------------
# Hooks
# ---------------------------------------------------------------------------------------------
@test("hooks: installed once; starting up again adds no second copy")
def _():
    """
    local n = #(TooltipDataProcessor.calls[Enum.TooltipDataType.Item] or {})
    assert(n == 1, "one item post-call: " .. n)
    MOCK.Fire("PLAYER_LOGIN")
    NS.Anchor.Hook(); NS.Look.Hook(); NS.Info.Hook()
    assert(#TooltipDataProcessor.calls[Enum.TooltipDataType.Item] == 1, "still one")
    assert(NS.hooks.anchor and NS.hooks.look and NS.hooks.info)
    -- one SetOwner hook: a tooltip ID line added once per post-call is the visible part; the hook count
    local T = GameTooltip; T:ClearLines(); T:AddLine("x")
    MOCK.Post(Enum.TooltipDataType.Spell, T, { id = 9 })
    assert(T:NumLines() == 2, "one line, not two")
    """

# ---------------------------------------------------------------------------------------------
# Sources: Questie's state, and what's kept
# ---------------------------------------------------------------------------------------------
QUESTIE = """
MOCK.qdb = { QuestPointers = {}, QueryItemSingle = function(id, key)
    if id == 900 and key == "questRewards" then return { 10 } end
  end,
  QueryQuestSingle = function(id, key) if key == "name" then return "A quest" end; if key == "questLevel" then return 20 end end,
  QueryNPCSingle = function() end, QueryObjectSingle = function() end }
JustTheTooltipSources = { items = {}, quests = {}, npcs = {}, objects = {}, instances = {} }
"""

@test("sources: Questie absent or loading: nothing kept; ready: its answer is used and kept; an unknown item kept as none", pre=QUESTIE)
def _():
    """
    NS.db.sources = true
    local S = NS.Sources
    local T = GameTooltip
    local function hover(id) T:ClearLines(); T:AddLine("x"); S.Add(T, id); return T:NumLines() > 1 end
    assert(S.QuestieState() == "absent")
    assert(not hover(900) and S.cache[900] == nil, "absent: nothing kept")
    -- loaded, still starting (its API says not ready; the item lookup not bound yet, like older Questie)
    Questie = { API = { isReady = false } }
    local mod = {}
    QuestieLoader = { ImportModule = function() return mod end }
    assert(S.QuestieState() == "loading")
    assert(not hover(900) and S.cache[900] == nil, "loading: nothing kept (1.5.0 kept 'no Questie' for the session)")
    -- ready
    for k, v in pairs(MOCK.qdb) do mod[k] = v end
    Questie.API.isReady = true
    assert(S.QuestieState() == "ready")
    assert(hover(900), "Questie's quest reward shown")
    assert(GameTooltipTextLeft2._text:find("A quest", 1, true), tostring(GameTooltipTextLeft2._text))
    assert(S.cache[900], "kept once final")
    assert(not hover(901) and S.cache[901], "an item Questie doesn't know: kept as none")
    """

@test("sources: Questie ready without an item lookup is final ('unusable'); without its API, ready once its quest list exists", pre=QUESTIE)
def _():
    """
    local S = NS.Sources
    Questie = { API = { isReady = true } }
    QuestieLoader = { ImportModule = function() return {} end }
    assert(S.QuestieState() == "unusable" and S.QuestieState() == "unusable")
    """

@test("sources: an older Questie with no API counts as ready once its quest list exists", pre=QUESTIE)
def _():
    """
    local S = NS.Sources
    local mod = { QueryItemSingle = MOCK.qdb.QueryItemSingle }
    QuestieLoader = { ImportModule = function() return mod end }
    Questie = {}
    assert(S.QuestieState() == "loading")
    mod.QuestPointers = {}
    assert(S.QuestieState() == "ready")
    """

# ---------------------------------------------------------------------------------------------
# M2: lifecycle, owners, look, late tooltips, compatibility
# ---------------------------------------------------------------------------------------------
@test("lifecycle: each new tooltip starts a clean record; nothing from the last one carries over")
def _():
    """
    local S, T = NS.Anchor.state, GameTooltip
    NS.db.instantHide = true
    -- a world unit's tooltip
    GameTooltip_SetDefaultAnchor(T, UIParent); T:Show()
    MOCK.units.mouseover = { exists = true, isPlayer = false, reaction = 2 }
    T.GetUnit = function() return "Defias", "mouseover" end
    MOCK.Post(Enum.TooltipDataType.Unit, T, {})
    local gen = S.gen
    assert(S.unit == true and S.watchUnit == true, "watching the unit")
    -- straight on to a bag item (no hide between): a clean record (1.6.0 kept 'a unit' until it hid)
    T:SetOwner(UIParent, "ANCHOR_RIGHT")
    assert(S.gen == gen + 1 and S.unit == false and S.watchUnit == false and S.startFocus == nil, "fresh")
    """

@test("lifecycle: a world tooltip that comes back with nothing new in it (a ghost) is hidden again; something new clears it")
def _():
    """
    local S, T = NS.Anchor.state, GameTooltip
    NS.db.instantHide = true
    GameTooltip_SetDefaultAnchor(T, UIParent); T:Show()
    T.GetUnit = function() return "Defias", "mouseover" end
    MOCK.units.mouseover = { exists = true }
    MOCK.Post(Enum.TooltipDataType.Unit, T, {})
    T:Hide()
    assert(S.ghost == true and S.unit == false)
    T:Show()
    assert(not T._shown, "the ghost hidden again")
    GameTooltip_SetDefaultAnchor(T, UIParent); T:Show()
    assert(T._shown and S.ghost == false, "a new tooltip shows")
    """

@test("lifecycle: a world unit's tooltip goes when the game's mouseover unit is gone")
def _():
    """
    local S, T = NS.Anchor.state, GameTooltip
    NS.db.instantHide = true
    GameTooltip_SetDefaultAnchor(T, UIParent); T:Show()
    T.GetUnit = function() return "Defias", "mouseover" end
    MOCK.units.mouseover = { exists = true }
    MOCK.Post(Enum.TooltipDataType.Unit, T, {})
    MOCK.Update(0.06)
    assert(T._shown, "still hovered")
    MOCK.units.mouseover = { exists = false }
    MOCK.Update(0.06)
    assert(not T._shown, "hidden when the unit is gone")
    """

@test("owners: hidden once the mouse has been over the frame and left it; a frame the mouse never was on keeps it; a hidden frame takes it")
def _():
    """
    local S, T = NS.Anchor.state, GameTooltip
    NS.db.instantHide = true
    local f = MOCK.obj("SomeButton", UIParent)
    -- shown for a frame the mouse isn't on (an addon, the keyboard): left alone (1.6.0 hid it in 0.1 s)
    f._over = false
    GameTooltip_SetDefaultAnchor(T, f); T:Show()
    for _ = 1, 10 do MOCK.Update(0.05) end
    assert(T._shown and S.owner == f and not S.ownerSeen, "kept")
    -- the mouse comes over it, then leaves
    f._over = true; MOCK.Update(0.05)
    assert(S.ownerSeen)
    f._over = false; MOCK.Update(0.05); assert(T._shown, "a moment off it")
    MOCK.Update(0.06); assert(not T._shown, "gone after 0.1 s off it")
    -- a frame that hides while its tooltip is up
    GameTooltip_SetDefaultAnchor(T, f); T:Show()
    f._over = true; MOCK.Update(0.05)
    f._shown = false; MOCK.Update(0.05)
    assert(not T._shown, "its frame gone: hidden at once")
    """

@test("look: Blizzard style puts back the border's own alpha and colour (not 1 and the default)")
def _():
    """
    local T = GameTooltip
    -- a fresh tooltip whose border another addon keeps faded and tinted
    local tip = MOCK.Tooltip("ShoppingTooltip1")
    tip.NineSlice._alpha = 0.6
    tip.NineSlice.GetBorderColor = function() return 0.1, 0.2, 0.3 end
    local set
    tip.NineSlice.SetBorderColor = function(_, r, g, b) set = { r, g, b } end
    NS.db.look = "addon"
    NS.Look.Adopt(tip); tip:Show()
    assert(tip.NineSlice._alpha == 0, "JTT style: the game's border faded out")
    NS.db.look = "blizzard"; NS.Look.Refresh()
    assert(tip.NineSlice._alpha == 0.6, "its own alpha back: " .. tostring(tip.NineSlice._alpha))
    assert(set and set[1] == 0.1 and set[3] == 0.3, "its own border colour back")
    """

@test("late tooltips: one of ours made after login is styled the first time JTT writes to it, once")
def _():
    """
    NS.db.look = "addon"
    local tip = MOCK.Tooltip("ShoppingTooltip3")
    assert(not NS.Look.adopted[tip])
    tip:AddLine("Some Item")
    MOCK.Post(Enum.TooltipDataType.Item, tip, { id = 1 })
    assert(NS.Look.adopted[tip], "adopted")
    tip:Show()
    assert(NS.Look.skins[tip] and NS.Look.skins[tip]._shown, "styled")
    local n = 0
    local old = tip._scripts.OnShow
    MOCK.Post(Enum.TooltipDataType.Item, tip, { id = 1 })
    assert(tip._scripts.OnShow == old, "hooked once")
    -- not ours (an addon's hidden scanning tooltip): never touched
    local scan = MOCK.Tooltip("SomeAddonScanTooltip")
    MOCK.Post(Enum.TooltipDataType.Item, scan, { id = 1 })
    assert(not NS.Look.adopted[scan] and scan:NumLines() == 0)
    """

@test("compatibility: a tooltip moved after JTT placed it is counted; one left alone isn't; /jtt compat reports")
def _():
    """
    NS.db.anchor = "cursor"
    local T = GameTooltip
    GameTooltip_SetDefaultAnchor(T, UIParent); T:Show()
    MOCK.RunTimers()
    assert(NS.Anchor.placement.placed == 1 and NS.Anchor.placement.moved == 0, "left alone")
    GameTooltip_SetDefaultAnchor(T, UIParent); T:Show()
    local other = MOCK.obj("TipTacAnchor", UIParent)
    T:SetPoint("BOTTOMRIGHT", other, "BOTTOMRIGHT", 0, 0) -- another addon moves it
    MOCK.RunTimers()
    assert(NS.Anchor.placement.moved == 1 and NS.Anchor.placement.lastBy == "TipTacAnchor")
    -- a check for an earlier tooltip is dropped
    GameTooltip_SetDefaultAnchor(T, UIParent); T:Show()
    T:SetOwner(UIParent, "ANCHOR_RIGHT")
    T:SetPoint("BOTTOMRIGHT", other, "BOTTOMRIGHT", 0, 0)
    MOCK.RunTimers()
    assert(NS.Anchor.placement.moved == 1, "a newer tooltip isn't counted against the old placement")
    PRINTS = {}
    SlashCmdList.JUSTTHETOOLTIP("compat")
    local t = table.concat(PRINTS, " / ")
    assert(t:find("2 moved", 1, true) == nil and t:find("1 moved by something else", 1, true) and t:find("Questie: absent", 1, true), t)
    """

# ---------------------------------------------------------------------------------------------
# M3: the information engine
# ---------------------------------------------------------------------------------------------
@test("facts: an item's kind is known before the client has it (GetItemInfoInstant); level and quality once it has")
def _():
    """
    local F = NS.Facts
    MOCK.instant = { [7000] = { equipLoc = "INVTYPE_CHEST", classID = 4 } }
    local it = F.Item(nil, { id = 7000 })
    assert(it.id == 7000 and it.link == "item:7000" and it.classID == 4 and it.equipLoc == "INVTYPE_CHEST", "kind known")
    assert(it.cached == false and it.level == nil and it.quality == nil, "level and quality not yet")
    MOCK.items[7000] = { level = 33, equipLoc = "INVTYPE_CHEST", classID = 4, quality = 3 }
    it = F.Item(nil, { id = 7000 })
    assert(it.cached and it.level == 33 and it.quality == 3)
    assert(F.Item(nil, nil).id == nil, "nothing to go on: an empty record, no error")
    """

@test("facts: each unit detail is asked of the game once per tooltip, shared by the target line and the colours")
def _():
    """
    local calls = {}
    for _, fn in ipairs({ "UnitIsPlayer", "UnitClass", "UnitReaction" }) do
      local old = _G[fn]
      _G[fn] = function(t, ...) local k = fn .. ":" .. t; calls[k] = (calls[k] or 0) + 1; return old(t, ...) end
    end
    local T = GameTooltip
    T.GetUnit = function() return "Defias", "mouseover" end
    MOCK.units.mouseover = { exists = true, isPlayer = false, reaction = 2 }
    T:ClearLines(); T:AddLine("Defias"); T:SetOwner(UIParent)
    MOCK.Post(Enum.TooltipDataType.Unit, T, {})
    assert(calls["UnitIsPlayer:mouseover"] == 1 and calls["UnitReaction:mouseover"] == 1,
      "once each (1.7.0 asked UnitIsPlayer twice): " .. tostring(calls["UnitIsPlayer:mouseover"]))
    """

@test("categories: one failing leaves the others; its error is kept and said once; /jtt info lists it")
def _():
    """
    MOCK.items[19019] = { level = 80, equipLoc = "INVTYPE_WEAPONMAINHAND", classID = 2, quality = 5 }
    NS.Sources.Add = function() error("sources broke") end
    local T = GameTooltip
    PRINTS = {}
    T:ClearLines(); T:AddLine("Thunderfury")
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 19019 })
    T:ClearLines(); T:AddLine("Thunderfury")
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 19019 })
    assert(GameTooltipTextLeft2._text:find("Item level 80", 1, true) and GameTooltipTextLeft3._text:find("Item ID: 19019", 1, true),
      "the level and the ID still there")
    assert(NS.Facts.errors.sources.n == 2, "kept")
    local said = 0
    for _, p in ipairs(PRINTS) do if p:find("an error in", 1, true) then said = said + 1 end end
    assert(said == 1, "said once: " .. said)
    local info = table.concat(NS.Facts.InfoLines(), " / ")
    assert(info:find("Where gear comes from: on; available; Verified in WoW Forever; errors: 2", 1, true), info)
    """

@test("categories: one the client can't do is skipped quietly and listed as not available")
def _():
    """
    C_Item.GetItemInfo = nil; GetItemInfo = nil
    MOCK.items[19019] = { level = 80, equipLoc = "INVTYPE_WEAPONMAINHAND", classID = 2 }
    local T = GameTooltip
    PRINTS = {}
    T:ClearLines(); T:AddLine("Thunderfury")
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 19019 })
    assert(T:NumLines() == 2 and GameTooltipTextLeft2._text:find("Item ID", 1, true), "only the ID")
    assert(#PRINTS == 0, "no error said")
    assert(table.concat(NS.Facts.InfoLines(), " / "):find("Item level: on; not on this client (C_Item.GetItemInfo|GetItemInfo)", 1, true))
    """

@test("duplicates: an item level or target line already there isn't added; a second pass on the same tooltip adds nothing")
def _():
    """
    MOCK.items[19019] = { level = 80, equipLoc = "INVTYPE_WEAPONMAINHAND", classID = 2, quality = 5 }
    JustTheTooltipSources = { items = { [19019] = "c164" }, quests = {}, npcs = {}, objects = {}, instances = {}, skills = { [164] = "Blacksmithing" } }
    local T = GameTooltip
    -- another addon's item level
    T:ClearLines(); T:AddLine("Thunderfury"); T:AddLine("Item Level: 80")
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 19019 })
    for i = 3, T:NumLines() do assert(not GameTooltipTextLeft3._text:find("Item level", 1, true)) end
    -- the same tooltip written to twice: one of each JTT line
    T:ClearLines(); T:AddLine("Thunderfury")
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 19019 })
    local n = T:NumLines()
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 19019 })
    assert(T:NumLines() == n and n == 4, "level, source, ID once each: " .. n .. " then " .. T:NumLines())
    -- another addon's target line
    T.GetUnit = function() return "Bob", "mouseover" end
    MOCK.units.mouseovertarget = { exists = true, isMe = false, name = "Kurran" }
    T:ClearLines(); T:AddLine("Bob"); T:AddLine("Targeting: Kurran")
    MOCK.Post(Enum.TooltipDataType.Unit, T, {})
    assert(T:NumLines() == 2, "no second target line")
    """

@test("provenance: each source line says where it came from and how far to trust it; /jtt source lists them all")
def _():
    """
    JustTheTooltipSources = { items = { [500] = "q10;d20:15.5,21;c164" }, quests = { [10] = "A Quest|20|" },
      npcs = { [20] = "Hogger|11|11|2|12|", [21] = "Gnoll|10|10|0|12|" }, objects = {}, instances = {}, skills = { [164] = "Blacksmithing" } }
    local L = NS.Sources.Explain(500)
    local t = table.concat(L, " / ")
    assert(L[1]:find("item 500: 4 sources known", 1, true), L[1])
    assert(t:find("Quest: A Quest (Level 20) | from JTT's data (QuestieDB, WoW: Forever) | database", 1, true), t)
    assert(t:find("Hogger", 1, true) and t:find("listed by Classic 1.12 drop chance (not Forever's) | Classic 1.12 chance 15.5%", 1, true), t)
    assert(t:find("Crafted: Blacksmithing | from JTT's data (QuestieDB, WoW: Forever) | the game client's tables", 1, true), t)
    -- the tooltip itself stays clean: no provenance on it
    local T = GameTooltip
    T:ClearLines(); T:AddLine("Item")
    NS.Sources.Add(T, 500)
    for i = 1, T:NumLines() do
      local l = _G["GameTooltipTextLeft" .. i]._text or ""
      assert(not l:find("from ", 1, true) and not l:find("1.12", 1, true), l)
    end
    PRINTS = {}
    SlashCmdList.JUSTTHETOOLTIP("source item:500")
    assert(PRINTS[1] and PRINTS[1]:find("item 500", 1, true))
    """

# ---------------------------------------------------------------------------------------------
# M4: customization and presentation
# ---------------------------------------------------------------------------------------------
@test("where each line shows: a line turned off on comparisons or chat links stays on the game's tooltip")
def _():
    """
    MOCK.items[19019] = { level = 80, equipLoc = "INVTYPE_WEAPONMAINHAND", classID = 2 }
    NS.db.where.itemId = { compare = false }
    NS.db.where.spellId = { ref = false }
    local cmp = MOCK.Tooltip("ShoppingTooltip1")
    cmp:AddLine("x"); MOCK.Post(Enum.TooltipDataType.Item, cmp, { id = 19019 })
    local function has(tip, what)
      for i = 1, tip:NumLines() do if (_G[tip:GetName() .. "TextLeft" .. i]._text or ""):find(what, 1, true) then return true end end
    end
    assert(not has(cmp, "Item ID") and has(cmp, "Item level 80"), "comparison: no ID, the level still")
    local T = GameTooltip; T:ClearLines(); T:AddLine("x")
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 19019 })
    assert(has(T, "Item ID: 19019"), "the game's tooltip: the ID")
    ItemRefTooltip:ClearLines(); ItemRefTooltip:AddLine("x")
    MOCK.Post(Enum.TooltipDataType.Spell, ItemRefTooltip, { id = 5 })
    assert(not has(ItemRefTooltip, "Spell ID"), "a spell's chat link: off")
    -- a chat link hovered (the game's tooltip, owned by the chat window): a chat link too
    local chat = MOCK.obj("ChatFrame1", UIParent)
    local inner = MOCK.obj(nil, chat)
    T:ClearLines(); T:AddLine("x"); T:SetOwner(inner, "ANCHOR_CURSOR")
    MOCK.Post(Enum.TooltipDataType.Spell, T, { id = 5 })
    assert(not has(T, "Spell ID"), "hovered in chat: counts as a chat link")
    T:ClearLines(); T:AddLine("x"); T:SetOwner(UIParent, "ANCHOR_CURSOR")
    MOCK.Post(Enum.TooltipDataType.Spell, T, { id = 5 })
    assert(has(T, "Spell ID: 5"), "elsewhere: the game's")
    """

@test("where each line shows: the settings' boxes tick off and on again (1.9.0's untick turned it straight back on)")
def _():
    """
    NS.SetShowsOn("itemId", "compare", false)
    assert(NS.ShowsOn("itemId", "compare") == false and NS.db.where.itemId.compare == false, "off")
    assert(NS.ShowsOn("itemId", "main") == true, "the others still on")
    NS.SetShowsOn("itemId", "compare", true)
    assert(NS.ShowsOn("itemId", "compare") == true and NS.db.where.itemId.compare == nil, "on again")
    """

@test("settings window (2.1.0): the game's Settings design, six pages, every setting searchable; profiles switch from it")
def _():
    """
    MinimalSliderWithSteppersMixin = MinimalSliderWithSteppersMixin or { Label = { Right = 2 }, Event = { OnValueChanged = "OnValueChanged" } }
    local printed
    local p0 = NS.Print; NS.Print = function(m) printed = m end
    local w = NS.OpenOptions()
    NS.Print = p0
    assert(w and w.index and w._shown, tostring(printed))
    local per, where = {}, {}
    for _, e in ipairs(w.index) do per[e.page] = (per[e.page] or 0) + 1; where[e.label] = e.page end
    for i = 1, 6 do assert((per[i] or 0) >= 2, "page " .. i .. ": " .. tostring(per[i])) end
    assert(where["Tooltips go"] == 1 and where["Distance sideways"] == 1 and where["Size"] == 2 and where["Hide in combat"] == 3
      and where["Item level on gear"] == 3 and where["Show every detail"] == 4 and where["New profile"] == 5 and where["Tooltip position"] == 6)
    w.Refresh()
    for i = 1, 6 do w.Select(i) end
    assert(NS.NewProfile("Raid") and NS.ProfileName() == "Raid", "a profile, the window refreshed with it")
    NS.UseProfile(nil)
    """

@test("order: the item lines in the order chosen; an old or damaged order still has every line once")
def _():
    """
    MOCK.items[19019] = { level = 80, equipLoc = "INVTYPE_WEAPONMAINHAND", classID = 2 }
    JustTheTooltipSources = { items = { [19019] = "c164" }, quests = {}, npcs = {}, objects = {}, instances = {}, skills = { [164] = "Blacksmithing" } }
    NS.db.itemOrder = { "itemId", "itemLevel", "sources" }
    local T = GameTooltip; T:ClearLines(); T:AddLine("x")
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 19019 })
    assert(GameTooltipTextLeft2._text:find("Item ID", 1, true) and GameTooltipTextLeft3._text:find("Item level", 1, true)
      and GameTooltipTextLeft4._text:find("Source", 1, true))
    NS.db.itemOrder = { "itemId", "nonsense", "itemId" }
    local o = NS.ItemOrder()
    assert(#o == 4 and o[1] == "itemId" and o[2] == "itemLevel" and o[3] == "sources" and o[4] == "itemValue", "1.10.0's item value added at the end")
    NS.db.itemOrder = nil
    assert(#NS.ItemOrder() == 4, "missing: the default order")
    assert(NS.MoveItemLine("sources", -1) and NS.ItemOrder()[1] == "sources" and not NS.MoveItemLine("sources", -1), "moved up; first can't go higher")
    """

@test("detail key: held, every source tagged with where it came from, and IDs even when off; let go, the usual three")
def _():
    """
    JustTheTooltipSources = { items = { [600] = "d1,2,3,4,5" }, quests = {},
      npcs = { [1] = "A|5|5|0|12|", [2] = "B|5|5|0|12|", [3] = "C|5|5|0|12|", [4] = "D|5|5|0|12|", [5] = "E|5|5|0|12|" },
      objects = {}, instances = {} }
    NS.db.detailKey, NS.db.ids = "ALT", false
    local T = GameTooltip
    local function text() local t = {} for i = 1, T:NumLines() do t[#t + 1] = _G["GameTooltipTextLeft" .. i]._text or "" end return table.concat(t, " / ") end
    T:ClearLines(); T:AddLine("x")
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 600 })
    assert(not text():find("Item ID", 1, true) and text():find("+2 more", 1, true) and not text():find("JTT data", 1, true), "not held: " .. text())
    MOCK.alt = true
    T:ClearLines(); T:AddLine("x")
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 600 })
    local t = text()
    assert(t:find("Item ID: 600", 1, true) and not t:find("more", 1, true), "held: " .. t)
    local n = 0 for _ in t:gmatch("%(JTT data%)") do n = n + 1 end
    assert(n == 5, "five tagged: " .. n)
    -- sources the data only counts (it names up to 12): said so, held
    JustTheTooltipSources.items[601] = "d1,2,3,4,5+4"
    T:ClearLines(); T:AddLine("x")
    MOCK.Post(Enum.TooltipDataType.Item, T, { id = 601 })
    assert(text():find("+4 more: 4 not named (Just the Tooltip! names up to 12 of each kind)", 1, true), text())
    -- pressing the key over a shown tooltip shows it again (RefreshData)
    local refreshed = 0
    T.RefreshData = function() refreshed = refreshed + 1 end
    T:Show()
    MOCK.Fire("MODIFIER_STATE_CHANGED", "LALT", 1)
    MOCK.Fire("MODIFIER_STATE_CHANGED", "LSHIFT", 1)
    assert(refreshed == 1, "only for the detail key: " .. refreshed)
    """

SAVED_OLD = """
JustTheTooltipDB = { anchor = "cursor", scale = 1.2, ids = false }
"""

@test("profiles: older saved settings are the shared ones; a profile is independent; per character; deleting one goes back to shared", pre=SAVED_OLD)
def _():
    """
    assert(NS.db == JustTheTooltipDB and NS.db.anchor == "cursor" and NS.db.scale == 1.2 and NS.db.ids == false, "1.8.0's settings kept, shared")
    assert(NS.db.where and NS.db.detailKey == "none", "new settings filled")
    assert(NS.NewProfile("Raid") and NS.ProfileName() == "Raid" and JustTheTooltipCharDB.profile == "Raid")
    assert(NS.db ~= JustTheTooltipDB and NS.db.anchor == "cursor", "a copy of the settings in use")
    NS.db.scale = 0.8
    assert(JustTheTooltipDB.scale == 1.2, "the shared settings untouched")
    NS.UseProfile(nil); assert(NS.db.scale == 1.2 and NS.ProfileName() == nil)
    NS.UseProfile("Raid"); assert(NS.db.scale == 0.8)
    assert(not NS.NewProfile("Raid") and not NS.NewProfile("  "), "taken or empty: refused")
    assert(not NS.UseProfile("Nope"))
    NS.DeleteProfile("Raid"); assert(NS.ProfileName() == nil and NS.db == JustTheTooltipDB, "back to shared")
    -- a character still set to a profile deleted elsewhere: shared at its next login
    JustTheTooltipCharDB.profile = "Gone"; NS.LoadDB()
    assert(NS.db == JustTheTooltipDB and JustTheTooltipCharDB.profile == nil)
    """

@test("size: at 100% a tooltip keeps its own size (another addon's); another size is applied; back to 100%, its own again")
def _():
    """
    local tip = MOCK.Tooltip("ShoppingTooltip2")
    tip._scale = 0.9
    NS.db.scale = 1
    NS.Look.Adopt(tip); tip:Show()
    assert(tip._scale == 0.9, "kept: " .. tip._scale)
    NS.db.scale = 1.2; NS.Look.Refresh(); assert(tip._scale == 1.2)
    NS.db.scale = 1; NS.Look.Refresh(); assert(tip._scale == 0.9, "its own again")
    """

@test("/jtt source: a drop NeedRoll's newer line replaces on the tooltip is marked so")
def _():
    """
    JustTheTooltipSources = { items = { [700] = "d1" }, quests = {}, npcs = { [1] = "Hogger|11|11|3|0|" }, objects = {}, instances = {} }
    NeedRollDB = {}
    C_AddOns = { IsAddOnLoaded = function(n) return n == "NeedRoll" end }
    local real = CreateFrame
    CreateFrame = function(kind, name, ...)
      if kind == "GameTooltip" then
        local t = MOCK.Tooltip(name)
        t.SetItemByID = function(s) s:ClearLines(); s:AddLine("Item"); s:AddLine("|A:Dungeon:14:14|a Hogger - The Stockade") end
        return t
      end
      return real(kind, name, ...)
    end
    NS.db.sources = true
    NS.Sources.Hold()
    local t = table.concat(NS.Sources.Explain(700), " / ")
    assert(t:find("Boss: Hogger | from JTT's data (QuestieDB, WoW: Forever) | database | not on the tooltip: NeedRoll's newer line for this dungeon replaces it", 1, true), t)
    assert(t:find("Dungeon: Hogger - The Stockade | from NeedRoll, in game", 1, true), t)
    """

# ---------------------------------------------------------------------------------------------
# M5: expanded information and the source data
# ---------------------------------------------------------------------------------------------
@test("NPC ID: a creature's from its GUID (the 6th part), never a player's or pet's; shown when turned on or with the detail key")
def _():
    """
    local F = NS.Facts
    assert(F.NpcFromGUID("Creature-0-1465-0-2105-448-000043F59F") == 448, "Hogger, the wiki's example")
    assert(F.NpcFromGUID("Vehicle-0-4170-0-41-68662-00000F4B37") == 68662)
    assert(F.NpcFromGUID("Player-1234-0ABCDEF") == nil and F.NpcFromGUID("Pet-0-1-0-0-416-01") == nil and F.NpcFromGUID(nil) == nil)
    local T = GameTooltip
    T.GetUnit = function() return "Hogger", "mouseover" end
    MOCK.units.mouseover = { exists = true, isPlayer = false, reaction = 2 }
    UnitGUID = function() return "Creature-0-1465-0-2105-448-000043F59F" end
    local function lines() local t = {} for i = 1, T:NumLines() do t[#t + 1] = _G["GameTooltipTextLeft" .. i]._text or "" end return table.concat(t, " / ") end
    T:ClearLines(); T:AddLine("Hogger"); MOCK.Post(Enum.TooltipDataType.Unit, T, {})
    assert(not lines():find("NPC ID", 1, true), "off by default")
    NS.db.npcIds = true
    T:ClearLines(); T:AddLine("Hogger"); MOCK.Post(Enum.TooltipDataType.Unit, T, {})
    assert(lines():find("NPC ID: 448", 1, true), lines())
    UnitGUID = function() return MOCK.SECRET end
    T:ClearLines(); T:AddLine("Hogger"); MOCK.Post(Enum.TooltipDataType.Unit, T, {})
    assert(not lines():find("NPC ID", 1, true), "a hidden GUID: no line, no error")
    """

@test("item value: how many you have and what they sell for together; none only with the detail key")
def _():
    """
    local V = NS.Info.ValueText
    assert(V(12, 10) == "You have 12 (sell for 1|cffc7c7cfs|r 20|cffeda55fc|r)", V(12, 10))
    assert(V(1, 25000):find("2|cffffd700g|r 50|cffc7c7cfs|r", 1, true), "gold and silver")
    assert(V(3, 0) == "You have 3" and V(0, 10) == nil and V(0, 10, true) == "You have none" and V(nil, 10) == nil)
    MOCK.items[2589] = { level = 5, equipLoc = "", classID = 7 }
    C_Item.GetItemCount = function() return 20 end
    local T = GameTooltip
    T:ClearLines(); T:AddLine("Linen Cloth"); MOCK.Post(Enum.TooltipDataType.Item, T, { id = 2589 })
    for i = 1, T:NumLines() do assert(not (_G["GameTooltipTextLeft" .. i]._text or ""):find("You have", 1, true), "off by default") end
    NS.db.itemValue = true
    T:ClearLines(); T:AddLine("Linen Cloth"); MOCK.Post(Enum.TooltipDataType.Item, T, { id = 2589 })
    local found
    for i = 1, T:NumLines() do if (_G["GameTooltipTextLeft" .. i]._text or ""):find("You have 20 (sell for", 1, true) then found = true end end
    assert(found, "shown when on")
    """

@test("spells: with the detail key, whether you know it (not on buffs); the newer API first, the older as a fallback")
def _():
    """
    NS.db.detailKey = "ALT"; MOCK.alt = true
    C_SpellBook = { IsSpellKnown = function(id) return id == 403 end }
    local T = GameTooltip
    local function last() return _G["GameTooltipTextLeft" .. T:NumLines()]._text or "" end
    T:ClearLines(); T:AddLine("Lightning Bolt"); MOCK.Post(Enum.TooltipDataType.Spell, T, { id = 403 })
    assert(last():find("You know this spell", 1, true), last())
    T:ClearLines(); T:AddLine("Chain Lightning"); MOCK.Post(Enum.TooltipDataType.Spell, T, { id = 421 })
    assert(last():find("Not learned", 1, true), last())
    T:ClearLines(); T:AddLine("Lightning Shield"); MOCK.Post(Enum.TooltipDataType.UnitAura, T, { id = 403 })
    assert(not last():find("know", 1, true), "not on a buff")
    C_SpellBook = nil; IsPlayerSpell = function() return true end
    T:ClearLines(); T:AddLine("x"); MOCK.Post(Enum.TooltipDataType.Spell, T, { id = 1 })
    assert(last():find("You know this spell", 1, true), "the older API")
    MOCK.alt = false
    T:ClearLines(); T:AddLine("x"); MOCK.Post(Enum.TooltipDataType.Spell, T, { id = 1 })
    assert(not last():find("know", 1, true), "not without the key")
    """

@test("places: with the detail key, where in the zone a vendor, creature or chest out in the world is; /jtt source too; the data's format said")
def _():
    """
    C_Map = { GetAreaInfo = function(id) return ({ [40] = "Westfall" })[id] end }
    JustTheTooltipSources = { version = 2, build = "1.60.1.71139", made = "2026-11-27",
      items = { [800] = "v1;d2" }, quests = {},
      npcs = { [1] = "Seller|10|10|0|40|AH|52|64", [2] = "Old Murk-Eye|20|20|1|40||" }, objects = {}, instances = {} }
    NS.db.sources = true
    local T = GameTooltip
    local function text() local t = {} for i = 1, T:NumLines() do t[#t + 1] = (_G["GameTooltipTextLeft" .. i]._text or "") .. "|" .. (_G["GameTooltipTextRight" .. i] and _G["GameTooltipTextRight" .. i]._text or "") end return table.concat(t, " / ") end
    T:ClearLines(); T:AddLine("x"); NS.Sources.Add(T, 800)
    assert(text():find("Westfall|r", 1, true) and not text():find("52, 64", 1, true), "no place without the key: " .. text())
    T:ClearLines(); T:AddLine("x"); NS.Sources.Add(T, 800, true)
    assert(text():find("Westfall 52, 64", 1, true), "with it: " .. text())
    local ex = table.concat(NS.Sources.Explain(800), " / ")
    assert(ex:find("Vendor: Seller (Westfall 52, 64)", 1, true) and ex:find("Old Murk-Eye", 1, true), ex)
    assert(NS.Sources.loadState == "loaded (format 2, game build 1.60.1.71139, made 2026-11-27)", NS.Sources.loadState)
    """

@test("data format: older data still reads (no places); newer data is reported as needing an update")
def _():
    """
    JustTheTooltipSources = { version = 3, items = {}, npcs = {}, quests = {}, objects = {} }
    NS.Sources.Explain(1)
    assert(NS.Sources.loadState:find("format 3", 1, true) and NS.Sources.loadState:find("update it", 1, true), NS.Sources.loadState)
    """

# ---------------------------------------------------------------------------------------------
# M6: diagnostics
# ---------------------------------------------------------------------------------------------
@test("lifecycle: each tooltip's place, what it showed, and what ended it (JTT's reason or the game); the last 20")
def _():
    """
    NS.db.instantHide, NS.db.anchor = true, "cursor"
    local T = GameTooltip
    -- a world unit, hidden by JTT when the unit's gone
    GameTooltip_SetDefaultAnchor(T, UIParent); T:Show()
    T.GetUnit = function() return "Defias", "mouseover" end
    MOCK.units.mouseover = { exists = true }
    MOCK.Post(Enum.TooltipDataType.Unit, T, {})
    MOCK.now = MOCK.now + 1.5
    MOCK.units.mouseover = { exists = false }
    MOCK.Update(0.06)
    local r = NS.Anchor.history[#NS.Anchor.history]
    assert(r.place == "following the cursor" and r.about == "a unit in the world" and r.ended == "JTT: no unit under the mouse", tostring(r.ended))
    assert(math.abs(r.endedAt - r.at - 1.5) < 1e-6)
    -- it comes back with nothing new: counted on the same tooltip
    T:Show()
    assert(r.ghosts == 1 and not T._shown)
    -- a bag item the game hides
    T:SetOwner(MOCK.obj("ContainerFrame1Item1", UIParent), "ANCHOR_RIGHT"); T:Show(); T:Hide()
    r = NS.Anchor.history[#NS.Anchor.history]
    assert(r.owner == "ContainerFrame1Item1" and r.anchor == "ANCHOR_RIGHT" and r.ended == "the game (or another addon)")
    -- a button refreshing its tooltip while it's up; then another frame taking it over
    local btn = MOCK.obj("ActionButton11", UIParent)
    T:SetOwner(btn, "ANCHOR_NONE"); T:Show(); T:SetOwner(btn, "ANCHOR_NONE")
    assert(NS.Anchor.history[#NS.Anchor.history - 1].ended == "refreshed by the same frame")
    T:SetOwner(MOCK.obj("ActionButton10", UIParent), "ANCHOR_NONE")
    assert(NS.Anchor.history[#NS.Anchor.history - 1].ended == "replaced (shown for ActionButton10)")
    T:Hide()
    -- begun but never shown (nothing to show), then another
    T:SetOwner(UIParent, "ANCHOR_NONE"); T:SetOwner(UIParent, "ANCHOR_NONE")
    assert(NS.Anchor.history[#NS.Anchor.history - 1].ended == "never shown (nothing to show)")
    -- no name: its place in the interface
    local slot = MOCK.obj(nil, UIParent); slot.GetDebugName = function() return "ContainerFrame1.Item3" end
    T:SetOwner(slot, "ANCHOR_NONE")
    assert(NS.Anchor.history[#NS.Anchor.history].owner == "ContainerFrame1.Item3")
    for _ = 1, 30 do T:SetOwner(UIParent, "ANCHOR_NONE") end
    assert(#NS.Anchor.history == 20, "the last 20")
    PRINTS = {}
    SlashCmdList.JUSTTHETOOLTIP("lifecycle")
    assert(#PRINTS == 10 and PRINTS[1]:find("#", 1, true), tostring(PRINTS[1]))
    """

@test("/jtt api: every function JTT uses, present or missing, and how far it's verified")
def _():
    """
    UnitGUID = function() end; C_TooltipInfo = { GetWorldCursor = function() end }
    local L = NS.Facts.ApiLines()
    assert(L[1]:find("game functions", 1, true))
    local t = table.concat(L, " / ")
    assert(t:find("C_Item.GetItemInfo or GetItemInfo: present as C_Item.GetItemInfo | item level, quality, sell price | Verified in WoW Forever", 1, true), t)
    local missing = tonumber(L[1]:match("(%d+) missing"))
    UnitGUID = nil
    assert(tonumber(NS.Facts.ApiLines()[1]:match("(%d+) missing")) == missing + 1, "a missing one counted")
    PRINTS = {}; SlashCmdList.JUSTTHETOOLTIP("api"); assert(#PRINTS == #L)
    """

@test("every tooltip type on every tooltip JTT touches: no error, the right lines")
def _():
    """
    MOCK.items[19019] = { level = 80, equipLoc = "INVTYPE_WEAPONMAINHAND", classID = 2, quality = 5 }
    UnitGUID = function() return "Creature-0-1-0-1-448-01" end
    NS.db.npcIds = true
    local tips = { GameTooltip, ItemRefTooltip }
    for _, n in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2" }) do tips[#tips + 1] = MOCK.Tooltip(n) end
    local E = Enum.TooltipDataType
    for _, tip in ipairs(tips) do
      local function has(what) for i = 1, tip:NumLines() do if (_G[tip:GetName() .. "TextLeft" .. i]._text or ""):find(what, 1, true) then return true end end end
      tip:ClearLines(); tip:AddLine("x"); MOCK.Post(E.Item, tip, { id = 19019 })
      assert(has("Item ID: 19019") and has("Item level 80"), tip:GetName() .. ": item")
      tip:ClearLines(); tip:AddLine("x"); MOCK.Post(E.Spell, tip, { id = 403 })
      assert(has("Spell ID: 403"), tip:GetName() .. ": spell")
      tip:ClearLines(); tip:AddLine("x"); MOCK.Post(E.UnitAura, tip, { id = 324 })
      assert(has("Spell ID: 324"), tip:GetName() .. ": aura")
      tip.GetUnit = function() return "Hogger", "mouseover" end
      MOCK.units.mouseover = { exists = true, isPlayer = false, reaction = 2 }
      tip:ClearLines(); tip:AddLine("Hogger"); tip:SetOwner(UIParent); MOCK.Post(E.Unit, tip, {})
      if tip == GameTooltip then assert(has("NPC ID: 448"), "unit: NPC ID") else assert(not has("NPC ID"), tip:GetName() .. ": units are the game's tooltip only") end
      MOCK.Post(E.Corpse, tip, {}); MOCK.Post(E.Object, tip, {})
    end
    assert(next(NS.Facts.errors) == nil, "no category errored")
    """

@test("/jtt compat: the versions of the addons JTT works with")
def _():
    """
    C_AddOns = { IsAddOnLoaded = function(n) return n == "Questie" or n == "FlareUI" end,
      GetAddOnMetadata = function(n) return ({ Questie = "12.15.0", FlareUI = "3.2" })[n] end }
    local t = table.concat(NS.CompatLines(), " / ")
    assert(t:find("integrations loaded: Questie 12.15.0, FlareUI 3.2", 1, true), t)
    """


def _validator():
    global count
    count += 1
    name = "source data: the real Data.lua passes the validator; a broken copy doesn't"
    try:
        sys.path.insert(0, os.path.join(ROOT, 'tools', 'sources'))
        import validate
        problems = validate.validate()
        assert not problems, problems[:5]
        import tempfile
        src = open(validate.DEFAULT, encoding='utf-8').read()
        broken = src.replace('version = 2,', 'version = 1,', 1).replace('items = {\n', 'items = {\n[1]="d99999999",\n', 1)
        with tempfile.NamedTemporaryFile('w', suffix='.lua', delete=False, encoding='utf-8') as f:
            f.write(broken)
        bad = validate.validate(f.name)
        os.unlink(f.name)
        assert any('format version' in b for b in bad) and any('99999999' in b for b in bad), bad[:5]
        print('ok   ', name)
    except Exception as e:  # noqa
        failures.append(name); print('FAIL ', name, '\n     ', e)


_validator()

if __name__ == '__main__':
    print(f"\n{count - len(failures)}/{count} passed")
    sys.exit(1 if failures else 0)
