local ADDON_NAME, ns = ...

local OneWoW_GUI = OneWoW_GUI
local PE = OneWoW.PredicateEngine

OneWoW_Bags = {}

local L = ns.L
local Events = ns.Events

local ipairs, pairs, tinsert = ipairs, pairs, tinsert
local hooksecurefunc = hooksecurefunc

local C_Timer = C_Timer
local C_Bank = C_Bank

ns.oneWoWHubActive = false
ns.bankOpen = false
ns.guildBankOpen = false
ns.isWarbandOnlyBankAccess = false
ns.inventoryPresentationState = {
    altShowActive = false,
}

local function DetectOneWoW()
    if OneWoW then
        ns.oneWoWHubActive = true
    end
end

local function ApplyTheme()
    OneWoW_Bags:ApplyTheme()
end

local function ApplyLanguage()
    -- Localization lives in the OneWoW Locale service now (scope = ADDON_NAME;
    -- shared vocab in the "shared" scope). SetLanguage refolds every scope in place,
    -- pushes BINDING_* globals, and fires OnApply; ns.L is a stable view.
    -- esMX->esES is normalized inside. Kept as a thin shim for the profile-sync loop
    -- (t-profiles SyncSettingToChildAddons) until Phase 6.
    local lang = OneWoW_GUI:GetSetting("language") or "enUS"
    OneWoW.Locale:SetLanguage(lang)
end

function OneWoW_Bags:ApplyTheme()
    OneWoW_GUI:ApplyTheme(ns)
end

function OneWoW_Bags:ApplyLanguage()
    ApplyLanguage()
end

local GUI_TARGET_KEYS = {
    bags = { "GUI" },
    bank = { "BankGUI" },
    guild = { "GuildBankGUI" },
    bank_related = { "BankGUI", "GuildBankGUI" },
    all = { "GUI", "BankGUI", "GuildBankGUI" },
}

local VISUAL_TARGET_KEYS = {
    bags = { "BagSet" },
    bank = { "BankSet" },
    guild = { "GuildBankSet" },
    bank_related = { "BankSet", "GuildBankSet" },
    all = { "BagSet", "BankSet", "GuildBankSet" },
}

local GUI_TO_SET = {
    GUI = "BagSet",
    BankGUI = "BankSet",
    GuildBankGUI = "GuildBankSet",
}

local pendingRefresh = {}
local pendingRefreshReason = {}
local refreshScheduled = false
-- Self-healing scheduler watchdog: if the flush timer armed at `lastArmTime`
-- is ever dropped (e.g. a zero-delay C_Timer callback lost across a loading
-- screen), `refreshScheduled` would latch true forever. Re-arming is allowed
-- once more than STALE_AFTER seconds have elapsed since the last arm, which is
-- far longer than a normal C_Timer.After(0) turnaround (~one frame) so it never
-- double-arms under same-frame coalescing.
local lastArmTime = 0
local STALE_AFTER = 0.05

local TARGET_TO_GUI = {
    bags = "GUI",
    bank = "BankGUI",
    guild = "GuildBankGUI",
}

local function ForEachTarget(owner, targetKey, targetMap, callback)
    local keys = targetMap[targetKey or "all"] or targetMap.all
    for _, key in ipairs(keys) do
        local value = owner[key]
        if value then
            callback(value, key)
        end
    end
end

local function EnsureTable(parent, key)
    local value = parent[key]
    if not value then
        value = {}
        parent[key] = value
    end
    return value
end

function ns:SetAltShowActive(active)
    self.inventoryPresentationState.altShowActive = active == true
end

function ns:IsAltShowActive()
    local db = self:GetDB()
    if not db.global.altToShow then return false end
    return self.inventoryPresentationState.altShowActive == true
end

function ns:GetItemSortMode()
    return self:GetDB().global.itemSort
end

--- Build PredicateEngine props for a button without treating guild-bank tab/slot
--- coordinates as C_Container bag/slot coordinates.
---@param button table
---@return table props
function ns:GetButtonProps(button)
    local info = button and button.owb_itemInfo
    local itemID = info and info.itemID
    if not itemID then return {} end

    if button.owb_isGuildBank then
        return PE:BuildProps(itemID, nil, nil, info.hyperlink or info)
    end

    return PE:BuildProps(itemID, button.owb_bagID, button.owb_slotID, info)
end

function ns:ShouldShowItemQuality(isBank, quality)
    if self:IsAltShowActive() then return true end
    if not quality or quality < 1 then return false end

    local db = self:GetDB()

    if isBank then
        return self.BankController:Get("rarityColor") == true
    end

    return db.global.rarityColor == true
end

function ns:ShouldDimJunkItem(isJunk)
    local db = self:GetDB()
    return isJunk and db.global.dimJunkItems and not self:IsAltShowActive()
end

function ns:ShouldStripJunkOverlays(isJunk)
    local db = self:GetDB()
    return isJunk and db.global.stripJunkOverlays and not self:IsAltShowActive()
end

function ns:IsBankUIEnabled()
    local db = self:GetDB()
    return db.global.enableBankUI ~= false
end

function ns:EnsureCategoryModification(categoryName)
    if not categoryName then return nil end

    local db = self:GetDB()

    local categoryModifications = EnsureTable(db.global, "categoryModifications")
    return EnsureTable(categoryModifications, categoryName)
end

function ns:EnsureBuiltinCategoryAddedItems(categoryName)
    local categoryModification = self:EnsureCategoryModification(categoryName)
    if not categoryModification then return nil end
    return EnsureTable(categoryModification, "addedItems")
end

function ns:InitializeControllers()
    if self.ControllersInitialized then return end

    self.WindowLayoutController = self.WindowLayoutController:Create(self)
    self.BagsController = self.BagsController:Create(self)
    self.BankController = self.BankController:Create(self)
    self.GuildBankController = self.GuildBankController:Create(self)
    self.SettingsController = self.SettingsController:Create(self)
    self.CategoryController = self.CategoryController:Create(self)

    self.ControllersInitialized = true
end

--- Clear category and predicate caches after settings or category data changes.
---@param scope "props"|nil Use "props" when item-property inputs changed.
function ns:InvalidateCategorization(scope)
    local db = self:GetDB()

    self.Categories:SetCustomCategories(db.global.customCategoriesV2)
    self.Categories:SetRecentItemDuration(db.global.recentItemDuration)
    self.Categories:SetRecentItems(db.global.recentItems)
    self.Categories:InvalidateCache()

    if scope == "props" then
        PE:InvalidatePropsCache()
    else
        PE:InvalidateCache()
    end
end

--- Surgical invalidation for a batch of item IDs. Used by
--- GET_ITEM_INFO_RECEIVED coalescing instead of the bulk
--- InvalidateCategorization("props") wipe, so streaming item info
--- preserves the identity-tier caches for items whose data is already
--- resolved.
---@param idSet table<number, boolean>|nil
function ns:InvalidateItemIDs(idSet)
    if not idSet or not next(idSet) then return end
    local Profile = self.Profile
    if Profile then Profile:Start("InvalidateItemIDs") end
    local evictedSlotKeys = PE:InvalidateItemIDs(idSet)
    self.Categories:InvalidateItemIDs(idSet, evictedSlotKeys)
    if Profile then Profile:Stop("InvalidateItemIDs") end
end

