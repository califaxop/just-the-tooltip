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
| `/jtt debug` | What the tooltip is doing right now |
| `/jtt info` | Each kind of information: on or off, available on this client, how far it's verified, any errors |
| `/jtt source <item>` | Every source known for an item (shift-click it in), where it was learned and how far to trust it |
| `/jtt compat` | Other tooltip addons, and whether anything moves tooltips after Just the Tooltip! places them |
| `/jtt report` | Bugs & Feedback: the form's link and a line to paste into it |

## Good to know
- Only tooltips the game would put in the bottom-right corner move. Tooltips that open beside your bags or a window stay next to them.

## Updates
New versions come out every **Wednesday at 12:00 UTC** (8 PM Philippine time, 8 AM US Eastern). Urgent fixes ship sooner.

## Feedback
Found a bug, have feedback or want a feature? Click **Bugs & Feedback** at the top right of the settings window (or type `/jtt report`): it gives you the form's link and, for a bug, a line to paste into it with everything we need. Or [open an issue](https://github.com/califaxop/just-the-tooltip/issues/new/choose) directly: there's a short form for each.

## Recent changes
- **1.9.0 (test build):** Choose where each line shows (the game's tooltip, chat links, comparisons) and the order of the lines on items. Optional "more detail" key (Alt or Ctrl): every source with where it was learned. Profiles: several sets of settings, one per character. At 100% size tooltips keep their own size.
- **1.8.0 (test build):** Each tooltip's details are read once and shared, and each kind of information works on its own: one error no longer affects the rest (new `/jtt info`). An item level or target line another addon already shows isn't repeated. New `/jtt source <item>`: every source for an item, where it was learned and how far to trust it.
- **1.7.0 (test build):** Each tooltip starts afresh (nothing carries over from the one before). A tooltip shown for a frame you're not over stays up; one whose frame hides goes with it. Blizzard's look restores the border exactly as it was. Comparison tooltips made later get JTT's look. New `/jtt compat` shows what other tooltip addons do alongside JTT.
- **1.6.0 (test build):** Fixed: a Spell or Item ID could be left out when the tooltip showed a longer number containing it. Fixed: following the cursor, the tooltip's distance from it changed with its size; now it's the distance you set at any size. Fixed: a unit detail the game hides could stop the target line and colours. Fixed: hovering new gear right after login could stop Questie's sources for the session.
- **1.5.0:** "Bugs & Feedback" now sits at the top right of the settings window, next to the ×. It opens a window (like Questie's trace export) with the form's link to copy at the top, for bug reports, feedback and feature requests, and for a bug, one line to paste into the form with your version, the game client, its settings and what the tooltip is doing right now; never your name, realm or guild. Also `/jtt report`. The settings window is now solid and comes to the front when opened or clicked: with several addons' settings open, they no longer show through each other.
- **1.4.3:** Fixed: the settings window's text is readable with EllesmereUI installed (EllesmereUI's quest tracker shrinks the game's tracker fonts to 1 px, and the window used them). No style settings any more: the look follows EllesmereUI or FlareUI on its own whenever one is installed.
- **1.4.2:** Just the Tooltip! takes precedence over Auctionator's "Vendor x1" line, which repeats the game's own Sell Price: it's off while you play (Auctionator's auction prices stay) and your Auctionator setting is put back when you log out.
- **1.4.1:** Fixed: a creature's tooltip (a live one or a corpse) could stay up after you moved off it: when the mouse went onto the interface (chat, action bars, unit frames), where the game still counts the creature as under the mouse, and for units the game keeps secret (it wouldn't say who was under the mouse, so the tooltip wasn't watched at all). It now goes as soon as you leave. New: /jtt trace shows, with times, what the game reports while you hover something and move off it (for bug reports).
- **1.4.0:** Item sources have a new look: a "Source:" heading naming the kinds (Quest, Dungeon, Raid, Boss, Enemy, Vendor, Crafted, Chest, World Drop, Random Chests), then a line for each with its icon (the map's dungeon and raid portals, the quest marker, a skull for creatures out in the world, a chest, the profession's icon); a single source sits on the heading line. Drops are listed likeliest first, so "+N more" holds the least likely (Classic's loot tables, from CMaNGOS Classic-DB; the chances aren't shown, since WoW: Forever's may differ). Dungeon bosses and trash now know their dungeon. With NeedRoll installed, Just the Tooltip! draws the sources and shows what NeedRoll knows its way (NeedRoll's newer dungeon and raid loot replaces ours for the dungeons it covers, its dungeon quests join ours); NeedRoll's own tooltip lines are turned off while Just the Tooltip!'s sources are on (its setting is put back as it was when you log out or turn ours off). Gear our data doesn't have yet is looked up in Questie, if installed.
- **1.3.1:** Fixed: a corpse's or object's tooltip in the world could stay up after you moved off it, until you hovered something else.
- **1.3.0:** EllesmereUI style when EllesmereUI is installed: the JTT-style tooltip becomes its flat dark panel with a thin border (quality and class colours kept), and the settings window is painted by EllesmereUI's own skinning API (your theme, accent colour and font).
- **1.2.0:** Where gear comes from on item tooltips: quest rewards, drops, vendors, chests and professions (Show, on by default). Comes with the companion addon "Just the Tooltip!: Sources", which loads only when you hover gear.
- **1.1.0:** NPC borders by how they feel about you: red hostile, yellow neutral, green friendly, grey when someone else tagged it (Look, on by default). The health bar under unit tooltips can be turned off (Show). Fixed a tooltip sometimes staying on screen after you moved off a unit or your player frame (until you hovered something else). Loads after other tooltip addons so its placement wins, and says if one is also loaded. JTT style and the settings use the game's tooltip border in bronze. New `/jtt debug` shows what the tooltip is doing, for bug reports.
- **1.0.0:** First release: tooltip at the game's spot, by your cursor or your own spot; Item ID / Spell ID, item level, target line, JTT style, tooltips that vanish the moment you stop hovering, and hiding in combat.

## Credits
Where gear comes from uses [QuestieDB](https://github.com/Questie/QuestieDB)'s WoW: Forever data (quest rewards, drops, vendors, chests), by the Questie team and contributors, under the GNU GPL v3; the "Just the Tooltip!: Sources" folder is GPL v3 too. Just the Tooltip! isn't made by or affiliated with Questie.
