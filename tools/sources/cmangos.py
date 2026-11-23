"""Drop chances from CMaNGOS Classic-DB (github.com/cmangos/classic-db, GPLv3): how likely a
creature is to drop an item, from its loot table (Classic 1.12 rates; WoW: Forever may differ).

    rates = drop_rates(sql_text, wanted_items)   # {(creature, item): percent}

How a loot table rolls (mangos): a row with groupid 0 rolls on its own (|chance|%); the rows of one
group give at most one item: those with a chance first, the rest (chance 0) share what's left
equally; a row with mincountOrRef < 0 rolls a shared table (reference_loot_template) with its
chance, maxcount times. An item reachable several ways: 1 - (1 - p1)(1 - p2)...
"""
import re
from collections import defaultdict

TOKEN = re.compile(r"'(?:[^'\\]|\\.)*'|[^,()]+|[(),]")


def rows(sql, table):
    """Every row of `table`'s INSERTs, as lists of raw values (numbers as text, strings quoted)."""
    head = "INSERT INTO `%s` VALUES " % table
    for line in sql.splitlines():
        if not line.startswith(head):
            continue
        row, depth = None, 0
        for tok in TOKEN.findall(line[len(head):]):
            if tok == "(":
                depth += 1
                if depth == 1:
                    row = []
            elif tok == ")":
                depth -= 1
                if depth == 0 and row is not None:
                    yield row
                    row = None
            elif tok == ",":
                continue
            elif row is not None:
                row.append(tok.strip())


def loot_tables(sql, table):
    """entry -> [(item, chance, group, mincountOrRef, maxcount)]"""
    t = defaultdict(list)
    for r in rows(sql, table):
        t[int(r[0])].append((int(r[1]), float(r[2]), int(r[3]), int(r[4]), int(r[5])))
    return t


def table_chances(entries, refs, memo, stack=()):
    """item -> chance (0-1) of it dropping from one loot table."""
    out = defaultdict(float)

    def add(item, p):
        out[item] = 1 - (1 - out[item]) * (1 - p)

    groups = defaultdict(list)
    for e in entries:
        groups[e[2]].append(e)
    for gid, es in groups.items():
        if gid == 0:
            for item, ch, _, ref, maxc in es:
                p = abs(ch) / 100.0
                if ref < 0:
                    sub = ref_chances(-ref, refs, memo, stack)
                    for it, q in sub.items():
                        add(it, 1 - (1 - p * q) ** max(1, maxc))
                else:
                    add(item, p)
        else:
            explicit = sum(abs(ch) for _, ch, *_ in es if ch != 0)
            equal = [e for e in es if e[1] == 0]
            share = max(0.0, 100.0 - explicit) / len(equal) if equal else 0.0
            for item, ch, _, ref, maxc in es:
                p = (abs(ch) if ch != 0 else share) / 100.0
                if ref < 0:
                    for it, q in ref_chances(-ref, refs, memo, stack).items():
                        add(it, p * q)
                else:
                    add(item, p)
    return out


def ref_chances(ref, refs, memo, stack):
    if ref in memo:
        return memo[ref]
    if ref in stack:  # (a loop: give up on it)
        return {}
    memo[ref] = table_chances(refs.get(ref, []), refs, memo, stack + (ref,))
    return memo[ref]


def drop_rates(sql, wanted):
    """{(creature, item): percent} for the items in `wanted`."""
    loot_id = {}
    for r in rows(sql, "creature_template"):
        lid = int(r[56])  # LootId (column 57)
        if lid:
            loot_id[int(r[0])] = lid
    loot = loot_tables(sql, "creature_loot_template")
    refs = loot_tables(sql, "reference_loot_template")
    memo, per_table, out = {}, {}, {}
    for npc, lid in loot_id.items():
        if lid not in per_table:
            per_table[lid] = {i: p for i, p in table_chances(loot.get(lid, []), refs, memo).items() if i in wanted}
        for item, p in per_table[lid].items():
            if p > 0:
                out[(npc, item)] = p * 100.0
    return out
