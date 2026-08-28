local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local DB = OneWoW_GUI.DB
local tinsert, tremove = tinsert, tremove

ns.DatabaseDefaults = {
    global = {
        language = GetLocale(),
        theme = "green",

        mainFrameSize = {
            width = 1400,
            height = 900
        },

        mainFramePosition = nil,

        altTrackerSettings = {
            enablePlaytimeTracking = true,
            enableDataCollection = true,
        },

        minimap = {
            hide = false,
            minimapPos = 220,
            theme = "horde",
        },

        favorites = {},
        favoriteBarSets = {},
        favoriteItems   = {},
        seasonChecklist = {},

        -- Last-used Items-tab duplicate-finder spec (seeded from the Storage
        -- default on first use; canonical default values live in that unit).
        dupeSpec = {},

        overrides = {
            progress = {},
        },
    },
}

-- Shallow-copy a baseline list (handles arrays of scalars and arrays of flat
-- tables) so edits to the SavedVariables copy never mutate ns.OverrideDefaults.
local function CopyOverrideList(src)
    if type(src) ~= "table" then return {} end
    local out = {}
    for i = 1, #src do
        local v = src[i]
        if type(v) == "table" then
            local t = {}
            for k, vv in pairs(v) do t[k] = vv end
            out[i] = t
        else
            out[i] = v
        end
    end
    return out
end

local function IdInList(list, id)
    if type(list) ~= "table" then return false end
    for i = 1, #list do
        if list[i] == id then return true end
    end
    return false
end

local function RemoveIdFromList(list, id)
    if type(list) ~= "table" then return end
    for i = #list, 1, -1 do
        if list[i] == id then
            tremove(list, i)
        end
    end
end

--- Season baseline currency IDs (static; do not mutate).
---@return number[]
function ns:GetSeasonCurrencyIDs()
    return ns.OverrideDefaults.progress.trackedCurrencyIDs
end

---@param id number
---@return boolean
function ns:IsSeasonCurrencyID(id)
    return IdInList(ns.OverrideDefaults.progress.trackedCurrencyIDs, id)
end

---@param id number
---@return boolean
function ns:IsSeasonCurrencyEnabled(id)
    local disabled = ns.db.global.overrides.progress.disabledSeasonCurrencies
    return not IdInList(disabled, id)
end

--- Turn a season-default currency on or off. Off IDs stay in the known set
--- so the Settings row remains; they are omitted from collection and columns.
---@param id number
---@param enabled boolean
function ns:SetSeasonCurrencyEnabled(id, enabled)
    local progress = ns.db.global.overrides.progress
    local disabled = progress.disabledSeasonCurrencies
    if type(disabled) ~= "table" then
        disabled = {}
        progress.disabledSeasonCurrencies = disabled
    end
    RemoveIdFromList(disabled, id)
    if not enabled then
        tinsert(disabled, id)
    end
    if #disabled == 0 then
        progress.disabledSeasonCurrencies = nil
    end
end

--- Extra currency IDs the player added (not in the season baseline).
---@return number[]
function ns:GetExtraCurrencyIDs()
    local extras = ns.db.global.overrides.progress.extraCurrencyIDs
    if type(extras) == "table" then
        return extras
    end
    return {}
end

--- Add by currency ID. A season-default ID is re-enabled instead of stored as extra.
---@param id number
---@return string result "invalid" | "exists" | "season" | "added"
function ns:AddTrackedCurrencyID(id)
    if type(id) ~= "number" or id <= 0 then
        return "invalid"
    end
    local info = C_CurrencyInfo.GetCurrencyInfo(id)
    if not info or not info.name or info.name == "" then
        return "invalid"
    end
    if ns:IsSeasonCurrencyID(id) then
        ns:SetSeasonCurrencyEnabled(id, true)
        return "season"
    end
    local progress = ns.db.global.overrides.progress
    local extras = progress.extraCurrencyIDs
    if type(extras) ~= "table" then
        extras = {}
        progress.extraCurrencyIDs = extras
    end
    if IdInList(extras, id) then
        return "exists"
    end
    tinsert(extras, id)
    return "added"
end

---@param id number
function ns:RemoveExtraCurrencyID(id)
    local progress = ns.db.global.overrides.progress
    local extras = progress.extraCurrencyIDs
    RemoveIdFromList(extras, id)
    if type(extras) == "table" and #extras == 0 then
        progress.extraCurrencyIDs = nil
    end
end

--- Re-enable every season default. Extra IDs are kept.
function ns:ResetSeasonCurrencyToggles()
    ns.db.global.overrides.progress.disabledSeasonCurrencies = nil
end

--- Clear season offs and extras (dialog-wide currency reset).
function ns:ResetCurrencyTracking()
    local progress = ns.db.global.overrides.progress
    progress.disabledSeasonCurrencies = nil
    progress.extraCurrencyIDs = nil
    progress.trackedCurrencyIDs = nil
end

