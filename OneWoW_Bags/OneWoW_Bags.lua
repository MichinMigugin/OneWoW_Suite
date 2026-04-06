local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local L = OneWoW_Bags.L
local Events = OneWoW_Bags.Events

local ipairs, pairs = ipairs, pairs
local hooksecurefunc = hooksecurefunc

local C_Timer = C_Timer
local C_Bank = C_Bank

_G.OneWoW_Bags = OneWoW_Bags

OneWoW_Bags.oneWoWHubActive = false
OneWoW_Bags.bankOpen = false
OneWoW_Bags.guildBankOpen = false
OneWoW_Bags.inventoryPresentationState = {
    altShowActive = false,
}

local function DetectOneWoW()
    if _G.OneWoW then
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
    local db = self:GetDB()
    return db.global.itemSort or "default"
end

function OneWoW_Bags:ShouldShowItemQuality(isBank, quality)
    if self:IsAltShowActive() then return true end
    if not quality or quality < 1 then return false end

    local db = self:GetDB()

    if isBank then
        return db.global.bankRarityColor == true
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
    return db and db.global.enableBankUI ~= false
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

function OneWoW_Bags:InvalidateCategorization(scope)
    local db = self:GetDB()

    self.Categories:SetCustomCategories(db.global.customCategoriesV2)
    self.Categories:SetRecentItemDuration(db.global.recentItemDuration)
    self.Categories:InvalidateCache()

    if scope == "props" then
        self.PredicateEngine:InvalidatePropsCache()
    else
        self.PredicateEngine:InvalidateCache()
    end
end

function OneWoW_Bags:RequestLayoutRefresh(target)
    ForEachTarget(self, target, GUI_TARGET_KEYS, function(gui)
        if gui.RefreshLayout then
            gui:RefreshLayout()
        end
    end)
end

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

local function GetAddonDisplayName()
    return "OneWoW " .. L["ADDON_TITLE"]
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

    ApplyTheme()
    ApplyLanguage()

    OneWoW_Bags.Categories:SetCustomCategories(self.db.global.customCategoriesV2)
    OneWoW_Bags.Categories:SetRecentItemDuration(self.db.global.recentItemDuration)

    self:RegisterSlashCommands()
    self:RegisterRuntimeEvents()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function(owner, newTheme)
        ApplyTheme()
        RefreshGUI(owner)
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", self, function(owner, newLang)
        ApplyLanguage()
        RefreshGUI(owner)
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", self, function(owner, newFont)
        RefreshGUI(owner)
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function(owner, newIconTheme)
        if owner.Minimap then
            owner.Minimap:UpdateIcon()
        end
        RefreshGUI(owner)
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", self, function(owner, isHidden)
        if owner.Minimap then
            owner.Minimap:SetShown(not isHidden)
        end
    end)

    local _ver = OneWoW_GUI:GetAddonVersion(ADDON_NAME)
    if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
        _G.OneWoW:RegisterLoadComponent("Bags", _ver, "/1wb")
    else
        _G.print("|cFF00FF00OneWoW|r: |cFFFFFFFF" .. L["ADDON_TITLE"] .. "|r |cFF888888 v." .. _ver .. " |r |cFF00FF00Loaded|r - /1wb")
    end
end

function OneWoW_Bags:OnPlayerLogin()
    DetectOneWoW()

    if not self.oneWoWHubActive then
        self.Minimap = OneWoW_GUI:CreateMinimapLauncher("OneWoW_Bags", {
            label = GetAddonDisplayName(),
            onClick = function()
                if self.GUI then self.GUI:Toggle() end
            end,
            onRightClick = function()
                if self.Settings then
                    if self.GUI then self.GUI:Show() end
                    self.Settings:Toggle()
                end
            end,
            onTooltip = function(frame)
                GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
                GameTooltip:SetText("|cFFFFD100OneWoW|r - |cFF00FF00" .. L["ADDON_TITLE"] .. "|r", 1, 1, 1)
                GameTooltip:AddLine(L["MINIMAP_SECTION_DESC"], 0.7, 0.7, 0.7)
                GameTooltip:Show()
            end,
        })
    end

    if _G.OneWoW and _G.OneWoW.RegisterMinimap then
        _G.OneWoW:RegisterMinimap("OneWoW_Bags", (_G.OneWoW.L and _G.OneWoW.L["CTX_OPEN_BAGS"]), nil, function()
            if self.GUI then self.GUI:Toggle() end
        end)
    end

    self.ItemPool:Preallocate(220)
    self.BagSet:Build()
    self.BagsBar:UpdateIcons()

    self:HookBlizzardBags()
    self:HookPetCageTooltip()
