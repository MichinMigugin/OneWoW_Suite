# OneWoW - AltTracker: Accounting

> **See also:** [OneWoW/Docs/ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)

**Gold tracking data collector for OneWoW AltTracker. Automatically tracks all gold income and expenses across all your characters.**

---

## What This Addon Does

This is a companion data collection addon for OneWoW AltTracker. It automatically tracks gold transactions from multiple sources:

- **Auction House** - Buys, sells, deposits, house cut, cancel fees, and refunds
- **Vendor Sales** - Gold from selling items (including junk / Sell All Junk / SellCursorItem)
- **Vendor Purchases** - Gold spent buying from vendors
- **Trainer Costs** - Gold spent learning abilities and specializations
- **Transmogrification** - Gold spent changing item appearance
- **Taxi / Barber** - Flight path fares and barber shop costs
- **NPC Orders** - Gold from crafted orders and services
- **Mail** - Gold sent through the mail system
- **Bank Operations** - Guild/warband bank flows and bank tab purchases
- **Trade** - Gold from trading with other players
- **Offline Delta** - Gold that changed while the character was offline
- **Other Income** - Quests, loot, Mythic+, and uncategorized fallback

---

## How It Works

Specialist trackers record categorized transactions and claim gold deltas. `GoldWatcher` listens to `PLAYER_MONEY` and only writes `uncategorized` rows for amounts that were not claimed. Cross-unit mail collection (Storage) records auction sales/refunds via `OneWoW_AltTracker_Accounting_API`.

### Ledger retention (daily rollup)

`settings.detailRetentionDays` (default `0` = Off; else 30/60/90/180/365) controls optional compaction. When enabled, `Modules/Compaction.lua` arms a `OneWoW.ChunkedJob` on login and when the setting changes: non-rollup rows older than the cutoff are merged into daily synthetic rows (`isRollup`, `rolledCount`, source `"Daily Rollup"`) grouped by character + day + type + category. Existing rollups are left alone. Compaction never runs on logout. Count-based `TrimTransactions` remains a safety net.

### Analytics (on-demand)

`Modules/Analytics.lua` exposes pure series builders used by the Financials Dashboard (and available on the public API):

- `BuildFlowSeries` — bucket income / expense / profit over the filtered range
- `BuildWalletSeries` — reconstruct a ledger-implied wallet path from a live `endBalance` anchor plus signed txs (transfers excluded from all-characters internal warband/guild moves)
- `BuildDashboardSummary` — per-day averages and top category / item rollups

Nothing is stored continuously for high/low or sparks; values recompute on Financials refresh / filter change / ledger edit.

### Financials Dashboard (AltTracker UI)

The Financials tab keeps a single ledger. An optional **Dashboard** toggle (persisted as `settings.financialsDashboard`) swaps the classic overview boxes for four metric panels (Income, Expense, Profit, Wallet) with sparklines. Shared filters still drive both the panels and the ledger. Wallet reconstruction can drift if the ledger is incomplete — the panel tooltip states that explicitly.

---

## Required Addon

This addon requires:
- **OneWoW_AltTracker** - The main AltTracker addon that reads this data

---

## Installation

1. Extract the `OneWoW_AltTracker_Accounting` folder to your `World of Warcraft\_retail_\Interface\AddOns\` directory
2. Make sure `OneWoW_AltTracker` is also installed
3. Restart World of Warcraft or type `/reload` in-game
4. Log in with your characters to collect transaction data
5. Open AltTracker and go to the Financials tab to view your gold history

---

## Support

**Website:** https://onewow.net/

**Report issues:** Through Discord community or our website

## Part of the AltTracker System

This data addon works with the main AltTracker:
- **OneWoW_AltTracker** - Main AltTracker addon (required)
- **OneWoW_AltTracker_Auctions** - Auction tracking
- **OneWoW_AltTracker_Collections** - Quests, achievements, mounts, pets
- **OneWoW_AltTracker_Endgame** - Raids, Mythic+, PVP
- **OneWoW_AltTracker_Professions** - Profession data
- **OneWoW_AltTracker_Storage** - Bank and inventory data
- **OneWoW_AltTracker_Character** - Character stats and equipment

---

**Author:** OneWoW Development Team

**Website:** https://onewow.net/

**All rights reserved. Part of the OneWoW Suite.**
