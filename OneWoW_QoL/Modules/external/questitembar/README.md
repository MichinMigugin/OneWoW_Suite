# Quest Item Bar Module

Displays a movable bar with clickable buttons for special quest items from your quest log. Shows cooldowns, charges, and supports sorting by quest title, item name, or proximity.

## Bar Behavior

- Items come from `GetQuestLogSpecialItemInfo` — the game's API for quest-specific usable items
- Bar shows up to 12 items (keybindings: QUESTITEM_1 through QUESTITEM_4)
- Cooldowns and charges are displayed on each button
- Left-click uses the item; tooltip shows quest association

## Settings

| Setting | Description |
|---------|-------------|
| **Show Bar** | Toggle bar visibility (preview mode) |
| **Lock Position** | Lock/unlock bar position for dragging |
| **Sort** | None, By Quest Title, By Item Name, or By Proximity |
| **Hide When Empty** | Hide the bar when no items to display |
| **Show Only Tracked Quest Items** | Restrict bar to items from quests you've tracked (watched) in the quest log |
| **Button Size** | 24–48 px |
| **Columns** | 1–12 columns for button layout |

## Show Only Tracked Quest Items

When enabled, the bar only shows items from quests the player has tracked (watched) in the quest log. Uses `C_QuestLog.GetQuestWatchType(questID)`:

- Returns `0` (Automatic) or `1` (Manual) when tracked
- Returns `nil` when not tracked

Both 0 and 1 mean the quest is tracked; only `nil` means not tracked.

## By Proximity Sort

When "By Proximity" is selected, the bar orders items by distance to your character. Uses `C_QuestLog.SortQuestWatches()` and `C_QuestLog.GetQuestIDForQuestWatchIndex()` — the same logic as the default objective tracker. Order updates on zone changes and every 5 seconds while moving within a zone.

**Tracked vs untracked:** Proximity order applies only to **tracked** quests. When "Show Only Tracked" is off, tracked quest items appear first (in proximity order), then untracked quest items (in quest log order). For proximity to affect a quest's position, you must track it in the quest log.

**Garrison and phased zones:** When you are in a Garrison, instance, or other phased zone, proximity is calculated from that map. Objectives in adjacent zones (e.g. Shadowmoon Valley when you portaled from Garrison) may appear in a different order than expected, as the game uses the instanced map for distance calculations.

## Quest Item Status

Diagnostic table in the settings panel. Always shows **all** quests (not filtered by Show Only Tracked). Explains why items are or aren't on the bar.

### Status Labels

| Status | Meaning |
|--------|---------|
| **Included** | Item is on the bar |
| **Quest not tracked** | Quest has a usable item but you haven't tracked it; track the quest to add it when "Show Only Tracked" is on |
| **No usable items** | Quest has no special/usable item |
| **No special item** | Quest has item and is tracked, but not on bar (e.g. bar full, sort order) |
| **Ready for turn-in** | Quest complete; item no longer usable |
| **Invalid item** | Item data could not be resolved |

## Events

| Event | Purpose |
|-------|---------|
| `QUEST_LOG_UPDATE` | General quest log changes (objectives, zone changes, etc.) |
| `QUEST_WATCH_LIST_CHANGED` | Track/untrack changes (shift-click in quest log) |
| `BAG_UPDATE_DELAYED` | Bag changes affecting item availability |
| `SPELL_UPDATE_COOLDOWN` / `BAG_UPDATE_COOLDOWN` | Cooldown updates |
| `PLAYER_ENTERING_WORLD` | Initial load / zone transitions |
| `ZONE_CHANGED` / `ZONE_CHANGED_NEW_AREA` | Proximity re-sort when in By Proximity mode |
| `UPDATE_BINDINGS` | Keybinding changes |

## Keybindings

- `QUESTITEM_1` through `QUESTITEM_4` — Use quest item 1–4

Configure in the game's Key Bindings under the OneWoW category.
