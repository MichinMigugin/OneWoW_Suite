local _, ns = ...

-- ============================================================================
-- Overlays 2.0 — definitions
-- ============================================================================
-- Preset catalog and runtime definition list for the predicate-driven overlay
-- engine. A "definition" is one paintable overlay: either a user overlay
-- (settings.overlays.userOverlays entry, preset-backed or fully custom) or
-- the detector-backed "upgrade" built-in. All matching for user overlays goes
-- through PredicateEngine expressions; presets are just canned expressions
-- with sensible icon defaults.
--
-- The itemlevel and qualityborder built-ins are NOT definitions — they are
-- rendered separately by the engine (no icon slot, no max-4 cap).
-- ============================================================================

local SE = ns.SearchExpand

ns.Overlays2Defs = {}
local Defs = ns.Overlays2Defs

local ipairs, pairs, type, tostring = ipairs, pairs, type, tostring
local tinsert, sort = tinsert, sort

-- Maximum number of icon overlays painted per item button. Item level and
-- the quality border do not count against this cap.
Defs.MAX_ICON_OVERLAYS = 4

-- ----------------------------------------------------------------------------
-- Preset catalog
-- ----------------------------------------------------------------------------
-- title/description are locale keys (shared with the 1.0 catalog so no locale
-- churn). expression may be a string or a function(entry) -> string for
-- presets whose rule depends on an extra option. extras lists preset-specific
-- entry keys the UI must render (with their defaults).

