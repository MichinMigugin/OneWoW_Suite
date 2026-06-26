# AltTracker — Items Tab

The Items tab aggregates everything your characters are holding into one searchable
list. It has two view-modes: the default **aggregated view** and the **duplicate
finder**.

Both views read through the OneWoW_AltTracker_Storage **Query layer**
(`API.Gather` / `API.FindDuplicates`); see
[OneWoW_AltTracker_Storage/Docs/ARCHITECTURE.md](../../OneWoW_AltTracker_Storage/Docs/ARCHITECTURE.md#query-layer-cross-alt-gather--filter--group--duplicates).
The list refreshes itself when items move (it subscribes to the storage-change
signal), so you don't need to reopen the tab after shuffling items around.

## Default view

One row per item ID, rolled up across every source: bags, personal banks, the
warband bank, guild banks, and active auctions. Columns: favorite, item, total
quantity, vendor value, AH value, and last-seen. Expand a row to see where each
copy lives (character — location × quantity). The search box accepts the full
[OneWoW search syntax](../../OneWoW_Bags/Docs/SEARCH_SYNTAX.md); the **Bound** and
**No Vendor** checkboxes filter the list.

## Duplicate finder

Tick **Duplicates** to switch the tab into the dupe grouping. Each row is a group
of copies the addon considers duplicates of one another; expand it to see every
copy with its item name, item ID, item level → upgrade ceiling, track, stats, and
socket, so you can tell at a glance which copy to keep.

### What counts as a "duplicate"

A duplicate is defined by a small spec you compose with the controls. Each enabled
toggle adds a dimension that splits broad groups into narrower ones. The controls:

- **Preset** — named starting points that fill the other controls. Pick one, then
  tweak → the label shows **Custom**.
  - *Same item* — every copy of the same base item.
  - *Same item + ilvl* — same item at the same item level.
  - *Same gear* — the default check: same item, redundant within an item-level
    band, split by primary/secondary stats and sockets.
  - *Similar gear* — functionally-equivalent gear across **different** item IDs
    (anchored on equip slot + armor type instead of item ID).
- **iLvl** — `Off` (ignore item level), `Exact` (split by exact item level), or
  `Range` (within a band of the best copy are redundant).
- **Primary / Secondary / Socket / Track** — split groups by primary stat,
  secondary-stat set, socket presence, or upgrade track (Hero/Veteran/…).
  **Track** is off by default; the Track column already shows it, so casual checks
  stay broad — turn it on to keep different tracks as separate duplicates.
- **Similar** — switch the anchor to equip slot + armor type (the *Similar gear*
  preset's mode).

All columns are shown regardless of which toggles are on, so you can see where a
*different* split would help. The last-used spec is saved per account and restored
on reload. Every control has an in-game tooltip describing exactly what it does.

> Item level is the **effective** level (upgrades included). Two copies at the same
> effective level can sit on different upgrade tracks — the higher track has more
> upgrade headroom, so it isn't truly redundant; that's what the Track split and the
> per-copy expand lines are for.
