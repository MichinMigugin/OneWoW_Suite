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

### 2. Recipe collection — core funnel + ProfessionRecipeCommit
**Files:** `OneWoW/Services/ProfessionRecipe.lua` (core, event owner),
`Modules/ProfessionRecipeCommit.lua` (this unit, persistence),
`Modules/ProfessionAdvanced.lua` (stored-count helper only)

Recipe scanning is **not** owned by this unit. The core `OneWoW.ProfessionRecipe`
service is the single suite-wide owner of the `TRADE_SKILL_*` /
`NEW_RECIPE_LEARNED` events (see [OneWoW/Docs/ARCHITECTURE.md](../../OneWoW/Docs/ARCHITECTURE.md)
§8.7). This unit subscribes on login (gated on `settings.trackRecipes`) via
`ProfessionRecipeCommit` and commits the ephemeral scan snapshots it receives.

**Collects (via the snapshot):**
- The set of *learned* recipe (spell) IDs for the opened profession
- An account-level map of item ID → recipe (spell) ID (`recipeItemMap`)

> **Important:** Only learned recipe **spell IDs** are stored, as a
> `[recipeSpellID] = true` set. No recipe names, icons, reagents, output items,
> categories, or craftability/quality details are persisted — consumers re-query
> those live from `C_TradeSkillUI` when needed. "Recipes by expansion" is
> **derived on demand** by consumers (e.g.
> `OneWoW_AltTracker/Modules/alttracker/st-professions.lua` via
> `OneWoW_AltTracker_Professions_API.GetRecipeProgress`); it is **not** stored on
> `charData`.

**Identity, merge, and self-healing (`ProfessionRecipeCommit`):**
- Canonical profession is resolved by **numeric skill-line identity first**
  (`baseInfo.professionID` → own-slot name → per-recipe
  `C_TradeSkillUI.GetProfessionInfoByRecipeID` plurality → catalog plurality when
  the catalog data unit is loaded). If nothing resolves, the commit is **skipped**
  — a recipe is never written under an empty `""` key. This fixes the original
  bug where a stale/empty name string produced `recipes[""]` and
  cross-contaminated buckets (e.g. Mining holding Cooking IDs).
- Merges are **monotonic**: a partial or empty scan never shrinks a stored set.
- Commits **self-heal**: the scanned IDs authoritatively belong to the resolved
  profession, so they are pruned from every other bucket and the `""` bucket is
  dropped on any resolved commit. A retryable v3 repair in `Core/Database.lua`
  relocates orphaned `""` entries at login for professions the player never
  reopens (deferred when no attribution source is available).

**Triggered By:** the core funnel's ready-gated, debounced scan callback
(coalesces `TRADE_SKILL_SHOW` / `TRADE_SKILL_LIST_UPDATE` / `NEW_RECIPE_LEARNED`).

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
1. **Core `OneWoW.ProfessionRecipe` funnel** (owns `TRADE_SKILL_SHOW` /
   `TRADE_SKILL_LIST_UPDATE` / `TRADE_SKILL_CLOSE` / `NEW_RECIPE_LEARNED`,
   ready-gated + debounced ~0.25s):
   - **Open callback** → `DataManager:OnProfessionWindowReady` collects basic
     profession info, equipment, concentration, and expansion skill bands.
   - **Scan callback** → `ProfessionRecipeCommit` commits learned recipe IDs +
     the item→recipe map.
   - **Closed callback** → transient-state teardown.

2. **PLAYER_EQUIPMENT_CHANGED** - Fired when gear changes (slots 20-30)
   - Updates basic profession info + equipment data (0.5s delay), via
     DataManager's own small event frame (a LoD unit cannot use the core's
     private `ns.RegisterEvent`).

3. **CURRENCY_DISPLAY_UPDATE** - Updates concentration (0.5s delay), same frame.

4. **TRAINER_SHOW** - Fired when trainer window opens
   - Records trainer location (0.5s delay)

### Manual Collection

**API Functions:**
- `ForceFullScan()` - Scans all available data right now
- `CollectBasicData()` - Scans only basic profession info and equipment

---

## DataManager Orchestration

**File:** `Modules/DataManager.lua`

DataManager orchestrates the **live-query** collectors (basics, equipment,
concentration, expansion bands). Recipe collection is owned by the core funnel +
`ProfessionRecipeCommit`, not DataManager.

**Responsibilities:**
- Subscribes to the core `OneWoW.ProfessionRecipe` open/closed callbacks for the
  live-query collectors
- Keeps a small private event frame for the two non-trade-skill events only
  (`PLAYER_EQUIPMENT_CHANGED`, `CURRENCY_DISPLAY_UPDATE`)
- Handles event timing (delays to ensure data is ready)
- Provides access to character data

**Event Flow (recipes):**
1. Core funnel fires the open callback (window ready) → collectors run
2. Core funnel fires the scan callback → `ProfessionRecipeCommit` resolves the
   canonical profession and commits (monotonic + self-healing)
3. Updates `lastUpdate` timestamp

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

This addon is a LoD datastore for the OneWoW suite.

**RequiredDeps:** OneWoW, OneWoW_AltTracker

The professions datastore can be queried for profession information across all
characters through `OneWoW_AltTracker_Professions_API`. Recipe totals/known
comparison also uses `OneWoW_CatalogData_Tradeskills_API` when that LoD unit is
loaded (nil-guarded — no OptionalDeps; display degrades to stored-only counts
otherwise).

---

## Version Information

**Current Version:** B6.2602.1600
**Interface:** 120000, 120001, 120002 (The War Within)
**Author:** OneWoW Development Team