local PRESETS = {
    {
        id = "junk",
        title = "OVR_JUNK_TITLE", description = "OVR_JUNK_DESC",
        expression = function(entry)
            if entry.includeGreyItems then return "#junk" end
            return "#markedjunk"
        end,
        extras = { showInTooltip = true, includeGreyItems = false },
        defaults = { icon = "bags-junkcoin", position = "CENTER", scale = 1.5 },
    },
    {
        id = "protected",
        title = "OVR_PROTECTED_TITLE", description = "OVR_PROTECTED_DESC",
        expression = "#protected",
        extras = { showInTooltip = true },
        defaults = { icon = "questlog-questtypeicon-lock", position = "CENTER", scale = 1.5 },
    },
    {
        id = "consumables",
        title = "OVR_CONSUMABLES_TITLE", description = "OVR_CONSUMABLES_DESC",
        expression = "#consumable",
        defaults = { icon = "VignetteEvent-SuperTracked", position = "TOPRIGHT" },
    },
    {
        id = "housingdecor",
        title = "OVR_HOUSINGDECOR_TITLE", description = "OVR_HOUSINGDECOR_DESC",
        expression = "#housingdecor",
        defaults = { icon = "shop-icon-housing-beds-selected", position = "TOPLEFT" },
    },
    {
        id = "knownitems",
        title = "OVR_KNOWNITEMS_TITLE", description = "OVR_KNOWNITEMS_DESC",
        expression = "#collectionknown",
        defaults = { icon = "warband-completed-icon", position = "TOPRIGHT" },
    },
    {
        id = "altcollected",
        title = "OVR_ALTCOLLECTED_TITLE", description = "OVR_ALTCOLLECTED_DESC",
        expression = "#altcollected",
        defaults = {
            icon = "transmog-icon-warning",
            position = "TOPRIGHT",
            iconTint = {1, 0.82, 0},
        },
    },
    {
        id = "unknownitems",
        title = "OVR_UNKNOWNITEMS_TITLE", description = "OVR_UNKNOWNITEMS_DESC",
        expression = "#collectionmissing and !#altcollected",
        defaults = { icon = "Warfronts-BaseMapIcons-Horde-Workshop-Minimap", position = "TOPLEFT" },
    },
    {
        id = "transmog",
        title = "OVR_TRANSMOG_TITLE", description = "OVR_TRANSMOG_DESC",
        expression = "#transmog and #unknowntransmog",
        defaults = { icon = "Warfronts-BaseMapIcons-Horde-Workshop-Minimap", position = "TOPLEFT" },
    },
    {
        id = "mounts",
        title = "OVR_MOUNTS_TITLE", description = "OVR_MOUNTS_DESC",
        expression = "#mount",
        defaults = { icon = "icon-mount", position = "TOPLEFT" },
    },
    {
        id = "pets",
        title = "OVR_PETS_TITLE", description = "OVR_PETS_DESC",
        expression = "#pet",
        defaults = { icon = "icon-pet", position = "TOPLEFT" },
    },
    {
        id = "quest",
        title = "OVR_QUEST_TITLE", description = "OVR_QUEST_DESC",
        expression = "#quest",
        defaults = { icon = "Quest-Campaign-Available", position = "CENTER" },
    },
    {
        id = "reagents",
        title = "OVR_REAGENTS_TITLE", description = "OVR_REAGENTS_DESC",
        expression = "#tradegoods",
        defaults = { icon = "Bonus-Objective-Star", position = "TOPRIGHT" },
    },
    {
        id = "recipe",
        title = "OVR_RECIPE_TITLE", description = "OVR_RECIPE_DESC",
        expression = "#recipe and #teachable",
        defaults = { icon = "icon-recipe", position = "BOTTOMRIGHT" },
    },
    {
        id = "soulbound",
        title = "OVR_SOULBOUND_TITLE", description = "OVR_SOULBOUND_DESC",
        expression = "#soulbound",
        defaults = { icon = "VignetteKill", position = "TOPLEFT" },
    },
    {
        id = "toys",
        title = "OVR_TOYS_TITLE", description = "OVR_TOYS_DESC",
        expression = "#toy",
        defaults = { icon = "icon-toy", position = "BOTTOMRIGHT" },
    },
    {
        id = "warbound",
        title = "OVR_WARBOUND_TITLE", description = "OVR_WARBOUND_DESC",
        expression = function(entry)
            if entry.includeWUE == false then return "#warbound and !#wue" end
            return "#warbound"
        end,
        extras = { includeWUE = true },
        defaults = { icon = "warbands-icon", position = "TOPLEFT" },
    },
    {
        id = "wue",
        title = "OVR_WUE_TITLE", description = "OVR_WUE_DESC",
        expression = "#wue",
        defaults = { icon = "warband-completed-icon", position = "TOPLEFT" },
    },
    {
        id = "boe",
        title = "OVR_BOE_TITLE", description = "OVR_BOE_DESC",
        expression = "#boe",
        defaults = { icon = "icon-flag", position = "TOPRIGHT" },
    },
    {
        id = "shoppinglist",
        title = "OVR_SHOPPINGLIST_TITLE", description = "OVR_SHOPPINGLIST_DESC",
        expression = function(entry)
            if entry.onlyNeeded then return "#shoppinglistneeded" end
            return "#shoppinglist"
        end,
        extras = { onlyNeeded = false },
        defaults = { icon = "Perks-ShoppingCart", position = "BOTTOMRIGHT" },
    },
}

local PRESETS_BY_ID = {}
for _, preset in ipairs(PRESETS) do
    PRESETS_BY_ID[preset.id] = preset
end

--- Ordered preset catalog (array of preset tables). Read-only.
function Defs:GetPresets()
    return PRESETS
end

---@param presetId string
---@return table|nil
function Defs:GetPreset(presetId)
    return PRESETS_BY_ID[presetId]
end

-- ----------------------------------------------------------------------------
-- Entry helpers
-- ----------------------------------------------------------------------------

--- Effective PE expression for a user overlay entry. Preset entries derive it
--- from the catalog (honoring extras); custom entries use their stored rule.
---@param entry table userOverlays entry
---@return string|nil
function Defs:ResolveExpression(entry)
    local preset = entry.preset and PRESETS_BY_ID[entry.preset]
    if preset then
        if type(preset.expression) == "function" then
            return preset.expression(entry)
        end
        return preset.expression
    end
    return entry.expression
