# OneWoW Suite Changelog

## Overlay System 2.0
- Rebuilt overlays for better performance and reliability
- Fixed items randomly darkening in the Warband bank after Cleanup
- Junk and Protected keybinds update overlays immediately (no reload)
- Custom overlays with item rules (PredicateEngine search syntax)
- Icon tinting, effects, backgrounds, and placement controls
- Quality border uses a clean OneWoW frame with adjustable thickness
- Item level overlay supports equipment, pets, and bag slot counts

## Overlay Settings
- New card-based settings with a live side preview
- Icon gallery, visual position picker, and dedicated Effects / Background cards
- Drag to reorder your overlay list (when search is empty)
- Add Overlay dialog hides presets you already have
- Preview shows Vendor and Auction House status at a glance
- Gear Upgrades, Item Level, and Quality Border share the same card layout
- Effect settings split into Icon and Background columns
- Background can use its own spin, zoom, or both
- Animated background styles still look correct when Background effect is None
- Icon scale no longer changes background size — use Background Scale instead

## Tooltips & Collections
- Tooltips → Collections: choose how “known by an alt” shows for recipes
  - Differentiated (green self, gold alt) — default, similar to ATT / Can I Mog It
  - Combined (green if you or an alt knows it)
  - Self only (ignore alts)
- Collected (green), Alt Collected (gold), and Not Collected (red) stay consistent across OneWoW

## Fixes
- Home portal ESC recognizes “teleport home” and “return to previous location” like the housing dashboard
- “Manage Roles & Alts here” in tooltip alt filtering shows a proper arrow (no broken box)

---

# Notes

## Collectibles (new tab)
- Track mounts, appearances, sets, pets, toys, heirlooms, decor, and recipes
- Sets list their appearances with collected status per piece and for the set overall
- Tracks vendor name and location, cost, and requirements (reputation, achievement, and similar)
- Capture uncollected vendor items to a Want List: Off, Prompt, or Automatic
- Option to auto-remove items once collected

---

# AltTracker

## Accounting
- Junk / bulk vendor sells count as Vendor Sell (QoL Sell Junk and Blizzard Sell All Junk), not Uncategorized
- New categories: Taxi, Barber, Offline Change, AH Cut, AH Refund, AH Cancel Fee, Bank Tab
- Auction sale mail records the house cut; outbid / refund mail is tracked
- Financials: ROI shows two decimals; All / Income / Expense stay clearly selected when active
- Optional Financials dashboard with income, expenses, profit, and wallet panels (plus sparklines)

## Fixes
- Progress tab shows the correct Mythic+ rating on each character row (no longer stuck at zero when score data exists)
- Skinning icon shows correctly on the Professions tab
- Profession icons display correctly in all languages and on expanded character rows

---

# Catalog

## Fixes
- Clicking a quest link from Item Search opens the correct quest in the Quests tab again
- Journal loot data keeps refreshing when Encounter Journal loot updates
- Collectible offer costs use correct modern coin formatting

---

# QoL

## Vendor Panel
- Add Items: five saveable custom filter slots (saved from Search Filter) instead of old presets
- Gear button adds items below an iLvl set in Options
- Search shows match count as “Adding [N]” with Add Items and Save Filter
- Live preview list while typing a search filter
- Clear One-Time Items also clears the search box
- Options: gear iLvl setting, Skip iLvl 1 for the Gear button, and Protected Items moved here
- Custom filter buttons stay evenly sized with long names (full name on tooltip)
- Hide Known Items shows the correct price when Plumber is enabled
- Fixed coin costs sticking to the wrong rows after hiding known items
- Merchant filter labels are localized (mounts, pets, decor, equipment slots, professions)
- Slot clear, one-time clear, protected-item count, and gear-add messages are localized

## Cursor Enhancer
- Situation-based visibility: define when and how the cursor ring appears from in-game context
- New UI for appearance settings and situation cards
- Global settings are defaults; only enabled situation cards change behavior
- Most specific matching situation wins; ties use card order (drag and drop to reorder)

## Minimap & Map
- Zone name no longer truncates to “…” or drifts when font size or zone changes
- Long zone names shrink to fit inside the minimap
- Left / center / right alignment grow from the correct edge when the name length changes
- Right, middle, and extra mouse buttons run your configured click actions (left click still pings)
- “Hide world map button” works again (addon provides its own button when Blizzard’s is gone)
- World map button tooltip is localized
- Draggable zone clock re-anchors correctly after you move it

## Auto Summon
- Auto-accept summon uses the current Retail summon API

---

# Bags

- New search keywords: `#altcollected`, `#altuncollected`, `#ensemble`, `#upgradetrack`
- Group items by subtype and upgrade track (sub-grouping for categories)
- Banks with many categories / sorts / groups load faster on cold start and open near-instantly afterward
- Tooltips on truncated category labels
- Quality borders use the Overlay System quality border (old rarity-color border settings removed)
- Custom bank UI keeps Blizzard’s bank frames off-screen so tooltips stay correct

---

*No user-facing changes this release for Trackers, Shopping List, Direct Deposit, or DevTool.*

---

- **Release**: Jul 16, 2026
- **Version**: R6.2607.1612
- **Status**: Live on curseforge
