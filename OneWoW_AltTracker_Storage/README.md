# OneWoW AltTracker: Storage

A specialized datastore addon that tracks all storage-related data for World of Warcraft characters including bags, banks, guild banks, warband banks, and mail.

## Overview

This addon automatically collects and stores detailed inventory data across all characters. The data is stored per-character and can be accessed by other addons through the provided API.

## What Data is Collected

### 1. Bags Module
**File:** `Modules/Bags.lua`

**Collects:**
- Bag IDs 0-4 (backpack + 4 bag slots)
- Each slot contains:
  - Item ID, Link, Name
  - Quality, Item Level
  - Texture icon
  - Stack count
  - Lock status (if currently being moved)
  - Bind status (isBound)
- Number of slots per bag
- Last update timestamp

**Event Triggers:**
- `BAG_UPDATE_DELAYED` - automatically tracks when bag contents change

**Stored In:** `charData.bags`

### 2. Personal Bank Module
**File:** `Modules/PersonalBank.lua`

**Collects:**
- Bank bag ID -1 (main bank slots)
- Bank bags 1-7 (purchasable bank bag slots)
- Each slot contains:
  - Item ID, Link, Name
  - Quality, Item Level
  - Texture icon
  - Stack count
  - Lock status
  - Bind status
- Number of slots per bag
- Last update timestamp

**Event Triggers:**
- `BANKFRAME_OPENED` - collected when player opens their bank (0.5s delay for data loading)

**Stored In:** `charData.personalBank`

### 3. Warband Bank Module
**File:** `Modules/WarbandBank.lua`

**Collects:**
- Warband Bank tabs 1-5
- Total account money stored in warband bank
- For each tab:
  - Tab name and icon
  - Up to 98 slots per tab
  - Each slot contains:
    - Item ID, Link, Name
    - Quality, Item Level
    - Texture icon
    - Stack count
    - Lock status
    - Bind status
- Last update timestamp

**Event Triggers:**
- Manual collection only (called by other addons)
- Uses `C_Bank.FetchDepositedMoney` and `C_Bank.FetchPurchasedBankTabData`

**Stored In:** `charData.warbandBank`

### 4. Guild Bank Module
**File:** `Modules/GuildBank.lua`

**Collects:**
- Guild name
- Total guild bank money
- Guild bank tabs 1-8
- For each viewable tab:
  - Tab name, icon
  - Deposit permissions
  - Up to 98 slots per tab
  - Each slot contains:
    - Item ID, Link, Name
    - Quality, Item Level
    - Texture icon
    - Stack count
    - Lock status
- Last update timestamp

**Event Triggers:**
- `GUILDBANKFRAME_OPENED` - collected when player opens guild bank (0.5s delay)
- `GUILDBANK_UPDATE_TABS` - updates when tabs are switched (0.2s delay)

**Stored In:** `charData.guildBank`

**Special Behavior:**
- Returns `nil` if character is not in a guild

### 5. Mail Module
**File:** `Modules/Mail.lua`

**Collects:**
- Total number of mail items
- Up to 20 most recent mail items
- For each mail:
  - Sender name
  - Subject line
  - Money amount
  - COD amount
  - Days left until expiration
  - Read status
  - Return status
  - Reply capability
  - GM mail flag
  - Attached items (up to `ATTACHMENTS_MAX_RECEIVE`)
  - For each attachment:
    - Item name, link, ID
    - Texture icon
    - Stack count
    - Quality
    - Usability flag
- Last update timestamp

**Event Triggers:**
- `MAIL_SHOW` - collected when mailbox opened (0.5s delay)
- `MAIL_INBOX_UPDATE` - updates when mail changes (0.2s delay)
- `UPDATE_PENDING_MAIL` - updates when pending mail indicator changes (0.2s delay)

**Stored In:** `charData.mail`

## Database Structure

### Saved Variable
**Name:** `OneWoW_AltTracker_Storage_DB`

**Root Structure:**
```lua
OneWoW_AltTracker_Storage_DB = {
    characters = {
        ["CharName-RealmName"] = {
            -- Character data here
        },
    },
    settings = {
        enableDataCollection = true,
        trackBags = true,
        trackPersonalBank = true,
        trackWarbandBank = true,
        trackGuildBank = true,
        trackMail = true,
    },
    version = 1,
}
```

### Character Data Structure
**Character Key Format:** `"CharacterName-RealmName"`

Each character entry contains:
```lua
characters["CharName-RealmName"] = {
    bags = {
        [bagID] = {
            numSlots = number,
            slots = {
                [slotID] = {
                    itemID = number,
                    itemLink = string,
                    itemName = string,
                    quality = number,
                    itemLevel = number,
                    texture = number,
                    stackCount = number,
                    isLocked = boolean,
                    isBound = boolean,
                },
            },
        },
    },
    bagsLastUpdate = timestamp,

    personalBank = {
        [bankBagID] = {
            numSlots = number,
            slots = { -- same structure as bags
            },
        },
    },
    personalBankLastUpdate = timestamp,

    warbandBank = {
        money = number,
        tabs = {
            [tabID] = {
                name = string,
                icon = number,
                slots = { -- same structure as bags
                },
            },
        },
    },
    warbandBankLastUpdate = timestamp,

    guildBank = {
        guildName = string,
        money = number,
        tabs = {
            [tabID] = {
                name = string,
                icon = number,
                canDeposit = boolean,
                slots = { -- same structure as bags
                },
            },
        },
    },
    guildBankLastUpdate = timestamp,

    mail = {
        numMails = number,
        mails = {
            [mailID] = {
                sender = string,
                subject = string,
                money = number,
                CODAmount = number,
                daysLeft = number,
                hasItem = boolean,
                wasRead = boolean,
                wasReturned = boolean,
                canReply = boolean,
                isGM = boolean,
                items = {
                    [attachmentIndex] = {
                        name = string,
                        itemLink = string,
                        itemID = number,
                        texture = number,
                        count = number,
                        quality = number,
                        canUse = boolean,
                    },
                },
            },
        },
    },
    mailLastUpdate = timestamp,
}
```

