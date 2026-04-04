local ADDON_NAME, OneWoW_Bags = ...

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local db = OneWoW_Bags.db
local L = OneWoW_Bags.L
local PE = OneWoW_Bags.PredicateEngine
local Categories = OneWoW_Bags.Categories
local ItemPool = OneWoW_Bags.ItemPool
local BagSet = OneWoW_Bags.BagSet
local BankSet = OneWoW_Bags.BankSet
local GuildBankSet = OneWoW_Bags.GuildBankSet
local BagsBar = OneWoW_Bags.BagsBar
local BankGUI = OneWoW_Bags.BankGUI
local GuildBankGUI = OneWoW_Bags.GuildBankGUI
local GuildBankBar = OneWoW_Bags.GuildBankBar
local BagTypes = OneWoW_Bags.BagTypes

local pairs, print, tonumber = pairs, print, tonumber
local hooksecurefunc = hooksecurefunc

local InCombatLockdown = InCombatLockdown
local C_Timer = C_Timer
local C_Bank = C_Bank
local C_PetJournal = C_PetJournal

_G.OneWoW_Bags = OneWoW_Bags

OneWoW_Bags.oneWoWHubActive = false
OneWoW_Bags.bankOpen = false
OneWoW_Bags.guildBankOpen = false

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

    OneWoW_GUI:MigrateSettings(self.db.global)

    ApplyTheme()
    ApplyLanguage()

    Categories:SetCustomCategories(db.global.customCategoriesV2)
    Categories:SetRecentItemDuration(db.global.recentItemDuration)

    self:RegisterSlashCommands()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function(owner, newTheme)
        ApplyTheme()
        local wasShown = owner.GUI and owner.GUI:IsShown()
        if owner.GUI then
            owner.GUI:FullReset()
            if wasShown then
                C_Timer.After(0.1, function() owner.GUI:Show() end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", self, function(owner, newLang)
        ApplyLanguage()
        local wasShown = owner.GUI and owner.GUI:IsShown()
        if owner.GUI then
            owner.GUI:FullReset()
            if wasShown then
                C_Timer.After(0.1, function() owner.GUI:Show() end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", self, function(owner, newFont)
        local wasShown = owner.GUI and owner.GUI:IsShown()
        if owner.GUI then
            owner.GUI:FullReset()
            if wasShown then
                C_Timer.After(0.1, function() owner.GUI:Show() end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function(owner, newIconTheme)
        if owner.Minimap then
            owner.Minimap:UpdateIcon()
        end
        local wasShown = owner.GUI and owner.GUI:IsShown()
        if owner.GUI then
            owner.GUI:FullReset()
            if wasShown then
                C_Timer.After(0.1, function() owner.GUI:Show() end)
            end
        end
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
        print("|cFF00FF00OneWoW|r: |cFFFFFFFFBags|r |cFF888888 v." .. _ver .. " |r |cFF00FF00Loaded|r - /1wb")
    end
end

function OneWoW_Bags:OnPlayerLogin()
    DetectOneWoW()

    if not self.oneWoWHubActive then
        self.Minimap = OneWoW_GUI:CreateMinimapLauncher("OneWoW_Bags", {
            label = "OneWoW Bags",
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
                GameTooltip:SetText("|cFFFFD100OneWoW|r - |cFF00FF00" .. L["ADDON_TITLE"] .. "|r")
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

    ItemPool:Preallocate(220)
    BagSet:Build()
    BagsBar:UpdateIcons()

    self:HookBlizzardBags()
    self:HookPetCageTooltip()
end

function OneWoW_Bags:HookPetCageTooltip()
    local CAGE_ID = PE.BATTLE_PET_CAGE_ID

    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if not data or not data.id or data.id ~= CAGE_ID then return end
        local _, itemLink = tooltip:GetItem()
        if not itemLink then return end
        local petID = itemLink:match("battlepet:(%d+)")
        if not petID then return end
        local speciesID = tonumber(petID)
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
    self.bankOpen = true
    self:SuppressBankFrame()

    local activeBankType = db.global.bankShowWarband and Enum.BankType.Account or Enum.BankType.Character
    if BankFrame and BankFrame.BankPanel then
        BankFrame.BankPanel:SetBankType(activeBankType)
        BankFrame.BankPanel:Show()
    end

    C_Bank.FetchPurchasedBankTabData(Enum.BankType.Character)
    C_Bank.FetchNumPurchasedBankTabs(Enum.BankType.Character)
    C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account)
    C_Bank.FetchNumPurchasedBankTabs(Enum.BankType.Account)

    BankGUI:Show()

    if db.global.autoOpenWithBank then
        self.GUI:Show()
    end
end

function OneWoW_Bags:OnBankClosed()
    if not self.bankOpen then return end
    self.bankOpen = false
    if BankFrame and BankFrame.BankPanel then
        BankFrame.BankPanel:Hide()
    end

    BankGUI:Hide()
    BankSet:ReleaseAll()
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

function OneWoW_Bags:OnGuildBankOpened()
    self.guildBankOpen = true

    self:SuppressGuildBankFrame()
    GuildBankGUI:Show()

    if db.global.autoOpenWithBank then
        self.GUI:Show()
    end
end

function OneWoW_Bags:OnGuildBankClosed()
    if not self.guildBankOpen then return end
    self.guildBankOpen = false
    GuildBankGUI:Hide()
    GuildBankSet:ReleaseAll()
    GuildBankSet:ClearCache()
    self:RestoreGuildBankFrame()
end

function OneWoW_Bags:OnGuildBankSlotsChanged()
    if not GuildBankSet.isBuilt then return end
    if self._guildBankUpdatePending then return end
    self._guildBankUpdatePending = true

    C_Timer.After(0, function()
        self._guildBankUpdatePending = false
        if not GuildBankSet.isBuilt then return end
        for tabID = 1, GuildBankSet.numTabs do
            if GuildBankSet.slots[tabID] then
                GuildBankSet:CacheTab(tabID)
            end
        end
        GuildBankSet:ApplyCacheToButtons()
            GuildBankGUI:RefreshLayout()
    end)
end

function OneWoW_Bags:OnGuildBankTabsUpdated()
    if self.guildBankOpen then
        GuildBankSet:Build()
        GuildBankBar:BuildTabButtons()
        GuildBankGUI:RefreshLayout()
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
    if BagSet.isBuilt then
        BagSet:UpdateDirtyBags(dirtyBags)
        self.GUI:RefreshLayout()
    end

    if self.bankOpen then
        if BankSet.isBuilt then
            BankSet:UpdateDirtyBags(dirtyBags)
            BankGUI:RefreshLayout()
        end
    end
end

function OneWoW_Bags:OnItemLockChanged(bagID, slotID)
    if BagSet.isBuilt and BagSet.slots[bagID] and BagSet.slots[bagID][slotID] then
        BagSet.slots[bagID][slotID]:OWB_RefreshLock()
    end

    if self.bankOpen then
        if BankSet.isBuilt and BankSet.slots[bagID] and BankSet.slots[bagID][slotID] then
            BankSet.slots[bagID][slotID]:OWB_RefreshLock()
        end
    end
end

function OneWoW_Bags:OnCooldownUpdate()
    if not BagSet.isBuilt then return end
    for bagID, bagSlots in pairs(BagSet.slots) do
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
    local function OpenOurBags()
        OneWoW_Bags.GUI:Show()
    end

    local function CloseOurBags()
        OneWoW_Bags.GUI:Hide()
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

    hooksecurefunc("OpenBackpack", OpenOurBags)
    hooksecurefunc("CloseBackpack", CloseOurBags)
    hooksecurefunc("ToggleAllBags", ToggleOurBags)
    hooksecurefunc("OpenAllBags", function() OpenOurBags() end)
    hooksecurefunc("CloseAllBags", function() CloseOurBags() end)

    hooksecurefunc("OpenBag", function(bagID)
        if BagTypes:IsPlayerBag(bagID) then
            OpenOurBags()
        end
    end)

    hooksecurefunc("CloseBag", function(bagID)
        if BagTypes:IsPlayerBag(bagID) then
            CloseOurBags()
        end
    end)

    if EventRegistry then
        EventRegistry:RegisterCallback("ContainerFrame.OpenAllBags", OpenOurBags, self)
        EventRegistry:RegisterCallback("ContainerFrame.CloseAllBags", CloseOurBags, self)
    end

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

    moneyDialog = result.frame
    moneyDialog:SetFrameLevel(500)
    moneyDialog._titleBar = result.titleBar
    moneyDialog._contentFrame = result.contentFrame

    local moneyBox = CreateFrame("Frame", "OneWoW_BagsMoneyInput", result.contentFrame, "MoneyInputFrameTemplate")
    moneyBox:SetPoint("TOP", result.contentFrame, "TOP", 0, -10)
    moneyDialog.moneyBox = moneyBox

    local btnRow = CreateFrame("Frame", nil, result.contentFrame)
    btnRow:SetHeight(26)
    btnRow:SetPoint("BOTTOM", result.contentFrame, "BOTTOM", 0, 10)

    local depositBtn = OneWoW_GUI:CreateFitTextButton(btnRow, { text = self.L["BANK_DEPOSIT_GOLD"] or "Deposit", height = 26 })
    moneyDialog.depositBtn = depositBtn

    local withdrawBtn = OneWoW_GUI:CreateFitTextButton(btnRow, { text = self.L["BANK_WITHDRAW_GOLD"] or "Withdraw", height = 26 })
    moneyDialog.withdrawBtn = withdrawBtn

    local function LayoutButtons()
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

    moneyDialog._layoutButtons = LayoutButtons
    return moneyDialog
end

function OneWoW_Bags:ShowMoneyDialog(config)
    local dialog = self:GetMoneyDialog()
    dialog:Hide()
    MoneyInputFrame_ResetMoney(dialog.moneyBox)

    if dialog._titleBar and dialog._titleBar._titleText then
        dialog._titleBar._titleText:SetText(config.title or "")
    end

    if config.anchorFrame then
        dialog:ClearAllPoints()
        dialog:SetPoint("BOTTOM", config.anchorFrame, "TOP", 0, 5)
    else
        dialog:ClearAllPoints()
        dialog:SetPoint("CENTER")
    end

    dialog.depositBtn:SetShown(config.onDeposit ~= nil)
    dialog.withdrawBtn:SetShown(config.onWithdraw ~= nil)
    if dialog._layoutButtons then dialog._layoutButtons() end

    local function doAction(callback)
        local copper = MoneyInputFrame_GetCopper(dialog.moneyBox)
        if copper > 0 and callback then
            callback(copper)
        end
        dialog:Hide()
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

    dialog:Show()
    dialog.moneyBox.gold:SetFocus()
end

_G["1WoW_Bags_OnAddonCompartmentClick"] = function(addonName, buttonName)
    if OneWoW_Bags.GUI then
        OneWoW_Bags.GUI:Toggle()
    end
end

_G["1WoW_Bags_OnAddonCompartmentEnter"] = function(addonName, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("|cFFFFD100OneWoW|r - |cFF00FF00Bags|r", 1, 1, 1)
    GameTooltip:AddLine(OneWoW_Bags.L["COMPARTMENT_TOGGLE"], 0.7, 0.7, 0.7)
    GameTooltip:Show()
end

_G["1WoW_Bags_OnAddonCompartmentLeave"] = function(addonName, button)
    GameTooltip:Hide()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        OneWoW_Bags:OnAddonLoaded(loadedAddon)
    end
end)
