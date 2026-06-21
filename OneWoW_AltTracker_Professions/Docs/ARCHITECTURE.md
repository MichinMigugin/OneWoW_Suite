# OneWoW AltTracker: Professions

> **See also:** [OneWoW/Docs/ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md) §6 (store access rules)

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
- The set of *learned* recipe (spell) IDs for the opened profession
- An account-level map of item ID → recipe (spell) ID (`recipeItemMap`)

> **Important:** Only learned recipe **spell IDs** are stored, as a
> `[recipeSpellID] = true` set. No recipe names, icons, reagents, output items,
> categories, or craftability/quality details are persisted — consumers re-query
> those live from `C_TradeSkillUI` when needed. "Recipes by expansion" is
> **derived on demand** by consumers (e.g.
> `OneWoW_AltTracker/Modules/alttracker/st-professions.lua`); it is **not** stored
> on `charData`.

**Triggered By:**
- TRADE_SKILL_SHOW event (when the profession window opens)
- TRADE_SKILL_LIST_UPDATE event (when the recipe list updates)

**Storage Location:**
- `charData.recipes[professionName]` — set of learned recipe spell IDs (`[recipeSpellID] = true`)
- `OneWoW_AltTracker_Professions_DB.recipeItemMap` — account-level `[itemID] = recipeSpellID` map (not per-character)

**Database Structure:**
```lua
-- Per-character: learned recipe SPELL IDs, keyed by profession name.
-- The value is simply `true`; no recipe detail is stored.
charData.recipes = {
    ["Blacksmithing"] = {
        [12345] = true,   -- 12345 = a recipe spell ID from C_TradeSkillUI.GetAllRecipeIDs()
        [12346] = true,
        -- more learned recipe spell IDs...
    },
    ["Engineering"] = { ... }
}

-- Account-level (DB root, NOT per-character): bridges an item to its recipe.
-- `itemID` comes from C_TradeSkillUI.GetRecipeItemLink(recipeID); used by callers
-- that start from an item (tooltips, item search) to find the recipe spell ID,
-- then check charData.recipes[prof][recipeSpellID].
OneWoW_AltTracker_Professions_DB.recipeItemMap = {
    [7913]  = 12345,  -- [craftedItemID] = recipeSpellID
    -- more item -> recipe mappings...
}
```

> **`recipesByExpansion` is not persisted.** Consumers that need it build it at
> read time from `charData.recipes` plus live `C_TradeSkillUI.GetRecipeInfo`
> lookups, grouping by the expansion IDs below.

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

            -- Learned recipe spell IDs, keyed by profession name ([spellID] = true)
            recipes = {
                ["ProfessionName"] = { [recipeSpellID] = true }
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

    -- Account-level item -> recipe spell ID map (see ProfessionAdvanced above)
    recipeItemMap = {
        [itemID] = recipeSpellID
    },

    settings = {
        enableDataCollection = true,
        trackRecipes = true,
        trackEquipment = true
    }
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

Other addons must read profession data through the public `OneWoW_AltTracker_Professions_API`
— **not** by touching `OneWoW_AltTracker_Professions_DB` directly (see the
store-access rules in [OneWoW/Docs/ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md) §6,
enforced by the `no-data-manager-bypass` pre-commit hook):

```lua
local API = OneWoW_AltTracker_Professions_API
if API then
    local charKey = "CharacterName-RealmName"
    local charData = API.GetCharacterData(charKey)

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

        -- Recipes: each entry is `[recipeSpellID] = true`, so just count the keys
        if charData.recipes then
            for profName, recipes in pairs(charData.recipes) do
                local count = 0
                for _ in pairs(recipes) do
                    count = count + 1
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
-- GetAllCharacters() returns a charKey -> charData map. Iterate it with pairs.
local blacksmiths = {}
local API = OneWoW_AltTracker_Professions_API
if API then
    for charKey, charData in pairs(API.GetAllCharacters()) do
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

for charKey, charData in pairs(allChars) do
    if charData.professions then
        for slotName, profData in pairs(charData.professions) do
            if profData.name == "Blacksmithing" then
                print(charKey .. " has Blacksmithing: " ..
                      profData.currentSkill .. "/" .. profData.maxSkill)
            end
        end
    end
end
```

### Example 2: Check Which Characters Can Craft An Item
```lua
local allChars = OneWoW_AltTracker_Professions_API.GetAllCharacters()
local searchRecipeID = 12345  -- a recipe SPELL ID

for charKey, charData in pairs(allChars) do
    if charData.recipes then
        -- charData.recipes[prof] is a [recipeSpellID] = true set (no detail stored)
        for profName, recipes in pairs(charData.recipes) do
            if recipes[searchRecipeID] then
                print(charKey .. " knows recipe " .. searchRecipeID .. " (" .. profName .. ")")
            end
        end
    end
end
```

### Example 3: Find Characters With Active Profession Cooldowns
```lua
local allChars = OneWoW_AltTracker_Professions_API.GetAllCharacters()

for charKey, charData in pairs(allChars) do
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
