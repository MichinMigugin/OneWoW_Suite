local _, ns = ...

ns.Integrations = ns.Integrations or {}
ns.Integrations.Baganator = ns.Integrations.Baganator or {}
local BaganatorImport = ns.Integrations.Baganator

local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local tinsert = table.insert
local string_sub = string.sub
local string_match = string.match
local string_gsub = string.gsub

local SECTION_END = "__end"
local BGR_PREFIX = "BGR!1!"

-- Baganator CategoryViews.Constants.OldPriorities (v1 category priority scale).
local OLD_PRIORITIES = {
    [220] = -1,
    [250] = 0,
    [300] = 1,
    [350] = 2,
    [400] = 3,
}

-- ------------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------------

local function normalizeCustomCategories(raw)
    local out = {}
    if type(raw) ~= "table" then return out end

    for cid, catData in pairs(raw) do
        if type(catData) == "table" then
            local entry = {
                name   = catData.name,
                items  = {},
                search = catData.search,
                hideIn = catData.hideIn,
                priority = catData.priority,
            }

            local items = catData.items
            if type(items) == "table" then
                if items[1] ~= nil then
                    for _, raw2 in ipairs(items) do
                        local n = tonumber(raw2)
                        if n then entry.items[tostring(n)] = true end
                    end
                else
                    for k, v in pairs(items) do
                        if v then
                            if type(k) == "string" and k:match("^i:") then
                                local n = tonumber(k:sub(3))
                                if n then entry.items[tostring(n)] = true end
                            else
                                local n = tonumber(k)
                                if n then entry.items[tostring(n)] = true end
                            end
                        end
                    end
                end
            end

            if type(catData.rules) == "table" then
                for _, rule in ipairs(catData.rules) do
                    if type(rule) == "table" and rule.type == "item" and rule.itemID then
                        local n = tonumber(rule.itemID)
                        if n then entry.items[tostring(n)] = true end
                    end
                end
            end

            out[cid] = entry
        end
    end
    return out
end

