local _, ns = ...

-- ============================================================================
-- TrackerTypeSchema
-- ============================================================================
-- Single source of ordered param descriptors per track type. The step editor
-- cards read presentation-only metadata and pull fields from here; Markup
-- positional parse walks the same list. Adding a type later is one table, not
-- a third if/elseif chain.
--
-- Field shape: key, labelKey, hintKey, width, isList, default, markupDefault,
-- maxLetters, widgetType ("editbox" | "dropdown" | "entityId"), entityKind,
-- options (table or fn).
-- markupDefault = "listLength" means "omit this positional and use the length
-- of the preceding isList field" (quest_pool pick).
-- ============================================================================

ns.TrackerTypeSchema = {}
local Schema = ns.TrackerTypeSchema

local tinsert = tinsert
local tonumber = tonumber
local strsplit = strsplit
local ipairs = ipairs

local EMPTY = {}

local function F(key, labelKey, hintKey, extra)
    extra = extra or {}
    extra.key = key
    extra.labelKey = labelKey
    extra.hintKey = hintKey
    extra.width = extra.width or 160
    extra.widgetType = extra.widgetType or "editbox"
    return extra
end

local function ID(key, labelKey, hintKey, kind, extra)
    extra = extra or {}
    extra.widgetType = "entityId"
    extra.entityKind = kind
    return F(key, labelKey, hintKey, extra)
end

local QUEST_ID = {
    ID("questID", "TRACKER_FL_QUEST_ID", "TRACKER_FH_QUEST_ID", "quest"),
}

local QUEST_POOL = {
    F("questIDs", "TRACKER_FL_QUEST_IDS", "TRACKER_FH_QUEST_IDS", {
        width = 320, isList = true, maxLetters = 400,
    }),
    F("pick", "TRACKER_FL_PICK", "TRACKER_FH_PICK", {
        width = 80, default = 1, markupDefault = "listLength",
    }),
}