--- Snapshot coalesced layout refresh state for `/owblayout dump`.
---@return table snapshot `{ refreshScheduled: boolean, pending: table<guiKey, { pending: boolean, reason: string|nil }> }`
function ns:GetLayoutDebugSchedulerSnapshot()
    local pending = {}
    for guiKey in pairs(pendingRefresh) do
        pending[guiKey] = {
            pending = pendingRefresh[guiKey] == true,
            reason = pendingRefreshReason[guiKey],
        }
    end
    return {
        refreshScheduled = refreshScheduled,
        pending = pending,
    }
end

--- Refresh item layout for one or more windows. Coalesced: multiple calls
--- in the same frame collapse to a single deferred flush. Hidden windows
--- and windows whose backing Set is mid-Build are skipped.
--- Whether a coalesced refresh should be queued for this GUI (avoids guild/bank pending while closed).
---@param guiKey "GUI"|"BankGUI"|"GuildBankGUI"
---@return boolean
function ns:ShouldQueueLayoutRefresh(guiKey)
    if guiKey == "GuildBankGUI" then
        return self.guildBankOpen == true
    end
    if guiKey == "BankGUI" then
        return self.bankOpen == true
    end
    return true
end

--- Clear coalesced refresh state for a window that is closing.
---@param guiKey "GUI"|"BankGUI"|"GuildBankGUI"
function ns:ClearPendingLayoutRefresh(guiKey)
    pendingRefresh[guiKey] = nil
    pendingRefreshReason[guiKey] = nil
end

-- When a window opens via the warm path it lays out synchronously, so the
-- OnShow hook's coalesced "show_onshow" request would be a redundant extra
-- pass. Show() suppresses the hook for its target around MainWindow:Show().
local suppressOnShowLayout = {}

--- @param targetKey "bags"|"bank"|"guild"
--- @param suppressed boolean
function ns:SetOnShowLayoutSuppressed(targetKey, suppressed)
    suppressOnShowLayout[targetKey] = suppressed or nil
end

--- @param targetKey "bags"|"bank"|"guild"
--- @return boolean
function ns:IsOnShowLayoutSuppressed(targetKey)
    return suppressOnShowLayout[targetKey] == true
end

--- Arm a coalesced flush, healing a latch whose timer was dropped.
--- Only arms when there is pending work; coalesces within a frame; re-arms
--- when the previous arm is older than STALE_AFTER (its timer never fired).
function ns:EnsureFlushScheduled()
    if next(pendingRefresh) == nil then return end
    local now = GetTime()
    if refreshScheduled and (now - lastArmTime) < STALE_AFTER then
        return
    end
    refreshScheduled = true
    lastArmTime = now
    self._flushClosure = self._flushClosure
        or function() self:FlushPendingLayoutRefreshes() end
    C_Timer.After(0, self._flushClosure)
end

--- Force-recover the layout scheduler. Clears the `refreshScheduled` latch and
--- re-arms a flush if work is pending. Used on zone enter, where a loading
--- screen can drop the pending zero-delay flush timer and wedge the latch.
function ns:KickLayoutScheduler()
    refreshScheduled = false
    local LD = self.LayoutDebug
    if LD and LD.enabled then
        LD:Record("scheduler_kick", { note = "latch reset" })
    end
    self:EnsureFlushScheduled()
end

---@param target "bags"|"bank"|"guild"|"bank_related"|"all"|nil
---@param reason string|nil diagnostic tag; first-write-wins per target
function ns:RequestLayoutRefresh(target, reason)
    ForEachTarget(self, target, GUI_TARGET_KEYS, function(_, key)
        if not self:ShouldQueueLayoutRefresh(key) then
            return
        end
        pendingRefresh[key] = true
        if reason and not pendingRefreshReason[key] then
            pendingRefreshReason[key] = reason
        end
        local LD = self.LayoutDebug
        if LD and LD.enabled then
            LD:Record("request", {
                guiKey = key,
                reason = reason,
                target = target,
            })
        end
    end)
    self:EnsureFlushScheduled()
end

--- Whether a coalesced layout refresh is still queued (requested but not yet
--- flushed) for the given target. A stuck-queued refresh at safety-net time
--- means the coalescer wedged; a clear queue means the last request flushed.
---@param targetKey "bags"|"bank"|"guild"
---@return boolean
function ns:HasPendingLayoutRefresh(targetKey)
    local guiKey = TARGET_TO_GUI[targetKey]
    return (guiKey and pendingRefresh[guiKey]) == true
end

--- Heuristic for a failed layout: the window is shown and its backing set has
--- items, but zero item buttons are visible (cleanup ran without a following
--- show pass). Used by the open safety net as a last-resort recovery.
---@param targetKey "bags"|"bank"|"guild"
---@return boolean
function ns:IsWindowBlank(targetKey)
    local guiKey = TARGET_TO_GUI[targetKey]
    local gui = guiKey and self[guiKey]
    if not (gui and gui.IsShown and gui:IsShown()) then return false end
    local LD = self.LayoutDebug
    if not (LD and LD.CountSetStats) then return false end
    local setKey = GUI_TO_SET[guiKey]
    local setObj = setKey and self[setKey]
    if not (setObj and setObj.isBuilt) then return false end
    local _, hasItem, shown = LD:CountSetStats(setObj)
    return hasItem > 0 and shown == 0
end

--- Schedule a post-open safety-net layout that survives a wedged scheduler.
--- Runs synchronously (RequestLayoutRefreshNow) so it recovers even if the
--- coalescer latch is stuck. It only forces a layout for the two failure modes
--- it exists to catch: a blank window (layout produced nothing visible) or a
--- refresh still stuck in the queue (coalescer wedged, never flushed). A
--- healthy window that already laid out and has no pending work is left alone,
--- so it no longer fires a redundant full relayout on a normal cold open.
---@param targetKey "bags"|"bank"|"guild"
---@param isShownFn function returns whether the window is still shown
function ns:ScheduleOpenSafetyNet(targetKey, isShownFn)
    C_Timer.After(0.5, function()
        if not isShownFn() then return end
        local blank = self:IsWindowBlank(targetKey)
        if blank or self:HasPendingLayoutRefresh(targetKey) then
            local LD = self.LayoutDebug
            if LD and LD.enabled then
                LD:Record(blank and "safety_net_blank" or "safety_net_wedged", { target = targetKey })
            end
            self:RequestLayoutRefreshNow(targetKey)
        end
    end)
end

--- Synchronous escape hatch for callers that cannot tolerate the
--- coalescer's one-frame delay. Skips visibility/build gating so a hidden
--- window can pre-warm its layout before being shown. Use sparingly.
---@param target "bags"|"bank"|"guild"|"bank_related"|"all"|nil
function ns:RequestLayoutRefreshNow(target)
    ForEachTarget(self, target, GUI_TARGET_KEYS, function(gui)
        if gui.RefreshLayout then
            gui:RefreshLayout()
        end
    end)
end