local function normalizeSections(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    for idx, sec in pairs(raw) do
        if type(sec) == "table" and sec.name then
            out[idx] = {
                name = sec.name,
                collapsed = sec.collapsed,
                showHeader = sec.showHeader,
                color = sec.color,
            }
        end
    end
    return out
end

local function normalizeOrder(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    for _, entry in ipairs(raw) do
        if type(entry) == "string" then
            tinsert(out, entry)
        end
    end
    return out
end

local function normalizeCategoryHidden(raw)
    local out = {}
    if type(raw) ~= "table" then return out end
    if raw[1] ~= nil then
        for _, sourceId in ipairs(raw) do
            if type(sourceId) == "string" then
                out[sourceId] = true
            end
        end
    else
        for sourceId, hidden in pairs(raw) do
            if hidden then
                out[sourceId] = true
            end
        end
    end
    return out
end

local function normalizeHideInArray(hideInList)
    local hideIn = {}
    if type(hideInList) ~= "table" then return hideIn end
    if hideInList[1] ~= nil then
        for _, key in ipairs(hideInList) do
            if key == "backpack" or key == "character_bank" or key == "warband_bank" then
                hideIn[key] = true
            end
        end
    else
        for key, val in pairs(hideInList) do
            if val then hideIn[key] = true end
        end
    end
    return hideIn
end

local function normalizeModificationEntry(entry, hasExplicitModsList)
    if type(entry) ~= "table" then return nil end
    local newMods = {}

    if hasExplicitModsList and type(entry.priority) == "number" then
        newMods.priority = entry.priority
    end

    if type(entry.items) == "table" then
        newMods.addedItems = newMods.addedItems or {}
        for _, itemID in ipairs(entry.items) do
            if type(itemID) == "number" then
                newMods.addedItems["i:" .. itemID] = true
            end
        end
    end

    if type(entry.pets) == "table" then
        newMods.addedItems = newMods.addedItems or {}
        for _, petID in ipairs(entry.pets) do
            if type(petID) == "number" then
                newMods.addedItems["p:" .. petID] = true
            end
        end
    end

    if type(entry.group) == "string" then
        newMods.group = entry.group
    end
    if entry.showGroupPrefix ~= nil then
        newMods.showGroupPrefix = entry.showGroupPrefix
    end
    if type(entry.color) == "string" and #entry.color == 6 then
        newMods.color = entry.color
    end
    if type(entry.hideIn) == "table" then
        local hideIn = normalizeHideInArray(entry.hideIn)
        if next(hideIn) then
            newMods.hideIn = hideIn
        end
    end

    if next(newMods) then
        return newMods
    end
    return nil
end

local function normalizeCategoryModifications(raw)
    local out = {}
    if type(raw) ~= "table" then return out end

    if raw[1] ~= nil then
        for _, entry in ipairs(raw) do
            if type(entry) == "table" then
                local sourceId = entry.source or entry.name
                local mods = normalizeModificationEntry(entry, true)
                if sourceId and mods then
                    out[sourceId] = mods
                end
            end
        end
        return out
    end

    for sourceId, mods in pairs(raw) do
        if type(mods) == "table" then
            out[sourceId] = mods
        end
    end
    return out
end

local function migrateV1Sections(import)
    if import.version ~= 1 or type(import.order) ~= "table" then
        return
    end
    import.sections = import.sections or {}
    local sectionIndex = 1
    for index, entry in ipairs(import.order) do
        if string_match(entry, "^_") and entry ~= SECTION_END then
            import.sections[tostring(sectionIndex)] = {
                name = string_match(entry, "^_(.*)"),
            }
            import.order[index] = "_" .. tostring(sectionIndex)
            sectionIndex = sectionIndex + 1
        end
    end
end

local function isExportShape(payload)
    return type(payload.categories) == "table"
end

local function isProfileShape(payload)
    return type(payload.custom_categories) == "table"
        or type(payload.customCategories) == "table"
end

local function buildIntermediate(source, fields)
    return {
        source                  = source,
        custom_categories       = fields.custom_categories or {},
        category_sections       = fields.category_sections or {},
        category_display_order  = fields.category_display_order or {},
        category_modifications  = fields.category_modifications or {},
        category_hidden         = fields.category_hidden or {},
        display_hints           = fields.display_hints or {},
        exportedLocale          = fields.exportedLocale,
        import_warnings         = fields.import_warnings or {},
    }
end

-- Port of Baganator ImportCategories export → profile intermediate shape.
function BaganatorImport:NormalizeExportPayload(import)
    migrateV1Sections(import)

    local customCategories = {}
    local categoryMods = {}
    local priorities = {}

    for _, c in ipairs(import.categories or {}) do
        if type(c) == "table" and type(c.name) == "string" and c.name ~= ""
            and type(c.search) == "string" then
            local sourceKey = c.source or c.name
            customCategories[sourceKey] = {
                name = c.name,
                search = c.search,
            }
            if type(c.priority) == "number" then
                priorities[sourceKey] = OLD_PRIORITIES[c.priority]
            end
        end
    end

    local modSource = import.modifications or import.categories or {}
    local hasExplicitMods = import.modifications ~= nil
    for _, c in ipairs(modSource) do
        local sourceKey = c.source or c.name
        if sourceKey then
            local newMods = normalizeModificationEntry(c, hasExplicitMods) or {}
            if hasExplicitMods and type(c.priority) == "number" then
                newMods.priority = c.priority
            end
            if next(newMods) then
                categoryMods[sourceKey] = newMods
            end
        end
    end

    for sourceKey in pairs(customCategories) do
        if not categoryMods[sourceKey] then
            categoryMods[sourceKey] = { priority = priorities[sourceKey] or 0 }
        elseif categoryMods[sourceKey].priority == nil then
            categoryMods[sourceKey].priority = priorities[sourceKey] or 0
        end
    end

    return buildIntermediate("baganator_string", {
        custom_categories      = customCategories,
        category_sections      = normalizeSections(import.sections),
        category_display_order = normalizeOrder(import.order),
        category_modifications = categoryMods,
        category_hidden        = normalizeCategoryHidden(import.hidden),
        exportedLocale         = import.exportedLocale,
    })
end

function BaganatorImport:NormalizeProfilePayload(profile, displayHints, source)
    local hidden = profile.category_hidden or profile.categoryHidden
    return buildIntermediate(source or "baganator_string", {
        custom_categories      = normalizeCustomCategories(profile.custom_categories or profile.customCategories),
        category_sections      = normalizeSections(profile.category_sections or profile.categorySections),
        category_display_order = normalizeOrder(profile.category_display_order or profile.categoryDisplayOrder),
        category_modifications = normalizeCategoryModifications(profile.category_modifications or profile.categoryModifications),
        category_hidden        = normalizeCategoryHidden(hidden),
        display_hints          = displayHints or {},
        exportedLocale         = profile.exportedLocale,
    })
end

-- ------------------------------------------------------------------
-- Decode paste strings (JSON v1/v2 or BGR!1! CBOR v3)
-- ------------------------------------------------------------------

function BaganatorImport:DecodeBaganatorPaste(text)
    if type(text) ~= "string" or text == "" then
        return nil, "empty input"
    end

    text = string_gsub(text, "^%s+", "")
    text = string_gsub(text, "%s+$", "")
    text = string_gsub(text, "||", "|")

    local cEU = C_EncodingUtil
    local payload
    local meta = { format = "json", missing_addon = false }

    if string_sub(text, 1, 1) == "{" then
        local ok, result = pcall(cEU.DeserializeJSON, text)
        if not ok or type(result) ~= "table" then
            return nil, "Could not decode Baganator string (invalid JSON)"
        end
        payload = result
        if payload.addon ~= "Baganator" and isExportShape(payload) then
            meta.missing_addon = true
        end
    elseif string_match(text, "^" .. BGR_PREFIX) then
        local ok, decoded = pcall(cEU.DecodeBase64, string_sub(text, #BGR_PREFIX + 1))
        if not ok then
            return nil, "Could not decode Baganator string (invalid Base64)"
        end
        local ok2, decompressed = pcall(cEU.DecompressString, decoded)
        if not ok2 then
            return nil, "Could not decode Baganator string (decompress failed)"
        end
        local ok3, result = pcall(cEU.DeserializeCBOR, decompressed)
        if not ok3 or type(result) ~= "table" then
            return nil, "Could not decode Baganator string (invalid CBOR)"
        end
        payload = result
        meta.format = "cbor"
        if payload.addon ~= "Baganator" then
            return nil, "Could not decode Baganator string (missing addon marker)"
        end
    else
        return nil, "Could not decode Baganator string (expected JSON or BGR!1!)"
    end

    return payload, nil, meta
end

-- ------------------------------------------------------------------
-- DirectRead: read from a loaded Baganator instance
-- ------------------------------------------------------------------

function BaganatorImport:DirectRead()
    local config = rawget(_G, "BAGANATOR_CONFIG")
    if not config or type(config.Profiles) ~= "table" then
        return nil, "BAGANATOR_CONFIG.Profiles not available"
    end

    local profileName = rawget(_G, "BAGANATOR_CURRENT_PROFILE") or "DEFAULT"
    local profile = config.Profiles[profileName]
    if not profile and config.Profiles.DEFAULT then
        profileName = "DEFAULT"
        profile = config.Profiles.DEFAULT
    end
    if not profile then
        return nil, "No Baganator profile found"
    end

    local displayHints = {}
    local defaults = rawget(_G, "BAGANATOR_DEFAULT_CATEGORY_NAMES")
    if type(defaults) == "table" then
        for id, nm in pairs(defaults) do
            displayHints[id] = nm
        end
    end

    return self:NormalizeProfilePayload(profile, displayHints, "baganator_direct")
end

-- ------------------------------------------------------------------
-- ParseString: read from an exported Baganator paste string
-- ------------------------------------------------------------------

function BaganatorImport:ParseString(text)
    local payload, err, meta = self:DecodeBaganatorPaste(text)
    if not payload then
        return nil, err
    end

    if payload.kind == "profile" then
        return nil, "Full Baganator profile import is not supported; export categories only."
    end
    if type(payload.version) == "number" and payload.version > 2 and payload.kind ~= "categories" then
        return nil, "Full Baganator profile import is not supported; export categories only."
    end

    local importWarnings = {}
    if meta and meta.missing_addon then
        tinsert(importWarnings, "missing_addon")
    end

    local intermediate
    if isExportShape(payload) then
        intermediate = self:NormalizeExportPayload(payload)
    elseif isProfileShape(payload) then
        intermediate = self:NormalizeProfilePayload(payload, payload.display_hints or {}, "baganator_string")
    else
        return nil, "Unrecognized Baganator category payload"
    end

    intermediate.source = "baganator_string"
    intermediate.import_warnings = importWarnings
    intermediate.decode_format = meta and meta.format or "json"
    return intermediate
end

-- ------------------------------------------------------------------
-- Shared: Baganator order grammar -> { sectionKey -> { categories } }
-- ------------------------------------------------------------------

function BaganatorImport:ResolveOrderToSections(order)
    local sections = {}
    local loose = {}
    local currentSection = nil

    for _, entry in ipairs(order or {}) do
        if string_sub(entry, 1, 2) == "__" then
            if entry == SECTION_END then
                currentSection = nil
            end
        elseif string_sub(entry, 1, 1) == "_" and entry ~= "----" then
            local idx = string_sub(entry, 2)
            currentSection = idx
            sections[idx] = sections[idx] or {}
        elseif entry == "----" then
            -- divider
        else
            if currentSection then
                tinsert(sections[currentSection], entry)
            else
                tinsert(loose, entry)
            end
        end
    end

    return sections, loose
end

-- ------------------------------------------------------------------
-- Baganator group -> OneWoW groupBy (semantic mapping)
-- ------------------------------------------------------------------

--- Map Baganator category modification group to OneWoW groupBy.
--- Baganator "type" groups by item subclass; OneWoW "type" is item class.
---@param baganatorGroup string
---@return string|nil
function BaganatorImport:MapGroupBy(baganatorGroup)
    if baganatorGroup == "type" then
        return "subtype"
    end
    return baganatorGroup
end

-- ------------------------------------------------------------------
-- Shared: hideIn -> appliesIn inversion
-- ------------------------------------------------------------------

function BaganatorImport:InvertHideIn(hideIn)
    if type(hideIn) ~= "table" then return nil end
    local appliesIn
    for _, key in ipairs({ "backpack", "character_bank", "warband_bank" }) do
        local hidden
        if hideIn[1] then
            for _, v in ipairs(hideIn) do
                if v == key then hidden = true; break end
            end
        else
            hidden = hideIn[key] and true or false
        end
        if hidden then
            appliesIn = appliesIn or {}
            appliesIn[key] = false
        end
    end
    return appliesIn
end
