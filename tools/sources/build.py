"""Builds JustTheTooltip_Sources/Data.lua: where each piece of gear comes from.

Sources (downloaded fresh each run, nothing kept in the repo):
  - QuestieDB's WoW: Forever database (github.com/Questie/QuestieDB, data/Forever, GPLv3):
    quest rewards, creature drops, vendors, objects (chests), with names, levels and zones.
  - The game client's own tables, from wago.tools (product wowf): which profession makes an
    item (SkillLineAbility + SpellEffect "create item"), and which items are gear (Item).

Zones are stored as AreaTable IDs and named in game (C_Map.GetAreaInfo), so the file stays small.

Run:  pip install lupa && python tools/sources/build.py [build]   (build: e.g. 1.60.1.71037; default: latest wowf)
"""
import csv
import io
import os
import re
import sys
import urllib.request

import lupa.lua51 as lupa

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "JustTheTooltip_Sources", "Data.lua")
QUESTIE = "https://raw.githubusercontent.com/Questie/QuestieDB/master/data/Forever/"
WAGO = "https://wago.tools/db2/{}/csv?build={}"

GEAR = {2, 4}            # item classes: weapons, armor
WORLD_DROP = 12          # dropped by more creatures than this: a world drop
MAX_IDS = 6              # creatures / vendors / objects kept per item (the rest are counted)
ALLIANCE = 1 | 4 | 8 | 64
HORDE = 2 | 16 | 32 | 128
PROFESSIONS = {164, 165, 197, 202, 333, 171, 185, 129, 356, 186, 182, 393}


