# OneWoW Suite Changelog

# OneWoW
## What's New
- After login (when the first-run wizard is not pending), a What's New dialog highlights this release; check "Don't show again this release" to dismiss it for this account until the next version
- Home has a What's New link to reopen the dialog anytime

## Home
- Home now shows addon cards for each suite feature (status, description, primary `/1w…` command); click a loaded card to open it, or Enable to jump to Manage Features
- Summary bar reports how many addons are loaded and how many need attention; version mismatches highlight the card and a footer banner
- Command Options lists Direct Deposit and Shopping List subcommands; other primary opens live on the cards
- Hub navigation uses a section dropdown (Home, features, Settings) under the title bar, with search on the same toolbar; the Home entry is labeled Home (window title stays OneWoW)
- Sections with more than one page get a second dropdown for that section’s pages, plus a favorite star; favorited pages pin on a short row under the toolbar (drag to reorder; overflow returns to the top of the page menu)
- Favorited pages in the page dropdown show a Camp Collection star atlas (not a font glyph)
- Text links use dedicated theme colors (idle / hover / underline) so they no longer match section headers; in-hub links like Manage Features show a small `>`
- Community links live on Home (Discord, Donate, OneWoW Home) with the same labels as before; they are no longer on Settings

## Settings
- Profiles shows UI & Addon Settings and Character Backup on one scroll (section headers; no mode toggle)
- Catalog and AltTracker Database Manager share the same title/description and row layout; Reset is disabled (with a tooltip) when that addon is not enabled
- Discord / Donate / OneWoW Home removed from Settings (use Home)
- The first Settings sub-tab is labeled Display (language, theme, font, minimap, value display)

## Slash commands
- Home cards and Command Options are the canonical `/1w…` set (hub `/1w`, feature opens on cards, Direct Deposit `/1wdd` with `deposit` / `pause` / `stop`, Shopping List `/1wsl add`)
- Other aliases still work this release; the next release will remove every slash command that is not shown on Home
- `/ow-wizard` removed — re-open the feature picker from Home → Manage Features (or Settings → Manage Features)

## Fixes
- Reference check no longer flags packed game CVars or macro `#showtooltip` text inside Character Profiles as missing search shortcuts

---

# QoL
## Tooltips
- Collections now shows a footer on Preyseeker voidcaches/chests and Bulging Ethereal/Winter packs: Not Collected pieces for your class (quality-colored names), or All items collected when you have them all

## Settings
- Developer Help removed from the QoL settings tab (module authoring lives in QoL docs / the Developers wiki)
- Weekly Reset Day section layout matches Catalog and AltTracker settings (full-width header, no extra divider)
- Weekly Reset Day no longer repeats the selected region beside the dropdown

## Fixes
- Auto Open now opens containers taken while mail, bank, merchant, or profession windows were open (rescans shortly after those windows close)
- Toggles detail status bar now updates when you change a CVar, and shows On/Off (or option labels) instead of raw `0`/`1`
- Floating Combat Text toggle description now correctly describes personal scrolling combat text (not world damage numbers); Healing Numbers describes healing you deal
- Toggles search also matches CVar names, so searching "floating" finds the Combat Text family

---

# Mail
## Fixes
- Shift-clicking a mail to collect it now clears the minimap new-mail icon (same as the Collect buttons)
- Attach failure and timeout logs now show readable item names instead of empty `[]` when the bag hyperlink has no display name yet
- Shipment Preview no longer shows raw item IDs when item data is still loading (shared name/link resolver with Activity and attach logs)
- Mail window X close no longer silently fails after a pending-review Exit left the close latch stuck, or when CloseMail did not hide the shell

## Inbox
- Expanding Auction House mail now shows a full invoice breakdown (sale price, deposit, house cut, amount received/paid, buyer/seller, and pending-funds ETA)

## Activity
- Pending reviews are expandable per shipment (shipment >> character) with Process/Discard on each row; global Process/Discard still applies to all
- Activity tab shows a count badge for pending shipment groups

---

# AltTracker
## UI
- Overview panels no longer repeat the tab name (Account Overview, Auctions Overview, Items Overview, and the other … Overview headers)

## Settings
- Roles & Alts pointer embeds the destination as an in-sentence text link (`Settings / Roles & Alts`); Database Manager uses the shared suite strings

