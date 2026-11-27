"""Checks JustTheTooltip_Sources/Data.lua (1.10.0): run after every build, and by tests/run_tests.py.

  python tools/sources/validate.py [path]     (needs: pip install lupa)

What it checks:
- the header names its upstream sources and their licences;
- the data's format version is the one Just the Tooltip! reads (FORMAT below, same as Sources.lua);
- the game build and date it was made from are there;
- every item's parts are well formed, and every quest, creature, object and profession they name
  exists;
- every creature and object row has its fields: numbers where numbers go, places within 0-100;
- the counts match the tables.

Prints each problem (at most 20) and exits 1 if there are any.
"""
import os
import re
import sys

import lupa.lua51 as lupa

FORMAT = 2
HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT = os.path.normpath(os.path.join(HERE, "..", "..", "JustTheTooltip_Sources", "Data.lua"))
PART = re.compile(r"^(q|d|v|o)([\d,:.]*)(\+\d+)?$|^w\d+-\d+$|^c\d+$|^r$")


def validate(path=DEFAULT):
    problems = []

    def bad(msg):
        problems.append(msg)

    src = open(path, encoding="utf-8").read()
    head = src[:600]
    for need in ("QuestieDB", "GPLv3", "CMaNGOS", "wago.tools"):
        if need not in head:
            bad("header doesn't name " + need)
    lua = lupa.LuaRuntime()
    lua.execute(src)
    d = lua.globals().JustTheTooltipSources
    if d is None:
        return ["JustTheTooltipSources isn't set"]
    if d["version"] != FORMAT:
        bad("format version %r, expected %d" % (d["version"], FORMAT))
    if not (isinstance(d["build"], str) and re.match(r"^\d+\.\d+\.\d+\.\d+$", d["build"])):
        bad("game build missing or malformed: %r" % d["build"])
    if not (isinstance(d["made"], str) and re.match(r"^\d{4}-\d\d-\d\d$", d["made"])):
        bad("date made missing: %r" % d["made"])

    def keys(t):
        return {} if t is None else {k: t[k] for k in t}

    # (indexed, not attributes: a Lua table's .items is lupa's own method)
    npcs, quests, objects, skills, items = (keys(d["npcs"]), keys(d["quests"]), keys(d["objects"]), keys(d["skills"]), keys(d["items"]))
    for n, row in npcs.items():
        f = row.split("|")
        if len(f) != 8:
            bad("creature %s: %d fields, expected 8" % (n, len(f)))
            continue
        if not f[0]:
            bad("creature %s: no name" % n)
        for i in (1, 2, 3, 4):
            if not f[i].lstrip("-").isdigit():
                bad("creature %s: field %d isn't a number (%r)" % (n, i + 1, f[i]))
        if f[5] not in ("", "A", "H", "AH"):
            bad("creature %s: faction %r" % (n, f[5]))
        if (f[6] == "") != (f[7] == ""):
            bad("creature %s: half a place" % n)
        elif f[6] and not (0 < float(f[6]) <= 100 and 0 < float(f[7]) <= 100):
            bad("creature %s: place outside 0-100 (%s, %s)" % (n, f[6], f[7]))
    for o, row in objects.items():
        f = row.split("|")
        if len(f) != 4 or not f[0] or not f[1].isdigit():
            bad("object %s: malformed %r" % (o, row))
    for q, row in quests.items():
        f = row.split("|")
        if len(f) != 3 or not f[0] or f[2] not in ("", "A", "H"):
            bad("quest %s: malformed %r" % (q, row))
    for iid, entry in items.items():
        for part in entry.split(";"):
            if not PART.match(part):
                bad("item %s: part %r" % (iid, part))
                continue
            kind, body = part[0], part[1:].split("+")[0]
            if kind in "qdvo":
                table = {"q": quests, "d": npcs, "v": npcs, "o": objects}[kind]
                for x in filter(None, body.split(",")):
                    ref = int(x.split(":")[0])
                    if ref not in table:
                        bad("item %s: %s %d isn't in the data" % (iid, {"q": "quest", "d": "creature", "v": "vendor", "o": "object"}[kind], ref))
            elif kind == "c" and int(part[1:]) not in skills:
                bad("item %s: profession %s isn't in the data" % (iid, part[1:]))
    c = d["count"]
    if c is None:
        bad("no counts")
    elif (c["items"], c["npcs"], c["quests"], c["objects"]) != (len(items), len(npcs), len(quests), len(objects)):
        bad("counts %r don't match the tables" % ((c["items"], c["npcs"], c["quests"], c["objects"]),))
    return problems


if __name__ == "__main__":
    p = validate(sys.argv[1] if len(sys.argv) > 1 else DEFAULT)
    for msg in p[:20]:
        print("problem:", msg)
    print("%d problem(s)" % len(p) if p else "source data OK")
    sys.exit(1 if p else 0)
