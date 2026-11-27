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

if __name__ == '__main__':
    print(f"\n{count - len(failures)}/{count} passed")
    sys.exit(1 if failures else 0)
