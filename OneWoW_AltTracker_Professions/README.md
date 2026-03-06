# OneWoW AltTracker: Professions

Comprehensive profession tracking system for World of Warcraft. Automatically collects profession data across all your characters including levels, recipes, equipment, cooldowns, and trainer locations.

## What Data Is Collected

### 1. ProfessionBasics Module
**File:** `Modules/ProfessionBasics.lua`

**Collects:**
- Profession names and icons
- Current skill level and maximum skill level
- Skill modifiers (bonuses from equipment, buffs)
- Number of abilities/spells
- Skill line ID
- Profession slot index

**Data Collected For:**
- Primary Profession 1 (slot: Primary1)
- Primary Profession 2 (slot: Primary2)
- Cooking (slot: Cooking)
- Fishing (slot: Fishing)
- Archaeology (slot: Archaeology)

**Triggered By:**
- TRADE_SKILL_SHOW event (opening profession window)
- PLAYER_EQUIPMENT_CHANGED event (changing profession gear)

**Storage Location:** `charData.professions`

**Database Structure:**
```lua
charData.professions = {
    Primary1 = {
        name = "Blacksmithing",
        icon = 136241,
        currentSkill = 175,
        maxSkill = 200,
        skillLine = 164,
        skillModifier = 0,
        numAbilities = 150,
        spellOffset = 2018,
        index = 1
    },
    Primary2 = { ... },
    Cooking = { ... },
    Fishing = { ... },
    Archaeology = { ... }
}
```

---

### 2. ProfessionAdvanced Module
**File:** `Modules/ProfessionAdvanced.lua`

**Collects:**
- All known recipes for the opened profession
- Recipe details (name, icon, ID, category)
- Craftability status (can craft, skill-up potential)
- Recipe reagents (materials required)
- Output items and quantities
- Quality system support (Dragonflight/TWW recipes)
- Recipe organization by expansion

**Triggered By:**
- TRADE_SKILL_SHOW event (0.5s delay, then 1s delay for advanced data)
- TRADE_SKILL_LIST_UPDATE event (0.3s delay when profession window is open)

**Storage Location:**
- `charData.recipes[professionName]` (all recipe details)
- `charData.recipesByExpansion[professionName]` (recipes organized by expansion)

**Database Structure:**
```lua
charData.recipes = {
    ["Blacksmithing"] = {
        [12345] = {
            recipeID = 12345,
            name = "Hardened Iron Shortsword",
            learned = true,
            craftable = true,
            disabled = false,
            favorite = false,
            icon = 135321,
            categoryID = 1501,
            canSkillUp = true,
            numSkillUps = 3,
            relativeDifficulty = "medium",
            supportsQualities = false,
            isRecraft = false,
            outputItemID = 7913,
            quantityMin = 1,
            quantityMax = 1,
            reagents = {
                {
                    itemID = 3575,
                    currencyID = nil,
                    quantity = 6,
                    required = true
                },
                -- more reagents...
            }
        },
        -- more recipes...
    },
    ["Engineering"] = { ... }
}

charData.recipesByExpansion = {
    ["Blacksmithing"] = {
        [0] = {  -- Classic
            expansionID = 0,
            expansionName = "Classic",
            learnedRecipes = 45,
            totalRecipes = 150,
            recipes = { 12345, 12346, 12347, ... }
        },
        [9] = {  -- Dragonflight
            expansionID = 9,
            expansionName = "Dragonflight",
            learnedRecipes = 120,
            totalRecipes = 200,
            recipes = { ... }
        },
        -- other expansions...
    }
}
```

**Expansion IDs:**
- 0: Classic
- 1: The Burning Crusade
- 2: Wrath of the Lich King
- 3: Cataclysm
- 4: Mists of Pandaria
- 5: Warlords of Draenor
- 6: Legion
- 7: Battle for Azeroth
- 8: Shadowlands
- 9: Dragonflight
- 10: The War Within
- 11: Midnight

---

### 3. ProfessionEquipment Module
**File:** `Modules/ProfessionEquipment.lua`

**Collects:**
- Profession tools (main hand tools)
- Profession accessories (gear that boosts profession skills)
- Item details (name, quality, item level, item ID, link)

**Equipment Slots:**
- Primary1: Tool (slot 20), Accessory1 (slot 21), Accessory2 (slot 22)
- Primary2: Tool (slot 23), Accessory1 (slot 24), Accessory2 (slot 25)
- Cooking: Tool (slot 26), Accessory1 (slot 27)
- Fishing: Tool (slot 28), Accessory1 (slot 29), Accessory2 (slot 30)

**Triggered By:**
- TRADE_SKILL_SHOW event (when opening profession window)
- PLAYER_EQUIPMENT_CHANGED event (when changing profession gear, slots 20-30)

**Storage Location:** `charData.professionEquipment`