--- Flush pending coalesced refresh requests. Skips windows that are
--- hidden or whose backing Set is in the middle of a Build.
function ns:FlushPendingLayoutRefreshes()
    refreshScheduled = false
    local Profile = self.Profile
    if Profile then Profile:Start("RequestLayoutRefresh.Flush") end

    local guiKeys = {}
    for guiKey in pairs(pendingRefresh) do
        tinsert(guiKeys, guiKey)
    end

    local needsReschedule = false
    local LD = self.LayoutDebug
    for _, guiKey in ipairs(guiKeys) do
        if not pendingRefresh[guiKey] then
            -- Cleared by an earlier iteration or external path.
        else
            local reason = pendingRefreshReason[guiKey]
            local gui = self[guiKey]
            local setKey = GUI_TO_SET[guiKey]
            local backingSet = setKey and self[setKey]
            local visible = gui and gui.IsShown and gui:IsShown() or false
            local building = backingSet and backingSet._building == true
            local inProgress = gui and gui._layoutInProgress == true

            if not gui or not gui.RefreshLayout then
                pendingRefresh[guiKey] = nil
                pendingRefreshReason[guiKey] = nil
                if LD and LD.enabled then
                    LD:Record("flush_drop", { guiKey = guiKey, reason = reason, outcome = "no_gui", note = "missing RefreshLayout" })
                end
            elseif not self:ShouldQueueLayoutRefresh(guiKey) then
                pendingRefresh[guiKey] = nil
                pendingRefreshReason[guiKey] = nil
                if LD and LD.enabled then
                    LD:Record("flush_drop_stale", { guiKey = guiKey, reason = reason, note = "window closed" })
                end
            elseif visible and not building and inProgress then
                -- A layout is already running for this window (reentrant flush).
                -- Keep pending so the work is not lost to the reentrancy guard's
                -- early return; reschedule for a later frame.
                needsReschedule = true
                if LD and LD.enabled then
                    LD:Record("skip_in_progress", {
                        guiKey = guiKey,
                        reason = reason,
                        outcome = "skip_in_progress",
                        visible = visible,
                        building = building,
                        inProgress = inProgress,
                    })
                end
            elseif visible and not building then
                pendingRefresh[guiKey] = nil
                pendingRefreshReason[guiKey] = nil
                if LD and LD.enabled then
                    LD:Record("flush_exec", {
                        guiKey = guiKey,
                        reason = reason,
                        outcome = "exec",
                        visible = visible,
                        building = building,
                        inProgress = inProgress,
                    })
                end
                if Profile and reason then
                    Profile:Start(guiKey .. ":RefreshLayout.reason." .. reason)
                end
                self._currentRefreshReason = reason
                gui:RefreshLayout()
                self._currentRefreshReason = nil
                if Profile and reason then
                    Profile:Stop(guiKey .. ":RefreshLayout.reason." .. reason)
                end
            else
                needsReschedule = true
                if LD and LD.enabled then
                    local outcome = not visible and "skip_hidden" or (building and "skip_building" or "skip")
                    LD:Record(outcome, {
                        guiKey = guiKey,
                        reason = reason,
                        outcome = outcome,
                        visible = visible,
                        building = building,
                        inProgress = inProgress,
                    })
                end
            end
        end
    end

    if needsReschedule then
        if LD and LD.enabled then
            LD:Record("flush_reschedule", { note = "pending work remains" })
        end
        -- Allow EnsureFlushScheduled to arm a fresh timer: the current flush
        -- set refreshScheduled = false at entry, so this re-arms cleanly.
        self:EnsureFlushScheduled()
    end

    if Profile then Profile:Stop("RequestLayoutRefresh.Flush") end
end

local SET_TO_TARGET = {
    BagSet = "bags",
    BankSet = "bank",
    GuildBankSet = "guild",
}

--- Re-render only slots whose cached item matches one of the given item IDs.
--- Used by GET_ITEM_INFO_RECEIVED streaming to avoid rebuilding every slot.
--- Emits a coalesced layout refresh only for the sets that actually matched
--- one of the item IDs, so e.g. bank-only item-info batches don't refresh
--- the bags window.
---@param itemIDs table<number, boolean>|number[]|nil
function ns:UpdateSlotsForItemIDs(itemIDs)
    if not itemIDs then return end
    for _, key in ipairs(VISUAL_TARGET_KEYS.all) do
        local setObj = self[key]
        if setObj and setObj.isBuilt and setObj.UpdateSlotsForItems then
            local matched = setObj:UpdateSlotsForItems(itemIDs)
            if matched then
                self:RequestLayoutRefresh(SET_TO_TARGET[key], "item_info")
            end
        end
    end
end

--- Refresh item button visuals and then refresh layout for affected windows.
---@param target "bags"|"bank"|"guild"|"bank_related"|"all"|nil
function ns:RequestVisualRefresh(target)
    ForEachTarget(self, target, VISUAL_TARGET_KEYS, function(setObj)
        if setObj.isBuilt == false then
            return
        end

        if setObj.RefreshAllVisuals then
            setObj:RefreshAllVisuals()
        elseif setObj.UpdateAllSlots then
            setObj:UpdateAllSlots()
        end
    end)

    if target == "bags" then
        self:RequestLayoutRefresh("bags")
    elseif target == "bank" then
        self:RequestLayoutRefresh("bank")
    elseif target == "guild" then
        self:RequestLayoutRefresh("guild")
    elseif target == "bank_related" then
        self:RequestLayoutRefresh("bank_related")
    else
        self:RequestLayoutRefresh("all")
    end
end

--- Schedule a single deferred refresh ~750ms after a UI surface is first shown.
--- Covers items whose tooltip/item info arrives silently (no GET_ITEM_INFO_RECEIVED
--- event) between the initial categorization pass and the user actually viewing
--- the bag. The tentative-verdict guard in Categories:GetItemCategory leaves
--- those slot entries unset, so this second refresh re-evaluates them against
--- now-warmer data without bulk-wiping the cache.
---
--- Idempotent: rapid open/close/open cycles coalesce into a single timer.
---
--- The catchup is a no-op unless `_hasPendingTentatives` was set during the
--- preceding build/refresh pass. This avoids 500–800 OWB_FullUpdate calls plus
--- a cascading layout refresh on `/reload`-style opens where item info is
--- already cached and no tentative verdicts were ever produced.
---
--- The refresh is surgical: `Categories` records the specific still-unresolved
--- item IDs (`_pendingTentativeItemIDs`) and drops each one on a successful
--- resolution, so at catchup time the set holds only items whose data arrived
--- silently (no `GET_ITEM_INFO_RECEIVED`). We reconcile just those slots via
--- the same `InvalidateItemIDs` + `UpdateSlotsForItemIDs` path the item_info
--- wave uses, instead of rebuilding every slot. If the set is empty, the
--- item_info wave already reconciled everything and the catchup does nothing.
function ns:ScheduleTooltipCatchupRefresh()
    if self._tooltipCatchupPending then return end
    self._tooltipCatchupPending = true
    C_Timer.After(0.75, function()
        self._tooltipCatchupPending = false

        local Profile = ns.Profile
        if not self._hasPendingTentatives then
            if Profile then
                Profile:Start("ns:ScheduleTooltipCatchupRefresh.skipped")
                Profile:Stop("ns:ScheduleTooltipCatchupRefresh.skipped")
            end
            return
        end

        self._hasPendingTentatives = false
        local pending = self._pendingTentativeItemIDs
        self._pendingTentativeItemIDs = nil

        -- The set is the source of truth: successful (non-tentative)
        -- resolutions drop their item from it, so an empty set means the
        -- item_info wave already reconciled every provisional verdict before
        -- the catchup fired. Nothing to do — skip the refresh entirely.
        if not (pending and next(pending)) then
            if Profile then
                Profile:Start("ns:ScheduleTooltipCatchupRefresh.reconciled")
                Profile:Stop("ns:ScheduleTooltipCatchupRefresh.reconciled")
            end
            return
        end

        if Profile then
            Profile:Start("ns:ScheduleTooltipCatchupRefresh.executed")
            Profile:Stop("ns:ScheduleTooltipCatchupRefresh.executed")
        end

        -- Surgical: evict + re-render only the still-tentative slots. Each
        -- matched set emits its own coalesced layout refresh, which
        -- re-categorizes with warm data (cache hits for everything else).
        self:InvalidateItemIDs(pending)
        self:UpdateSlotsForItemIDs(pending)
    end)