--- Collection + Progress columns: enabled season IDs, then extras.
--- Empty is a valid choice (every season currency off, no extras).
---@return number[]
function ns:GetTrackedCurrencyIDs()
    local out = {}
    local seen = {}
    local season = ns.OverrideDefaults.progress.trackedCurrencyIDs
    local disabled = ns.db.global.overrides.progress.disabledSeasonCurrencies
    for i = 1, #season do
        local id = season[i]
        if id and not IdInList(disabled, id) then
            seen[id] = true
            tinsert(out, id)
        end
    end
    local extras = ns.db.global.overrides.progress.extraCurrencyIDs
    if type(extras) == "table" then
        for i = 1, #extras do
            local id = extras[i]
            if id and id > 0 and not seen[id] then
                seen[id] = true
                tinsert(out, id)
            end
        end
    end
    return out
end

-- Effective override list. trackedCurrencyIDs is computed (season offs + extras)
-- so an empty player list cannot fall back to the full baseline. Other keys
-- still use copy-on-write: non-empty SavedVariables, else ns.OverrideDefaults.
function ns:GetProgressList(key)
    if key == "trackedCurrencyIDs" then
        return ns:GetTrackedCurrencyIDs()
    end
    local userList = ns.db.global.overrides.progress[key]
    if type(userList) == "table" and #userList > 0 then
        return userList
    end
    return ns.OverrideDefaults.progress[key]
end

-- Copy-on-write: ensure SavedVariables holds an editable copy of the list
-- (seeded from the static baseline on first edit), then return it for mutation.
-- Currencies do not use this path; use AddTrackedCurrencyID / extras APIs.
function ns:EnsureProgressList(key)
    if key == "trackedCurrencyIDs" then
        return ns:GetTrackedCurrencyIDs()
    end
    local progress = ns.db.global.overrides.progress
    if type(progress[key]) ~= "table" then
        progress[key] = CopyOverrideList(ns.OverrideDefaults.progress[key])
    end
    return progress[key]
end

function ns:InitializeDatabase()
    ns.db = DB:Init({
        savedVar = "OneWoW_AltTracker_DB",
        addonName = ADDON_NAME,
        defaults = ns.DatabaseDefaults,
    })

    -- AceDB/NewCompat-era cleanup: the hub never stored per-character or profile
    -- data. DB:Init single mode keeps char data under root.chars, so drop the
    -- legacy root tables to stop them syncing as dead weight.
    ns.db.root.char = nil
    ns.db.root.profileKeys = nil

    -- One-time reset of seeded progress overrides. SavedVariables now holds only
    -- user customizations; absence falls back to the static baseline, so wipe the
    -- old fully-seeded table once and let everyone adopt ns.OverrideDefaults.
    local global = ns.db.global
    if not global.overridesReset then
        global.overrides = { progress = {} }
        global.overridesReset = true
    end

    -- Drop stale weekly-activity overrides that still pointed at season metas
    -- 95842/95843 (sticky completion flag). Baseline now uses zone weeklies.
    if not global.weeklyActivityQuestsV2 then
        if global.overrides and global.overrides.progress then
            global.overrides.progress.weeklyActivityQuests = nil
        end
        global.weeklyActivityQuestsV2 = true
    end

    -- Hero Mistcrest 3440 and Dawnlight Manaflux 3378 were Hidden-category
    -- twins. Live Currency-tab IDs are 3445 and 3465. Remap any customized
    -- override list once; skip a target that is already in the list.
    if not global.progressCurrencyIDsV2 then
        local list = global.overrides and global.overrides.progress and global.overrides.progress.trackedCurrencyIDs
        if type(list) == "table" then
            local remap = { [3440] = 3445, [3378] = 3465 }
            local seen = {}
            local write = 1
            for read = 1, #list do
                local id = remap[list[read]] or list[read]
                if id and id > 0 and not seen[id] then
                    seen[id] = true
                    list[write] = id
                    write = write + 1
                end
            end
            for i = write, #list do
                list[i] = nil
            end
        end
        global.progressCurrencyIDsV2 = true
    end

    -- Old Override UI stored a full copy of trackedCurrencyIDs. Empty that
    -- copy fell back to every season default, so "hide all" was impossible.
    -- Split into disabledSeasonCurrencies + extraCurrencyIDs once.
    if not global.progressCurrencyTrackingV3 then
        local progress = global.overrides.progress
        local list = progress.trackedCurrencyIDs
        if type(list) == "table" and #list > 0 then
            local season = ns.OverrideDefaults.progress.trackedCurrencyIDs
            local userSet = {}
            for i = 1, #list do
                userSet[list[i]] = true
            end
            local seasonSet = {}
            local disabled = {}
            for i = 1, #season do
                local id = season[i]
                seasonSet[id] = true
                if not userSet[id] then
                    tinsert(disabled, id)
                end
            end
            local extras = {}
            for i = 1, #list do
                local id = list[i]
                if id and not seasonSet[id] then
                    tinsert(extras, id)
                end
            end
            progress.disabledSeasonCurrencies = #disabled > 0 and disabled or nil
            progress.extraCurrencyIDs = #extras > 0 and extras or nil
        end
        progress.trackedCurrencyIDs = nil
        global.progressCurrencyTrackingV3 = true
    end
end
