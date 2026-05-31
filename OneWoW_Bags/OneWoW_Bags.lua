local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local PE = OneWoW_GUI.PredicateEngine

local L = OneWoW_Bags.L
local Events = OneWoW_Bags.Events

local ipairs, pairs, tinsert = ipairs, pairs, tinsert
local hooksecurefunc = hooksecurefunc

local C_Timer = C_Timer
local C_Bank = C_Bank

-- DO NOT change this _G reference. Right side is local namespace table. Confusing as they're named the same.
-- We use _G[""] form since _G.OneWoW_Bags would get caught in pre-commit hook.
_G["OneWoW_Bags"] = OneWoW_Bags

OneWoW_Bags.oneWoWHubActive = false
OneWoW_Bags.bankOpen = false
OneWoW_Bags.guildBankOpen = false
OneWoW_Bags.isWarbandOnlyBankAccess = false
OneWoW_Bags.inventoryPresentationState = {
    altShowActive = false,
}

local function DetectOneWoW()
    if OneWoW then
        OneWoW_Bags.oneWoWHubActive = true
    end
end

local function ApplyTheme()
    OneWoW_GUI:ApplyTheme(OneWoW_Bags)
end

local function ApplyLanguage()
    local lang = OneWoW_GUI:GetSetting("language") or "enUS"
    if lang == "esMX" then lang = "esES" end
    local localeData = OneWoW_Bags.Locales[lang] or OneWoW_Bags.Locales["enUS"]
    local fallback = OneWoW_Bags.Locales["enUS"]
    for k, v in pairs(fallback) do
        L[k] = localeData[k] or v
    end
end

OneWoW_Bags.ApplyTheme = ApplyTheme
OneWoW_Bags.ApplyLanguage = ApplyLanguage

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
local lastRefreshTime = {}

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

--- Return the addon database handle after initialization.
---@return table db
function OneWoW_Bags:GetDB()
    return self.db
end

function OneWoW_Bags:SetAltShowActive(active)
    self.inventoryPresentationState.altShowActive = active == true
end

function OneWoW_Bags:IsAltShowActive()
    local db = self:GetDB()
    if not db.global.altToShow then return false end
    return self.inventoryPresentationState.altShowActive == true
end

function OneWoW_Bags:GetItemSortMode()
    return self:GetDB().global.itemSort
end

--- Build PredicateEngine props for a button without treating guild-bank tab/slot
--- coordinates as C_Container bag/slot coordinates.
---@param button table
---@return table props
function OneWoW_Bags:GetButtonProps(button)
    local info = button and button.owb_itemInfo
    local itemID = info and info.itemID
    if not itemID then return {} end

    if button.owb_isGuildBank then
        return PE:BuildProps(itemID, nil, nil, info.hyperlink or info)
    end

    return PE:BuildProps(itemID, button.owb_bagID, button.owb_slotID, info)
end

function OneWoW_Bags:ShouldShowItemQuality(isBank, quality)
    if self:IsAltShowActive() then return true end
    if not quality or quality < 1 then return false end

    local db = self:GetDB()

    if isBank then
        return self.BankController:Get("rarityColor") == true
    end

    return db.global.rarityColor == true
end

function OneWoW_Bags:ShouldDimJunkItem(isJunk)
    local db = self:GetDB()
    return isJunk and db.global.dimJunkItems and not self:IsAltShowActive()
end

function OneWoW_Bags:ShouldStripJunkOverlays(isJunk)
    local db = self:GetDB()
    return isJunk and db.global.stripJunkOverlays and not self:IsAltShowActive()
end

function OneWoW_Bags:IsBankUIEnabled()
    local db = self:GetDB()
    return db.global.enableBankUI ~= false
end

function OneWoW_Bags:EnsureCategoryModification(categoryName)
    if not categoryName then return nil end

    local db = self:GetDB()

    local categoryModifications = EnsureTable(db.global, "categoryModifications")
    return EnsureTable(categoryModifications, categoryName)
end

function OneWoW_Bags:EnsureBuiltinCategoryAddedItems(categoryName)
    local categoryModification = self:EnsureCategoryModification(categoryName)
    if not categoryModification then return nil end
    return EnsureTable(categoryModification, "addedItems")
end

function OneWoW_Bags:InitializeControllers()
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
function OneWoW_Bags:InvalidateCategorization(scope)
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
function OneWoW_Bags:InvalidateItemIDs(idSet)
    if not idSet or not next(idSet) then return end
    local Profile = self.Profile
    if Profile then Profile:Start("InvalidateItemIDs") end
    local evictedSlotKeys = PE:InvalidateItemIDs(idSet)
    self.Categories:InvalidateItemIDs(idSet, evictedSlotKeys)
    if Profile then Profile:Stop("InvalidateItemIDs") end