end

--- Fully reset window frames and reopen windows that were visible.
---@param target "bags"|"bank"|"guild"|"bank_related"|"all"|nil
function ns:RequestWindowReset(target)
    ForEachTarget(self, target, GUI_TARGET_KEYS, function(gui, key)
        if not gui.FullReset then return end

        local wasShown = gui.IsShown and gui:IsShown()
        gui:FullReset()

        if key == "GUI" and wasShown then
            C_Timer.After(0.1, function()
                if self.GUI then
                    self.GUI:Show()
                end
            end)
        elseif key == "BankGUI" and wasShown and self.bankOpen then
            C_Timer.After(0.1, function()
                if self.BankGUI then
                    self.BankGUI:Show()
                end
            end)
        elseif key == "GuildBankGUI" and wasShown and self.guildBankOpen then
            C_Timer.After(0.1, function()
                if self.GuildBankGUI then
                    self.GuildBankGUI:Show()
                end
            end)
        end
    end)
end

local function RefreshGUI()
    local gui = ns.GUI
    if not gui then return end

    local wasShown = gui:IsShown()
    gui:FullReset()
    if wasShown then
        C_Timer.After(0.1, function()
            gui:Show()
        end)
    end
end

function ns:ReinitForLanguage(langCode)
    OneWoW_GUI:SetSetting("language", langCode)
    ApplyLanguage()
    if self.GUI then
        self.GUI:FullReset()
        C_Timer.After(0.1, function()
            self.GUI:Show()
        end)
    end
end

-- Core-driven init: the suite loader calls OneWoW_Bags:OnAddonLoaded()
-- right after it force-loads this module (WoW does not deliver our own
-- ADDON_LOADED when we are loaded during core's ADDON_LOADED dispatch). This
-- also registers our runtime events via RegisterRuntimeEvents.
local didInit = false
function OneWoW_Bags:OnAddonLoaded()
    if didInit then return end
    didInit = true
    OneWoW.Lifecycle:CreateHandlerRegistry(OneWoW_Bags)

    OneWoW_Bags:RegisterEnteringWorldHandler("zone_refresh", function(isLogin, isReload, isZoning)
        if isZoning then
            Events:OnPlayerEnteringWorld(isLogin, isReload)
        end
    end)

    ns:InitializeDatabase()
    ns:InitializeControllers()
    OneWoW_GUI:MigrateSettings(ns.db.global)

    if ns.Masque and ns.Masque.OnLoad then
        ns.Masque:OnLoad()
    end

    ApplyTheme()
    ApplyLanguage()

    ns.Categories:SetCustomCategories(ns.db.global.customCategoriesV2)
    ns.Categories:SetRecentItemDuration(ns.db.global.recentItemDuration)
    ns.Categories:SetRecentItems(ns.db.global.recentItems)

    ns:RegisterSlashCommands()
    ns:RegisterRuntimeEvents()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", OneWoW_Bags, function(myself, _)
        myself:ApplyTheme()
        RefreshGUI()
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", OneWoW_Bags, function(myself, _)
        myself:ApplyLanguage()
        RefreshGUI()
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", OneWoW_Bags, function(_, _)
        RefreshGUI()
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", OneWoW_Bags, function(_, _)
        RefreshGUI()
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnMoneyDisplayChanged", OneWoW_Bags, function()
        if ns.BagsBar and ns.BagsBar.UpdateGoldDisplay then
            ns.BagsBar:UpdateGoldDisplay()
        end
        if ns.BankBar and ns.BankBar.UpdateGold then
            ns.BankBar:UpdateGold()
        end
        if ns.GuildBankBar and ns.GuildBankBar.UpdateGold then
            ns.GuildBankBar:UpdateGold()
        end
    end)

    local _ver = OneWoW:GetAddonVersion(ADDON_NAME)
    if OneWoW and OneWoW.RegisterLoadComponent then
        OneWoW:RegisterLoadComponent("Bags", _ver, "/1wb")
    end
end

-- Idempotent: runs from the module's own PLAYER_LOGIN at startup, or is driven
-- by the loader (OneWoW:EnsureLoaded) for a mid-session enable, when
-- PLAYER_LOGIN has already fired and won't reach this module.
function OneWoW_Bags:OnPlayerLogin()
    if ns.didLogin then return end
    ns.didLogin = true
    DetectOneWoW()

    if OneWoW and OneWoW.RegisterMinimap then
        OneWoW:RegisterMinimap("OneWoW_Bags", L["CTX_OPEN_BAGS"], nil, function()
            if ns.GUI then ns.GUI:Toggle() end
        end)
    end

    ns.ItemPool:Preallocate(ns.Constants.ITEM_POOL_PREALLOC_SIZE)
    ns.BagSet:Build()
    ns.BagsBar:UpdateIcons()

    ns:HookBlizzardBags()
    ns:HookPetCageTooltip()
    if ns.InstallIntegrationHooks then
        ns:InstallIntegrationHooks()
    end
    if ns.RegisterTooltipProvider then
        ns:RegisterTooltipProvider()
    end
    if OneWoW_Bags.FireLoginHandlers then
        OneWoW_Bags:FireLoginHandlers()
    end
end

function OneWoW_Bags:OnPlayerEnteringWorld(isLogin, isReload, isZoning)
    if OneWoW_Bags.FireEnteringWorldHandlers then
        OneWoW_Bags:FireEnteringWorldHandlers(isLogin, isReload, isZoning)
    end
end

function ns:HookPetCageTooltip()
    local predicateEngine = PE
    local CAGE_ID = predicateEngine.BATTLE_PET_CAGE_ID

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not data or not data.id or data.id ~= CAGE_ID then return end
        local _, itemLink = tooltip:GetItem()
        if not itemLink then return end
        local petData = predicateEngine:GetBattlePetData(CAGE_ID, itemLink)
        if not petData or not petData.speciesID or not petData.petName then return end
        tooltip:AddLine(" ")
        tooltip:AddLine(petData.petName, 1, 0.82, 0)
        if petData.petType and petData.petType > 0 then
            local petTypeName = _G["BATTLE_PET_NAME_" .. petData.petType] or (L["PET_TYPE_PREFIX"] .. petData.petType)
            tooltip:AddLine(petTypeName, 0.7, 0.7, 0.7)
        end
        local numCollected, limit = petData.numCollected, petData.limit
        if numCollected then
            if numCollected > 0 then
                tooltip:AddLine(COLLECTED .. ": " .. numCollected .. "/" .. (limit or "?"), 0.2, 1, 0.2)
            else
                tooltip:AddLine(COLLECTED .. ": 0/" .. (limit or "?"), 1, 0.2, 0.2)
            end
        end
        tooltip:Show()
    end)
end

