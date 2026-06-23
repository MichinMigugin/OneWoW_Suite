# OneWoW AltTracker: Collections

> **See also:** [OneWoW/Docs/ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)

Collections data tracking addon for OneWoW AltTracker system. Tracks quests, reputations, achievements, battle pets, and mounts across all your characters.

## Overview

This addon collects and stores collections-related data for each character:
- Active and completed quests
- Faction reputations and standings
- Achievement progress and completion
- Battle pet collection and stats
- Mount collection and availability

## Architecture

### Core Files
- **Core/Database.lua** - Database initialization, character key generation, data retrieval
- **Core/Core.lua** - Addon initialization, event handling, player login processing

### Data Collection Modules

#### Quests Module (`Modules/Quests.lua`)
Tracks quest log and completion status.

**Functions:**
- `CollectData(charKey, charData)` - Collects all quest data for a character
- `IsQuestCompleted(questID)` - Checks if a quest is completed
- `GetQuestInfo(questID)` - Retrieves detailed quest information

**Data Stored:**
- Active quests (questID, title, level, daily/weekly status, completion state)
- Completed quest IDs
- Quest log capacity and counts

#### Reputations Module (`Modules/Reputations.lua`)
Tracks faction reputations and standings.

**Functions:**
- `CollectData(charKey, charData)` - Collects all reputation data for a character
- `GetFactionStanding(factionID)` - Retrieves current standing with a faction

**Data Stored:**
- Faction details (name, description, reaction level)
- Standing values (current, thresholds)
- Paragon reputation status
- Watch/war status flags

#### Achievements Module (`Modules/Achievements.lua`)
Tracks achievement progress and completion.

**Functions:**
- `CollectData(charKey, charData)` - Collects all achievement data for a character
- `GetAchievementInfo(achievementID)` - Retrieves detailed achievement information including criteria

**Data Stored:**
- Total achievement points
- Completed achievement count
- Recent achievements (last 25)
- Achievement criteria progress

#### PetsMounts Module (`Modules/PetsMounts.lua`)
Tracks battle pets and mounts.

**Functions:**
- `CollectData(charKey, charData)` - Collects both pet and mount data
- `CollectPets(pmData)` - Collects battle pet collection data
- `CollectMounts(pmData)` - Collects mount collection data
- `GetPetInfo(petID)` - Retrieves detailed pet information
- `GetMountInfo(mountID)` - Retrieves detailed mount information

**Data Stored:**
- Pet collection (species, names, levels, stats, battle readiness)
- Mount collection (names, spell IDs, favorite status, usability)
- Collection totals and owned counts

### DataManager (`Modules/DataManager.lua`)
Orchestrates all data collection modules and handles real-time updates.

**Functions:**
- `Initialize()` - Initializes the DataManager
- `RegisterEvents()` - Registers game events for automatic updates
- `CollectAllData()` - Triggers all module data collection
- `UpdateQuests()` - Updates quest data only
- `UpdateReputations()` - Updates reputation data only
- `UpdateAchievements()` - Updates achievement data only
- `UpdatePetsMounts()` - Updates pets/mounts data only
- `GetCharacterData(charKey)` - Retrieves character data
- `GetAllCharacters()` - Retrieves all characters sorted by last update
- `DeleteCharacter(charKey)` - Deletes character data

**Events Monitored:**
- PLAYER_ALIVE, PLAYER_ENTERING_WORLD - Full data collection
- UNIT_QUEST_LOG_CHANGED, QUEST_ACCEPTED, QUEST_REMOVED, QUEST_LOG_UPDATE - Quest updates
- UPDATE_FACTION - Reputation updates
- ACHIEVEMENT_EARNED, CRITERIA_UPDATE - Achievement updates
- NEW_PET_ADDED, MOUNT_JOURNAL_USABILITY_CHANGED - Pet/mount updates

## Database Structure

**SavedVariable:** `OneWoW_AltTracker_Collections_DB`

