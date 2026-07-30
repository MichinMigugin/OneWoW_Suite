# OneWoW Suite Changelog

# OneWoW
## What's New
- After login (when the first-run wizard is not pending), a What's New dialog highlights this release; check "Don't show again this release" to dismiss it for this account until the next version
- Home has a What's New link to reopen the dialog anytime

## Slash commands
- Home Available Commands now lists only the canonical `/1w…` set (hub `/1w`, Bags `/1wbags`, Direct Deposit `/1wdd` with `deposit` / `pause` / `stop`, Shopping List `/1wsl add`, and the other `/1w` feature opens)
- Other aliases still work this release; the next release will remove every slash command that is not shown on Home
- `/ow-wizard` removed — re-open the feature picker from Home → Manage Features (or Settings → Manage Features)

## Fixes
- Reference check no longer flags packed game CVars or macro `#showtooltip` text inside Character Profiles as missing search shortcuts

---

# QoL
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
## Auctions
- Auction history is no longer capped at 100 entries
- Auctions list supports sorting, realm filter, and Bags-style item search (`#` keywords, shortcuts, and the search help button)
- Expanding an auction row shows full details (timestamps, prices, detection, market/mail when available)
- Large history lists load in the background so the UI stays responsive

## Accounting
- Auction sale mail now records sale price, AH deposit refund, and house cut as separate lines (deposit refund uses the AH Deposit category with note "AH deposit refund")
- Auction sale and refund mail now always claim their net gold so mailbox gold changes are not double-counted when the house cut is zero

## Fixes
- Financials transaction list no longer stays blank on first open until the timeframe dropdown is toggled

---

# Notes
## NPCs
- Added Quartermaster category
- Category lists sort as All, Other, then A–Z

---
