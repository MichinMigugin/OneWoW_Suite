# OneWoW Suite Changelog

# OneWoW
## Home
- Mail now appears under Stand-alone Addons on the home page

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
## Fixes
- No longer errors when talking to quest NPCs inside instances

---

# Mail
## Fixes
- Closing with the X works when the window was opened via `/owmail` (not only from a mailbox)

---

# AltTracker
## Financials
- Looted gold from mobs, auto-loot, and delve end piles is categorized as Looted Gold instead of Uncategorized Income
- Optional daily rollup for older transactions (Keep detailed history; default Off) to compact the ledger over time
- Ledger options (detail retention, guild-as-personal, reset) move behind a settings gear into a toggleable row

---

# Bags
## Features
- Search transfer and Ctrl+Right-click deposit work while the guild bank is open (fills partial stacks, then empty slots)

---

# Direct Deposit
## Features
- Guild-bank auto/manual deposits use the shared suite deposit planner (partial stacks, then empty slots)

---

*No user-facing changes this release for Notes, Trackers, Shopping List, or DevTool.*

---

- **Release**: TBD
- **Version**: TBD
- **Status**: Draft