end

--- Refresh item layout for one or more windows. Coalesced: multiple calls
--- in the same frame collapse to a single deferred flush. Hidden windows
--- and windows whose backing Set is mid-Build are skipped.
---@param target "bags"|"bank"|"guild"|"bank_related"|"all"|nil
---@param reason string|nil diagnostic tag; first-write-wins per target
function OneWoW_Bags:RequestLayoutRefresh(target, reason)
    ForEachTarget(self, target, GUI_TARGET_KEYS, function(_, key)
        pendingRefresh[key] = true
        if reason and not pendingRefreshReason[key] then
            pendingRefreshReason[key] = reason
        end
    end)
    if not refreshScheduled then
        refreshScheduled = true
        C_Timer.After(0, function() self:FlushPendingLayoutRefreshes() end)
    end
end

--- Get the (GetTime-based) timestamp of the most recent RefreshLayout call
--- that was actually executed via the scheduler for the given target.
---@param targetKey "bags"|"bank"|"guild"
---@return number|nil seconds
function OneWoW_Bags:GetLastRefreshTime(targetKey)
    local guiKey = TARGET_TO_GUI[targetKey]
    return guiKey and lastRefreshTime[guiKey] or nil
end

--- Synchronous escape hatch for callers that cannot tolerate the
--- coalescer's one-frame delay. Skips visibility/build gating so a hidden
--- window can pre-warm its layout before being shown. Use sparingly.
---@param target "bags"|"bank"|"guild"|"bank_related"|"all"|nil
function OneWoW_Bags:RequestLayoutRefreshNow(target)
    ForEachTarget(self, target, GUI_TARGET_KEYS, function(gui)
        if gui.RefreshLayout then
            gui:RefreshLayout()
        end
    end)
end

--- Flush pending coalesced refresh requests. Skips windows that are
--- hidden or whose backing Set is in the middle of a Build.
function OneWoW_Bags:FlushPendingLayoutRefreshes()
    refreshScheduled = false
    local Profile = self.Profile
    if Profile then Profile:Start("RequestLayoutRefresh.Flush") end

    local guiKeys = {}
    for guiKey in pairs(pendingRefresh) do
        tinsert(guiKeys, guiKey)
    end

    local needsReschedule = false
    for _, guiKey in ipairs(guiKeys) do
        if not pendingRefresh[guiKey] then
            -- Cleared by an earlier iteration or external path.
        else
            local reason = pendingRefreshReason[guiKey]
            local gui = self[guiKey]
            local setKey = GUI_TO_SET[guiKey]
            local backingSet = setKey and self[setKey]
            local visible = gui and (gui.IsShown == nil or gui:IsShown())
            local building = backingSet and backingSet._building == true

            if not gui or not gui.RefreshLayout then
                pendingRefresh[guiKey] = nil
                pendingRefreshReason[guiKey] = nil
            elseif visible and not building then
                pendingRefresh[guiKey] = nil
                pendingRefreshReason[guiKey] = nil
                if Profile and reason then
                    Profile:Start(guiKey .. ":RefreshLayout.reason." .. reason)
                end
                lastRefreshTime[guiKey] = GetTime()
                self._currentRefreshReason = reason
                gui:RefreshLayout()
                self._currentRefreshReason = nil
                if Profile and reason then
                    Profile:Stop(guiKey .. ":RefreshLayout.reason." .. reason)
                end
            else
                needsReschedule = true
            end
        end
    end

    if needsReschedule then
        for guiKey in pairs(pendingRefresh) do
            if pendingRefresh[guiKey] then
                refreshScheduled = true
                C_Timer.After(0, function()
                    self:FlushPendingLayoutRefreshes()
                end)
                break
            end
        end
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
function OneWoW_Bags:UpdateSlotsForItemIDs(itemIDs)
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
function OneWoW_Bags:RequestVisualRefresh(target)
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
function OneWoW_Bags:ScheduleTooltipCatchupRefresh()
    if self._tooltipCatchupPending then return end
    self._tooltipCatchupPending = true
    C_Timer.After(0.75, function()
        self._tooltipCatchupPending = false

        local Profile = OneWoW_Bags.Profile
        if not self._hasPendingTentatives then
            if Profile then
                Profile:Start("OneWoW_Bags:ScheduleTooltipCatchupRefresh.skipped")
                Profile:Stop("OneWoW_Bags:ScheduleTooltipCatchupRefresh.skipped")
            end
            return
        end

        self._hasPendingTentatives = false
        if Profile then
            Profile:Start("OneWoW_Bags:ScheduleTooltipCatchupRefresh.executed")
            Profile:Stop("OneWoW_Bags:ScheduleTooltipCatchupRefresh.executed")
        end

        local refreshBags = self.GUI and self.GUI:IsShown()
        local refreshBankRelated = self.bankOpen or self.guildBankOpen
        if refreshBags and refreshBankRelated then
            self:RequestVisualRefresh("all")
        elseif refreshBankRelated then
            self:RequestVisualRefresh("bank_related")
        elseif refreshBags then
            self:RequestVisualRefresh("bags")
        end
    end)