## Auctions
- Auction history is no longer capped at 100 entries
- Auctions list supports sorting, realm filter, and Bags-style item search (`#` keywords, shortcuts, and the search help button)
- Expanding an auction row shows full details (timestamps, prices, detection, market/mail when available)
- Large history lists load in the background so the UI stays responsive

## Accounting
- Auction sale mail now records sale price, AH deposit refund, and house cut as separate lines (deposit refund uses the AH Deposit category with note "AH deposit refund")
- Auction sale and refund mail now always claim their net gold so mailbox gold changes are not double-counted when the house cut is zero

## Action Bars
- Bar icon rows and Restore buttons now line up with the bar name
- Bar names are no longer truncated or indented
- Per-bar Restore sits on the name row (right side), in a compact size
- Check the bars you want and use Selected to restore several at once (same bar numbers)
- Restore actions share one row: All Bars, Selected, Keybinds, Macros
- More space between set details and the restore action row

## Fixes
- Financials transaction list no longer stays blank on first open until the timeframe dropdown is toggled
- Action bar restore now places flyouts like Summon Demon (and similar spellbook flyouts) instead of failing with "Flyout not available"

---

# Notes
## UI
- Adding notes no longer spams chat with success lines (vendor collectible capture still reports how many were added)
- List tabs no longer show a redundant "… Controls" label above the toolbar (Notes, Items, Collectibles, Zones, Players, NPCs)
- Categories sort A–Z in every Notes type filter and dialog (All stays first in filters)
- Note bodies focus when clicked anywhere and keep the cursor in view while typing
- Existing note titles are wrapping text (edit the title in note settings)
- Storage dropdowns in create/edit dialogs say Account (same as the list filter), not Account-wide
- Zone note header shows Category on the lower right above Map (no storage label; storage stays on the list card)
- Detail headers and note bodies share the same sizes across Notes types; tooltip line fields use the same themed inputs as Players
- Player note header shows Profession 1/2 under Category (e.g. Professions: Alchemy, Inscription)
- Notes list splits Daily and Weekly into their own sections (then Favorites, then Notes); the old New section is gone
- Drag rows within a section to set Custom order (replaces Manual and up/down arrows); other sort modes still work until Custom is set
- Section headers and Category/Storage filter menus show counts; Collectibles Type and Status menus do too
- Notes sort menu includes Modified; Custom replaces Manual across list tabs

## Categories
- NPC default category is General (was Other); existing Other notes remap to General
- Players no longer list Other as a built-in (same as General); existing Other notes remap to General
- Items no longer list Collectible as a built-in; existing Collectible item notes remap to General

## NPCs
- Added Quartermaster category
- Selecting an NPC note no longer stalls on first open; associated quests open in Catalog with an NPC filter instead of listing them inline

## Zones
- Zone notes link to Catalog Quests with that zone’s filter pre-filled
- Zone notes store zone and subzone separately (opaque ids); titles still show “Zone - Subzone”; Catalog uses map/zone name so subzone notes find the right quests
- Existing zone notes migrate once to the new shape on login
- Zone list cards include a delete icon (same place as other Notes lists)

---

# Catalog
## Journal
- Instance Type is a Show All / Dungeons / Raids dropdown; Item Type uses singular labels in taxonomy order
- Instance cards show only present collectible tags (including Transmog), flowing to fit
- Collections summary lists progress for categories that drop loot, with a muted “No Mount, Pet, or Toy” line for what’s missing (or No Collections when none)
- Has uncollected checkbox hides instances where every tracked collectible (and quest reward) is already done
- Journal listing matches the Adventure Guide by expansion (dual-listed remakes like Deadmines; Onyxia under Wrath only)
- Difficulty filter uses valid difficulties for the instance (including classic 10/25 and Timewalking) with Adventure Guide-style size labels
- Timewalking instances show a Timewalking tag; empty cards show Loading loot… until live Adventure Guide data arrives
- Detail header shows only Instance ID and Map ID (expansion and type stay on the list cards)
- Quest loot rows use Wowhead and View Quest text links instead of buttons; ItemID and Quest ID are omitted so names fit at narrow widths
- Instance cards count real bosses only (General Loot / Quest / Achievement buckets are excluded); singular “1 Boss” vs “N Bosses”
- Loot table Item column has more width; column header Special renamed to Type

## Quests
- OpenQuestsFiltered deep-link applies zone and/or NPC (giver or turn-in) filters from Notes
- Active NPC filter shows as a clearable chip next to Clear on the Quests search bar

---
