# Just the Tooltip!

**The game's tooltip, where you want it, with just the extras you'll use.**

Put the tooltip by your cursor so you never have to look down to the corner of the screen, or park it anywhere you like. Add item and spell IDs, item level, who a unit is targeting and a cleaner look, without bloat.

## Highlights
- **Position:** the game's spot, **following your cursor** (below-right, below-left, above-right or above-left, at the distance you choose), or your own spot anywhere on screen.
- **Cursor for the world only (optional):** units and objects follow your cursor, while action bars and buttons keep the game's spot.
- **IDs:** Item ID and Spell ID on items, spells, buffs and debuffs (not added twice if another addon already shows them).
- **Item level** on gear.
- **Where gear comes from:** quest rewards, boss and elite drops (with the zone), vendors and chests for your faction, professions and world drops (with their levels), most useful first, up to three lines plus "+N more". Gear that only comes from random-loot chests just says so. The data comes with the download as a small companion addon, "Just the Tooltip!: Sources", that only loads the first time you hover gear. It's refreshed every week.
- **Target line:** who a unit is targeting, with a red ">> You <<" when it's you.
- **Health bar** under unit tooltips: keep it or turn it off.
- **Look:** JTT style (a dark panel with a bronze border, FlareUI's when it's installed) or Blizzard's, a border in the item's quality or player's class color (NPCs: red hostile, yellow neutral, green friendly), and a size slider.
- **No lingering:** tooltips vanish as soon as you stop hovering, in the world or on your unit frames (no fade).
- **Combat (optional):** hide tooltips for things in the world during combat; hold Shift to see them.
- **Plays well with others:** it changes the game's tooltip rather than replacing it, so lines from Equip This!, Questie, What's Training and other addons still show.

## Quick start
1. Install and play: it starts at the game's usual spot with the extras on.
2. Type `/jtt`, set Position to "Follow my cursor" and hover "Hover to preview".

## Commands
| Command | Does |
|---|---|
| `/jtt` (or `/justthetooltip`) | Open settings |
| `/jtt move` | Drag your own tooltip spot (right-click the box when done) |
| `/jtt reset` | Tooltips back at the game's spot |
| `/jtt debug` | What the tooltip is doing right now (handy for bug reports) |

## Good to know
- Only tooltips the game would put in the bottom-right corner move. Tooltips that open beside your bags or a window stay next to them.

## Updates
New versions come out every **Wednesday at 12:00 UTC** (8 PM Philippine time, 8 AM US Eastern). Urgent fixes ship sooner.

## Feedback
Found a bug or have an idea? [Open an issue](https://github.com/califaxop/just-the-tooltip/issues/new/choose): there's a short form for each. The settings window has a "Report a bug / suggest" button with this link too.

## Recent changes
- **1.3.1:** Fixed: a corpse's or object's tooltip in the world could stay up after you moved off it, until you hovered something else.
- **1.3.0:** EllesmereUI style when EllesmereUI is installed: the JTT-style tooltip becomes its flat dark panel with a thin border (quality and class colours kept), and the settings window is painted by EllesmereUI's own skinning API (your theme, accent colour and font).
- **1.2.0:** Where gear comes from on item tooltips: quest rewards, drops, vendors, chests and professions (Show, on by default). Comes with the companion addon "Just the Tooltip!: Sources", which loads only when you hover gear.
- **1.1.0:** NPC borders by how they feel about you: red hostile, yellow neutral, green friendly, grey when someone else tagged it (Look, on by default). The health bar under unit tooltips can be turned off (Show). Fixed a tooltip sometimes staying on screen after you moved off a unit or your player frame (until you hovered something else). Loads after other tooltip addons so its placement wins, and says if one is also loaded. JTT style and the settings use the game's tooltip border in bronze. New `/jtt debug` shows what the tooltip is doing, for bug reports.
- **1.0.0:** First release: tooltip at the game's spot, by your cursor or your own spot; Item ID / Spell ID, item level, target line, JTT style, tooltips that vanish the moment you stop hovering, and hiding in combat.

## Credits
Where gear comes from uses [QuestieDB](https://github.com/Questie/QuestieDB)'s WoW: Forever data (quest rewards, drops, vendors, chests), by the Questie team and contributors, under the GNU GPL v3; the "Just the Tooltip!: Sources" folder is GPL v3 too. Just the Tooltip! isn't made by or affiliated with Questie.