end

--- Fully reset window frames and reopen windows that were visible.
---@param target "bags"|"bank"|"guild"|"bank_related"|"all"|nil
function OneWoW_Bags:RequestWindowReset(target)
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

local function RefreshGUI(owner)
    local gui = owner.GUI
    if not gui then return end

    local wasShown = gui:IsShown()
    gui:FullReset()
    if wasShown then
        C_Timer.After(0.1, function()
            gui:Show()
        end)
    end
end

function OneWoW_Bags:ReinitForLanguage(langCode)
    OneWoW_GUI:SetSetting("language", langCode)
    ApplyLanguage()
    if self.GUI then
        self.GUI:FullReset()
        C_Timer.After(0.1, function()
            self.GUI:Show()
        end)
    end
end

function OneWoW_Bags:OnAddonLoaded(loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end

    self:InitializeDatabase()
    self:InitializeControllers()
    OneWoW_GUI:MigrateSettings(self.db.global)

    if self.Masque and self.Masque.OnLoad then
        self.Masque:OnLoad()
    end

    ApplyTheme()
    ApplyLanguage()

    OneWoW_Bags.Categories:SetCustomCategories(self.db.global.customCategoriesV2)
    OneWoW_Bags.Categories:SetRecentItemDuration(self.db.global.recentItemDuration)
    OneWoW_Bags.Categories:SetRecentItems(self.db.global.recentItems)

    self:RegisterSlashCommands()
    self:RegisterRuntimeEvents()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function(owner, _)
        ApplyTheme()
        RefreshGUI(owner)
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", self, function(owner, _)
        ApplyLanguage()
        RefreshGUI(owner)
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", self, function(owner, _)
        RefreshGUI(owner)
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function(owner, _)
        RefreshGUI(owner)
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnMoneyDisplayChanged", self, function()
        if OneWoW_Bags.BagsBar and OneWoW_Bags.BagsBar.UpdateGoldDisplay then
            OneWoW_Bags.BagsBar:UpdateGoldDisplay()
        end
        if OneWoW_Bags.BankBar and OneWoW_Bags.BankBar.UpdateGold then
            OneWoW_Bags.BankBar:UpdateGold()
        end
        if OneWoW_Bags.GuildBankBar and OneWoW_Bags.GuildBankBar.UpdateGold then
            OneWoW_Bags.GuildBankBar:UpdateGold()
        end
    end)

    local _ver = OneWoW_GUI:GetAddonVersion(ADDON_NAME)
    if OneWoW and OneWoW.RegisterLoadComponent then
        OneWoW:RegisterLoadComponent("Bags", _ver, "/1wb")
    end
end

function OneWoW_Bags:OnPlayerLogin()
    DetectOneWoW()

    if OneWoW and OneWoW.RegisterMinimap then
        OneWoW:RegisterMinimap("OneWoW_Bags", (OneWoW.L and OneWoW.L["CTX_OPEN_BAGS"]), nil, function()
            if self.GUI then self.GUI:Toggle() end
        end)
    end

    self.ItemPool:Preallocate(OneWoW_Bags.Constants.ITEM_POOL_PREALLOC_SIZE)
    self.BagSet:Build()
    self.BagsBar:UpdateIcons()

    self:HookBlizzardBags()
    self:HookPetCageTooltip()
end

function OneWoW_Bags:HookPetCageTooltip()
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

function OneWoW_Bags:OnBankOpened()
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

function OneWoW_Bags:OnBankClosed()
    if not self:IsBankUIEnabled() then
        self.bankOpen = false
        self.isWarbandOnlyBankAccess = false
        self:RestoreBankFrame()
        return
    end
    if not self.bankOpen then return end
    self.bankOpen = false
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