end

function OneWoW_Bags:HookPetCageTooltip()
    local predicateEngine = self.PredicateEngine
    if not predicateEngine or not predicateEngine.BATTLE_PET_CAGE_ID then return end
    local CAGE_ID = predicateEngine.BATTLE_PET_CAGE_ID

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not data or not data.id or data.id ~= CAGE_ID then return end
        local _, itemLink = tooltip:GetItem()
        if not itemLink then return end
        local petID = itemLink:match("battlepet:(%d+)")
        if not petID then return end
        local speciesID = _G.tonumber(petID)
        if not speciesID then return end
        local petName, _, petType = C_PetJournal.GetPetInfoBySpeciesID(speciesID)
        if petName then
            tooltip:AddLine(" ")
            tooltip:AddLine(petName, 1, 0.82, 0)
            if petType then
                local petTypeName = _G["BATTLE_PET_NAME_" .. petType] or ("Type " .. petType)
                tooltip:AddLine(petTypeName, 0.7, 0.7, 0.7)
            end
            local numCollected, limit = C_PetJournal.GetNumCollectedInfo(speciesID)
            if numCollected then
                if numCollected > 0 then
                    tooltip:AddLine(COLLECTED .. ": " .. numCollected .. "/" .. (limit or "?"), 0.2, 1, 0.2)
                else
                    tooltip:AddLine(COLLECTED .. ": 0/" .. (limit or "?"), 1, 0.2, 0.2)
                end
            end
            tooltip:Show()
        end
    end)
end

function OneWoW_Bags:OnBankOpened()
    self.bankOpen = self:IsBankUIEnabled()
    if not self:IsBankUIEnabled() then
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
end