def get(url):
    req = urllib.request.Request(url, headers={"User-Agent": "JustTheTooltip-sources-builder"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def latest_build():
    html = get("https://wago.tools/builds").decode("utf-8", "replace")
    m = re.search(r'"product":"wowf","version":"([\d.]+)"', html.replace("&quot;", '"'))
    if not m:
        sys.exit("could not find the latest wowf build on wago.tools; pass one as an argument")
    return m.group(1)


def questie(lua, name, data_key):
    """Load one QuestieDB file: its data table, keyed by id."""
    src = get(QUESTIE + name).decode("utf-8")
    lua.execute(src)
    body = lua.eval("QuestieDB." + data_key)
    t = lua.execute(body) if isinstance(body, str) else body
    return {int(k): v for k, v in t.items()}


def table(t):
    return {} if t is None else {k: t[k] for k in t}


def lst(t):
    return [] if t is None else [t[k] for k in sorted(t)]


def wago(name, build):
    return list(csv.DictReader(io.StringIO(get(WAGO.format(name, build)).decode("utf-8"))))


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def main():
    build = sys.argv[1] if len(sys.argv) > 1 else latest_build()
    print("game build", build)

    lua = lupa.LuaRuntime(unpack_returned_tuples=True)
    lua.execute("QuestieDB = {}; QuestieLoader = { ImportModule = function() return QuestieDB end }")
    items = questie(lua, "foreverItemDB.lua", "itemData")
    npcs = questie(lua, "foreverNpcDB.lua", "npcData")
    quests = questie(lua, "foreverQuestDB.lua", "questData")
    objects = questie(lua, "foreverObjectDB.lua", "objectData")

    # the client's tables: gear items, and what makes them
    item_class = {int(r["ID"]): int(r["ClassID"]) for r in wago("Item", build)}
    skill_of = {}   # spell -> (skill line, skill needed)
    for r in wago("SkillLineAbility", build):
        sk = int(r["SkillLine"])
        if sk in PROFESSIONS:
            skill_of[int(r["Spell"])] = (sk, int(r["MinSkillLineRank"] or 0), int(r["TrivialSkillLineRankLow"] or 0))
    skill_names = {int(r["ID"]): r["DisplayName_lang"] for r in wago("SkillLine", build) if int(r["ID"]) in PROFESSIONS}
    crafted = {}    # item -> (skill, rank)
    for r in wago("SpellEffect", build):
        if r["Effect"] == "24" and r["EffectItemType"] not in ("", "0"):
            sp = int(r["SpellID"])
            if sp in skill_of:
                sk, rank, low = skill_of[sp]
                item = int(r["EffectItemType"])
                need = rank or low
                if item not in crafted or need < crafted[item][1]:
                    crafted[item] = (sk, need)

    def is_gear(iid, row=None):
        cls = item_class.get(iid)
        if cls is None and row is not None:
            cls = row[12]
        return cls in GEAR

    used_npc, used_quest, used_obj = set(), set(), set()
    out_items = {}
    for iid in sorted(set(int(k) for k in items) | set(crafted)):
        row = items[iid] if iid in items else None
        if not is_gear(iid, row):
            continue
        parts = []
        if row is not None:
            qr = [q for q in lst(row[6]) if q in quests]
            if qr:
                parts.append("q" + ",".join(str(q) for q in qr[:MAX_IDS]))
                used_quest.update(qr[:MAX_IDS])
            drops = [n for n in lst(row[2]) if n in npcs]
            if len(drops) > WORLD_DROP:
                lv = [x for n in drops for x in (npcs[n][4], npcs[n][5]) if x]
                parts.append("w%d-%d" % (min(lv or [0]), max(lv or [0])))
            elif drops:
                # bosses and elites first, then by level
                drops.sort(key=lambda n: (-(npcs[n][6] or 0), -(npcs[n][5] or 0)))
                keep = drops[:MAX_IDS]
                parts.append("d" + ",".join(str(n) for n in keep) + ("+%d" % (len(drops) - len(keep)) if len(drops) > len(keep) else ""))
                used_npc.update(keep)
            vend = [n for n in lst(row[14]) if n in npcs]
            if vend:
                keep = vend[:MAX_IDS]
                parts.append("v" + ",".join(str(n) for n in keep) + ("+%d" % (len(vend) - len(keep)) if len(vend) > len(keep) else ""))
                used_npc.update(keep)
            objs = [o for o in lst(row[3]) if o in objects]
            if objs:
                keep = objs[:MAX_IDS]
                parts.append("o" + ",".join(str(o) for o in keep) + ("+%d" % (len(objs) - len(keep)) if len(objs) > len(keep) else ""))
                used_obj.update(keep)
        if iid in crafted:
            sk, need = crafted[iid]
            parts.append("c%d" % sk)  # (the skill needed isn't in the tables reliably: just the profession)
        if parts:
            out_items[iid] = ";".join(parts)

    def zone(z):
        return int(z) if z else 0

    lines = [
        "-- AUTO GENERATED by tools/sources/build.py: do not edit.",
        "-- Where gear comes from. Quest, drop, vendor and object data: QuestieDB (WoW: Forever), GPLv3,",
        "-- https://github.com/Questie/QuestieDB. Professions: the game client's tables (via wago.tools).",
        "JustTheTooltipSources = {",
        "build = %s," % lua_str(build),
        # npc: name | minLevel | maxLevel | rank | zone | friendly to ("A", "H", "AH", "")
        "npcs = {",
    ]
    for n in sorted(used_npc):
        r = npcs[n]
        lines.append("[%d]=%s," % (n, lua_str("|".join(str(x) for x in (r[1], r[4] or 0, r[5] or 0, r[6] or 0, zone(r[9]), r[13] or "")))))
    lines.append("},")
    # quest: name | level | faction ("A", "H" or "")
    lines.append("quests = {")
    for q in sorted(used_quest):
        r = quests[q]
        races = r[6] or 0
        fac = "" if not races or (races & ALLIANCE and races & HORDE) else ("A" if races & ALLIANCE else "H")
        lines.append("[%d]=%s," % (q, lua_str("|".join(str(x) for x in (r[1], r[5] or 0, fac)))))
    lines.append("},")
    # object: name | zone
    lines.append("objects = {")
    for o in sorted(used_obj):
        r = objects[o]
        lines.append("[%d]=%s," % (o, lua_str("|".join(str(x) for x in (r[1], zone(r[5]))))))
    lines.append("},")
    lines.append("skills = {")
    for sk in sorted(skill_names):
        lines.append("[%d]=%s," % (sk, lua_str(skill_names[sk])))
    lines.append("},")
    # item: ";"-separated parts: q<quests>, d<creatures>[+more], w<minLevel>-<maxLevel> (world drop),
    # v<vendors>[+more], o<objects>[+more], c<profession>
    lines.append("items = {")
    for iid in sorted(out_items):
        lines.append("[%d]=%s," % (iid, lua_str(out_items[iid])))
    lines.append("},")
    lines.append("}")
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("items %d, npcs %d, quests %d, objects %d -> %s (%d KB)" % (
        len(out_items), len(used_npc), len(used_quest), len(used_obj), OUT, os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