**Database Structure:**
```lua
charData.professionEquipment = {
    ["Blacksmithing"] = {
        professionName = "Blacksmithing",
        tool = {
            slotID = 20,
            itemID = 191233,
            itemLink = "|cff0070dd|Hitem:191233...",
            itemName = "Khaz'gorite Blacksmith's Hammer",
            itemQuality = 3,  -- Rare
            itemLevel = 350
        },
        accessory1 = {
            slotID = 21,
            itemID = 198245,
            itemLink = "|cff0070dd|Hitem:198245...",
            itemName = "Draconium Blacksmith's Toolbox",
            itemQuality = 3,
            itemLevel = 350
        },
        accessory2 = nil  -- Empty slot
    },
    ["Engineering"] = { ... }
}
```

---

### 4. ProfessionCooldowns Module
**File:** `Modules/ProfessionCooldowns.lua`

**Collects:**
- Active recipe cooldowns
- Cooldown expiration times
- Recipe names and IDs on cooldown

**Triggered By:**
- TRADE_SKILL_SHOW event (when opening profession window)
- TRADE_SKILL_LIST_UPDATE event (when profession data updates)

**Storage Location:** `charData.recipeCooldowns[professionName]`

**Database Structure:**
```lua
charData.recipeCooldowns = {
    ["Tailoring"] = {
        [12345] = {
            recipeID = 12345,
            recipeName = "Mooncloth",
            cooldown = 86400,  -- Cooldown duration in seconds
            cooldownExpires = 1708123456,  -- Unix timestamp
            scannedAt = 1708037056  -- Unix timestamp when scanned
        },
        -- more recipes on cooldown...
    }
}
```

**Helper Functions:**
- `GetActiveCooldowns()` - Returns only cooldowns that haven't expired yet
- `CleanExpiredCooldowns()` - Removes expired cooldowns from database

---

### 5. ProfessionTrainers Module
**File:** `Modules/ProfessionTrainers.lua`

**Collects:**
- Trainer locations (zone, subzone, map coordinates)
- Visit timestamps
- Map IDs and position data

**Triggered By:**
- TRAINER_SHOW event (when opening profession trainer NPC)

**Storage Location:** `charData.trainerLocations` (array, max 50 entries)

**Database Structure:**
```lua
charData.trainerLocations = {
    [1] = {
        zoneName = "Valdrakken",
        subZoneName = "Artisan's Market",
        mapID = 2112,
        position = {
            x = 0.581,
            y = 0.423
        },
        timestamp = 1708037056
    },
    [2] = { ... },
    -- up to 50 most recent trainer visits
}
```

**Helper Functions:**
- `GetRecentTrainers(count)` - Returns most recent trainer visits
- `GetTrainersByZone(zoneName)` - Returns all trainer visits in a specific zone

---

## Database Structure

**Global Variable:** `OneWoW_AltTracker_Professions_DB`

**Top Level Structure:**
```lua
OneWoW_AltTracker_Professions_DB = {
    characters = {
        ["CharName-RealmName"] = {
            -- Basic profession info
            professions = { ... },

            -- Equipment
            professionEquipment = { ... },

            -- Recipes (organized by profession)
            recipes = {
                ["ProfessionName"] = { [recipeID] = {...} }
            },

            -- Recipes organized by expansion
            recipesByExpansion = {
                ["ProfessionName"] = { [expansionID] = {...} }
            },

            -- Cooldowns (organized by profession)
            recipeCooldowns = {
                ["ProfessionName"] = { [recipeID] = {...} }
            },

            -- Trainer locations (array)
            trainerLocations = { ... },

            -- Last update timestamp
            lastUpdate = 1708037056
        }
    },

    settings = {
        enableDataCollection = true,
        trackRecipes = true,
        trackEquipment = true,
        trackCooldowns = true,
        trackTrainers = true
    },

    version = 1
}
```

---

## When Data Is Collected

### Automatic Collection

**Event-Driven Collection:**
1. **TRADE_SKILL_SHOW** - Fired when profession window opens
   - Collects basic profession info (0.5s delay)
   - Collects advanced recipe data (1.0s delay)
   - Collects equipment data
   - Collects cooldown data

2. **TRADE_SKILL_LIST_UPDATE** - Fired when recipe list changes
   - Updates recipe data for currently open profession (0.3s delay)
   - Updates cooldown data

3. **PLAYER_EQUIPMENT_CHANGED** - Fired when gear changes (slots 20-30)
   - Updates basic profession info (0.5s delay)
   - Updates equipment data

4. **TRAINER_SHOW** - Fired when trainer window opens
   - Records trainer location (0.5s delay)

### Manual Collection

**API Functions:**
- `ForceFullScan()` - Scans all available data right now
- `CollectBasicData()` - Scans only basic profession info and equipment

---

## DataManager Orchestration

**File:** `Modules/DataManager.lua`

The DataManager acts as the central orchestrator that triggers data collection from all modules:

**Responsibilities:**
- Registers game events
- Handles event timing (delays to ensure data is ready)
- Calls appropriate module collection functions
- Manages current open profession state
- Provides access to character data

**Event Flow:**
1. Game event fires (TRADE_SKILL_SHOW, etc.)
2. DataManager receives event with delay
3. DataManager calls appropriate module(s)
4. Module collects data and stores in database
5. Updates `lastUpdate` timestamp

