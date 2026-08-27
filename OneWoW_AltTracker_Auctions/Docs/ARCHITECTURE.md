# OneWoW AltTracker: Auctions

> **See also:** [OneWoW/Docs/ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)

Auction house data tracking module for OneWoW AltTracker suite. Monitors active auctions and bids across all characters.

## Overview

This addon automatically tracks auction house activity including active auctions listed by the character and active bids placed by the character. Data is collected whenever the auction house is opened and stored per-character for access across all alts.

## Features

- Automatic data collection when auction house opens
- Real-time updates when auctions are created, canceled, or expired
- Tracks active auctions with full item details
- Tracks active bids with bidding information
- Per-character data storage
- Data accessible via SavedVariables for other addons
- Statistics calculation for quick summaries

## Data Collection Modules

### ActiveAuctions Module

Collects and manages data about auctions the character has listed at the auction house.

**Data Collected:**
- Auction ID
- Item ID, name, link, icon, rarity
- Item level
- Quantity listed
- Bid amount (current bid)
- Buyout amount
- Time left in seconds
- Expiration timestamp
- Bidder name (if there is a bid)
- Status code
- Collection timestamp

**Key Functions:**
- `CollectData(charKey, charData)` - Queries auction house API and stores auction data
- `GetAuctionStats(charData)` - Returns statistics including total auctions, total value, and number expiring soon

**Statistics Provided:**
- `total` - Total number of active auctions
- `value` - Total buyout value of all auctions
- `expiringSoon` - Number of auctions expiring within 2 hours

### ActiveBids Module

Collects and manages data about bids the character has placed on auction house items.

