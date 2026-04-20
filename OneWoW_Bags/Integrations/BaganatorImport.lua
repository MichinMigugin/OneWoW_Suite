local _, OneWoW_Bags = ...

OneWoW_Bags.Integrations = OneWoW_Bags.Integrations or {}
OneWoW_Bags.Integrations.Baganator = OneWoW_Bags.Integrations.Baganator or {}
local BaganatorImport = OneWoW_Bags.Integrations.Baganator

local pairs, ipairs, type, tostring, tonumber = pairs, ipairs, type, tostring, tonumber
local tinsert = table.insert
local string_sub, string_lower = string.sub, string.lower

-- ------------------------------------------------------------------
-- Helpers
-- ------------------------------------------------------------------

-- Read a Baganator intermediate profile-style payload (`profile`) and emit
-- a normalized shape that Planner.lua can consume without caring whether
-- the source was a live DirectRead or a deserialized JSON string.
--
-- Output shape:
--   {
--       source = "baganator_direct" | "baganator_string",
--       custom_categories = { [cid] = { name, items = { [numericID]=true }, search = string?, hideIn = {...} } },
--       category_sections = { [bagIndex] = { name, collapsed, showHeader } },
--       category_display_order = { raw order array from Baganator },
--       category_modifications = { [name] = modification table },
--       display_hints = { [default_*] = localizedName },
--   }
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
                            local n = tonumber(k)
                            if n then entry.items[tostring(n)] = true end
                        end
                    end
                end
            end

            -- Baganator also supports `rules` with type=item for explicit item rules
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

-- ------------------------------------------------------------------
-- DirectRead: read from a loaded Baganator instance
-- ------------------------------------------------------------------

function BaganatorImport:DirectRead()
    local config = rawget(_G, "BAGANATOR_CONFIG")
    if not config or type(config.Profiles) ~= "table" then
        return nil, "BAGANATOR_CONFIG.Profiles not available"
    end

    local profile
    for _, candidate in pairs(config.Profiles) do
        profile = candidate
        break
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

    return {
        source                  = "baganator_direct",
        custom_categories       = normalizeCustomCategories(profile.custom_categories),
        category_sections       = normalizeSections(profile.category_sections),
        category_display_order  = normalizeOrder(profile.category_display_order),
        category_modifications  = {},
        display_hints           = displayHints,
    }
end

-- ------------------------------------------------------------------
-- ParseString: read from an exported Baganator JSON paste string
-- ------------------------------------------------------------------

local function tryDeserializeJSON(text)
    local cEU = rawget(_G, "C_EncodingUtil")
    if cEU and cEU.DeserializeJSON then
        local ok, result = pcall(cEU.DeserializeJSON, text)
        if ok and type(result) == "table" then
            return result
        end
    end
    return nil
end

function BaganatorImport:ParseString(text)
    if type(text) ~= "string" or text == "" then
        return nil, "empty input"
    end

    -- Baganator exports compress-wrap payloads; try the straight JSON path
    -- first (v1 export format per Baganator\CustomiseDialog\Categories\ImportExport.lua).
    local payload = tryDeserializeJSON(text)
    if not payload then
        -- Fall through: Baganator's compressed format includes a header like
        -- "!BAGANATOR2" or similar. For v1 we only support the raw-JSON path;
        -- compressed payloads emit an error the preview dialog surfaces.
        return nil, "Could not decode Baganator string (expected JSON)"
    end

    local normalized = {
        source                  = "baganator_string",
        custom_categories       = normalizeCustomCategories(payload.custom_categories or payload.customCategories),
        category_sections       = normalizeSections(payload.category_sections or payload.categorySections),
        category_display_order  = normalizeOrder(payload.category_display_order or payload.categoryDisplayOrder),
        category_modifications  = payload.category_modifications or payload.categoryModifications or {},
        display_hints           = payload.display_hints or {},
        exportedLocale          = payload.exportedLocale,
    }
    return normalized
end

-- ------------------------------------------------------------------
-- Shared: Baganator order grammar -> { sectionKey -> { categories } }
-- ------------------------------------------------------------------
-- Baganator order entries:
--   "_<bagIndex>"   -> start of a section (bagIndex is a number-as-string)
--   "__end"         -> end of current section
--   "----"          -> divider (display-only, ignored for membership)
--   "default_*"     -> default category source ID
--   any other       -> custom category ID (key into custom_categories)

function BaganatorImport:ResolveOrderToSections(order)
    local sections = {}      -- bagIndex -> array of source IDs
    local loose = {}         -- source IDs not inside any section
    local currentSection = nil

    for _, entry in ipairs(order or {}) do
        if string_sub(entry, 1, 2) == "__" then
            if entry == "__end" then
                currentSection = nil
            end
        elseif string_sub(entry, 1, 1) == "_" and entry ~= "----" then
            local idx = string_sub(entry, 2)
            currentSection = idx
            sections[idx] = sections[idx] or {}
        elseif entry == "----" then
            -- divider, ignore
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
-- Shared: hideIn -> appliesIn inversion
-- ------------------------------------------------------------------
-- Baganator "hideIn" lists bag views the category should NOT appear in.
-- OneWoW uses "appliesIn" with a `false` entry per disabled view.
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