function OneWoW_Bags:SuppressGuildBankFrame()
    if not GuildBankFrame then return end
    if self._guildBankSuppressed then return end
    self._guildBankSuppressed = true

    self._gbOrigOnHide = GuildBankFrame:GetScript("OnHide")
    GuildBankFrame:SetScript("OnHide", nil)
    GuildBankFrame:ClearAllPoints()
    GuildBankFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 0, -10000)
    GuildBankFrame:SetAlpha(0)
end

function OneWoW_Bags:RestoreGuildBankFrame()
    if not self._guildBankSuppressed then return end
    if not GuildBankFrame then return end
    self._guildBankSuppressed = false
    if self._gbOrigOnHide then
        GuildBankFrame:SetScript("OnHide", self._gbOrigOnHide)
    end
    self._gbOrigOnHide = nil
    GuildBankFrame:SetAlpha(1)
end

function OneWoW_Bags:RefreshGuildBankContents()
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

function OneWoW_Bags:TrackGuildBankTransferTab(tabID)
    if not tabID then return end
    self._guildBankTransferTabs = self._guildBankTransferTabs or {}
    self._guildBankTransferTabs[tabID] = true
end

function OneWoW_Bags:TrackGuildBankTransferSource(tabID, slotID)
    if not tabID or not slotID then return end
    self._guildBankTransferSources = self._guildBankTransferSources or {}
    tinsert(self._guildBankTransferSources, {tab = tabID, slot = slotID})
end

function OneWoW_Bags:PurgeClearSource(tabID, slotID)
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

function OneWoW_Bags:ProcessPendingGuildBankTransferTabs()
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

function OneWoW_Bags:QueueGuildBankRefresh()
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

function OneWoW_Bags:OnGuildBankOpened()
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

function OneWoW_Bags:OnGuildBankClosed()
    if not self:IsBankUIEnabled() then
        self.guildBankOpen = false
        self:RestoreGuildBankFrame()
        return
    end
    if not self.guildBankOpen then return end
    self.guildBankOpen = false
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

function OneWoW_Bags:OnGuildBankSlotsChanged()
    self:QueueGuildBankRefresh()
end

function OneWoW_Bags:OnGuildBankItemLockChanged()
    if not self.GuildBankSet.isBuilt then return end
    local currentTab = GetCurrentGuildBankTab()
    if currentTab then
        self.GuildBankSet:RefreshLockVisuals({[currentTab] = true})
    end
end

function OneWoW_Bags:OnGuildBankTabsUpdated()
    if self.guildBankOpen then
        -- GuildBankSet:Build() already emits a coalesced RequestLayoutRefresh("guild").
        self.GuildBankSet:Build()
        self.GuildBankBar:BuildTabButtons()
    end
end

function OneWoW_Bags:OnGuildBankMoneyUpdated()
    if self.GuildBankBar then
        self.GuildBankBar:UpdateGold()
    end
end

function OneWoW_Bags:OnGuildBankWithdrawMoneyUpdated()
    if self.GuildBankBar then
        self.GuildBankBar:UpdateWithdrawButton()
    end
end

function OneWoW_Bags:OnPlayerMoney()
    if self.bankOpen and self.BankBar then
        self.BankBar:UpdateGold()
    end
end

function OneWoW_Bags:OnAccountMoney()
    if self.bankOpen and self.BankBar then
        self.BankBar:UpdateGold()
    end
end

function OneWoW_Bags:OnBankTabsChanged(bankType)
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

function OneWoW_Bags:SuppressBankFrame()
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

function OneWoW_Bags:RestoreBankFrame()
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

function OneWoW_Bags:ProcessBagUpdate(dirtyBags)
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

function OneWoW_Bags:OnItemLockChanged(bagID, slotID)
    if self.BagSet.isBuilt and self.BagSet.slots[bagID] and self.BagSet.slots[bagID][slotID] then
        self.BagSet.slots[bagID][slotID]:OWB_RefreshLock()
    end

    if self.bankOpen then
        if self.BankSet.isBuilt and self.BankSet.slots[bagID] and self.BankSet.slots[bagID][slotID] then
            self.BankSet.slots[bagID][slotID]:OWB_RefreshLock()
        end
    end
end

function OneWoW_Bags:RefreshCooldowns()
    if not self.BagSet.isBuilt then return end
    for _, bagSlots in pairs(self.BagSet.slots) do
        for _, button in pairs(bagSlots) do
            if button.owb_hasItem then
                button:OWB_RefreshCooldown()
            end
        end
    end
end

function OneWoW_Bags:OnCooldownUpdate()
    if self._cooldownRefreshPending then return end
    self._cooldownRefreshPending = true
    C_Timer.After(0.05, function()
        self._cooldownRefreshPending = false
        self:RefreshCooldowns()
    end)
