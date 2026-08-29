-- ============================================================================
-- FeatureHealth
-- ============================================================================
-- Suite attention evaluator for Home (and shared read-only surfaces).
-- Composes AddonLoader enable APIs + ownership/consumer graphs — does not invent
-- a third enable layer. Soft opt-out and Blizzard (hard) disable of a unit are
-- silent for that unit unless they diminish or break a still-wanted dependent.
--
-- Classes: load_pending | diminished | broken | version_mismatch | remote_update
-- Dismissable: load_pending, diminished (account-wide featureHealthDismissed)
-- Non-dismissable: broken, version_mismatch, remote_update
-- ============================================================================
local _, ns = ...

local C_AddOns = C_AddOns
local ipairs = ipairs
local pairs = pairs
local format = string.format

local CLASS_LOAD_PENDING = "load_pending"
local CLASS_DIMINISHED = "diminished"
local CLASS_BROKEN = "broken"
local CLASS_VERSION = "version_mismatch"
local CLASS_REMOTE_UPDATE = "remote_update"

--- Display label for a catalog root or store load unit.
---@param addonName string
---@return string
local function UnitLabel(addonName)
    local L = ns.L
    local catalog = ns.FirstRun and ns.FirstRun.CATALOG
    if catalog then
        for _, entry in ipairs(catalog) do
            if entry.addonName == addonName then
                return L[entry.labelKey]
            end
        end
    end
    local storeKey = ns:GetStoreLabelKey(addonName)
    if storeKey then return L[storeKey] end
    local manifest = ns:GetManifestByAddon(addonName)
    if manifest and manifest.display then return manifest.display end
    return addonName
end

--- TOC version differs from core (DevTool roots skip parity).
---@param addonName string
---@param coreVersion string|nil
---@param skipParity boolean?
---@return boolean
local function IsVersionMismatch(addonName, coreVersion, skipParity)
    if skipParity or addonName == "OneWoW" or not coreVersion then return false end
    local ver = ns:GetAddonVersion(addonName)
    return ver ~= nil and ver ~= coreVersion
end

--- Why a unit is not usable for a wanted consumer, or nil when available.
--- @return string|nil kind "missing"|"hard_off"|"soft_off"|"not_loaded"|"broken"
--- @return string|nil detail load-failure token when kind is broken
local function UnitGap(name)
    if not name or not C_AddOns.DoesAddOnExist(name) then
        return "missing"
    end
    if not ns:IsAddonEnabled(name, true) then
        return "hard_off"
    end
    if ns:IsFeatureOptedOut(name) then
        return "soft_off"
    end
    if C_AddOns.IsAddOnLoaded(name) then
        return nil
    end
    local status, reason = ns:GetAddonStatus(name, true)
    if status == "warning" then
        return "broken", reason
    end
    return "not_loaded"
end

---@return table dismissed
local function DismissStore()
    return ns.db.global.featureHealthDismissed
end

