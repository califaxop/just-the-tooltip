# Just the Tooltip!: source data

The "Source:" lines on gear come from `JustTheTooltip_Sources/Data.lua`. It's a separate
load-on-demand addon: it loads the first time you hover gear with Sources on, and costs nothing
before that.

## Upstream sources

| Data | From | Licence | Confidence |
|---|---|---|---|
| Quest rewards, creature drops, vendors, objects (chests), with names, levels, zones, factions | [QuestieDB](https://github.com/Questie/QuestieDB), `data/Forever` (WoW: Forever) | GPL v3 | Forever's database as the Questie team keeps it |
| Which profession makes an item; which items are gear | the game client's own tables (SkillLineAbility, SpellEffect, Item), via [wago.tools](https://wago.tools), product `wowf` | game data | the client's |
| Drop order (likeliest first) | [CMaNGOS Classic-DB](https://github.com/cmangos/classic-db), Classic 1.12 loot tables | GPL v3 | **Classic 1.12's rates, not Forever's**: used to order drops; the chances are never shown on tooltips (`/jtt source` shows them, labelled as Classic's) |
| Items missing from the data (new since it was built) | Questie in game, if installed and ready | — | as Questie's |
| Newer dungeon and raid drops and dungeon quests | NeedRoll in game, if installed | — | NeedRoll's loot tables |

Attribution is kept in three places: `Data.lua`'s header, `JustTheTooltip_Sources/README.md` and
the README's Credits. The companion folder is GPL v3 (`JustTheTooltip_Sources/LICENSE`). JTT isn't
made by or affiliated with Questie or CMaNGOS.

## Building

```
pip install lupa
python tools/sources/build.py [build]     # e.g. 1.60.1.71037; default: the latest wowf build on wago.tools
```

Everything is downloaded fresh on each run, and nothing upstream is kept in the repository.
`tools/sources/cmangos.py` reads the CMaNGOS dump for drop chances. Never edit `Data.lua` by hand.

Settings in `build.py`:

| Setting | Value | Meaning |
|---|---|---|
| `GEAR` | 2, 4 | weapons and armor only |
| `WORLD_DROP` | 12 | dropped by more creatures than this: one "World drop" line with its level range |
| `MAX_IDS` | 12 (6 before 1.10.0) | creatures, vendors and objects named per item (the rest counted as "+N more") |
| `FORMAT` | 2 | the data's format (also in `validate.py` and `Sources.lua`) |
| `RANDOM_CHEST` | 25 | a container with more pieces of gear than this is random loot |

## Format

The tables are `items`, `npcs`, `quests`, `objects`, `instances` and `skills`.
- Each item entry is a `;`-separated list of parts: `q` quests, `d` drops (`id:chance`), `v`
  vendors, `o` objects, `w` world drop levels, `c` profession, `r` random chests.
- Creatures: name | min level | max level | rank | zone | friendly to | x | y. Objects: name | zone
  | x | y. x, y (format 2) is the first spawn in that zone, 0-100, from QuestieDB; empty inside
  instances or when there's none.
- Zones are area IDs, named in game (`C_Map.GetAreaInfo`), which keeps the file small.

## Checking

```
python tools/sources/validate.py
```

It checks:
- the header's attribution (QuestieDB, CMaNGOS, GPLv3, wago.tools);
- the format version, the build and the date made;
- every item part's shape;
- every quest, creature, object and profession reference;
- every creature, object and quest row's fields, with places within 0-100;
- the counts.

Run it after every build. `tests/run_tests.py` runs it too, and checks that it catches a broken
copy.

## Versioning

- `Data.lua` records its format (`version = 2`), the game build it was made from
  (`build = "1.60.1.71139"`), the date (`made`) and its counts.
- The companion's toc has its own version (1.1.0 since format 2).
- JTT reads format 1 (no places) and format 2. Newer data than it reads is reported (`/jtt info`,
  `/jtt report`: "newer than this Just the Tooltip! reads: update it").
- The data is refreshed weekly with the Wednesday release when upstream has changed.

## Limitations

- Drop order follows Classic 1.12's loot tables, which may differ on Forever. That's why chances
  are never shown on tooltips (only in `/jtt source`, labelled as Classic's), and why NeedRoll's
  newer dungeon lines replace JTT's where it has them.
- Quests and vendors are filtered to your faction. Chests marked for the other faction are left
  out.
- Items new since the build only show sources once Questie is installed and ready (1.6.0: asked
  again until it is).
- Zone names come from the game; a zone it doesn't name is shown without one.
- Provenance (1.8.0): every line knows where it came from (JTT's data, Questie in game, NeedRoll in
  game) and how far to trust it (database; database for your faction; the client's tables;
  NeedRoll's newer loot tables; drops "listed by Classic 1.12 drop chance (not Forever's)").
  Ordinary tooltips stay clean; `/jtt source <item>` shows it all, the Classic chance included
  (labelled as Classic's).
