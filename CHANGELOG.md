# OneWoW Suite Changelog

# OneWoW
## Home
- Summary “needs attention” no longer counts features you turned off on purpose (soft or hard); it lists real issues (version mismatch, load failures, missing data packs) and lets you dismiss non-critical ones

## Search
- `#geartoken` finds Use: loot-spec gear tokens (e.g. Baleful); distinct from `#contexttoken` (season/reagent context tokens)
- `#myclass` / `forclass=` also match class-restricted Use: tokens (Classes: tooltip line), not only equippable gear; `#myspec` stays equipment-only

## Settings
- On/Off controls are a single button that shows the current state (soft green On, muted Off with red text); click to toggle — used across Bags, QoL Features, Tooltips, and other settings
- Toggle rows put title and description on the left with On/Off on the right; the button is slightly smaller; Auto Mount setting titles no longer end with a colon

# QoL

## Features
- Module On/Off sits in the detail header; Details is a text link under Category when a module has author/contact/link info
- “Mount Status” on the bottom bar only appears for Auto Mount (no longer sticks when switching modules)
- AutoOpen blacklist and BagBar item / macro / blacklist lists share the same add-by-ID, drag chip, and list layout (empty lists show “No items”)

## Player Mounts
- Display Mode is a single dropdown (Name / Name + Type / Full Details) instead of three buttons

## Portals
- Added Corewarden's Hearthstone

## Minimap Button Collector
- Enhanced OneWoW row icons match Home / Manage Features (including Mail); Core still uses the brand mark

## FrameMover
- Per-frame Reset next to the scale percent is a text link instead of a chunky button (Reset All Positions / Scales stay buttons)

# Mail
## Settings
- Gear on the tab bar opens a compact settings popover with a slider for how long to wait for send confirmation (5–30 seconds; default 8) — raise it if laggy connections cause false timeouts

## Fixes
- Shipments no longer try to mail the character you are on (Character targets and Role members); Blizzard rejects self-mail
- Title bar no longer shows a second mail icon next to the window title (brand mark only, like other OneWoW windows)

---

# Catalog
- Soft-requires AltTracker Storage (BringUp pulls it with Catalog); without Storage, Catalog stays usable but Home marks it diminished

## Journal
- Clear restores the search placeholder instead of leaving the box blank

## Item Search
- Dropped the “Results” and “Item Details” panel titles
- Search placeholder is “Search items…”; Clear next to search resets text and source filter and restores the placeholder

## Quests
- Dropped the “Quests” and “Quest Details” panel titles
- Expansion filter sits under search on the left (full width); Zone and Progress share the right row; Advanced is a compact control on the second row
- Search placeholder is “Search quests…”; Clear restores it
- List cards match Journal: name, `Expansion | Quest Type`, colored category tags; status icons along the bottom-right with category tags
- Detail drops the duplicate favorite star; meta is Zone|Faction, Categories|Traits, then Quest ID|Map ID (no repeated Expansion/Type)

## Tradeskills
- Dropped the “Professions” and “Recipe Details” panel titles so more room goes to the list and detail
- Recipe detail matches Journal/Vendors: `Expansion | Profession` under the name, one `Recipe ID | Item ID` line (Item ID omitted when none), no repeated Profession/Expansion rows
- Profession filter is a dropdown (not a button grid); filter bars are shorter so the list starts higher
- Recipe list rows show a muted `Expansion | Profession` line under the name (omits what’s already implied by the active filters / expansion groups)
- Reagent quantities show account-wide have/need (`12/15`) when Storage is available; otherwise the old `x15` style
- On Hand section lists owned reagents for the selected recipe; expand a row for owner / location / quantity breakdown
- Have Materials filter (right header) shows only recipes whose required reagents you own across Storage; expansion dropdown sits above the known checkboxes like Journal
- Search placeholder shows again when you open the tab (reset no longer leaves the box blank until you click away)
- Clear next to search resets filters like Journal/Vendors and restores the placeholder

---

# Bags
## Sorting
- Item Level sort orders bags and reagent bags by slot count (same number the Item Level overlay shows), then by your sub-sort

---

# DirectDeposit
- Keep Specific Items and Item Auto-Deposit use the same add-by-ID / drag / list chrome as QoL Features; empty lists show “No items”

---

*No user-facing changes this release for AltTracker, Notes, ShoppingList, Trackers, or Vendors.*

---

- **Last Updated**: Aug 8, 2026
