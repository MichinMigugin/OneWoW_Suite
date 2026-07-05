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
-- v1 resolves `mount` and `appearance:source`. The key grammar is complete for
-- every planned type so keys built now stay valid as resolution is extended.
-- ============================================================================

local Collectibles = {}
ns.Collectibles = Collectibles

local C_MountJournal = C_MountJournal
local C_TransmogCollection = C_TransmogCollection
local C_Spell = C_Spell
local C_Item = C_Item

local tonumber, type, select, floor = tonumber, type, select, math.floor
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
    appearance = { subtype = true },  -- appearance:source:<sourceID> | appearance:ima:<imaID>
    pet        = { subtype = false },
    toy        = { subtype = false },
    heirloom   = { subtype = false },
    decor      = { subtype = false },
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
---@param key string
---@return table|nil state
function Collectibles.GetCollectionState(key)
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
    end

    return nil
end
