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

## Settings
- Toast Alerts, Tooltips, and Overlays use an Enabled/Disabled control in the detail header (same style as Features On/Off); the old Status line and repeating name on the bottom bar are gone on Features, Toggles, Toast, Tooltips, and Overlays
- Features (including module settings), Toast Alerts, and Tooltips use the same collapsible section cards as Overlays — click a section header to fold or expand; remembered until you reload
- Overlay Integrations use the same Enabled/Disabled control when an addon is detected (no overlapping status text + button)
- Gear Upgrade Overlay (and Tooltips → Gear Upgrades): Max alts shown and Sort alts by sit below their labels so they no longer clip in a narrow window

## Features
- Module On/Off sits in the detail header; Details is a text link under Category when a module has author/contact/link info
- “Mount Status” on the bottom bar only appears for Auto Mount (no longer sticks when switching modules)
- AutoOpen blacklist and BagBar item / macro / blacklist lists share the same add-by-ID, drag chip, and list layout (empty lists show “No items”)

## Player Mounts
- Display Mode is a single dropdown (Name / Name + Type / Full Details) instead of three buttons

## Portals
- Redesigned Portals settings: always-visible categories with usable/total counts, a Settings page for ESC options, Known/Unknown cards, inline Custom add, and width-based icon wrap
- ESC Portals only shows portals you can use; added Lightcalled Hearthstone
- Optional Keep Favorites Expanded on ESC; Show ESC Top Row master toggle for the hearth/pins row

## Minimap Button Collector
- Enhanced OneWoW row icons match Home / Manage Features (including Mail); Core still uses the brand mark
- Close Behavior, Grow Direction, and each icon’s Collector / Map / Hide choice are dropdowns; Enabled / Disabled still shows whether that addon is loaded

## Map Mini Tools
- Click Actions bindings (Right / Middle / Button 4 / Button 5) are dropdowns instead of a row of radio-checkboxes

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

- **Last Updated**: Aug 9, 2026