```lua
OneWoW_AltTracker_Collections_DB = {
    characters = {
        ["CharName-RealmName"] = {
            quests = {
                activeCount = number,
                active = { {questID, title, level, isDaily, isWeekly, isComplete, ...}, ... },
                completed = { questID, ... },
                completedCount = number,
            },
            reputations = {
                factions = { {factionID, name, reaction, currentStanding, ...}, ... },
                count = number,
            },
            achievements = {
                totalPoints = number,
                completedCount = number,
                recent = { {achievementID, name, points, month, day, year}, ... },
            },
            petsMounts = {
                pets = {
                    totalCount = number,
                    ownedCount = number,
                    collection = { {petID, speciesID, level, stats, ...}, ... },
                },
                mounts = {
                    totalCount = number,
                    ownedCount = number,
                    collection = { {mountID, name, spellID, icon, ...}, ... },
                },
            },
            lastUpdate = timestamp,
        },
        -- More characters...
    },
    settings = {
        enableDataCollection = boolean,
    },
    version = number,
}
```

## Data Access

Persistence lives in `OneWoW_AltTracker_Collections_DB` (the WoW `## SavedVariables`
root). **Cross-unit readers must use `OneWoW_AltTracker_Collections_API`** — not the
`_DB` global directly (see [OneWoW/Docs/ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md) §6,
enforced by the `no-data-manager-bypass` pre-commit hook).

### Accessing Data from Other Addons

```lua
local API = OneWoW_AltTracker_Collections_API
if API then
    local charKey = "CharacterName-RealmName"
    local charData = API.GetCharacterData(charKey)

    if charData then
        -- Quest data
        if charData.quests then
            print("Active quests:", charData.quests.activeCount)
            print("Completed quests:", charData.quests.completedCount)
        end

        -- Reputation data
        if charData.reputations then
            for _, faction in ipairs(charData.reputations.factions) do
                print(faction.name .. ": " .. faction.reaction)
            end
        end

        -- Achievement data
        if charData.achievements then
            print("Achievement Points:", charData.achievements.totalPoints)
            print("Completed Achievements:", charData.achievements.completedCount)
        end

        -- Pets and Mounts
        if charData.petsMounts then
            print("Pets Owned:", charData.petsMounts.pets.ownedCount)
            print("Mounts Owned:", charData.petsMounts.mounts.ownedCount)
        end
    end
end
```

### Checking Quest Completion

```lua
local API = OneWoW_AltTracker_Collections_API
if API and API.IsQuestCompleted(12345) then
    print("Quest 12345 is completed on the current character!")
end
```

## Integration with AltTracker

This addon is designed to work with the main OneWoW_AltTracker addon. It:
- Shares the same database structure pattern
- Uses consistent character key format (Name-Realm)
- Stores data in a separate SavedVariable for modularity
- Updates data automatically via game events
- Data is exposed to other units through `OneWoW_AltTracker_Collections_API`

## Data Collection Behavior

### Automatic Collection
Data is automatically collected on:
- Player login
- World entry
- Relevant game events (quest turn-ins, reputation gains, etc.)

### Manual Collection
Data collection can be triggered manually via API:
```lua
OneWoW_AltTracker_Collections_API.DataManager.CollectAllData()
```

### Data Freshness
- Each character entry has a `lastUpdate` timestamp
- Characters are sorted by most recent update
- Stale data can be identified and refreshed

## Performance Considerations

- Event-driven updates use 0.5-1 second delays to batch rapid changes
- Quest log scanning is optimized (only scans on quest events)
- Pet/mount collection uses filtered journal queries
- Large data sets (completed quests, all factions) are stored efficiently

## Future Enhancements

Potential additions:
- Quest chain tracking
- Reputation milestone alerts
- Achievement completion percentage
- Pet battle statistics
- Mount favorites sync
- Collection comparison across alts
- Missing achievement/pet/mount detection

## Version History

- **B6.2602.1600** - Initial release
  - Quest tracking (active and completed)
  - Reputation tracking (all factions with paragon support)
  - Achievement tracking (points and recent completions)
  - Battle pet collection tracking
  - Mount collection tracking
  - Automatic event-driven updates
  - Global API for external access
