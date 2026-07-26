# OneWoW Suite Changelog

# OneWoW
## Features
- Search Shortcuts in Settings: keyword synonyms (`#decks` → `#combinable`) and named expressions (`SAVED(Name)`) work suite-wide anywhere search expressions are used
- `CATEGORY(Name)` in those expressions expands Bags custom search-category rules when Bags is loaded (Mail shipments, overlays, and other suite filters included)
- A keyword synonym can stand for a whole expression, not just another keyword — `#sell` can mean `quality<=0 | CATEGORY(Junk)`
- Renaming a synonym, a named expression, or a Bags category keeps every expression that used the old name working, wherever it was saved — including Mail shipments, QoL filters, Direct Deposit rules, overlays, and saved profiles
- Deleting or renaming one of these now tells you exactly what would break and where — which addon, which rule, by name — before you commit, and never blocks you
- Search Shortcuts is a single list you can filter by kind, showing how many rules use each entry and which old names it still answers to
- Check references finds anything pointing at something that no longer exists, and can clear out old names nothing uses any more
- Saving an expression that duplicates one you already have offers to point at the original instead, so the two cannot drift apart
- A synonym that a later built-in keyword has taken over is flagged in the list instead of silently never matching

## Fixes
- Windows no longer jump to the center of the screen or lose their place on small or scaled displays (e.g. Steam Deck); oversized windows shrink to fit so the bottom stays reachable
- Collected / known / missing overlays update when collection status changes (transmog, mounts, pets, toys, heirlooms, decor, recipes) and after login settle; junk/protected marks refresh without a reload
- Chinese and Korean clients no longer error on load when scanning item charges; bag search keywords for charges and tradeable loot work correctly across all client languages
- The keyword help panel picks up synonyms as soon as you add them, without reopening
- The Search Shortcuts list no longer goes blank after changing theme, language, or the minimap setting

## Settings
- Language, theme, font, minimap, and value display are edited only in OneWoW Settings (removed from Bags, Shopping List, Direct Deposit, and DevTool windows)

## Home
- Mail now appears under Stand-alone Addons on the home page
- Available Commands lists Catalog (`/1wcat`, `/owcat`, `/onewowcatalog`), Bags, Mail, and Trackers; removed the unimplemented `/ddeposit clean` line

## Optimizations
- Bag and bank updates are handled in one place across the suite (Bags, overlays, QoL helpers, and AltTracker storage) for smoother inventory refresh
- Guild bank open/close and slot updates share the same Inventory funnel suite-wide (Bags, Storage, overlays, Accounting, DirectDeposit, auto-open)
- Shared guild-bank deposit planner fills partial stacks then empty slots (used by Direct Deposit and Bags)

---

# QoL
## Fixes
- Toggles tab sliders (Spell Queue Window, UI scale, volume, camera, nameplates, graphics, …) drag and update CVars correctly again
- Toggles CVars updated for Retail 12.0 (floating combat text `*_v2`, nameplate class colors, camera speeds, and other renamed/removed settings)
- Floating combat text toggles refresh immediately when changed

## Toggles
- Added Secure Ability Toggle, No Debuff Filter on Target, Display Lua Errors, Camera Indirect Visibility/Offset, and Nameplates at Base
- Expanded Combat Text: world text scale, float mode, periodics, absorbs, directional damage numbers, damage reduction, low mana/health, friendly healers, and pet spell damage

---

# Catalog
## Features
- Added `/1wcat` slash alias (alongside `/owcat` and `/onewowcatalog`)

## Fixes
- No longer errors when talking to quest NPCs inside instances

---

# Mail
## Features
- Shipment match expressions support `SAVED(Name)`, `CATEGORY(Name)`, and keyword synonyms from Search Shortcuts
- Compose To and shipment Character target: click or use the chevron to browse alts (and the rest of the address book), type to filter, and clear with the X

## Fixes
- Closing with the X works when the window was opened via `/owmail` (not only from a mailbox)
- Selected collect no longer keeps taking mail below the checked rows after each delete shifts the inbox
- Blank Subject on Compose no longer hangs until timeout; fills item name, gold amount, or "(No subject)" as needed
- Inbox and Activity scrollbars match the suite theme and resize with the window instead of a fixed width

---

# AltTracker
## Fixes
- Chat and README slash commands now match the registered aliases (`/1wat`, `/owat`, `/onewowat`)

## Financials
- Looted gold from mobs, auto-loot, and delve end piles is categorized as Looted Gold instead of Uncategorized Income
- Optional daily rollup for older transactions (Keep detailed history; default Off) to compact the ledger over time
- Ledger options (detail retention, guild-as-personal, reset) move behind a settings gear into a toggleable row

---

# Bags
## Features
- Search transfer and Ctrl+Right-click deposit work while the guild bank is open (fills partial stacks, then empty slots)
- Importing a bundle whose named expression clashes with one of yours lets you decide per entry: bring it in under a new name, or keep yours

## Fixes
- By Type categories keep matching after a client language change; they compared translated type names before, so switching language silently emptied them
- A By Type category whose type and subtype cannot occur together (or no longer exist) is reported instead of quietly matching nothing
- Renaming a category keeps its collapsed or expanded state in the bag and bank windows
- Undoing a bag import no longer deletes named expressions belonging to other addons, and keeps the ones it restores intact
- Deleting a category now says plainly that pinned items are not deleted, and lists the rules elsewhere that reference it

## Optimizations
- Item categorization is faster when opening bags and banks, most noticeably with many custom categories

## Settings
- General tab no longer duplicates OneWoW appearance settings (use OneWoW Settings)
- Named search shortcuts move to OneWoW Settings → Search Shortcuts; Bags Search keeps history limit and a link to that hub tab
- Saving from the bags/bank search bar still works; shortcuts are stored suite-wide

---

# Direct Deposit
## Features
- Guild-bank auto/manual deposits use the shared suite deposit planner (partial stacks, then empty slots)
## Settings
- Settings tab no longer duplicates OneWoW appearance settings (use OneWoW Settings)

---

# Shopping List
## Settings
- Settings view no longer duplicates OneWoW appearance settings (use OneWoW Settings)

---

# DevTool
## Settings
- Settings tab no longer duplicates OneWoW appearance settings (use OneWoW Settings)

---

*No user-facing changes this release for Notes or Trackers.*

---

- **Release**: TBD
- **Version**: TBD
- **Status**: Draft
