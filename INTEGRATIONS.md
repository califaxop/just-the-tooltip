# Just the Tooltip!: integrations

For each addon, this file separates three things:
- **Detected:** it's loaded.
- **Available:** the parts JTT uses are there and work now.
- **Used:** what JTT actually does with it.

Another addon's internals are never assumed stable just because they exist today: every part is
checked before each use, and JTT does without it when a part is missing.

| Addon | Detected by | Available when | JTT uses it to | Changes to its settings | Status |
|---|---|---|---|---|---|
| **Questie** | `QuestieLoader.ImportModule` exists | `QuestieDB.QueryItemSingle` is a function and Questie says it's ready (`Questie.API.isReady`; older Questie: once `QuestPointers` exists). States: absent / loading / ready / unusable (1.6.0, `/jtt report`) | find sources for gear JTT's own data lacks (quest rewards, drops, vendors, objects) | none | Verified by source (Questie 12.9.0, 12.11.1); Verified in WoW Forever for the source lines |
| **NeedRoll** | `IsAddOnLoaded("NeedRoll")` (asked until it is; it may load later) | `NeedRollDB` is a table | read its dungeon and raid drops and dungeon quests from a hidden tooltip, shown JTT's way; where it names a dungeon, its drops replace JTT's | `NeedRollDB.tooltipSources = false` (its lines off) while JTT's sources are on. Put back at logout, or when JTT's sources are turned off, unless changed in NeedRoll meanwhile | Verified by source (v1.9.0: `tooltipSources` false = off, nil = on); Verified in WoW Forever |
| **Auctionator** | `Auctionator.Config` has `Get`, `Set` and `Options.VENDOR_TOOLTIPS` | as detected | (nothing read) | its "Vendor x1" tooltip line, which repeats the game's Sell Price, is off for the session. Put back at logout unless turned on again in Auctionator | In use since 1.4.2; every part checked before use. Not verified by source here (the local copy is the older 4.0.x line) |
| **FlareUI** | `FlareUI` table | its media | JTT style takes FlareUI's border and panel | none | Verified in WoW Forever |
| **EllesmereUI** | `UI.HasEllesmere()` (its skin API) | its panel colour | JTT style uses its flat panel colour and a thin border | none | Verified in WoW Forever |
| **TipTac, TinyTooltip, TinyTooltip-Reforged, ElvUI, Tukui, CursorTooltip** | `IsAddOnLoaded(name)` at login | — | a one-time warning: JTT has the last say on where the tooltip goes (it loads after them, OptionalDeps), but they may also move or restyle it | none | Detection: Verified in WoW Forever. How each behaves alongside JTT: Inferred (M2 compatibility diagnostics) |
| **Equip This!, What's Training, Questie (its own lines)** | — | — | nothing: they add lines to the same tooltip, and JTT keeps them | none | Verified in WoW Forever |

## Diagnostics (1.7.0)

`/jtt compat` (also in `/jtt report`) shows:
- the other tooltip addons that are loaded;
- how many tooltips JTT placed, and how many something else moved afterwards, with the frame each
  now hangs from;
- which tooltips JTT styles;
- what JTT does with NeedRoll and Auctionator;
- Questie's state and the source data's state.

Before 1.7.0 the only diagnostic for the other tooltip addons was the one-time warning at login.

## Rules

- **Session-only changes.** A change to another addon's setting lasts for the session only. It's
  put back at PLAYER_LOGOUT, before that addon's settings are saved.
- **The player's choice wins.** If the player changes that setting themselves during the session,
  JTT leaves their choice.
- **No duplicate lines.**
  - A source another addon already names (a boss, quest, vendor or chest) isn't repeated.
  - An ID another addon already shows isn't repeated: any common wording, whole numbers only
    (1.6.0).