function ns:OnBankOpened()
    self.bankOpen = self:IsBankUIEnabled()
    if not self:IsBankUIEnabled() then
        self.isWarbandOnlyBankAccess = false
        self:RestoreBankFrame()
        if self.BankGUI and self.BankGUI:IsShown() then
            self.BankGUI:Hide()
        end
        if self.db.global.autoOpenWithBank then
            self.GUI:Show()
        end
        return
    end

    self:SuppressBankFrame()

    local canUseCharacter = C_Bank.CanUseBank(Enum.BankType.Character)
    local canUseAccount = C_Bank.CanUseBank(Enum.BankType.Account)
    self.isWarbandOnlyBankAccess = canUseAccount and not canUseCharacter or false
    if self.isWarbandOnlyBankAccess then
        self.db.global.bankShowWarband = true
    end

    local activeBankType = self.db.global.bankShowWarband and Enum.BankType.Account or Enum.BankType.Character
    if BankFrame and BankFrame.BankPanel then
        BankFrame.BankPanel:SetBankType(activeBankType)
        BankFrame.BankPanel:Show()
    end

    C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
    C_Bank.FetchNumPurchasedBankTabs(Enum.BankType.Character)
    C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
    C_Bank.FetchNumPurchasedBankTabs(Enum.BankType.Account)

    self.BankGUI:Show()

    if self.db.global.autoOpenWithBank then
        self.GUI:Show()
    end

    if self.InfoBar and self.InfoBar.UpdateVisibility then
        self.InfoBar:UpdateVisibility()
    end

    self:ScheduleTooltipCatchupRefresh()
end

function ns:OnBankClosed()
    if not self:IsBankUIEnabled() then
        self.bankOpen = false
        self.isWarbandOnlyBankAccess = false
        self:RestoreBankFrame()
        return
    end
    if not self.bankOpen then return end
    self.bankOpen = false
    self:ClearPendingLayoutRefresh("BankGUI")
    self.isWarbandOnlyBankAccess = false
    if BankFrame and BankFrame.BankPanel then
        BankFrame.BankPanel:Hide()
    end

    self.BankGUI:Hide()
    self.BankSet:ReleaseAll()

    if self.InfoBar and self.InfoBar.UpdateVisibility then
        self.InfoBar:UpdateVisibility()
    end
end

function ns:SuppressGuildBankFrame()
    if not GuildBankFrame then return end
    if self._guildBankSuppressed then return end
    self._guildBankSuppressed = true

    self._gbOrigOnHide = GuildBankFrame:GetScript("OnHide")
    GuildBankFrame:SetScript("OnHide", nil)
    GuildBankFrame:ClearAllPoints()
    GuildBankFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, -10000)
    GuildBankFrame:SetAlpha(0)
end

function ns:RestoreGuildBankFrame()
    if not self._guildBankSuppressed then return end
    if not GuildBankFrame then return end
    self._guildBankSuppressed = false
    if self._gbOrigOnHide then
        GuildBankFrame:SetScript("OnHide", self._gbOrigOnHide)
    end
    self._gbOrigOnHide = nil
    GuildBankFrame:SetAlpha(1)
end

function ns:RefreshGuildBankContents()
    if not self.GuildBankSet.isBuilt then return end

    self:ProcessPendingGuildBankTransferTabs()
    self.GuildBankSet:UpdateAllSlots()

    local sources = self._guildBankClearSources
    if sources then
        local expired = self._guildBankClearSourcesExpiry and GetTime() > self._guildBankClearSourcesExpiry
        local remaining = {}
        for _, src in ipairs(sources) do
            local cached = self.GuildBankSet.cache[src.tab] and self.GuildBankSet.cache[src.tab][src.slot]
            if cached and cached.texture then
                if not expired then
                    self.GuildBankSet:ClearCacheSlot(src.tab, src.slot)
                    tinsert(remaining, src)
                end
            end
        end
        if #remaining > 0 then
            self._guildBankClearSources = remaining
        else
            self._guildBankClearSources = nil
            self._guildBankClearSourcesExpiry = nil
        end
    end

    if self.GuildBankBar then
        self.GuildBankBar:UpdateFreeSlots(self.GuildBankSet:GetFreeSlotCount(), self.GuildBankSet:GetSlotCount())
    end

    self:RequestLayoutRefresh("guild")
end

function ns:TrackGuildBankTransferTab(tabID)
    if not tabID then return end
    self._guildBankTransferTabs = self._guildBankTransferTabs or {}
    self._guildBankTransferTabs[tabID] = true
end

function ns:TrackGuildBankTransferSource(tabID, slotID)
    if not tabID or not slotID then return end
    self._guildBankTransferSources = self._guildBankTransferSources or {}
    tinsert(self._guildBankTransferSources, {tab = tabID, slot = slotID})
end

function ns:PurgeClearSource(tabID, slotID)
    local sources = self._guildBankClearSources
    if sources then
        for i = #sources, 1, -1 do
            if sources[i].tab == tabID and sources[i].slot == slotID then
                tremove(sources, i)
            end
        end
        if #sources == 0 then
            self._guildBankClearSources = nil
            self._guildBankClearSourcesExpiry = nil
        end
    end
    local pending = self._guildBankTransferSources
    if pending then
        for i = #pending, 1, -1 do
            if pending[i].tab == tabID and pending[i].slot == slotID then
                tremove(pending, i)
            end
        end
        if #pending == 0 then
            self._guildBankTransferSources = nil
        end
    end
end

function ns:ProcessPendingGuildBankTransferTabs()
    local transferTabs = self._guildBankTransferTabs
    if not transferTabs then
        return
    end

    local cursorType = GetCursorInfo()
    if cursorType then
        return
    end

    self._guildBankTransferTabs = nil
    self._guildBankSeenBagPickup = false

    if self._guildBankTransferSources then
        if not self._guildBankClearSources then
            self._guildBankClearSources = {}
        end
        for _, src in ipairs(self._guildBankTransferSources) do
            tinsert(self._guildBankClearSources, src)
        end
        self._guildBankClearSourcesExpiry = GetTime() + 5
        self._guildBankTransferSources = nil
    end

    for tabID in pairs(transferTabs) do
        QueryGuildBankTab(tabID)
    end

    C_Timer.After(0.5, function()
        if self.guildBankOpen and self.GuildBankSet and self.GuildBankSet.isBuilt then
            self:QueueGuildBankRefresh()
        end
    end)
end

function ns:QueueGuildBankRefresh()
    if not self.GuildBankSet.isBuilt then return end

    if self._guildBankUpdatePending then
        return
    end
    self._guildBankUpdatePending = true

    C_Timer.After(0, function()
        self._guildBankUpdatePending = false
        self:RefreshGuildBankContents()
    end)
end

function ns:OnGuildBankOpened()
    self.guildBankOpen = self:IsBankUIEnabled()
    if not self:IsBankUIEnabled() then
        self:RestoreGuildBankFrame()
        if self.GuildBankGUI and self.GuildBankGUI:IsShown() then
            self.GuildBankGUI:Hide()
        end
        if self.db.global.autoOpenWithBank then
            self.GUI:Show()
        end
        return
    end

    self._guildBankUpdatePending = false
    self._guildBankTransferTabs = nil
    self._guildBankTransferSources = nil
    self._guildBankClearSources = nil
    self._guildBankClearSourcesExpiry = nil
    self._guildBankSeenBagPickup = false
    self._wasPlacingBeforeGBOp = nil
    self._destHadItemBeforeGBOp = nil
    self:SuppressGuildBankFrame()

    self.GuildBankGUI:Show()

    if self.db.global.autoOpenWithBank then
        self.GUI:Show()
    end

    self:ScheduleTooltipCatchupRefresh()
end