--- Build raw attention items (before dismiss filter). Also returns active id set.
---@return table[] items
---@return table activeIds
local function CollectRawAttention()
    local L = ns.L
    local items = {}
    local activeIds = {}
    local seen = {}

    ---@param id string
    ---@param class string
    ---@param dismissable boolean
    ---@param text string
    local function add(id, class, dismissable, text)
        if seen[id] then return end
        seen[id] = true
        activeIds[id] = true
        items[#items + 1] = {
            id = id,
            class = class,
            dismissable = dismissable,
            text = text,
        }
    end

    local coreVersion = ns:GetAddonVersion("OneWoW")
    local catalog = ns.FirstRun and ns.FirstRun.CATALOG or {}

    -- Version mismatches (non-dismissable).
    local mismatchLabels = {}
    local mismatchSeen = {}
    local function addMismatch(addonName, skipParity)
        if mismatchSeen[addonName] or not IsVersionMismatch(addonName, coreVersion, skipParity) then
            return
        end
        mismatchSeen[addonName] = true
        mismatchLabels[#mismatchLabels + 1] = UnitLabel(addonName)
    end
    for _, entry in ipairs(catalog) do
        addMismatch(entry.addonName, entry.addonName == "OneWoW_Utility_DevTool")
    end
    for _, mParent in ipairs(ns:GetManifestParentsWithStores()) do
        for _, store in ipairs(mParent.stores) do
            addMismatch(store, false)
        end
    end
    if #mismatchLabels > 0 then
        local text
        if #mismatchLabels <= 3 then
            local joined = mismatchLabels[1]
            for i = 2, #mismatchLabels do
                joined = joined .. ", " .. mismatchLabels[i]
            end
            text = format(L["HOME_VERSION_MISMATCH_NAMED"], joined, coreVersion or "")
        else
            text = format(L["HOME_VERSION_MISMATCH_NOTICE"], coreVersion or "")
        end
        add("version_mismatch", CLASS_VERSION, false, text)
    end

    local latestSeen = ns.db.global.remoteUpdateLatestSeen
    if latestSeen ~= "" and ns.VersionCheck.IsNewer(latestSeen, coreVersion) then
        add(
            "remote_update",
            CLASS_REMOTE_UPDATE,
            false,
            format(L["HOME_REMOTE_UPDATE"], latestSeen, coreVersion or "")
        )
    end

    -- Catalog roots: load_pending / broken when soft-wanted; silent when hard/soft off.
    for _, entry in ipairs(catalog) do
        local name = entry.addonName
        if ns:IsFeatureWanted(name, true) then
            if not C_AddOns.IsAddOnLoaded(name) then
                local status, reason = ns:GetAddonStatus(name, true)
                if status == "warning" then
                    add(
                        "broken:" .. name,
                        CLASS_BROKEN,
                        false,
                        format(L["HOME_ATTENTION_BROKEN"], UnitLabel(name), ns:GetLoadFailureText(reason))
                    )
                else
                    add(
                        "load_pending:" .. name,
                        CLASS_LOAD_PENDING,
                        true,
                        format(L["HOME_ATTENTION_LOAD_PENDING"], UnitLabel(name))
                    )
                end
            else
                -- Consumer datastores: gaps diminish the wanted+loaded consumer.
                for _, store in ipairs(entry.datastores) do
                    local gap, detail = UnitGap(store)
                    if gap == "not_loaded" and ns:IsFeatureWanted(store, true) then
                        local st, reason = ns:GetAddonStatus(store, true)
                        if st == "warning" then
                            add(
                                "broken:" .. store,
                                CLASS_BROKEN,
                                false,
                                format(L["HOME_ATTENTION_BROKEN"], UnitLabel(store), ns:GetLoadFailureText(reason))
                            )
                        else
                            add(
                                "load_pending:" .. store,
                                CLASS_LOAD_PENDING,
                                true,
                                format(L["HOME_ATTENTION_LOAD_PENDING"], UnitLabel(store))
                            )
                        end
                    elseif gap == "broken" then
                        add(
                            "broken:" .. store,
                            CLASS_BROKEN,
                            false,
                            format(L["HOME_ATTENTION_BROKEN"], UnitLabel(store), ns:GetLoadFailureText(detail))
                        )
                    elseif gap then
                        add(
                            "diminished:" .. name .. ":" .. store,
                            CLASS_DIMINISHED,
                            true,
                            format(L["HOME_ATTENTION_DIMINISHED"], UnitLabel(name), UnitLabel(store))
                        )
                    end
                end
            end
        end
    end

    -- Owned optional packs off while hub is wanted+loaded (not already covered
    -- as a consumer pull relationship above).
    for _, mParent in ipairs(ns:GetManifestParentsWithStores()) do
        local parent = mParent.addon
        if ns:IsFeatureWanted(parent, true) and C_AddOns.IsAddOnLoaded(parent) then
            for _, store in ipairs(mParent.stores) do
                local gap, detail = UnitGap(store)
                if not gap then
                    -- available
                elseif gap == "not_loaded" and ns:IsFeatureWanted(store, true) then
                    if not ns:IsLazyStore(store) then
                        local st, reason = ns:GetAddonStatus(store, true)
                        if st == "warning" then
                            add(
                                "broken:" .. store,
                                CLASS_BROKEN,
                                false,
                                format(L["HOME_ATTENTION_BROKEN"], UnitLabel(store), ns:GetLoadFailureText(reason))
                            )
                        else
                            add(
                                "load_pending:" .. store,
                                CLASS_LOAD_PENDING,
                                true,
                                format(L["HOME_ATTENTION_LOAD_PENDING"], UnitLabel(store))
                            )
                        end
                    end
                elseif gap == "broken" then
                    add(
                        "broken:" .. store,
                        CLASS_BROKEN,
                        false,
                        format(L["HOME_ATTENTION_BROKEN"], UnitLabel(store), ns:GetLoadFailureText(detail))
                    )
                elseif gap then
                    -- Skip if a wanted consumer already owns a diminished row for this store.
                    local coveredByConsumer = false
                    for _, consumer in ipairs(ns:GetStoreCatalogConsumers(store)) do
                        if ns:IsFeatureWanted(consumer, true) and C_AddOns.IsAddOnLoaded(consumer) then
                            coveredByConsumer = true
                            break
                        end
                    end
                    if not coveredByConsumer then
                        add(
                            "diminished:" .. parent .. ":" .. store,
                            CLASS_DIMINISHED,
                            true,
                            format(L["HOME_ATTENTION_DIMINISHED"], UnitLabel(parent), UnitLabel(store))
                        )
                    end
                end
            end
        end
    end

    return items, activeIds
end

--- Prune dismiss entries that no longer match an active attention id.
---@param activeIds table
local function PruneDismissed(activeIds)
    local dismissed = DismissStore()
    for id in pairs(dismissed) do
        if not activeIds[id] then
            dismissed[id] = nil
        end
    end
end

--- Suite attention items after account dismiss filter.
---@return table[] items
---@return number loadedCount CATALOG roots currently openable (loaded + wanted / pending_disable)
function ns:EvaluateSuiteAttention()
    local raw, activeIds = CollectRawAttention()
    PruneDismissed(activeIds)

    local dismissed = DismissStore()
    local items = {}
    for _, item in ipairs(raw) do
        -- Non-dismissable always shown; dismissable hidden when dismissed.
        -- Escalation to broken uses a different id, so prior diminished dismiss
        -- does not silence a broken row.
        if not item.dismissable or not dismissed[item.id] then
            items[#items + 1] = item
        end
    end

    local loaded = 0
    local catalog = ns.FirstRun and ns.FirstRun.CATALOG or {}
    for _, entry in ipairs(catalog) do
        local state = self:GetFeatureUnitState(entry.addonName)
        if state == "all" or state == "some" or state == "pending_disable" then
            loaded = loaded + 1
        end
    end

    return items, loaded
end

--- Account-dismiss a dismissable attention id (no-op for unknown / non-dismissable).
---@param id string
function ns:DismissFeatureAttention(id)
    if not id then return end
    local raw = CollectRawAttention()
    for _, item in ipairs(raw) do
        if item.id == id and item.dismissable then
            DismissStore()[id] = true
            EventRegistry:TriggerEvent("ns.FeatureStateChanged", id)
            return
        end
    end
end