## Data Collection Orchestration

### DataManager (Modules/DataManager.lua)
The DataManager orchestrates all data collection:

1. **Initialization** - Registers all storage-related events
2. **Event Handling** - Routes events to appropriate collection modules
3. **Module Coordination** - Calls individual module collection functions
4. **Settings Respect** - Only collects data if tracking is enabled for that module

### Event Flow
```
Event Triggered
    ↓
DataManager:HandleEvent()
    ↓
Adds delay for data loading (0.2-0.5s)
    ↓
Calls appropriate module CollectData()
    ↓
Module stores data in character table
    ↓
Updates lastUpdate timestamp
```

## How to Access the Data

### Accessing Data from Other Addons

The main OneWoW_AltTracker addon reads storage data directly from the `OneWoW_AltTracker_Storage_DB` SavedVariable:

```lua
local db = OneWoW_AltTracker_Storage_DB
if db and db.characters then
    local charKey = "CharName-RealmName"
    local charData = db.characters[charKey]

    if charData then
        -- Bags
        if charData.bags then
            for bagID, bagData in pairs(charData.bags) do
                print("Bag " .. bagID .. " has " .. bagData.numSlots .. " slots")
                if bagData.slots then
                    for slotID, itemData in pairs(bagData.slots) do
                        print("  " .. itemData.itemName .. " x" .. itemData.stackCount)
                    end
                end
            end
        end

        -- Personal Bank
        if charData.personalBank then
            for bankBagID, bagData in pairs(charData.personalBank) do
                print("Bank bag " .. bankBagID .. " has " .. bagData.numSlots .. " slots")
            end
        end

        -- Mail
        if charData.mail and charData.mail.mails then
            print("Total mail items:", charData.mail.numMails)
            for mailID, mailData in ipairs(charData.mail.mails) do
                print("From:", mailData.sender, "Subject:", mailData.subject)
            end
        end

        -- Guild Bank
        if charData.guildBank then
            print("Guild:", charData.guildBank.guildName)
            print("Guild Bank Money:", charData.guildBank.money)
        end
    end
end
```

### Search for Items Across All Characters

```lua
local searchItemID = 12345
local db = OneWoW_AltTracker_Storage_DB
if db and db.characters then
    for charKey, charData in pairs(db.characters) do
        -- Search bags
        if charData.bags then
            for bagID, bagData in pairs(charData.bags) do
                if bagData.slots then
                    for slotID, itemData in pairs(bagData.slots) do
                        if itemData.itemID == searchItemID then
                            print(charKey .. " has " .. itemData.stackCount .. " in bags")
                        end
                    end
                end
            end
        end
    end
end
```

## When Data is Collected

### Automatic Collection
- **Bags:** Every time bag contents change (`BAG_UPDATE_DELAYED`)
- **Personal Bank:** When bank is opened (`BANKFRAME_OPENED`)
- **Guild Bank:** When guild bank is opened or tabs switch (`GUILDBANKFRAME_OPENED`, `GUILDBANK_UPDATE_TABS`)
- **Mail:** When mailbox is opened or inbox updates (`MAIL_SHOW`, `MAIL_INBOX_UPDATE`)

### Manual Collection
- **Warband Bank:** Must be manually triggered (no automatic events)
- **Force All:** Call `API.ForceDataCollection()` to collect all enabled data types

### Login Collection
- Automatically collects bag data on `PLAYER_LOGIN`

## Settings

Settings control what data is tracked:
```lua
OneWoW_AltTracker_Storage_DB.settings = {
    enableDataCollection = true,  -- Master toggle
    trackBags = true,             -- Track character bags
    trackPersonalBank = true,     -- Track personal bank
    trackWarbandBank = true,      -- Track warband bank
    trackGuildBank = true,        -- Track guild bank
    trackMail = true,             -- Track mail
}
```

## Integration with Other Addons

This addon is designed to be used by:
- **OneWoW_AltTracker** - Main UI and display addon
- Any other addon that needs storage data across characters

## Dependencies
- **Optional:** OneWoW_AltTracker (for UI integration)
- **Required:** World of Warcraft interface 120000+

## File Structure
```
OneWoW_AltTracker_Storage/
├── Core/
│   ├── Core.lua           - Addon initialization and event handling
│   └── Database.lua       - Database structure and access functions
├── Modules/
│   ├── Bags.lua          - Bag data collection
│   ├── PersonalBank.lua  - Personal bank data collection
│   ├── WarbandBank.lua   - Warband bank data collection
│   ├── GuildBank.lua     - Guild bank data collection
│   ├── Mail.lua          - Mail data collection
│   └── DataManager.lua   - Orchestrates all data collection
├── API/
│   └── StorageAPI.lua    - Public API for external addons
├── Locales/
│   └── enUS.lua          - English localization
├── OneWoW_AltTracker_Storage.lua  - Main addon file with API setup
└── OneWoW_AltTracker_Storage.toc  - Addon manifest
```

## Version
**Current Version:** B6.2602.1600

## Author
MichinMuggin / Ricky

## Website
https://wow2.xyz/
