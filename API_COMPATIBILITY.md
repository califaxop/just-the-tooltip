# Just the Tooltip!: API compatibility (WoW: Forever, Interface 16001)

Status labels:
- **Verified in WoW Forever**: seen working in the game (the author's reports, screenshots,
  `/jtt debug`, `/jtt trace`, `/jtt report`), or read the same way by another of the author's
  addons that is verified in game.
- **Verified by source / documentation**: Blizzard's API documentation, or the source of the
  addon or code that uses it; not yet observed on Forever.
- **Inferred but untested**: assumed from behaviour or from other clients.
- **Unsupported**: not available, or not used.

Every call whose answer can be hidden goes through `ns.Safe` (1.6.0): missing, erroring or secret
values become nil.

## Tooltip system

| API | Use | Status |
|---|---|---|
| `TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item / Spell / UnitAura / Unit, fn(tip, data))`, `data.id`, `data.hyperlink` | lines after the game's: IDs, item level, sources, target line, colours | Verified in WoW Forever (these lines show) |
| `Enum.TooltipDataType.Corpse`, `.Object` | hide a corpse's or an object's tooltip when the mouse leaves | In use since 1.3.x; that it fires for every corpse and object: Inferred (M2) |
| `GameTooltip_SetDefaultAnchor(tip, parent)` (hooked) | follow the cursor, your own spot | Verified in WoW Forever |
| `GameTooltip:SetOwner`, `:FadeOut`, `OnShow` / `OnHide` / `OnTooltipCleared` scripts | tooltip lifecycle | Verified in WoW Forever (instant hide works) |
| `tip:GetItem()` → name, link | the item's link | Verified in WoW Forever |
| `tip:GetUnit()` → name, unit | the unit token | Verified in WoW Forever; can be secret (handled) |
| `tip:GetTooltipData()` | `/jtt debug` | Verified in WoW Forever |
| `C_TooltipInfo.GetWorldCursor()` | is the mouse still over something in the world | Verified in WoW Forever (`/jtt trace`, 1.4.x) |
| `UPDATE_MOUSEOVER_UNIT`, `WORLD_CURSOR_TOOLTIP_UPDATE(anchorType)`, `Enum.WorldCursorAnchorType.None` | world tooltips that stayed up | Verified in WoW Forever (`/jtt trace`) |
| `GetMouseFoci()` (older: `GetMouseFocus()`) | the mouse moved onto the interface | Verified in WoW Forever |

## Positioning

| API | Use | Status |
|---|---|---|
| `GetCursorPosition()` | the cursor, in screen units | Verified in WoW Forever |
| `Region:SetPoint(point, relativeTo, relativePoint, x, y)`: offsets in the placed frame's scale | the cursor converted by the tooltip's own effective scale | Verified by source (What's Training's Forever menu: `x / menu:GetEffectiveScale()`). At 100%: Verified in WoW Forever. At other sizes: in-game check 2 (1.6.0) |
| `GetEffectiveScale()` (tooltip, UIParent) | the cursor conversion; the gap in interface units | as above |

## Items

| API | Returns used | Status |
|---|---|---|
| `C_Item.GetItemInfo(link)` (older: `GetItemInfo`) | 4th item level, 9th equip location, 12th class ID; nil while uncached | Verified in WoW Forever (Equip This!'s engine reads the same positions) |
| `C_Item.GetItemQualityByID(link)` | quality border | Verified in WoW Forever |
| `ITEM_QUALITY_COLORS` | quality border | Verified in WoW Forever |

## Units

| API | Use | Status |
|---|---|---|
| `UnitExists`, `UnitIsPlayer`, `UnitClass` (2nd: class token), `UnitReaction(unit, "player")`, `UnitIsUnit`, `UnitName`, `UnitIsTapDenied` | target line, borders, name colour | In use and working: Verified in WoW Forever. Which of them the game hides, and when: Inferred (all handled as possibly secret) |
| `C_ClassColor.GetClassColor(class)`, `RAID_CLASS_COLORS` | class colours | Verified by documentation; in use |

## Other

| API | Use | Status |
|---|---|---|
| `C_AddOns.LoadAddOn(name)` → loaded, reason | the companion data | Verified in WoW Forever (it loads); the reason string: Verified by documentation |
| `C_AddOns.GetAddOnInfo(name)` → ..., reason (6th) | is the companion installed | Verified by documentation; in use |
| `C_AddOns.IsAddOnLoaded` (older: `IsAddOnLoaded`) | other addons | Verified in WoW Forever |
| `C_Map.GetAreaInfo(areaID)` | zone names in source lines | Verified in WoW Forever |
| `C_Texture.GetAtlasInfo(atlas)` | source icons, with a texture fallback | Verified in WoW Forever |
| `UnitFactionGroup("player")` | faction filter for quests and vendors | Verified in WoW Forever |
| `issecretvalue` | secret values | Verified in WoW Forever (present on the client) |

## Testing an API in game

- `/jtt debug`: what the tooltip is doing now (type, owner, unit, state).
- `/jtt trace`: what the game says and what JTT does while you hover and leave something.
- `/jtt report`: version, client, settings, the sources and Questie state, the hooks.
