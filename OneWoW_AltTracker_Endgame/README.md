# OneWoW AltTracker: Endgame

Endgame data tracking module for OneWoW AltTracker system. Tracks Mythic Plus, Raids, Great Vault, and PVP activities across all characters.

## Overview

This addon collects and stores endgame progression data for all characters on your account. Data is automatically collected on login and updated when relevant events occur.

## Modules

### 1. Mythic Plus Module
**File:** `/Modules/MythicPlus.lua`

Tracks Mythic Plus keystone and progression data.

**Data Collected:**
- Current keystone (mapID, level, mapName)
- Overall Mythic Plus score
- Season best runs for all dungeons (in-time and overtime)
- Run details including level, duration, and party members
- Character class information for each party member

**WoW APIs Used:**
- `C_MythicPlus.GetOwnedKeystoneChallengeMapID()`
- `C_MythicPlus.GetOwnedKeystoneLevel()`
- `C_ChallengeMode.GetMapUIInfo(mapID)`
- `C_ChallengeMode.GetOverallDungeonScore()`
- `C_ChallengeMode.GetMapTable()`
- `C_MythicPlus.GetSeasonBestForMap(mapID)`

**Data Structure:**
```lua
charData.mythicPlus = {
    currentKeystone = {
        mapID = number,
        level = number,
        mapName = string,
    },
    overallScore = number,
    seasonBest = {
        [mapID] = {
            intime = {
                level = number,
                durationSec = number,
                members = {
                    { name = string, classID = number }
                }
            },
            overtime = {
                level = number,
                durationSec = number,
                members = {
                    { name = string, classID = number }
                }
            }
        }
    },
    lastUpdated = timestamp
}
```

### 2. Raids Module
**File:** `/Modules/Raids.lua`

Tracks raid lockouts and boss kill progress.

**Data Collected:**
- Active raid lockouts for all difficulties
- Boss kill status for each encounter
- Lockout reset times
- Extended lockout status
- Raid size and difficulty information

**WoW APIs Used:**
- `RequestRaidInfo()`
- `GetNumSavedInstances()`
- `GetSavedInstanceInfo(index)`
- `GetSavedInstanceEncounterInfo(index, encounterIndex)`

**Data Structure:**
```lua
charData.raids = {
    lockouts = {
        {
            name = string,
            id = number,
            reset = number,
            difficulty = number,
            difficultyName = string,
            extended = boolean,
            maxPlayers = number,
            numEncounters = number,
            encounterProgress = number,
            encounters = {
                {
                    name = string,
                    isKilled = boolean,
                    fileDataID = number
                }
            }
        }
    },
    lastUpdated = timestamp
}
```

### 3. Great Vault Module
**File:** `/Modules/GreatVault.lua`

Tracks weekly Great Vault progress and rewards.

**Data Collected:**
- Available reward status
- Progress for Raid, Dungeon, and World activities
- Activity thresholds and completion status
- Example rewards for each activity slot
- Item level and quality information

**WoW APIs Used:**
- `C_WeeklyRewards.HasAvailableRewards()`
- `C_WeeklyRewards.GetActivities()`
- `C_WeeklyRewards.GetExampleRewardItemHyperlinks(activityID)`
- `GetItemInfo(itemID)`

**Data Structure:**
```lua
charData.greatVault = {
    hasAvailableRewards = boolean,
    activities = {
        raid = {
            {
                type = number,
                index = number,
                level = number,
                progress = number,
                threshold = number,
                rewards = {
                    {
                        itemID = number,
                        itemLevel = number,
                        itemQuality = number,
                        hyperlink = string
                    }
                }
            }
        },
        dungeon = { ... },
        world = { ... }
    },
    lastUpdated = timestamp
}
```

### 4. PVP Module
**File:** `/Modules/PVP.lua`

Tracks PVP progression, ratings, and currencies.

**Data Collected:**
- Honor level
- Lifetime PVP statistics (kills, deaths)
- Seasonal ratings for 2v2, 3v3, RBG
- Tier information and item levels
- Honor and Conquest currency amounts

**WoW APIs Used:**
- `UnitHonorLevel("player")`
- `GetPVPLifetimeStats()`
- `C_PvP.GetPvpTierInfo(bracketType)`
- `C_PvP.GetSeasonBestInfo(bracketType)`
- `C_CurrencyInfo.GetCurrencyInfo(currencyID)`

**Data Structure:**
```lua
charData.pvp = {
    honorLevel = number,
    lifetimeStats = {
        honorableKills = number,
        kills = number,
        deaths = number
    },
    season = {
        arena2v2 = {
            tierID = number,
            tierName = string,
            activityItemLevel = number,
            weeklyItemLevel = number,
            rating = number,
            tier = number
        },
        arena3v3 = { ... },
        rbg = { ... }
    },
    currencies = {
        honor = {
            id = number,
            name = string,
            quantity = number,
            maxQuantity = number,
            iconFileID = number
        },
        conquest = {
            id = number,
            name = string,
            quantity = number,
            maxQuantity = number,
            maxWeeklyQuantity = number,
            quantityEarnedThisWeek = number,
            iconFileID = number
        }
    },
    lastUpdated = timestamp
}
```

## DataManager Orchestration

**File:** `/Modules/DataManager.lua`

Central orchestrator for all endgame data collection modules.

**Responsibilities:**
- Initialize all modules on player login
- Register and handle game events
- Coordinate data collection across all modules
- Provide unified interface for data access