function OneWoW_Bags:OnBankClosed()
    if not self:IsBankUIEnabled() then
        self.bankOpen = false
        self:RestoreBankFrame()
        return
    end
    if not self.bankOpen then return end
    self.bankOpen = false
    if BankFrame and BankFrame.BankPanel then
        BankFrame.BankPanel:Hide()
    end

    self.BankGUI:Hide()
    self.BankSet:ReleaseAll()
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

    if self.GuildBankGUI and self.GuildBankGUI:IsShown() then
        self.GuildBankGUI:RefreshLayout()
    end
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

    if not self._guildBankRefreshDriver then
        self._guildBankRefreshDriver = CreateFrame("Frame")
    end

    self._guildBankRefreshDriver:SetScript("OnUpdate", function(frame)
        frame:SetScript("OnUpdate", nil)
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
        self.GuildBankSet:Build()
        self.GuildBankBar:BuildTabButtons()
        if self.GuildBankGUI and self.GuildBankGUI:IsShown() then
            self.GuildBankGUI:RefreshLayout()
        end
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
    if self.BagSet.isBuilt then
        self.BagSet:UpdateDirtyBags(dirtyBags)
        self.GUI:RefreshLayout()
    end

    if self.bankOpen then
        if self.BankSet.isBuilt then
            self.BankSet:UpdateDirtyBags(dirtyBags)
            self.BankGUI:RefreshLayout()
        end
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

function OneWoW_Bags:OnCooldownUpdate()
    if not self.BagSet.isBuilt then return end
    for bagID, bagSlots in pairs(self.BagSet.slots) do
        for slotID, button in pairs(bagSlots) do
            if button.owb_hasItem then
                button:OWB_RefreshCooldown()
            end
        end
    end
end

function OneWoW_Bags:RegisterSlashCommands()
    SLASH_ONEWOW_BAGS1 = "/1wb"
    SLASH_ONEWOW_BAGS2 = "/onewowbags"
    SLASH_ONEWOW_BAGS3 = "/1wbags"

    SlashCmdList["ONEWOW_BAGS"] = function(msg)
        self.GUI:Toggle()
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

    local function CloseOurBags(source)
        if source == "auto" then
            if IsMerchantVisible() then
                return
            end
            if OneWoW_Bags.vendorInteractionActive then
                return
            end
            if OneWoW_Bags.vendorCloseGuardActive then
                return
            end
        end
        OneWoW_Bags.GUI:Hide()
    end

    local function ToggleOurBags(source)
        OneWoW_Bags.GUI:Toggle()
    end

    local bindingFrame = CreateFrame("Button", "OneWoW_BagsBindingFrame")
    bindingFrame:RegisterForClicks("AnyDown")
    bindingFrame:SetScript("OnClick", function()
        ToggleOurBags("explicit")
    end)
    self.bindingFrame = bindingFrame

    local function SetupBindingOverrides()
        if _G.InCombatLockdown() then
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

    bindingFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" or event == "UPDATE_BINDINGS" then
            SetupBindingOverrides()
        end
    end)
    bindingFrame:RegisterEvent("UPDATE_BINDINGS")
    SetupBindingOverrides()

    for i = 1, 13 do
        local frame = _G["ContainerFrame" .. i]
        if frame then
            frame:HookScript("OnShow", function(self) self:Hide() end)
        end
    end

    if ContainerFrameCombinedBags then
        ContainerFrameCombinedBags:HookScript("OnShow", function(self) self:Hide() end)
    end

    hooksecurefunc("OpenBackpack", function() OpenOurBags("auto") end)
    hooksecurefunc("CloseBackpack", function() CloseOurBags("auto") end)
    hooksecurefunc("ToggleAllBags", function() ToggleOurBags("auto") end)
    hooksecurefunc("OpenAllBags", function() OpenOurBags("auto") end)
    hooksecurefunc("CloseAllBags", function() CloseOurBags("auto") end)

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
    hooksecurefunc("SplitGuildBankItem", function(tabID, slotID)
        self:TrackGuildBankTransferTab(tabID)
    end)
    if C_Container and C_Container.PickupContainerItem then
        hooksecurefunc(C_Container, "PickupContainerItem", function()
            if self.guildBankOpen then
                self._guildBankSeenBagPickup = true
            end
        end)
    end

    hooksecurefunc("OpenBag", function(bagID)
        if self.BagTypes:IsPlayerBag(bagID) then
            OpenOurBags("auto")
        end
    end)

    hooksecurefunc("CloseBag", function(bagID)
        if self.BagTypes:IsPlayerBag(bagID) then
            CloseOurBags("auto")
        end
    end)

    if EventRegistry then
        EventRegistry:RegisterCallback("ContainerFrame.OpenAllBags", function()
            OpenOurBags("auto")
        end, self)
        EventRegistry:RegisterCallback("ContainerFrame.CloseAllBags", function()
            CloseOurBags("auto")
        end, self)
    end

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

_G["1WoW_Bags_OnAddonCompartmentClick"] = function(addonName, buttonName)
    if OneWoW_Bags.GUI then
        OneWoW_Bags.GUI:Toggle()
    end
end

_G["1WoW_Bags_OnAddonCompartmentEnter"] = function(addonName, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("|cFFFFD100OneWoW|r - |cFF00FF00" .. L["ADDON_TITLE"] .. "|r", 1, 1, 1)
    GameTooltip:AddLine(L["COMPARTMENT_TOGGLE"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

_G["1WoW_Bags_OnAddonCompartmentLeave"] = function(addonName, button)
    GameTooltip:Hide()
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
    GET_ITEM_INFO_RECEIVED = function(itemID, ...)
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

eventFrame:SetScript("OnEvent", function(self, event, ...)
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