function ns:OnGuildBankClosed()
    if not self:IsBankUIEnabled() then
        self.guildBankOpen = false
        self:RestoreGuildBankFrame()
        return
    end
    if not self.guildBankOpen then return end
    self.guildBankOpen = false
    self:ClearPendingLayoutRefresh("GuildBankGUI")
    self._guildBankUpdatePending = false
    self._guildBankTransferTabs = nil
    self._guildBankTransferSources = nil
    self._guildBankClearSources = nil
    self._guildBankClearSourcesExpiry = nil
    self._guildBankSeenBagPickup = false
    self._wasPlacingBeforeGBOp = nil
    self._destHadItemBeforeGBOp = nil
    self.GuildBankGUI:Hide()
    self.GuildBankSet:ReleaseAll()
    self.GuildBankSet:ClearCache()
    self:RestoreGuildBankFrame()
end

function ns:OnGuildBankSlotsChanged()
    self:QueueGuildBankRefresh()
end

function ns:OnGuildBankItemLockChanged()
    if not self.GuildBankSet.isBuilt then return end
    local currentTab = GetCurrentGuildBankTab()
    if currentTab then
        self.GuildBankSet:RefreshLockVisuals({[currentTab] = true})
    end
end

function ns:OnGuildBankTabsUpdated()
    if self.guildBankOpen then
        -- GuildBankSet:Build() already emits a coalesced RequestLayoutRefresh("guild").
        self.GuildBankSet:Build()
        self.GuildBankBar:BuildTabButtons()
    end
end

function ns:OnGuildBankMoneyUpdated()
    if self.GuildBankBar then
        self.GuildBankBar:UpdateGold()
    end
end

function ns:OnGuildBankWithdrawMoneyUpdated()
    if self.GuildBankBar then
        self.GuildBankBar:UpdateWithdrawButton()
    end
end

function ns:OnPlayerMoney()
    if self.bankOpen and self.BankBar then
        self.BankBar:UpdateGold()
    end
end

function ns:OnAccountMoney()
    if self.bankOpen and self.BankBar then
        self.BankBar:UpdateGold()
    end
end

function ns:OnBankTabsChanged(bankType)
    if not self.bankOpen then return end

    local activeBankType = self.db.global.bankShowWarband and Enum.BankType.Account or Enum.BankType.Character
    if bankType and bankType ~= activeBankType then
        return
    end

    C_Bank.FetchPurchasedBankTabData(activeBankType)
    C_Bank.FetchNumPurchasedBankTabs(activeBankType)

    self.BankController:Set("selectedTab", nil)

    if self.BankGUI and self.BankGUI.ClearForcedPurchasePrompt then
        self.BankGUI:ClearForcedPurchasePrompt()
    end

    if self.BankSet then
        -- Build() materializes only newly-purchased tabs (others remain
        -- cached); it also emits a coalesced RequestLayoutRefresh("bank").
        self.BankSet:Build()
    end

    if self.BankBar then
        self.BankBar:BuildTabButtons()
        self.BankBar:UpdateTabHighlights()
        self.BankBar:UpdateGold()
    end
end

function ns:SuppressBankFrame()
    if not BankFrame then return end
    if self._bankFrameSuppressed then return end
    self._bankFrameSuppressed = true

    self._bankHiddenParent = CreateFrame("Frame")
    self._bankHiddenParent:Hide()

    self._bankOrigOnShow = BankFrame:GetScript("OnShow")
    self._bankOrigOnHide = BankFrame:GetScript("OnHide")
    self._bankOrigOnEvent = BankFrame:GetScript("OnEvent")

    BankFrame:SetScript("OnShow", nil)
    BankFrame:SetScript("OnHide", nil)
    BankFrame:SetScript("OnEvent", nil)

    BankFrame:ClearAllPoints()
    BankFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, -10000)
    BankFrame:SetAlpha(0)
    BankFrame:EnableMouse(false)
    BankFrame:Show()

    for i = 7, 13 do
        local cf = _G["ContainerFrame" .. i]
        if cf then
            cf:SetParent(self._bankHiddenParent)
        end
    end
end

function ns:RestoreBankFrame()
    if not self._bankFrameSuppressed then return end
    self._bankFrameSuppressed = false

    if BankFrame then
        if self._bankOrigOnShow then
            BankFrame:SetScript("OnShow", self._bankOrigOnShow)
        end
        if self._bankOrigOnHide then
            BankFrame:SetScript("OnHide", self._bankOrigOnHide)
        end
        if self._bankOrigOnEvent then
            BankFrame:SetScript("OnEvent", self._bankOrigOnEvent)
        end

        BankFrame:EnableMouse(true)
        BankFrame:SetAlpha(1)

        if BankFrame.BankPanel then
            BankFrame.BankPanel:Hide()
        end

        for i = 7, 13 do
            local cf = _G["ContainerFrame" .. i]
            if cf and self._bankHiddenParent and cf:GetParent() == self._bankHiddenParent then
                cf:SetParent(UIParent)
            end
        end
    end

    self._bankOrigOnShow = nil
    self._bankOrigOnHide = nil
    self._bankOrigOnEvent = nil
    self._bankHiddenParent = nil
end

function ns:ProcessBagUpdate(dirtyBags)
    self.Categories:OnPlayerBagDirtySnapshot(dirtyBags)

    -- Partition dirty bagIDs by container domain so we only refresh the
    -- windows that actually had data change. During bank-open the server
    -- streams BAG_UPDATEs for bank tabs only - the bags window does not
    -- need to re-layout for those, and vice versa.
    local bagsDirty, bankDirty = false, false
    for bagID in pairs(dirtyBags) do
        if self.BagTypes:IsPlayerBag(bagID) then
            bagsDirty = true
        elseif self.BankTypes:IsPersonalBankTab(bagID) or self.BankTypes:IsWarbandTab(bagID) then
            bankDirty = true
        end
    end

    if self.BagSet.isBuilt and bagsDirty then
        self.BagSet:UpdateDirtyBags(dirtyBags)
        self:RequestLayoutRefresh("bags", "bag_update")
    end

    if self.bankOpen and self.BankSet.isBuilt and bankDirty then
        self.BankSet:UpdateDirtyBags(dirtyBags)
        self:RequestLayoutRefresh("bank", "bag_update")
    end
end

function ns:OnItemLockChanged(bagID, slotID)
    if self.BagSet.isBuilt and self.BagSet.slots[bagID] and self.BagSet.slots[bagID][slotID] then
        self.BagSet.slots[bagID][slotID]:OWB_RefreshLock()
    end

    if self.bankOpen then
        if self.BankSet.isBuilt and self.BankSet.slots[bagID] and self.BankSet.slots[bagID][slotID] then
            self.BankSet.slots[bagID][slotID]:OWB_RefreshLock()
        end
    end
end

function ns:RefreshCooldowns()
    if not self.BagSet.isBuilt then return end
    for _, bagSlots in pairs(self.BagSet.slots) do
        for _, button in pairs(bagSlots) do
            if button.owb_hasItem then
                button:OWB_RefreshCooldown()
            end
        end
    end
end

function ns:OnCooldownUpdate()
    if self._cooldownRefreshPending then return end
    self._cooldownRefreshPending = true
    C_Timer.After(0.05, function()
        self._cooldownRefreshPending = false
        self:RefreshCooldowns()
    end)
end