**Events Monitored:**
- `PLAYER_ALIVE` - Full data collection on login
- `PLAYER_ENTERING_WORLD` - Full data collection on world enter
- `CHALLENGE_MODE_MAPS_UPDATE` - Update Mythic Plus data
- `MYTHIC_PLUS_CURRENT_AFFIX_UPDATE` - Update Mythic Plus data
- `UPDATE_INSTANCE_INFO` - Update Raid lockouts
- `WEEKLY_REWARDS_UPDATE` - Update Great Vault data
- `CURRENCY_DISPLAY_UPDATE` - Update PVP currencies
- `PVP_RATED_STATS_UPDATE` - Update PVP ratings
- `HONOR_LEVEL_UPDATE` - Update PVP honor level

**Methods:**
- `Initialize()` - Initialize the DataManager
- `RegisterEvents()` - Register all game events
- `CollectAllData()` - Trigger collection from all modules
- `UpdateMythicPlus()` - Update only Mythic Plus data
- `UpdateRaids()` - Update only Raid data
- `UpdateGreatVault()` - Update only Great Vault data
- `UpdatePVP()` - Update only PVP data
- `GetCharacterData(charKey)` - Retrieve character data
- `GetAllCharacters()` - Retrieve all characters sorted by last login
- `DeleteCharacter(charKey)` - Remove character data

## Database Structure

**SavedVariable:** `OneWoW_AltTracker_Endgame_DB`

**File:** `/Core/Database.lua`

```lua
OneWoW_AltTracker_Endgame_DB = {
    characters = {
        ["CharName-RealmName"] = {
            lastLogin = timestamp,
            mythicPlus = { ... },
            raids = { ... },
            greatVault = { ... },
            pvp = { ... }
        }
    },
    settings = {
        enableDataCollection = boolean
    },
    version = number
}
```

**Database Functions:**
- `ns:InitializeDatabase()` - Initialize database with defaults
- `ns:GetCharacterKey()` - Generate character key (Name-Realm)
- `ns:GetCharacterData(charKey)` - Get or create character data
- `ns:GetAllCharacters()` - Get all characters sorted by last login
- `ns:DeleteCharacter(charKey)` - Delete character data

## Data Access

This addon stores all data in the `OneWoW_AltTracker_Endgame_DB` SavedVariable. Other addons access this data directly.

### Accessing Data from Other Addons

The main OneWoW_AltTracker addon reads endgame data directly from the SavedVariable:

```lua
local db = OneWoW_AltTracker_Endgame_DB
if db and db.characters then
    local charKey = "CharacterName-RealmName"
    local charData = db.characters[charKey]

    if charData then
        -- Mythic Plus data
        if charData.mythicPlus then
            print("M+ Score:", charData.mythicPlus.overallScore)
            if charData.mythicPlus.currentKeystone then
                print("Current Key:", charData.mythicPlus.currentKeystone.mapName,
                      "+" .. charData.mythicPlus.currentKeystone.level)
            end
        end

        -- Raid lockouts
        if charData.raids and charData.raids.lockouts then
            for _, lockout in ipairs(charData.raids.lockouts) do
                print(lockout.name .. ": " .. lockout.encounterProgress .. "/" .. lockout.numEncounters)
            end
        end

        -- Great Vault
        if charData.greatVault then
            print("Vault Ready:", charData.greatVault.hasAvailableRewards)
        end

        -- PVP
        if charData.pvp then
            print("Honor Level:", charData.pvp.honorLevel)
            print("3v3 Rating:", charData.pvp.season.arena3v3.rating or 0)
        end
    end
end
```

### Check All Characters for Vault Rewards

```lua
local db = OneWoW_AltTracker_Endgame_DB
if db and db.characters then
    for charKey, charData in pairs(db.characters) do
        if charData.greatVault and charData.greatVault.hasAvailableRewards then
            print(charKey .. " has vault rewards available!")
        end
    end
end
```

### Find Highest Mythic Plus Score

```lua
local highestScore = 0
local highestChar = nil
local db = OneWoW_AltTracker_Endgame_DB
if db and db.characters then
    for charKey, charData in pairs(db.characters) do
        if charData.mythicPlus and charData.mythicPlus.overallScore then
            if charData.mythicPlus.overallScore > highestScore then
                highestScore = charData.mythicPlus.overallScore
                highestChar = charKey
            end
        end
    end
end
if highestChar then
    print(highestChar .. " has the highest M+ score:", highestScore)
end
```

## File Structure

```
OneWoW_AltTracker_Endgame/
├── API/
│   └── EndgameAPI.lua          # Global API interface
├── Core/
│   ├── Database.lua            # Database initialization and access
│   └── Core.lua                # Addon initialization and event handling
├── Locales/
│   └── enUS.lua                # English localization
├── Modules/
│   ├── MythicPlus.lua          # Mythic Plus data collection
│   ├── Raids.lua               # Raid lockout data collection
│   ├── GreatVault.lua          # Great Vault progress tracking
│   ├── PVP.lua                 # PVP rating and currency tracking
│   └── DataManager.lua         # Central orchestrator
├── OneWoW_AltTracker_Endgame.lua    # Main addon file
├── OneWoW_AltTracker_Endgame.toc    # TOC file
└── README.md                   # This file
```

## Integration with OneWoW AltTracker

This addon is designed to work seamlessly with the main OneWoW_AltTracker addon. When both are loaded:

1. Data collection happens automatically on login
2. Events trigger real-time updates as activities are completed
3. All data is accessible via the global API
4. Character keys match between both addons (Name-Realm format)

## Version

Current Version: B6.2602.1600
Interface: 120000, 120001, 120002
Author: MichinMuggin / Ricky

## Dependencies

- Optional: OneWoW_AltTracker (main addon)
- No required dependencies

## Notes

- Data is stored per-character using Name-Realm format
- All timestamps use Unix epoch time (seconds since 1970-01-01)
- Data collection is event-driven with delayed updates to avoid API throttling
- Character list is automatically sorted by last login time
- All modules follow the DataManager orchestration pattern