end

--- Validate a PE rule string. Returns ok plus a printable error on failure.
---@param expr string
---@return boolean ok
---@return string|nil err
function Defs:ValidateExpression(expr)
    if type(expr) ~= "string" or expr == "" then
        return false, "empty expression"
    end
    local compiled, err = SE:Compile(expr)
    if not compiled then
        return false, err or "expression did not compile"
    end
    return true
end

--- Fresh userOverlays entry for a preset (or a blank custom overlay when
--- presetId is nil). Caller assigns id/order and persists via the registry.
---@param presetId string|nil
---@param name string|nil display name for custom overlays
---@return table entry
function Defs:NewEntry(presetId, name)
    local entry = {
        enabled = true,
        position = "TOPRIGHT",
        scale = 1.0,
        alpha = 1.0,
        effect = "none",
        applyToVendorItems = false,
        applyToAuctionHouse = false,
        icon = { kind = "list", value = "VignetteEvent-SuperTracked" },
    }
    local preset = presetId and PRESETS_BY_ID[presetId]
    if preset then
        entry.preset = presetId
        if preset.defaults then
            entry.icon.value = preset.defaults.icon or entry.icon.value
            if preset.defaults.iconTint then
                entry.icon.tint = preset.defaults.iconTint
            end
            entry.position = preset.defaults.position or entry.position
            entry.scale = preset.defaults.scale or entry.scale
        end
        if preset.extras then
            for key, default in pairs(preset.extras) do
                entry[key] = default
            end
        end
    else
        entry.name = name
        entry.expression = ""
    end
    return entry
end

-- ----------------------------------------------------------------------------
-- Runtime definition list
-- ----------------------------------------------------------------------------

local Registry = ns.SettingsFeatureRegistry

--- Compiled, order-sorted list of active icon-overlay definitions. Each item:
---   { id, entry, compiled }        -- expression-driven user overlay
---   { id = "upgrade", entry, upgrade = true }  -- detector-backed built-in
--- Invalid or disabled entries are skipped. Compile errors are recorded on
--- the returned list's `errors[id] = message` map for the settings UI.
---@return table defs array with an `errors` field
function Defs:BuildActiveList()
    local list = { errors = {} }
    local userOverlays = Registry:GetFeatureSettings("overlays", "userOverlays")

    local ordered = {}
    for id, entry in pairs(userOverlays) do
        if type(entry) == "table" then
            tinsert(ordered, { id = id, entry = entry })
        end
    end
    sort(ordered, function(a, b)
        local oa, ob = a.entry.order or 0, b.entry.order or 0
        if oa ~= ob then return oa < ob end
        return a.id < b.id
    end)

    for _, item in ipairs(ordered) do
        local entry = item.entry
        if entry.enabled then
            local expr = self:ResolveExpression(entry)
            if expr and expr ~= "" then
                local compiled, err = SE:Compile(expr)
                if compiled then
                    tinsert(list, { id = item.id, entry = entry, compiled = compiled })
                else
                    list.errors[item.id] = err or "expression did not compile"
                end
            end
        end
    end

    -- Detector-backed built-in: evaluated last (fixed priority after user
    -- overlays), still counts against the icon cap.
    local upgradeCfg = Registry:GetFeatureSettings("overlays", "upgrade")
    if upgradeCfg.enabled then
        tinsert(list, { id = "upgrade", entry = upgradeCfg, upgrade = true })
    end

    return list
end

--- Generate a unique userOverlays id.
---@param userOverlays table current userOverlays map
---@return string
function Defs:GenerateId(userOverlays)
    local base = "ov_" .. tostring(GetServerTime())
    local id = base
    local n = 0
    while userOverlays[id] do
        n = n + 1
        id = base .. "_" .. n
    end
    return id
end