**Data Collected:**
- Auction ID
- Item ID, name, link, icon, rarity
- Item level
- Quantity
- Minimum bid amount
- Current bid amount (character's bid)
- Buyout amount
- Time left code
- Bidder name
- Collection timestamp

**Key Functions:**
- `CollectData(charKey, charData)` - Queries auction house API and stores bid data
- `GetBidStats(charData)` - Returns statistics including total bids and total bid amount

**Statistics Provided:**
- `total` - Total number of active bids
- `amount` - Total amount of gold currently bid

### DataManager Module

Central orchestrator that coordinates data collection from all modules.

**Responsibilities:**
- Event registration and handling
- Auction house state tracking
- Module coordination
- Data collection timing and throttling

**Events Monitored:**
- `AUCTION_HOUSE_SHOW` - Initial data collection when AH opens
- `AUCTION_HOUSE_CLOSED` - Track AH close state
- `OWNED_AUCTIONS_UPDATED` - Refresh auction data
- `AUCTION_CANCELED` - Update after cancellation
- `AUCTION_HOUSE_AUCTIONS_EXPIRED` - Update after expiration
- `AUCTION_HOUSE_AUCTION_CREATED` - Update after listing
- `PLAYER_INTERACTION_MANAGER_FRAME_SHOW` - Alternative AH open detection

**Key Functions:**
- `Initialize()` - Set up data manager
- `RegisterEvents()` - Register all auction house events
- `QueryAndCollectData()` - Query AH API and trigger collection
- `CollectAllData()` - Call all module data collectors
- `IsAuctionHouseOpen()` - Check if AH is currently open

## Database Structure

### SavedVariables: OneWoW_AltTracker_Auctions_DB

```lua
{
    characters = {
        ["CharName-RealmName"] = {
            activeAuctions = {
                [1] = {
                    auctionID = number,
                    itemID = number,
                    itemName = string,
                    itemLink = string,
                    itemIcon = number,
                    itemRarity = number,
                    itemLevel = number,
                    quantity = number,
                    bidAmount = number,
                    buyoutAmount = number,
                    timeLeftSeconds = number,
                    endsAt = timestamp,
                    bidder = string or nil,
                    status = number,
                    collectedAt = timestamp,
                },
                -- ... more auctions
            },
            numActiveAuctions = number,
            totalAuctionValue = number,
            lastAuctionUpdate = timestamp,

            activeBids = {
                [1] = {
                    auctionID = number,
                    itemID = number,
                    itemName = string,
                    itemLink = string,
                    itemIcon = number,
                    itemRarity = number,
                    itemLevel = number,
                    quantity = number,
                    minBid = number,
                    bidAmount = number,
                    buyoutAmount = number,
                    timeLeft = number,
                    bidder = string,
                    collectedAt = timestamp,
                },
                -- ... more bids
            },
            numActiveBids = number,
            totalBidAmount = number,
            lastBidUpdate = timestamp,

            lastUpdate = timestamp,
        },
        -- ... more characters
    },
    settings = {
        enableDataCollection = boolean,
        trackAuctions = boolean,
        trackBids = boolean,
    },
    version = number,
}
```

## Data Access

Persistence lives in `OneWoW_AltTracker_Auctions_DB` (the WoW `## SavedVariables` root).
**Cross-unit readers must use `OneWoW_AltTracker_Auctions_API`** — not the `_DB` global
directly (see [OneWoW/Docs/ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md) §6,
enforced by the `no-data-manager-bypass` pre-commit hook).

### Accessing Data from Other Addons

```lua
local API = OneWoW_AltTracker_Auctions_API
if API then
    local charKey = "CharacterName-RealmName"
    local characters = API.GetCharacters()
    local charData = characters and characters[charKey]

    if charData then
        print("Active auctions: " .. (charData.numActiveAuctions or 0))
        print("Active bids: " .. (charData.numActiveBids or 0))
        print("Total auction value: " .. (charData.totalAuctionValue or 0))
    end
end
```

### Iterating All Characters

```lua
local API = OneWoW_AltTracker_Auctions_API
if API then
    for charKey, charData in pairs(API.GetCharacters()) do
        if charData.numActiveAuctions and charData.numActiveAuctions > 0 then
            print(charKey .. " has " .. charData.numActiveAuctions .. " auctions")
        end
    end
end
```

### Calculating Statistics

To get auction statistics (like expiring soon count), read character data through
`GetCharacters()` and process the returned tables:

```lua
local API = OneWoW_AltTracker_Auctions_API
local charData = API and API.GetCharacters()["CharName-RealmName"]
if charData and charData.activeAuctions then
    local expiringSoon = 0
    local serverTime = GetServerTime()
    local twoHours = 7200

    for _, auction in ipairs(charData.activeAuctions) do
        if auction.endsAt then
            local timeLeft = auction.endsAt - serverTime
            if timeLeft > 0 and timeLeft < twoHours then
                expiringSoon = expiringSoon + 1
            end
        end
    end

    print("Auctions expiring soon: " .. expiringSoon)
end
```

### AH price cache and full scan

`StartFullScan`, `StopFullScan`, `CanFullScan`, `GetPrice`, `GetPriceForSpecies`,
`GetScanMeta`, `StartTargetedScan`, and `GetCharacters` live on the same `_API`
table (see `Core/API.lua`).

- **Population:** The AH Prices sidebar panel (`UI/AHPricesPanel.lua`) on
  `AuctionHouseFrameTabSideBar` calls `StartFullScan` (`AHReplicateScanner`
  replicate scan). Optional auto-scan on AH open is controlled by
  `autoScanOnOpen` (default off). Results are written to the realm-scoped
  `OneWoW_AHPrices` SavedVariable v2 schema (14-day TTL purge on login; v1
  data discarded).
- **Item keys:** `OneWoW.AHItemKeys` (core) serializes Blizzard `ItemKey`
  tables to storage keys (`id:ilvl:suffix:species`) for gear, pets, and
  commodities.
- **Consumption:** AltTracker Items, QoL tooltips, Trackers farm value, and
  Catalog item search read prices through `OneWoW.ItemPrices:GetUnitAHPrice`
  (link-aware for the OneWoW source), or Auctionator/TSM when configured in
  the shared AH price source dropdown (`SHARED_AH_SOURCE_*` locale keys).
- **Phase 2:** `AHTargetedScanner` queues `SearchForItemKeys` lookups with
  throttling for on-demand price refresh.

## Architecture

### Module Pattern
Each data collection module follows the AltTracker DataManager orchestration pattern:

1. **Event Trigger** - Auction house opened or updated
2. **DataManager Orchestration** - DataManager receives event and queries AH API
3. **Module Execution** - Each module (ActiveAuctions, ActiveBids) collects its data
4. **Database Storage** - Data stored in character's database entry

### Module Autonomy
Each module is self-contained with:
- Own data collection logic
- Own API interaction
- Own data structure definitions
- Own statistics calculation

### Separation of Concerns
- **Modules** - Data collection, WoW API calls, database operations
- **DataManager** - Event handling, timing, orchestration only
- **Core** - Database initialization, character key generation
- **SavedVariable** - Persistence root (`OneWoW_AltTracker_Auctions_DB`); cross-unit reads via `OneWoW_AltTracker_Auctions_API`

## File Structure

```
OneWoW_AltTracker_Auctions/
├── OneWoW_AltTracker_Auctions.toc
├── OneWoW_AltTracker_Auctions.lua (no public globals; API lives in Core/API.lua)
├── Docs/
│   └── ARCHITECTURE.md (this file)
├── Locales/ (11 locales)
├── Core/
│   ├── Database.lua (character DB + AH price cache defaults)
│   ├── AHPriceCache.lua (realm-scoped OneWoW_AHPrices v2)
│   ├── AHScanCoordinator.lua (scan lock, cooldown, AH close hooks)
│   ├── API.lua (Public API — global OneWoW_AltTracker_Auctions_API)
│   └── Core.lua (Addon initialization, scanner/panel wiring)
├── UI/
│   └── AHPricesPanel.lua (AH sidebar tab + scan controls)
└── Modules/
    ├── AHReplicateScanner.lua (full replicate scan)
    ├── AHTargetedScanner.lua (SearchForItemKeys queue, phase 2)
    ├── ActiveAuctions.lua (Auction data collection)
    ├── ActiveBids.lua (Bid data collection)
    └── DataManager.lua (Event orchestration, auto-scan hook)
```

## Dependencies

**Required:**
- World of Warcraft Retail (11.0.0+)
- Interface version: 120000 or higher

**Optional:**
- OneWoW_AltTracker (main addon) - For integrated UI display

## How Data Collection Works

### Automatic Data Collection
Data is automatically collected when:
- Auction house is opened
- New auction is created
- Auction is canceled
- Auctions expire
- Owned auctions are updated

### Collection Process
1. Game event fires (e.g., AUCTION_HOUSE_SHOW)
2. DataManager receives the event
3. After a brief delay (to ensure data is loaded), DataManager calls the collection modules
4. ActiveAuctions and ActiveBids modules query the WoW API
5. Data is stored in the character's entry in `OneWoW_AltTracker_Auctions_DB`
6. Timestamps are updated to track when data was collected

### Data Storage
Auction data is organized by character key (`"Name-Realm"` format) inside
`OneWoW_AltTracker_Auctions_DB` and persists across sessions. Other suite units and
third-party addons read it through `OneWoW_AltTracker_Auctions_API.GetCharacters()` (and
the scan helpers on the same table), not by indexing `_DB` directly.

### Integration with OneWoW_AltTracker
The main OneWoW_AltTracker addon uses `OneWoW_AltTracker_Auctions_API` to display
auction information in its UI, providing a centralized view of auctions across all
characters.

## Technical Details

### WoW API Functions Used
- `C_AuctionHouse.GetNumOwnedAuctions()` - Get count of player's auctions
- `C_AuctionHouse.GetOwnedAuctionInfo(index)` - Get auction details by index
- `C_AuctionHouse.GetNumBids()` - Get count of player's bids
- `C_AuctionHouse.GetBidInfo(index)` - Get bid details by index
- `C_AuctionHouse.QueryOwnedAuctions({})` - Request server update for owned auctions
- `GetItemInfo(itemID)` - Get item name, link, rarity
- `C_Item.GetItemIconByID(itemID)` - Get item icon texture
- `GetServerTime()` - Get current server timestamp
- `UnitName("player")` - Get player name
- `GetRealmName()` - Get realm name

### Data Collection Timing
- Initial collection: 1 second after auction house opens
- Update collection: 0.5 seconds after events fire
- Query delay: 0.5 seconds after query request

### Character Key Format
`"CharacterName-RealmName"` - Used for database indexing and cross-character lookup

## Version History

- **B6.2602.1600** - Initial release with active auctions and bids tracking

## Author

OneWoW Development Team

## Website

https://onewow.net/