end

function OneWoW_Bags:RegisterSlashCommands()
    SLASH_ONEWOW_BAGS1 = "/1wb"
    SLASH_ONEWOW_BAGS2 = "/onewowbags"
    SLASH_ONEWOW_BAGS3 = "/1wbags"

    SlashCmdList["ONEWOW_BAGS"] = function()
        self.GUI:Toggle()
    end

    SLASH_ONEWOW_BAGS_EXPORT1 = "/owbags-export"
    SlashCmdList["ONEWOW_BAGS_EXPORT"] = function()
        local Serializer = OneWoW_Bags.ImportExport and OneWoW_Bags.ImportExport.Serializer
        local LibCopyPaste = LibStub and LibStub("LibCopyPaste-1.0", true)
        if not Serializer or not LibCopyPaste then
            print("|cFFFF6060" .. L["ADDON_CHAT_PREFIX"] .. "|r " .. L["EXPORT_UNAVAILABLE_SERIALIZER"])
            return
        end
        local db = OneWoW_Bags.db
        if not db or not db.global then
            print("|cFFFF6060" .. L["ADDON_CHAT_PREFIX"] .. "|r " .. L["EXPORT_UNAVAILABLE_DB"])
            return
        end
        local title = L["EXPORT_DIALOG_TITLE"]
        local payload = Serializer:Encode(Serializer:BuildExport(db))
        LibCopyPaste:Copy(title, payload, { readOnly = true, frameStrata = "FULLSCREEN_DIALOG" })
    end
end

function OneWoW_Bags:HookBlizzardBags()
    local function IsMerchantVisible()
        return MerchantFrame and MerchantFrame:IsShown()
    end

    local function OpenOurBags(source)
        if source == "auto" and IsMerchantVisible() then
            return
        end
        OneWoW_Bags.GUI:Show()
    end

    local function ToggleOurBags()
        OneWoW_Bags.GUI:Toggle()
    end

    local bindingFrame = CreateFrame("Button", "OneWoW_BagsBindingFrame")
    bindingFrame:RegisterForClicks("AnyDown")
    bindingFrame:SetScript("OnClick", function()
        ToggleOurBags()
    end)
    self.bindingFrame = bindingFrame

    local function SetupBindingOverrides()
        if InCombatLockdown() then
            bindingFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
            return
        end
        bindingFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
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

    bindingFrame:SetScript("OnEvent", function(_, event)
        if event == "PLAYER_REGEN_ENABLED" or event == "UPDATE_BINDINGS" then
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

end

function OneWoW_Bags:OnMerchantShow()
    self.vendorInteractionActive = true
    self.vendorCloseGuardActive = false
    self.vendorAutoOpenedBags = false
    if not self.db.global.autoOpen then
        return
    end
    self.vendorAutoOpenedBags = true
    self.GUI:Show()
end

function OneWoW_Bags:OnMerchantClosed()
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

function OneWoW_Bags:GetMoneyDialog()
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

    local dialogFrame = assert(result.frame, "OneWoW_Bags:CreateDialog missing frame")
    local contentFrame = assert(result.contentFrame, "OneWoW_Bags:CreateDialog missing contentFrame")
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
function OneWoW_Bags:ShowMoneyDialog(config)
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

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

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
    MERCHANT_SHOW = function(...)
        Events:OnMerchantShow(...)
    end,
    MERCHANT_CLOSED = function(...)
        Events:OnMerchantClosed(...)
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
    PLAYER_EQUIPMENT_CHANGED = function(...)
        Events:OnPredicateInvalidation(...)
    end,
    GET_ITEM_INFO_RECEIVED = function(itemID)
        Events:OnItemInfoReceived(itemID)
    end,
    PLAYER_ENTERING_WORLD = function(isLogin, isReload)
        Events:OnPlayerEnteringWorld(isLogin, isReload)
    end,
    SKILL_LINES_CHANGED = function(...)
        PE:InvalidateKnownProfessions()
        Events:OnPredicateInvalidation(...)
    end,
}

function OneWoW_Bags:RegisterRuntimeEvents()
    if self.runtimeEventsRegistered then return end

    self.runtimeEventsRegistered = true
    for _, eventName in ipairs(Events.RuntimeEvents) do
        eventFrame:RegisterEvent(eventName)
    end
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        OneWoW_Bags:OnAddonLoaded(loadedAddon)
    elseif event == "PLAYER_LOGIN" then
        OneWoW_Bags:OnPlayerLogin()
    else
        local handler = runtimeEventHandlers[event]
        if handler then
            handler(...)
        end
    end
end)