-- Every TRACK_TYPES entry. Cards in the editor cover a subset; the rest are
-- here so markup import and later picker phases share one parse.
local BY_TYPE = {
    manual              = EMPTY,
    quest               = QUEST_ID,
    quest_account       = QUEST_ID,
    quest_active        = QUEST_ID,
    quest_world         = QUEST_ID,
    rare_quest          = QUEST_ID,
    quest_pool          = QUEST_POOL,
    quest_pool_account  = QUEST_POOL,
    quest_progress      = {
        ID("questID", "TRACKER_FL_QUEST_ID", "TRACKER_FH_QUEST_ID", "quest"),
        F("objectiveIndex", "TRACKER_FL_OBJECTIVE_INDEX", "TRACKER_FH_PICK", { width = 80, default = 1 }),
    },
    campaign            = {
        ID("campaignID", "TRACKER_FL_CAMPAIGN_ID", "TRACKER_FH_CAMPAIGN_ID", "campaign"),
    },
    level               = {
        F("level", "TRACKER_FL_LEVEL", "TRACKER_FH_LEVEL", { width = 60 }),
    },
    item                = {
        ID("itemID", "TRACKER_FL_ITEM_ID", "TRACKER_FH_ITEM_ID", "item"),
        F("count", "TRACKER_FL_COUNT", "TRACKER_FH_COUNT", { width = 80, default = 1 }),
    },
    currency            = {
        ID("currencyID", "TRACKER_FL_CURRENCY_ID", "TRACKER_FH_CURRENCY_ID", "currency"),
        F("amount", "TRACKER_FL_AMOUNT", "TRACKER_FH_AMOUNT", { width = 100, default = 1 }),
    },
    achievement         = {
        ID("achievementID", "TRACKER_FL_ACHIEVEMENT_ID", "TRACKER_FH_ACHIEVEMENT_ID", "achievement"),
    },
    reputation          = {
        ID("factionID", "TRACKER_FL_FACTION_ID", "TRACKER_FH_FACTION_ID", "faction"),
        F("standing", "TRACKER_FL_STANDING", "TRACKER_FH_STANDING", { width = 60, default = 6 }),
    },
    renown              = {
        ID("factionID", "TRACKER_FL_FACTION_ID", "TRACKER_FH_FACTION_ID", "faction"),
        F("level", "TRACKER_FL_RENOWN_LEVEL", "TRACKER_FH_RENOWN_LEVEL", { width = 60, default = 1 }),
    },
    spell_known         = {
        ID("spellID", "TRACKER_FL_SPELL_ID", "TRACKER_FH_SPELL_ID", "spell"),
    },
    ilvl                = {
        F("ilvl", "TRACKER_FL_ILVL", "TRACKER_FH_ILVL", { width = 80 }),
    },
    location            = {
        ID("mapID", "TRACKER_FL_MAP_ID", "TRACKER_FH_MAP_ID", "map", { width = 100 }),
    },
    coordinates         = {
        ID("mapID", "TRACKER_FL_MAP_ID", "TRACKER_FH_MAP_ID", "map", { width = 100 }),
        F("x", "TRACKER_FL_X", "TRACKER_FH_XY", { width = 60 }),
        F("y", "TRACKER_FL_Y", "TRACKER_FH_XY", { width = 60 }),
        F("radius", "TRACKER_FL_RANGE", "TRACKER_FH_RANGE", { width = 50, default = 15 }),
    },
    npc_interact        = {
        ID("npcID", "TRACKER_FL_NPC_ID", "TRACKER_FH_NPC_ID", "npc"),
    },
    enter_instance      = {
        ID("instanceID", "TRACKER_FL_INSTANCE_ID", "TRACKER_FH_INSTANCE_ID", "instance"),
    },
    kill_creature       = {
        ID("creatureID", "TRACKER_FL_CREATURE_ID", "TRACKER_FH_CREATURE_ID", "npc"),
    },
    kill_encounter      = {
        ID("encounterID", "TRACKER_FL_ENCOUNTER_ID", "TRACKER_FH_ENCOUNTER_ID", "encounter"),
    },
    loot_item           = {
        ID("itemID", "TRACKER_FL_ITEM_ID", "TRACKER_FH_ITEM_ID", "item"),
    },
    toy                 = {
        ID("itemID", "TRACKER_FL_TOY_ITEM_ID", "TRACKER_FH_TOY_ITEM_ID", "toy"),
    },
    mount               = {
        ID("mountID", "TRACKER_FL_MOUNT_ID", "TRACKER_FH_MOUNT_ID", "mount"),
    },
    pet                 = {
        ID("speciesID", "TRACKER_FL_SPECIES_ID", "TRACKER_FH_SPECIES_ID", "pet"),
    },
    transmog            = {
        ID("itemModifiedAppearanceID", "TRACKER_FL_APPEARANCE_ID", "TRACKER_FH_APPEARANCE_ID", "transmog"),
    },
    exploration         = {
        F("areaID", "TRACKER_FL_AREA_ID", "TRACKER_FH_AREA_ID"),
    },
    vault_raid          = EMPTY,
    vault_dungeon       = EMPTY,
    vault_world         = EMPTY,
    prof_skill          = {
        F("baseSkillLineID", "TRACKER_FL_SPELL_ID", "TRACKER_FH_SPELL_ID"),
    },
    prof_concentration  = {
        ID("currencyID", "TRACKER_FL_CURRENCY_ID", "TRACKER_FH_CURRENCY_ID", "currency"),
    },
    prof_knowledge      = {
        F("skillLineVariantID", "TRACKER_FL_SPELL_ID", "TRACKER_FH_SPELL_ID"),
    },
    prof_firstcraft     = {
        F("spellIDs", "TRACKER_FL_SPELL_ID", "TRACKER_FH_SPELL_ID", {
            width = 320, isList = true, maxLetters = 400,
        }),
    },
    prof_catchup        = {
        ID("currencyID", "TRACKER_FL_CURRENCY_ID", "TRACKER_FH_CURRENCY_ID", "currency"),
    },
    custom_timer        = {
        F("interval", "TRACKER_FL_INTERVAL", "TRACKER_FH_INTERVAL", { width = 80, default = 3600 }),
    },
}

--- Ordered param descriptors for `trackType`, or an empty list.
---@param trackType string|nil
---@return table
function Schema.GetFields(trackType)
    return BY_TYPE[trackType] or EMPTY
end

--- Positional parse of a markup `type:a:b:c` param string into a params table.
---@param trackType string
---@param paramStr string|nil
---@return table
function Schema.ParseParams(trackType, paramStr)
    local fields = Schema.GetFields(trackType)
    local params = {}
    if not paramStr or #fields == 0 then return params end

    local parts = { strsplit(":", paramStr) }
    local listLen = 0
    for i, field in ipairs(fields) do
        local raw = parts[i]
        if field.isList then
            local ids = {}
            if raw then
                for id in raw:gmatch("(%d+)") do
                    tinsert(ids, tonumber(id))
                end
            end
            params[field.key] = ids
            listLen = #ids
        else
            local n = raw and tonumber(raw)
            if n then
                params[field.key] = n
            elseif field.markupDefault == "listLength" then
                params[field.key] = listLen
            elseif field.default ~= nil then
                params[field.key] = tonumber(field.default) or field.default
            elseif raw and raw ~= "" then
                params[field.key] = raw
            end
        end
    end
    return params
end