function ns:RegisterSlashCommands()
    SLASH_ONEWOW_BAGS1 = "/1wb"
    SLASH_ONEWOW_BAGS2 = "/onewowbags"
    SLASH_ONEWOW_BAGS3 = "/1wbags"

    SlashCmdList["ONEWOW_BAGS"] = function()
        self.GUI:Toggle()
    end

    SLASH_ONEWOW_BAGS_EXPORT1 = "/owbags-export"
    SlashCmdList["ONEWOW_BAGS_EXPORT"] = function()
        local Serializer = ns.ImportExport and ns.ImportExport.Serializer
        if not Serializer then
            print("|cFFFF6060" .. L["ADDON_CHAT_PREFIX"] .. "|r " .. L["EXPORT_UNAVAILABLE_SERIALIZER"])
            return
        end
        local db = ns.db
        if not db or not db.global then
            print("|cFFFF6060" .. L["ADDON_CHAT_PREFIX"] .. "|r " .. L["EXPORT_UNAVAILABLE_DB"])
            return
        end
        local title = L["EXPORT_DIALOG_TITLE"]
        local payload = Serializer:Encode(Serializer:BuildExport(db))
        OneWoW.CopyPaste:Copy(title, payload, { readOnly = true, frameStrata = "FULLSCREEN_DIALOG" })
    end
end

function ns:ShouldHideBlizzardBagsBar()
    local db = self.db
    return db.global.hideBlizzardBagsBar == true
end

function ns:UpdateBlizzardBagsBarVisibility()
    local blizzBagsBar = BagsBar
    if not blizzBagsBar then return end

    if not self._blizzardBagsBarHooked then
        self._blizzardBagsBarHooked = true
        blizzBagsBar:HookScript("OnShow", function(frame)
            if ns:ShouldHideBlizzardBagsBar() then
                frame:Hide()
            end
        end)
    end

    if self:ShouldHideBlizzardBagsBar() then
        blizzBagsBar:Hide()
    else
        blizzBagsBar:Show()
    end
end

function ns:HookBlizzardBags()
    local function IsMerchantVisible()
        return MerchantFrame and MerchantFrame:IsShown()
    end

    local function OpenOurBags(source)
        if source == "auto" and IsMerchantVisible() then
            return
        end
        ns.GUI:Show()
    end

    local function ToggleOurBags()
        ns.GUI:Toggle()
    end

    local bindingFrame = CreateFrame("Button", "OneWoW_BagsBindingFrame")
    bindingFrame:RegisterForClicks("AnyDown")
    bindingFrame:SetScript("OnClick", function()
        ToggleOurBags()
    end)
    self.bindingFrame = bindingFrame

    local function ApplyBindingOverrides()
        ClearOverrideBindings(bindingFrame)

        local bindings = {
            "TOGGLEBACKPACK",
            "TOGGLEBAG1",
            "TOGGLEBAG2",
            "TOGGLEBAG3",
            "TOGGLEBAG4",
            "TOGGLEREAGENTBAG",
            "OPENALLBAGS",
        }

        for _, binding in ipairs(bindings) do
            local key1, key2 = GetBindingKey(binding)
            if key1 then
                SetOverrideBinding(bindingFrame, true, key1, "CLICK OneWoW_BagsBindingFrame:LeftButton")
            end
            if key2 then
                SetOverrideBinding(bindingFrame, true, key2, "CLICK OneWoW_BagsBindingFrame:LeftButton")
            end
        end
    end

    local function SetupBindingOverrides()
        -- SetOverrideBinding is protected, so defer until protected actions are
        -- allowed (combat lockdown / Combat / Encounter / keystone / PvP) — but NOT
        -- the Map restriction, so bindings still set up inside a Delve out of combat.
        -- One-shot: a re-run (e.g. UPDATE_BINDINGS) replaces any pending request.
        OneWoW.Restriction.RunWhenUnrestricted("protected", "OneWoW_Bags.bindings", ApplyBindingOverrides)
    end

    bindingFrame:SetScript("OnEvent", function(_, event)
        if event == "UPDATE_BINDINGS" then
            SetupBindingOverrides()
        end
    end)
    bindingFrame:RegisterEvent("UPDATE_BINDINGS")
    SetupBindingOverrides()

    for i = 1, 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame then
            frame:HookScript("OnShow", function(myself) myself:Hide() end)
        end
    end

    if ContainerFrameCombinedBags then
        ContainerFrameCombinedBags:HookScript("OnShow", function(myself) myself:Hide() end)
    end

    hooksecurefunc("OpenBackpack", function() OpenOurBags("auto") end)
    hooksecurefunc("ToggleAllBags", function() ToggleOurBags() end)
    hooksecurefunc("OpenAllBags", function() OpenOurBags("auto") end)

    hooksecurefunc("PickupGuildBankItem", function(tabID, slotID)
        local cursorAfter = GetCursorInfo()
        local wasPlacing = self._wasPlacingBeforeGBOp
        local destHadItem = self._destHadItemBeforeGBOp
        self._wasPlacingBeforeGBOp = nil
        self._destHadItemBeforeGBOp = nil

        self:TrackGuildBankTransferTab(tabID)

        if not slotID then return end

        if wasPlacing and destHadItem and not cursorAfter then
            self:PurgeClearSource(tabID, slotID)
            self._guildBankTransferSources = nil
        elseif wasPlacing or not cursorAfter then
            self:PurgeClearSource(tabID, slotID)
        else
            self:TrackGuildBankTransferSource(tabID, slotID)
        end
    end)
    hooksecurefunc("SplitGuildBankItem", function(tabID, _)
        self:TrackGuildBankTransferTab(tabID)
    end)
    hooksecurefunc(C_Container, "PickupContainerItem", function()
        if self.guildBankOpen then
            self._guildBankSeenBagPickup = true
        end
    end)

    hooksecurefunc("OpenBag", function(bagID)
        if self.BagTypes:IsPlayerBag(bagID) then
            OpenOurBags("auto")
        end
    end)

    EventRegistry:RegisterCallback("ContainerFrame.OpenAllBags", function()
        OpenOurBags("auto")
    end, self)

    self:UpdateBlizzardBagsBarVisibility()
end

function ns:OnMerchantShow()
    self.vendorInteractionActive = true
    self.vendorCloseGuardActive = false
    self.vendorAutoOpenedBags = false
    if not self.db.global.autoOpen then
        return
    end
    self.vendorAutoOpenedBags = true
    self.GUI:Show()
end

function ns:OnMerchantClosed()
    self.vendorInteractionActive = false
    self.vendorCloseGuardActive = true
    if self.db.global.autoClose and self.GUI and self.GUI:IsShown() then
        self.GUI:Hide()
    end
    self.vendorAutoOpenedBags = false
    C_Timer.After(0, function()
        self.vendorCloseGuardActive = false
    end)
end

local moneyDialog = nil

