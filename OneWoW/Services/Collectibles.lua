local _, ns = ...

-- ============================================================================
-- Collectibles
-- ============================================================================
-- The canonical core resolver for collectible identity: it turns a stable
-- collectible key string (`mount:1234`, `appearance:source:5678`, ...) into
-- live display data and live collection state, and owns the key grammar every
-- other unit uses to reference a collectible across load-unit boundaries.
--
-- LOD split (see Docs/COLLECTIBLES.md):
--   core (this file) = identity + live Blizzard state, NO user SavedVariables
--   OneWoW_Notes     = user content (categories, intent, notes) keyed by these strings
--   OneWoW_Trackers  = executable plans keyed by these strings
--
-- Collection state is queried from the Blizzard journals at call time, never
-- persisted as truth: `GetCollectionState` is always live. Nothing here holds
-- state, so the service is a set of pure functions published on the Facade.
--
-- Resolution currently covers `mount`, `appearance:source`, `pet`, `toy`,
-- `heirloom`, `set` (transmog set / "ensemble"), `decor` (housing catalog), and
-- `recipe` (a profession recipe item — "Recipe:/Technique:/Pattern: ...");
-- `ResolveKeyFromItem` maps an itemID onto those. The key grammar is complete for
-- every planned type so keys built now stay valid as resolution is extended
-- (`campsite` lands later).
--
-- A `set` is a first-class *acquisition* record (it is the single thing a vendor
-- sells and the thing you link/want), but collection *truth* for it stays a view:
-- GetCollectionState/`set` derives from the set's member appearances, never a
-- stored flag. Members are read-only live views (GetSetMembers) — the set is the
-- only stored key; individual appearances are not fanned out into records.
-- ============================================================================

local Collectibles = {}
ns.Collectibles = Collectibles

local C_MountJournal = C_MountJournal
local C_Transmog = C_Transmog
local C_TransmogCollection = C_TransmogCollection
local C_TransmogSets = C_TransmogSets
local C_PetJournal = C_PetJournal
local C_ToyBox = C_ToyBox
local C_Heirloom = C_Heirloom
local C_CurrencyInfo = C_CurrencyInfo
local C_Spell = C_Spell
local C_Item = C_Item
local C_HousingCatalog = C_HousingCatalog
local PlayerHasToy = PlayerHasToy
local GetMoney = GetMoney
local CreateFrame = CreateFrame
local UnitLevel = UnitLevel

-- DressUpModel slot map; robes use the chest slot.
local INVENTORY_SLOTS_BY_EQUIP_LOC = {
    ["INVTYPE_HEAD"] = {1},
    ["INVTYPE_NECK"] = {2},
    ["INVTYPE_SHOULDER"] = {3},
    ["INVTYPE_BODY"] = {4},
    ["INVTYPE_CHEST"] = {5},
    ["INVTYPE_ROBE"] = {5},
    ["INVTYPE_WAIST"] = {6},
    ["INVTYPE_LEGS"] = {7},
    ["INVTYPE_FEET"] = {8},
    ["INVTYPE_WRIST"] = {9},
    ["INVTYPE_HAND"] = {10},
    ["INVTYPE_FINGER"] = {11},
    ["INVTYPE_TRINKET"] = {12},
    ["INVTYPE_CLOAK"] = {15},
    ["INVTYPE_WEAPON"] = {16, 17},
    ["INVTYPE_SHIELD"] = {17},
    ["INVTYPE_2HWEAPON"] = {16, 17},
    ["INVTYPE_WEAPONMAINHAND"] = {16},
    ["INVTYPE_RANGED"] = {16},
    ["INVTYPE_RANGEDRIGHT"] = {16},
    ["INVTYPE_WEAPONOFFHAND"] = {17},
    ["INVTYPE_HOLDABLE"] = {17},
    ["INVTYPE_TABARD"] = {19},
}

local dressUpModel