---

## How To Access The Data

### Accessing Data from Other Addons

The main OneWoW_AltTracker addon reads profession data directly from the `OneWoW_AltTracker_Professions_DB` SavedVariable:

```lua
local db = OneWoW_AltTracker_Professions_DB
if db and db.characters then
    local charKey = "CharacterName-RealmName"
    local charData = db.characters[charKey]

    if charData then
        -- Basic profession info
        if charData.professions then
            for slotName, profData in pairs(charData.professions) do
                print(profData.name .. ": " .. profData.currentSkill .. "/" .. profData.maxSkill)
            end
        end

        -- Profession equipment
        if charData.professionEquipment then
            for profName, equipment in pairs(charData.professionEquipment) do
                print(profName .. " tool:", equipment.tool and equipment.tool.itemName or "None")
            end
        end

        -- Recipes
        if charData.recipes then
            for profName, recipes in pairs(charData.recipes) do
                local count = 0
                for recipeID, recipeData in pairs(recipes) do
                    if recipeData.learned then
                        count = count + 1
                    end
                end
                print(profName .. " recipes known:", count)
            end
        end

        -- Cooldowns
        if charData.recipeCooldowns then
            for profName, cooldowns in pairs(charData.recipeCooldowns) do
                for recipeID, cd in pairs(cooldowns) do
                    local timeLeft = cd.cooldownExpires - time()
                    if timeLeft > 0 then
                        print(cd.recipeName .. " cooldown:", SecondsToTime(timeLeft))
                    end
                end
            end
        end
    end
end
```

### Find Characters with Specific Profession

```lua
local blacksmiths = {}
local db = OneWoW_AltTracker_Professions_DB
if db and db.characters then
    for charKey, charData in pairs(db.characters) do
        if charData.professions then
            for slotName, profData in pairs(charData.professions) do
                if profData.name == "Blacksmithing" then
                    table.insert(blacksmiths, {key = charKey, data = profData})
                end
            end
        end
    end
end
```

---

## Usage Examples

### Example 1: List All Characters With Blacksmithing
```lua
local allChars = OneWoW_AltTracker_Professions_API.GetAllCharacters()

for _, char in ipairs(allChars) do
    local charData = char.data

    if charData.professions then
        for slotName, profData in pairs(charData.professions) do
            if profData.name == "Blacksmithing" then
                print(char.key .. " has Blacksmithing: " ..
                      profData.currentSkill .. "/" .. profData.maxSkill)
            end
        end
    end
end
```

### Example 2: Check Which Characters Can Craft An Item
```lua
local allChars = OneWoW_AltTracker_Professions_API.GetAllCharacters()
local searchRecipeID = 12345

for _, char in ipairs(allChars) do
    local charData = char.data

    if charData.recipes then
        for profName, recipes in pairs(charData.recipes) do
            if recipes[searchRecipeID] and recipes[searchRecipeID].learned then
                print(char.key .. " can craft " .. recipes[searchRecipeID].name)
            end
        end
    end
end
```

### Example 3: Find Characters With Active Profession Cooldowns
```lua
local allChars = OneWoW_AltTracker_Professions_API.GetAllCharacters()

for _, char in ipairs(allChars) do
    local charKey = char.key
    local charData = char.data

    if charData.professions then
        for slotName, profData in pairs(charData.professions) do
            local cooldowns = OneWoW_AltTracker_Professions_API.GetActiveCooldowns(charKey, profData.name)

            if #cooldowns > 0 then
                print(charKey .. " - " .. profData.name .. " has " .. #cooldowns .. " cooldowns")

                for _, cd in ipairs(cooldowns) do
                    local timeLeft = cd.cooldownExpires - time()
                    print("  - " .. cd.recipeName .. ": " .. SecondsToTime(timeLeft) .. " left")
                end
            end
        end
    end
end
```

### Example 4: Find Missing Profession Equipment
```lua
local charKey = OneWoW_AltTracker_Professions_API.GetCurrentCharacterKey()
local charData = OneWoW_AltTracker_Professions_API.GetCharacterData(charKey)

if charData and charData.professions then
    for slotName, profData in pairs(charData.professions) do
        local equipment = OneWoW_AltTracker_Professions_API.GetProfessionEquipment(charKey, profData.name)

        if equipment then
            if not equipment.tool then
                print(profData.name .. " is missing a tool!")
            end
            if not equipment.accessory1 and not equipment.accessory2 then
                print(profData.name .. " has no accessories!")
            end
        end
    end
end
```

---

## Integration With OneWoW AltTracker

This addon is designed to work as a standalone datastore or integrate with the main OneWoW AltTracker addon.

**OptionalDeps:** OneWoW_AltTracker

When the main AltTracker addon is loaded, this professions datastore can be queried for profession information across all characters.

---

## Version Information

**Current Version:** B6.2602.1600
**Interface:** 120000, 120001, 120002 (The War Within)
**Author:** MichinMuggin / Ricky
