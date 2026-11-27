# Just the Tooltip!: source data

The "Source:" lines on gear come from `JustTheTooltip_Sources/Data.lua`. It's a separate
load-on-demand addon: it loads the first time you hover gear with Sources on, and costs nothing
before that.

## Upstream sources

| Data | From | Licence | Confidence |
|---|---|---|---|
| Quest rewards, creature drops, vendors, objects (chests), with names, levels, zones, factions | [QuestieDB](https://github.com/Questie/QuestieDB), `data/Forever` (WoW: Forever) | GPL v3 | Forever's database as the Questie team keeps it |
| Which profession makes an item; which items are gear | the game client's own tables (SkillLineAbility, SpellEffect, Item), via [wago.tools](https://wago.tools), product `wowf` | game data | the client's |
| Drop order (likeliest first) | [CMaNGOS Classic-DB](https://github.com/cmangos/classic-db), Classic 1.12 loot tables | GPL v3 | **Classic 1.12's rates, not Forever's**: used only to order drops; the chances are never shown |
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
| `MAX_IDS` | 6 | creatures, vendors and objects kept per item (the rest counted as "+N more") |
| `RANDOM_CHEST` | 25 | a container with more pieces of gear than this is random loot |

## Format

The tables are `items`, `npcs`, `quests`, `objects`, `instances` and `skills`.
- Each item entry is a `;`-separated list of parts: `q` quests, `d` drops (`id:chance`), `v`
  vendors, `o` objects, `w` world drop levels, `c` profession, `r` random chests.
- Zones are area IDs, named in game (`C_Map.GetAreaInfo`), which keeps the file small.

## Versioning

- `Data.lua` records the game build it was made from (`build = "1.60.1.71037"`).
- The companion's toc has its own version (1.0.0).
- The data is refreshed weekly with the Wednesday release when upstream has changed.
- Planned for Milestone 5: a data version JTT checks against, so an old companion is reported.

## Limitations

- Drop order follows Classic 1.12's loot tables, which may differ on Forever. That's why chances
  are never shown, and why NeedRoll's newer dungeon lines replace JTT's where it has them.
- Quests and vendors are filtered to your faction. Chests marked for the other faction are left
  out.
- Items new since the build only show sources once Questie is installed and ready (1.6.0: asked
  again until it is).
- Zone names come from the game; a zone it doesn't name is shown without one.
- Provenance and confidence per line are planned for Milestone 3. Ordinary tooltips stay clean,
  with the detail available in a diagnostics view.
