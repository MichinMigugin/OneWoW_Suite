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
## NPCs
- Added Quartermaster category
- Category lists sort as All, Other, then A–Z

---