function ns:GetMoneyDialog()
    if moneyDialog then return moneyDialog end

    local result = OneWoW_GUI:CreateDialog({
        name = "OneWoW_BagsMoneyDialog",
        title = "",
        width = 300,
        height = 120,
        strata = "DIALOG",
        movable = true,
        escClose = true,
    })

    local dialogFrame = assert(result.frame, "ns:CreateDialog missing frame")
    local contentFrame = assert(result.contentFrame, "ns:CreateDialog missing contentFrame")
    local titleBar = result.titleBar

    dialogFrame:SetFrameLevel(500)

    local moneyBox = CreateFrame("Frame", "OneWoW_BagsMoneyInput", contentFrame, "MoneyInputFrameTemplate")
    moneyBox:SetPoint("TOP", contentFrame, "TOP", 0, -10)

    local btnRow = CreateFrame("Frame", nil, contentFrame)
    btnRow:SetHeight(26)
    btnRow:SetPoint("BOTTOM", contentFrame, "BOTTOM", 0, 10)

    local depositBtn = OneWoW_GUI:CreateFitTextButton(btnRow, { text = DEPOSIT, height = 26 })

    local withdrawBtn = OneWoW_GUI:CreateFitTextButton(btnRow, { text = WITHDRAW, height = 26 })

    local function layoutButtons()
        depositBtn:ClearAllPoints()
        withdrawBtn:ClearAllPoints()
        local depW = depositBtn:GetWidth()
        local witW = withdrawBtn:GetWidth()
        local gap = 10
        local depShown = depositBtn:IsShown()
        local witShown = withdrawBtn:IsShown()

        if depShown and witShown then
            local totalW = depW + witW + gap
            btnRow:SetWidth(totalW)
            depositBtn:SetPoint("LEFT", btnRow, "LEFT", 0, 0)
            withdrawBtn:SetPoint("LEFT", depositBtn, "RIGHT", gap, 0)
        elseif depShown then
            btnRow:SetWidth(depW)
            depositBtn:SetPoint("LEFT", btnRow, "LEFT", 0, 0)
        elseif witShown then
            btnRow:SetWidth(witW)
            withdrawBtn:SetPoint("LEFT", btnRow, "LEFT", 0, 0)
        end
    end

    moneyDialog = {
        frame = dialogFrame,
        titleBar = titleBar,
        moneyBox = moneyBox,
        depositBtn = depositBtn,
        withdrawBtn = withdrawBtn,
        layoutButtons = layoutButtons,
    }

    return moneyDialog
end

--- Show the shared money input dialog for bank and guild-bank money actions.
--- `config` may provide title, anchorFrame, onDeposit, and/or onWithdraw.
---@param config table
function ns:ShowMoneyDialog(config)
    local dialog = self:GetMoneyDialog()
    dialog.frame:Hide()
    MoneyInputFrame_ResetMoney(dialog.moneyBox)

    local titleText = dialog.titleBar and dialog.titleBar._titleText
    if titleText then
        local setText = titleText["SetText"]
        if setText then
            setText(titleText, config.title or "")
        end
    end

    if config.anchorFrame then
        dialog.frame:ClearAllPoints()
        dialog.frame:SetPoint("BOTTOM", config.anchorFrame, "TOP", 0, 5)
    else
        dialog.frame:ClearAllPoints()
        dialog.frame:SetPoint("CENTER")
    end

    dialog.depositBtn:SetShown(config.onDeposit ~= nil)
    dialog.withdrawBtn:SetShown(config.onWithdraw ~= nil)
    dialog.layoutButtons()

    local function doAction(callback)
        local copper = MoneyInputFrame_GetCopper(dialog.moneyBox)
        if copper > 0 and callback then
            callback(copper)
        end
        dialog.frame:Hide()
    end

    dialog.depositBtn:SetScript("OnClick", function()
        doAction(config.onDeposit)
    end)

    dialog.withdrawBtn:SetScript("OnClick", function()
        doAction(config.onWithdraw)
    end)

    local onEnter = function()
        if config.onDeposit and not config.onWithdraw then
            doAction(config.onDeposit)
        elseif config.onWithdraw and not config.onDeposit then
            doAction(config.onWithdraw)
        end
    end
    dialog.moneyBox.gold:SetScript("OnEnterPressed", onEnter)
    dialog.moneyBox.silver:SetScript("OnEnterPressed", onEnter)
    dialog.moneyBox.copper:SetScript("OnEnterPressed", onEnter)

    dialog.frame:Show()
    dialog.moneyBox.gold:SetFocus()
end

-- No file-scope lifecycle registration: the loader calls OnAddonLoaded directly,
-- which registers our runtime events via RegisterRuntimeEvents below.
local eventFrame = CreateFrame("Frame")

local runtimeEventHandlers = {
    BAG_UPDATE = function(...)
        Events:OnBagUpdate(...)
    end,
    BAG_UPDATE_DELAYED = function(...)
        Events:OnBagUpdateDelayed(...)
    end,
    ITEM_LOCK_CHANGED = function(...)
        Events:OnItemLockChanged(...)
    end,
    BAG_UPDATE_COOLDOWN = function(...)
        Events:OnCooldownUpdate(...)
    end,
    QUEST_ACCEPTED = function(...)
        Events:OnQuestAccepted(...)
    end,
    QUEST_REMOVED = function(...)
        Events:OnQuestRemoved(...)
    end,
    BANKFRAME_OPENED = function(...)
        Events:OnBankOpened(...)
    end,
    BANKFRAME_CLOSED = function(...)
        Events:OnBankClosed(...)
    end,
    BANK_TABS_CHANGED = function(...)
        Events:OnBankTabsChanged(...)
    end,
    PLAYER_INTERACTION_MANAGER_FRAME_SHOW = function(...)
        Events:OnPlayerInteractionShow(...)
    end,
    PLAYER_INTERACTION_MANAGER_FRAME_HIDE = function(...)
        Events:OnPlayerInteractionHide(...)
    end,
    GUILDBANKBAGSLOTS_CHANGED = function(...)
        Events:OnGuildBankSlotsChanged(...)
    end,
    GUILDBANK_ITEM_LOCK_CHANGED = function(...)
        Events:OnGuildBankItemLockChanged(...)
    end,
    GUILDBANK_UPDATE_TABS = function(...)
        Events:OnGuildBankTabsUpdated(...)
    end,
    GUILDBANK_UPDATE_MONEY = function(...)
        Events:OnGuildBankMoneyUpdated(...)
    end,
    GUILDBANK_UPDATE_WITHDRAWMONEY = function(...)
        Events:OnGuildBankWithdrawMoneyUpdated(...)
    end,
    PLAYER_MONEY = function(...)
        Events:OnPlayerMoney(...)
    end,
    ACCOUNT_MONEY = function(...)
        Events:OnAccountMoney(...)
    end,
    EQUIPMENT_SETS_CHANGED = function(...)
        Events:OnPredicateInvalidation(...)
    end,
    PLAYER_EQUIPMENT_CHANGED = function(inventorySlot)
        Events:OnPredicateInvalidation()
        Events:OnPlayerEquipmentChanged(inventorySlot)
    end,
    BAG_CONTAINER_UPDATE = function()
        Events:OnBagContainerUpdate()
    end,
    GET_ITEM_INFO_RECEIVED = function(itemID)
        Events:OnItemInfoReceived(itemID)
    end,
    SKILL_LINES_CHANGED = function(...)
        PE:InvalidateKnownProfessions()
        Events:OnPredicateInvalidation(...)
    end,
    PLAYER_LEVEL_UP = function()
        Events:OnPredicateInvalidation()
    end,
    ACTIVE_TALENT_GROUP_CHANGED = function()
        Events:OnPredicateInvalidation()
    end,
    PLAYER_SPECIALIZATION_CHANGED = function(unit)
        if unit == "player" then
            Events:OnPredicateInvalidation()
        end
    end,
}

function ns:RegisterRuntimeEvents()
    if self.runtimeEventsRegistered then return end

    self.runtimeEventsRegistered = true
    for _, eventName in ipairs(Events.RuntimeEvents) do
        eventFrame:RegisterEvent(eventName)
    end

    -- MERCHANT_SHOW / MERCHANT_CLOSED route through the core OneWoW.Merchant
    -- funnel (single MERCHANT_* owner) instead of this frame.
    OneWoW.Merchant.RegisterShowCallback("OneWoW_Bags", function()
        Events:OnMerchantShow()
    end)
    OneWoW.Merchant.RegisterClosedCallback("OneWoW_Bags", function()
        Events:OnMerchantClosed()
    end)
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local handler = runtimeEventHandlers[event]
    if handler then
        handler(...)
    end
end)