-- A `decor` key is always the Decor housing-catalog entry type (the grammar has
-- no room for the entry type, and rooms aren't collectible records).
local DECOR_ENTRY_TYPE = Enum.HousingCatalogEntryType.Decor

local ipairs, tonumber, type, select, floor = ipairs, tonumber, type, select, math.floor
local strsplit, strtrim = strsplit, strtrim

-- ---------------------------------------------------------------------------
-- Key grammar: `type[:subtype]:id`
-- ---------------------------------------------------------------------------
-- Each type carries at most one subtype segment; `id` is always the trailing
-- positive integer. `subtype = true` types REQUIRE the middle segment (e.g.
-- appearance keys are never bare `appearance:<id>`). Resolution for a type can
-- lag its grammar entry — the table is the single source of truth for what a
-- valid key looks like.
local KEY_SEP = ":"

local TYPES = {
    mount      = { subtype = false },
    appearance = { subtype = true },  -- appearance:source:<sourceID> | appearance:item:<itemID> | appearance:ima:<imaID>
    pet        = { subtype = false },
    toy        = { subtype = false },
    heirloom   = { subtype = false },
    set        = { subtype = false },  -- transmog set / "ensemble": set:<setID>
    decor      = { subtype = false },
    recipe     = { subtype = false },  -- profession recipe item: recipe:<itemID>
    campsite   = { subtype = false },
}

local function CoerceID(value)
    local id = tonumber(value)
    if not id or id <= 0 or id ~= floor(id) then return nil end
    return id
end

--- Build a canonical collectible key, or nil if the arguments are invalid.
--- Subtype-less types: `BuildKey("mount", 1234)`.
--- Subtype types:      `BuildKey("appearance", "source", 5678)`.
---@param collType string
---@return string|nil key
function Collectibles.BuildKey(collType, a, b)
    if type(collType) ~= "string" then return nil end
    collType = collType:lower()
    local def = TYPES[collType]
    if not def then return nil end

    if def.subtype then
        if type(a) ~= "string" or a == "" then return nil end
        local id = CoerceID(b)
        if not id then return nil end
        return collType .. KEY_SEP .. a:lower() .. KEY_SEP .. id
    end

    local id = CoerceID(a)
    if not id then return nil end
    return collType .. KEY_SEP .. id
end

--- Parse a key into `{ type, subtype?, id, key }`, or nil if malformed.
--- The returned `key` is the canonical (lowercased, integer-normalized) form.
---@param key string
---@return table|nil descriptor
function Collectibles.ParseKey(key)
    if type(key) ~= "string" or key == "" then return nil end

    local collType, seg2, seg3, seg4 = strsplit(KEY_SEP, key)
    if not collType then return nil end
    collType = collType:lower()
    local def = TYPES[collType]
    if not def then return nil end

    if def.subtype then
        if seg4 ~= nil then return nil end
        if type(seg2) ~= "string" or seg2 == "" then return nil end
        local id = CoerceID(seg3)
        if not id then return nil end
        local subtype = seg2:lower()
        return {
            type = collType,
            subtype = subtype,
            id = id,
            key = collType .. KEY_SEP .. subtype .. KEY_SEP .. id,
        }
    end

    if seg3 ~= nil then return nil end
    local id = CoerceID(seg2)
    if not id then return nil end
    return {
        type = collType,
        id = id,
        key = collType .. KEY_SEP .. id,
    }
end

--- Normalize an untrusted key string to canonical form, or nil if invalid.
--- Trims surrounding whitespace so user- or hyperlink-sourced input round-trips.
---@param key string
---@return string|nil canonical
function Collectibles.CanonicalizeKey(key)
    if type(key) == "string" then
        key = strtrim(key)
    end
    local descriptor = Collectibles.ParseKey(key)
    return descriptor and descriptor.key or nil
end

--- Build the `(collectible=<key>)` reference token used in note bodies.
--- Token grammar only; conversion to a clickable link lives in OneWoW_Notes.
---@param key string
---@return string|nil token
function Collectibles.BuildLink(key)
    local canonical = Collectibles.CanonicalizeKey(key)
    if not canonical then return nil end
    return "(collectible=" .. canonical .. ")"
end

-- ---------------------------------------------------------------------------
-- Display resolution (live, per type)
-- ---------------------------------------------------------------------------

local function ResolveMount(id)
    local name, spellID, icon = C_MountJournal.GetMountInfoByID(id)
    if not name then return nil end

    local sourceText
    local _, _, source = C_MountJournal.GetMountInfoExtraByID(id)
    if source and source ~= "" then
        sourceText = strtrim((source:gsub("|n", " ")))
        if sourceText == "" then sourceText = nil end
    end

    return {
        type = "mount",
        name = name,
        icon = icon,
        link = spellID and C_Spell.GetSpellLink(spellID) or nil,
        sourceText = sourceText,
    }
end

-- `sourceID` and `itemModifiedAppearanceID` are the same identifier: GetSourceInfo
-- gives the display name + item; GetAppearanceSourceInfo gives the icon + link.
-- Fall back to the item record for any field the transmog APIs leave nil (common
-- before the item is cached).
local function ResolveAppearanceSource(id)
    local sourceInfo = C_TransmogCollection.GetSourceInfo(id)
    local appearanceInfo = C_TransmogCollection.GetAppearanceSourceInfo(id)

    local name = sourceInfo and sourceInfo.name
    local icon = appearanceInfo and appearanceInfo.icon
    local link = appearanceInfo and appearanceInfo.itemLink
    local itemID = sourceInfo and sourceInfo.itemID

    if (not name or not icon or not link) and itemID then
        local itemName, itemLink, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(itemID)
        name = name or itemName
        link = link or itemLink
        icon = icon or itemIcon
    end

    if not (name or icon or link) then return nil end

    return {
        type = "appearance",
        subtype = "source",
        name = name,
        icon = icon,
        link = link,
    }
end

-- Stored `appearance:item:<itemID>` keys (ResolveKeyFromItem no longer mints these).
-- Collection truth is PlayerHasTransmog(itemID).
local function ResolveAppearanceItem(id)
    local itemName, itemLink, _, _, _, _, itemSubType, _, _, itemIcon = C_Item.GetItemInfo(id)
    local icon = itemIcon or select(5, C_Item.GetItemInfoInstant(id))
    if not (itemName or icon or itemLink) then return nil end

    if itemSubType == "" then itemSubType = nil end

    return {
        type = "appearance",
        subtype = "item",
        name = itemName,
        icon = icon,
        link = itemLink,
        sourceText = itemSubType,
    }
end

-- A battle pet is keyed by speciesID; the journal gives name/icon/source, but no
-- per-species item link (links need a specific caged-pet GUID), so link stays nil.
local function ResolvePet(id)
    local name, icon, _, _, sourceText = C_PetJournal.GetPetInfoBySpeciesID(id)
    if not name then return nil end

    if sourceText and sourceText ~= "" then
        sourceText = strtrim((sourceText:gsub("|n", " ")))
        if sourceText == "" then sourceText = nil end
    else
        sourceText = nil
    end

    return {
        type = "pet",
        name = name,
        icon = icon,
        sourceText = sourceText,
    }
end

-- Toy display comes from the toy box; fall back to the item record for any field
-- the toy box leaves nil before the item is cached.
local function ResolveToy(id)
    local _, name, icon = C_ToyBox.GetToyInfo(id)
    local link = C_ToyBox.GetToyLink(id)

    if not name or not icon then
        local itemName, itemLink, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(id)
        name = name or itemName
        link = link or itemLink
        icon = icon or itemIcon
    end

    if not (name or icon or link) then return nil end

    return {
        type = "toy",
        name = name,
        icon = icon,
        link = link,
    }
end

-- Heirloom display comes from the heirloom journal (name + the `source` string);
-- the item record fills icon/link/name before the heirloom data is cached.
local function ResolveHeirloom(id)
    local name, _, _, icon, _, source = C_Heirloom.GetHeirloomInfo(id)
    local link = C_Heirloom.GetHeirloomLink(id)

    if not name or not icon or not link then
        local itemName, itemLink, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(id)
        name = name or itemName
        link = link or itemLink
        icon = icon or itemIcon
    end

    if not (name or icon or link) then return nil end

    local sourceText
    if source and source ~= "" then
        sourceText = strtrim((source:gsub("|n", " ")))
        if sourceText == "" then sourceText = nil end
    end

    return {
        type = "heirloom",
        name = name,
        icon = icon,
        link = link,
        sourceText = sourceText,
    }
end

-- A transmog set ("ensemble") resolves to its set name plus a representative
-- icon. Sets carry no icon field and no chat hyperlink, so the icon is taken from
-- the set's first primary appearance — mirroring Blizzard's TransmogUtil.GetSetIcon,
-- which walks GetSetPrimaryAppearances and treats each `appearanceID` as a source.
-- Callers that captured the teaching ensemble item can substitute that item's
-- icon/link at display time; this is the source-less fallback.
local function ResolveSet(id)
    local info = C_TransmogSets.GetSetInfo(id)
    if not info then return nil end

    local icon
    local appearances = C_TransmogSets.GetSetPrimaryAppearances(id)
    if appearances and appearances[1] then
        local member = ResolveAppearanceSource(appearances[1].appearanceID)
        icon = member and member.icon
    end

    local label = info.label
    if label == "" then label = nil end

    return {
        type = "set",
        name = info.name,
        icon = icon,
        sourceText = label,
    }
end

-- Housing decor resolves from the housing catalog. `GetCatalogEntryInfoByRecordID`
-- takes (entryType, recordID, tryGetOwnedInfo) — pass `true` so ownership counts
-- populate (GetCollectionState reuses the same entry info). Decor art can be a
-- texture file or an atlas; we resolve a texture (falling back to the granting
-- item's icon), and take the item link when the entry maps to an item.
local function GetDecorEntryInfo(recordID)
    return C_HousingCatalog.GetCatalogEntryInfoByRecordID(DECOR_ENTRY_TYPE, recordID, true)
end

local function ResolveDecor(id)
    local info = GetDecorEntryInfo(id)
    if not info then return nil end

    local icon = info.iconTexture
    local link
    if info.itemID then
        local _, itemLink, _, _, _, _, _, _, _, itemIcon = C_Item.GetItemInfo(info.itemID)
        link = itemLink
        icon = icon or itemIcon or select(5, C_Item.GetItemInfoInstant(info.itemID))
    end

    local sourceText = info.sourceText
    if sourceText == "" then sourceText = nil end

    return {
        type = "decor",
        name = info.name,
        icon = icon,
        link = link,
        sourceText = sourceText,
    }
end

-- A profession recipe item (what a vendor sells: "Recipe:/Technique:/Pattern: ...").
-- Keyed by the recipe *item* id — that is the buyable/linkable unit and what the
-- merchant funnel detects — so display comes straight from the item record.
-- `sourceText` is the item's subtype (the profession, e.g. "Inscription").
local function ResolveRecipe(id)
    local itemName, itemLink, _, _, _, _, itemSubType, _, _, itemIcon = C_Item.GetItemInfo(id)
    local icon = itemIcon or select(5, C_Item.GetItemInfoInstant(id))
    if not (itemName or icon or itemLink) then return nil end

    if itemSubType == "" then itemSubType = nil end

    return {
        type = "recipe",
        name = itemName,
        icon = icon,
        link = itemLink,
        sourceText = itemSubType,
    }
end

-- Whether the recipe a given recipe item teaches is already known. Delegates to
-- the canonical `ns.RecipeKnownUtil` (core, loaded before this file): it maps the
-- recipe *item* to its taught recipe spell via the tooltip's `ItemSpellTriggerLearn`
-- line (NOT `C_Item.GetItemSpell`, which on e.g. an enchant "Formula:" returns the
-- illusion Use spell, not the teach spell) and answers known from the
-- ProfessionRecipe scan cache / AltTracker data / `GetRecipeInfo(...).learned`.
-- `IsRecipeKnown` returns `true`/`nil` (nil = not known or not yet resolvable), so
-- normalize to a strict boolean.
local function IsRecipeItemKnown(itemID, context)
    return ns.RecipeKnownUtil:IsRecipeKnown(itemID, context) == true
end

--- Live display data for a collectible key: `{ name, icon, link, sourceText?, type }`.
--- Returns nil for unknown/malformed keys or types without resolution yet.
---@param key string
---@return table|nil display
function Collectibles.ResolveDisplay(key)
    local descriptor = Collectibles.ParseKey(key)
    if not descriptor then return nil end

    if descriptor.type == "mount" then
        return ResolveMount(descriptor.id)
    elseif descriptor.type == "appearance" and descriptor.subtype == "source" then
        return ResolveAppearanceSource(descriptor.id)
    elseif descriptor.type == "appearance" and descriptor.subtype == "item" then
        return ResolveAppearanceItem(descriptor.id)
    elseif descriptor.type == "pet" then
        return ResolvePet(descriptor.id)
    elseif descriptor.type == "toy" then
        return ResolveToy(descriptor.id)
    elseif descriptor.type == "heirloom" then
        return ResolveHeirloom(descriptor.id)
    elseif descriptor.type == "set" then
        return ResolveSet(descriptor.id)
    elseif descriptor.type == "decor" then
        return ResolveDecor(descriptor.id)
    elseif descriptor.type == "recipe" then
        return ResolveRecipe(descriptor.id)
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Collection state (live, per type)
-- ---------------------------------------------------------------------------

--- Live collection state for a collectible key. Always a table with a common
--- `collected` boolean plus type-specific detail; nil for unknown/malformed
--- keys or types without resolution yet. Never persisted — query at display time.
---   mount      -> { collected }
---   appearance -> { collected, bySource, byItem? }  (collected == bySource)
---   pet        -> { collected, numCollected, limit? }  (collected == numCollected > 0)
---   toy        -> { collected }
---   heirloom   -> { collected }
---   set        -> { collected, numCollected, total }  (collected == whole set owned)
---   decor      -> { collected, numOwned, numStored, numPlaced }  (collected == numOwned > 0)
---   recipe     -> { collected }  (collected == the taught recipe is known)
---@param key string
---@param context table|nil `{ hyperlink?, bagID?, slotID?, tooltipData? }`
---@return table|nil state
function Collectibles.GetCollectionState(key, context)
    local descriptor = Collectibles.ParseKey(key)
    if not descriptor then return nil end

    if descriptor.type == "mount" then
        local isCollected = select(11, C_MountJournal.GetMountInfoByID(descriptor.id))
        return { collected = isCollected == true }
    elseif descriptor.type == "appearance" and descriptor.subtype == "source" then
        local bySource = C_TransmogCollection.PlayerHasTransmogItemModifiedAppearance(descriptor.id) == true
        local byItem
        local itemID = C_TransmogCollection.GetSourceItemID(descriptor.id)
        if itemID then
            byItem = C_TransmogCollection.PlayerHasTransmog(itemID) == true
        end
        return { collected = bySource, bySource = bySource, byItem = byItem }
    elseif descriptor.type == "appearance" and descriptor.subtype == "item" then
        local collected = C_TransmogCollection.PlayerHasTransmog(descriptor.id) == true
        return { collected = collected, byItem = collected }
    elseif descriptor.type == "pet" then
        -- Pets carry a count (numCollected can exceed 1); `collected` is the common
        -- boolean, `numCollected`/`limit` are the detail consumers that need the
        -- count (e.g. tracker objectives) read.
        local numCollected, limit = C_PetJournal.GetNumCollectedInfo(descriptor.id)
        numCollected = numCollected or 0
        return { collected = numCollected > 0, numCollected = numCollected, limit = limit }
    elseif descriptor.type == "toy" then
        return { collected = PlayerHasToy(descriptor.id) == true }
    elseif descriptor.type == "heirloom" then
        return { collected = C_Heirloom.PlayerHasHeirloom(descriptor.id) == true }
    elseif descriptor.type == "set" then
        -- Collection truth for a set is a *view* over its members: prefer the
        -- authoritative set flag, falling back to primary-appearance progress.
        local info = C_TransmogSets.GetSetInfo(descriptor.id)
        local progress = Collectibles.GetEnsembleProgress(descriptor.id)
        local numCollected = (progress and progress.collected) or 0
        local total = (progress and progress.total) or 0
        local collected = (info and info.collected == true)
            or (total > 0 and numCollected >= total)
        return { collected = collected, numCollected = numCollected, total = total }
    elseif descriptor.type == "decor" then
        -- Quantity model: decor is owned in counts (storage + placed), matching
        -- Blizzard's GetEntryTotalOwned (totalNumStored + remainingRedeemable +
        -- totalNumPlaced). "Collected" is simply owning at least one instance.
        local info = GetDecorEntryInfo(descriptor.id)
        if not info then return { collected = false } end
        local stored = (info.totalNumStored or 0) + (info.remainingRedeemable or 0)
        local placed = info.totalNumPlaced or 0
        local numOwned = stored + placed
        return { collected = numOwned > 0, numOwned = numOwned, numStored = stored, numPlaced = placed }
    elseif descriptor.type == "recipe" then
        return { collected = IsRecipeItemKnown(descriptor.id, context) }
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Item-facing collection facade
-- ---------------------------------------------------------------------------

local BATTLE_PET_CAGE_ID = 82800

--- Whether an item grants a collectible and if the current character owns it.
--- Returns nil when the item has no collection relationship. A wardrobe-rejected
--- transmog source (starter profession tools) returns
--- `{ applicable = false, collected = false, type = "appearance" }` so tooltips
--- can show Not Collectable without treating the item as `#transmog` / `#uncollected`.
--- Otherwise `{ applicable = true, collected = bool, key = string, type = string, ... }`
--- with type-specific fields merged from `GetCollectionState`.
---@param itemID number
---@param hyperlink string|nil
---@param context table|nil `{ bagID?, slotID?, tooltipData? }` — bag/slot or live tooltip lines for recipe known checks
---@return table|nil status
function Collectibles.GetItemCollectionStatus(itemID, hyperlink, context)
    itemID = CoerceID(itemID)
    if not itemID then return nil end

    context = context or {}
    if hyperlink and not context.hyperlink then
        context.hyperlink = hyperlink
    end
    -- Tooltip decoration already has structured lines; stay off C_TradeSkillUI
    -- resolves that re-init LibRangeCheck via SPELLS_CHANGED on recipe hover.
    if context.tooltipData and context.light == nil then
        context.light = true
    end

    local key, uncollectableAppearance = Collectibles.ResolveKeyFromItem(itemID, hyperlink)
    if not key then
        if uncollectableAppearance then
            return {
                applicable = false,
                collected = false,
                type = "appearance",
            }
        end
        return nil
    end

    local descriptor = Collectibles.ParseKey(key)
    if not descriptor then return nil end

    local state = Collectibles.GetCollectionState(key, context)
    local collected = state and state.collected == true or false

    local collectedByAlt = false
    if descriptor.type == "recipe" and not collected then
        local Registry = OneWoW.SettingsFeatureRegistry
        if Registry then
            local collections = Registry:GetFeatureSettings("tooltips", "collections")
            local mode = collections and collections.recipeAltDisplay or "differentiated"
            -- "self" only paints personal collection; skip the alt roster walk.
            if mode ~= "self" then
                local rk = Registry:GetFeatureSettings("tooltips", "recipeknowledge")
                local altScope = rk and rk.altScope
                if altScope and ns.RecipeKnownUtil then
                    collectedByAlt = ns.RecipeKnownUtil:IsRecipeKnownByScopedAlt(itemID, altScope, context) == true
                end
            end
        end
    end

    local status = {
        applicable = true,
        collected = collected,
        collectedByAlt = collectedByAlt,
        key = key,
        type = descriptor.type,
    }
    if state then
        for field, value in pairs(state) do
            if field ~= "collected" then
                status[field] = value
            end
        end
    end
    return status
end

-- ---------------------------------------------------------------------------
-- Item -> key resolution
-- ---------------------------------------------------------------------------

-- Upgraded/catalyst links often carry bonus IDs that make GetItemInfo(hyperlink)
-- return nothing while GetItemInfo(itemID) still resolves the canonical source.
-- Artifact / Remix links may fail both; DressUpModel TryOn is the next tier.

local function GetDressUpModel()
    if not dressUpModel then
        dressUpModel = CreateFrame("DressUpModel")
    end
    return dressUpModel
end

--- Normalize a DressUpModel / visual id to the modified-appearance source for `itemID`.
local function SourceIDForItem(candidateID, itemID)
    if not candidateID or candidateID == 0 then return nil end

    local sourceInfo = C_TransmogCollection.GetSourceInfo(candidateID)
    if sourceInfo and sourceInfo.itemID == itemID then
        return candidateID
    end

    local sources = C_TransmogCollection.GetAllAppearanceSources(candidateID)
    if sources then
        for _, sourceID in ipairs(sources) do
            local info = C_TransmogCollection.GetSourceInfo(sourceID)
            if info and info.itemID == itemID then
                return sourceID
            end
        end
    end

    return nil
end

local function GetTryOnSlots(itemID, tryLink)
    local _, _, _, equipLoc = C_Item.GetItemInfoInstant(tryLink)
    local slots = equipLoc and INVENTORY_SLOTS_BY_EQUIP_LOC[equipLoc]
    if slots then return slots end

    -- GetSlotForInventoryType expects Enum.InventoryType (numeric), not INVTYPE_* strings.
    local inventoryType = C_Item.GetItemInventoryTypeByID(tryLink)
    if not inventoryType and itemID then
        inventoryType = C_Item.GetItemInventoryTypeByID(itemID)
    end
    if inventoryType then
        local slot = C_Transmog.GetSlotForInventoryType(inventoryType)
        if slot then
            return { slot }
        end
    end

    if C_Item.IsDressableItemByID(tryLink) then
        return { 16, 17 }
    end

    return nil
end

local function ResolveTransmogSourceIDViaTryOn(itemID, tryLink)
    if not tryLink or not C_Item.IsDressableItemByID(tryLink) then
        return nil
    end
    if not select(2, C_Item.GetItemInfoInstant(tryLink)) then
        return nil
    end

    local tryOnItemID = itemID or tonumber(tryLink:match("item:(%d+)"))
    if not tryOnItemID then return nil end

    local slots = GetTryOnSlots(tryOnItemID, tryLink)
    if not slots then return nil end

    local model = GetDressUpModel()
    model:SetUnit("player")
    model:Undress()
    for i = 1, #slots do
        model:TryOn(tryLink, slots[i])
        local tmogInfo = model:GetItemTransmogInfo(slots[i])
        local appearanceID = tmogInfo and tmogInfo.appearanceID
        local sourceID = SourceIDForItem(appearanceID, tryOnItemID)
        if sourceID then
            return sourceID
        end
    end

    return nil
end

local function ResolveArtifactSourceID(itemID)
    if not itemID or not C_Item.IsItemDataCachedByID(itemID) then
        return nil
    end
    local _, _, quality = C_Item.GetItemInfo(itemID)
    if quality ~= Enum.ItemQuality.Artifact then
        return nil
    end

    local level = UnitLevel("player")
    for appearanceIndex = 1, 999 do
        local tryLink = ("item:%d::::::::%d:::::1:8:%d:"):format(itemID, level, appearanceIndex)
        local _, sourceID = C_TransmogCollection.GetItemInfo(tryLink)
        if sourceID then
            return sourceID
        end
    end

    return nil
end

-- Dressable items still get a source ID for preview. Starter profession tools
-- (Blacksmith Hammer, Mining Pick, …) are NotValidForTransmog / CantCollect:
-- they never enter the wardrobe. IsDressableItemByID is not collectability.
-- If GetSourceInfo has not loaded yet, keep the source rather than dropping a
-- real appearance.
---@param sourceID number
---@return boolean
local function IsCollectableTransmogSource(sourceID)
    local info = C_TransmogCollection.GetSourceInfo(sourceID)
    if not info then return true end
    local sourceType = info.sourceType
    if sourceType == Enum.TransmogSource.NotValidForTransmog
        or sourceType == Enum.TransmogSource.CantCollect then
        return false
    end
    return true
end

--- Live `itemModifiedAppearanceID` plus whether that source can enter the wardrobe.
--- Tries hyperlink, bare itemID, DressUpModel TryOn, then artifact link synthesis.
---@param itemID number|nil
---@param hyperlink string|nil
---@return number|nil sourceID
---@return boolean|nil collectable false when a source exists but cannot enter the collection
local function ResolveTransmogSourceIDEx(itemID, hyperlink)
    itemID = CoerceID(itemID)
    if not itemID and not hyperlink then return nil end

    local _, sourceID
    if hyperlink then
        _, sourceID = C_TransmogCollection.GetItemInfo(hyperlink)
    end
    if not sourceID and itemID then
        _, sourceID = C_TransmogCollection.GetItemInfo(itemID)
    end
    if not sourceID then
        local tryLink = hyperlink or (itemID and ("item:%d"):format(itemID))
        if tryLink then
            sourceID = ResolveTransmogSourceIDViaTryOn(itemID, tryLink)
        end
    end
    if not sourceID and itemID then
        sourceID = ResolveArtifactSourceID(itemID)
    end
    if not sourceID then return nil end
    if not IsCollectableTransmogSource(sourceID) then
        return sourceID, false
    end
    return sourceID, true
end

--- Live `itemModifiedAppearanceID` for a wardrobe-collectable item, or nil
--- when the item has no source or the source cannot enter the collection.
---@param itemID number
---@param hyperlink string|nil
---@return number|nil sourceID
function Collectibles.ResolveTransmogSourceID(itemID, hyperlink)
    local sourceID, collectable = ResolveTransmogSourceIDEx(itemID, hyperlink)
    if collectable == false then return nil end
    return sourceID
end

--- Resolve the collectible key an item grants, or nil if the item is not a
--- known collectible. Used to classify merchant/loot items into collectibles.
--- Order matters: a caged-pet or mount item also has an appearance-less nature,
--- so the specific collection journals are checked before the transmog source
--- fallback. An ensemble item teaches a whole transmog set (and has no transmog
--- source of its own), so it resolves to `set:<setID>` — checked before the
--- single-appearance fallback. A recipe-class item ("Recipe:/Technique:/Pattern:")
--- is always a `recipe:<itemID>` — checked before the decor branch because a
--- housing-decor recipe teaches a craft (it does not itself grant the decor).
--- A housing decor item maps to `decor:<recordID>`.
--- `sourceID == itemModifiedAppearanceID`, so an equippable item with a
--- wardrobe-collectable source maps to `appearance:source:<id>`.
--- A second return of true means a transmog source exists but cannot enter the
--- wardrobe (NotValidForTransmog / CantCollect) — not a collectible key.
---@param itemID number
---@param hyperlink string|nil battle-pet cage links need the hyperlink for species
---@return string|nil key
---@return boolean|nil uncollectableAppearance
function Collectibles.ResolveKeyFromItem(itemID, hyperlink)
    itemID = CoerceID(itemID)
    if not itemID then return nil end

    local mountID = C_MountJournal.GetMountFromItem(itemID)
    if mountID then
        return Collectibles.BuildKey("mount", mountID)
    end

    if C_ToyBox.GetToyInfo(itemID) then
        return Collectibles.BuildKey("toy", itemID)
    end

    local speciesID = select(13, C_PetJournal.GetPetInfoByItemID(itemID))
    if not speciesID and itemID == BATTLE_PET_CAGE_ID and hyperlink then
        speciesID = tonumber(hyperlink:match("|Hbattlepet:(%d+):"))
    end
    if speciesID then
        return Collectibles.BuildKey("pet", speciesID)
    end

    if C_Heirloom.IsItemHeirloom(itemID) then
        return Collectibles.BuildKey("heirloom", itemID)
    end

    -- A recipe-class item teaches a craft — it is a recipe collectible in its own
    -- right (and, for decor recipes, does NOT map to the crafted decor's catalog
    -- entry), so classify by item class before the decor/transmog fallbacks.
    if ns.PredicateEngine:IsRecipeItemIdentity(itemID) then
        return Collectibles.BuildKey("recipe", itemID)
    end

    -- Housing decor items grant a catalog Decor entry (rooms are not records).
    local decorEntry = C_HousingCatalog.GetCatalogEntryInfoByItem(hyperlink or itemID)
    if decorEntry and decorEntry.entryType == DECOR_ENTRY_TYPE and decorEntry.recordID then
        return Collectibles.BuildKey("decor", decorEntry.recordID)
    end

    -- Ensemble items ("Ensemble: ...") teach an entire transmog set: the set is
    -- the buyable/linkable unit, so resolve to a set key rather than the item's
    -- (nonexistent) single appearance.
    local setID = C_Item.GetItemLearnTransmogSet(itemID)
    if setID then
        return Collectibles.BuildKey("set", setID)
    end

    local sourceID, collectable = ResolveTransmogSourceIDEx(itemID, hyperlink)
    if sourceID and collectable then
        return Collectibles.BuildKey("appearance", "source", sourceID)
    end
    if collectable == false then
        return nil, true
    end

    return nil
end

-- ---------------------------------------------------------------------------
-- Vendor-offer affordability (view layer, live, no SavedVariables)
-- ---------------------------------------------------------------------------

--- Live affordability of a vendor offer against the player's current gold,
--- currencies, and items. View-time only — never persist the result (it changes
--- as the player earns/spends). Returns a uniform table:
---   `{ affordable, requirements = { { kind, name?, currencyID?/itemID?, need, have, met } } }`
--- `kind` is `"gold"` | `"currency"` | `"item"`. `affordable` is the AND of every
--- requirement's `met`; an offer with no cost is trivially affordable.
---@param offer table `{ cost?, currencies? }` snapshot (merchant/vendor item entry shape)
---@return table|nil affordability, nil for a nil offer
function Collectibles.GetOfferAffordability(offer)
    if type(offer) ~= "table" then return nil end

    local requirements = {}
    local affordable = true

    local goldCost = tonumber(offer.cost) or 0
    if goldCost > 0 then
        local have = GetMoney() or 0
        local met = have >= goldCost
        if not met then affordable = false end
        requirements[#requirements + 1] = {
            kind = "gold", need = goldCost, have = have, met = met,
        }
    end

    if type(offer.currencies) == "table" then
        for _, cost in ipairs(offer.currencies) do
            local need = tonumber(cost.amount) or 0
            if need > 0 then
                local have, req = 0, nil
                if cost.currencyID then
                    local info = C_CurrencyInfo.GetCurrencyInfo(cost.currencyID)
                    have = (info and info.quantity) or 0
                    req = { kind = "currency", currencyID = cost.currencyID, name = cost.name }
                elseif cost.itemID then
                    have = C_Item.GetItemCount(cost.itemID) or 0
                    req = { kind = "item", itemID = cost.itemID, name = cost.name }
                end
                if req then
                    req.need = need
                    req.have = have
                    req.met = have >= need
                    if not req.met then affordable = false end
                    requirements[#requirements + 1] = req
                end
            end
        end
    end

    return { affordable = affordable, requirements = requirements }
end

-- ---------------------------------------------------------------------------
-- Ensemble / transmog-set rollups (view layer, live, no SavedVariables)
-- ---------------------------------------------------------------------------
-- A transmog set ("ensemble") is a collection of appearance sources. These are
-- pure views over the live Blizzard set APIs: member keys enumerate the set's
-- per-slot sources as canonical `appearance:source` keys, and progress counts
-- how many of those sources are collected (reusing GetCollectionState so the
-- service stays the single source of collection truth). Nothing is persisted.

--- Canonical `appearance:source` keys for every source in a transmog set,
--- including each slot's alternate sources (`C_TransmogSets.GetAllSourceIDs`).
--- This is a *superset* of the set's per-slot primary appearances, so its count
--- is larger than the completion figure Blizzard shows — use
--- `GetEnsembleProgress` for the user-facing "collected/total", and this only
--- when you genuinely need every source key that belongs to the set.
---@param setID number transmog set id
---@return table|nil keys array of `appearance:source:<id>` strings, or nil
function Collectibles.GetEnsembleMemberKeys(setID)
    setID = CoerceID(setID)
    if not setID then return nil end

    local sources = C_TransmogSets.GetAllSourceIDs(setID)
    if not sources or #sources == 0 then return nil end

    local keys = {}
    for _, sourceID in ipairs(sources) do
        local key = Collectibles.BuildKey("appearance", "source", sourceID)
        if key then keys[#keys + 1] = key end
    end

    if #keys == 0 then return nil end
    return keys
end

--- Live collection progress for a transmog set, matching the count Blizzard's
--- Appearances > Sets tab shows (e.g. "9/9"). This is the set's per-slot
--- **primary appearances** (`C_TransmogSets.GetSetPrimaryAppearances`), not
--- `GetEnsembleMemberKeys`/`GetAllSourceIDs` — the latter also returns each
--- slot's alternate sources, which roughly doubles the total and disagrees with
--- Blizzard's UI. `.collected` on each primary appearance is already the live
--- account state, so no separate `GetCollectionState` pass is needed.
---@param setID number transmog set id
---@return table|nil progress `{ collected, total, name }`, or nil for an unknown set
function Collectibles.GetEnsembleProgress(setID)
    setID = CoerceID(setID)
    if not setID then return nil end

    local appearances = C_TransmogSets.GetSetPrimaryAppearances(setID)
    if not appearances then return nil end

    local collected, total = 0, 0
    for _, appearance in ipairs(appearances) do
        total = total + 1
        if appearance.collected then
            collected = collected + 1
        end
    end
    if total == 0 then return nil end

    local setInfo = C_TransmogSets.GetSetInfo(setID)
    return {
        collected = collected,
        total = total,
        name = setInfo and setInfo.name or nil,
    }
end

--- Live, read-only member rows for a transmog set: one entry per primary
--- (per-slot) appearance, matching the count Blizzard's Sets tab shows. Each
--- entry is `{ key?, name?, icon?, link?, collected }`. Display fields come from
--- the live transmog APIs (each primary appearance's `appearanceID` doubles as a
--- source id, as Blizzard's TransmogUtil.GetSetIcon relies on), and `collected`
--- is the per-appearance live account state. `key` is the canonical
--- `appearance:source` key for callers that want to open the individual piece;
--- members are never persisted as their own records. Nil for an unknown set.
---@param setID number transmog set id
---@return table|nil members array of member entries, or nil
function Collectibles.GetSetMembers(setID)
    setID = CoerceID(setID)
    if not setID then return nil end

    local appearances = C_TransmogSets.GetSetPrimaryAppearances(setID)
    if not appearances then return nil end

    local members = {}
    for _, appearance in ipairs(appearances) do
        local sourceID = appearance.appearanceID
        local display = ResolveAppearanceSource(sourceID)
        members[#members + 1] = {
            key       = Collectibles.BuildKey("appearance", "source", sourceID),
            name      = display and display.name or nil,
            icon      = display and display.icon or nil,
            link      = display and display.link or nil,
            collected = appearance.collected == true,
        }
    end

    if #members == 0 then return nil end
    return members
end

--- The transmog set ids that contain a given appearance-source collectible key.
--- Lets a consumer bridge from an `appearance:source` collectible to its set(s)
--- without touching C_TransmogSets directly. Returns nil for non-appearance keys
--- or a source that belongs to no set.
---@param key string an `appearance:source:<id>` collectible key
---@return table|nil setIDs array of transmog set ids, or nil
function Collectibles.GetContainingSets(key)
    local descriptor = Collectibles.ParseKey(key)
    if not descriptor or descriptor.type ~= "appearance" or descriptor.subtype ~= "source" then
        return nil
    end

    local setIDs = C_TransmogSets.GetSetsContainingSourceID(descriptor.id)
    if not setIDs or #setIDs == 0 then return nil end
    return setIDs
end
