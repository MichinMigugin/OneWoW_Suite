local ADDON_NAME, OneWoW_Bags = ...

_G.OneWoW_Bags = OneWoW_Bags

local L = OneWoW_Bags.L
local OneWoW_GUI = OneWoW_Bags.GUILib

OneWoW_Bags.oneWoWHubActive = false

local function DetectOneWoW()
    if _G.OneWoW then
        OneWoW_Bags.oneWoWHubActive = true
    end
end

local function ApplyTheme()
    if OneWoW_GUI then
        OneWoW_GUI:ApplyTheme(OneWoW_Bags)
    end
end

local function ApplyLanguage()
    local lang
    if OneWoW_GUI then
        lang = OneWoW_GUI:GetSetting("language") or "enUS"
    else
        local hub = _G.OneWoW
        if hub and hub.db and hub.db.global then
            lang = hub.db.global.language or "enUS"
        else
            lang = OneWoW_Bags.db and OneWoW_Bags.db.global.language or "enUS"
        end
    end
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
    if OneWoW_GUI then
        OneWoW_GUI:SetSetting("language", langCode)
    else
        self.db.global.language = langCode
    end
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

    if OneWoW_GUI then
        OneWoW_GUI:MigrateSettings(self.db.global)
    end

    ApplyTheme()
    ApplyLanguage()

    if self.Categories then
        self.Categories:SetCustomCategories(self.db.global.customCategoriesV2)
    end

    self:RegisterSlashCommands()

    if OneWoW_GUI then
        OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function(owner, newTheme)
            ApplyTheme()
            local wasShown = owner.GUI and owner.GUI:IsShown()
            if owner.GUI then
                owner.GUI:FullReset()
                if wasShown then
                    C_Timer.After(0.1, function()
                        owner.GUI:Show()
                    end)
                end
            end
        end)

        OneWoW_GUI:RegisterSettingsCallback("OnLanguageChanged", self, function(owner, newLang)
            ApplyLanguage()
            local wasShown = owner.GUI and owner.GUI:IsShown()
            if owner.GUI then
                owner.GUI:FullReset()
                if wasShown then
                    C_Timer.After(0.1, function()
                        owner.GUI:Show()
                    end)
                end
            end
        end)

        OneWoW_GUI:RegisterSettingsCallback("OnFontChanged", self, function(owner, newFont)
            local wasShown = owner.GUI and owner.GUI:IsShown()
            if owner.GUI then
                owner.GUI:FullReset()
                if wasShown then
                    C_Timer.After(0.1, function()
                        owner.GUI:Show()
                    end)
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
                    C_Timer.After(0.1, function()
                        owner.GUI:Show()
                    end)
                end
            end
        end)

        OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", self, function(owner, isHidden)
            if owner.Minimap then
                owner.Minimap:SetShown(not isHidden)
            end
        end)
    end

    local _ver = C_AddOns.GetAddOnMetadata(ADDON_NAME, "Version") or self.Constants.VERSION
    if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
        _G.OneWoW:RegisterLoadComponent("Bags", _ver, "/1wb")
    else
        print("|cFF00FF00OneWoW|r: |cFFFFFFFFBags|r |cFF888888 v." .. _ver .. " |r |cFF00FF00Loaded|r - /1wb")
    end
end

function OneWoW_Bags:OnPlayerLogin()
    DetectOneWoW()

    if not self.oneWoWHubActive then
        if self.Minimap then
            self.Minimap:Initialize()
        end
    end

    local Pool = self.ItemPool
    if Pool then
        Pool:Preallocate(220)
    end

    local BagSet = self.BagSet
    if BagSet then
        BagSet:Build()
    end

    if self.BagsBar then
        self.BagsBar:UpdateIcons()
    end

    self:HookBlizzardBags()
end

function OneWoW_Bags:ProcessBagUpdate(dirtyBags)
    local BagSet = self.BagSet
    if not BagSet or not BagSet.isBuilt then return end

    BagSet:UpdateDirtyBags(dirtyBags)

    if self.GUI and self.GUI.RefreshLayout then
        self.GUI:RefreshLayout()
    end
end

function OneWoW_Bags:OnItemLockChanged(bagID, slotID)
    local BagSet = self.BagSet
    if not BagSet or not BagSet.isBuilt then return end
    if BagSet.slots[bagID] and BagSet.slots[bagID][slotID] then
        BagSet.slots[bagID][slotID]:OWB_RefreshLock()
    end
end

function OneWoW_Bags:OnCooldownUpdate()
    local BagSet = self.BagSet
    if not BagSet or not BagSet.isBuilt then return end
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
        if self.GUI then
            self.GUI:Toggle()
        end
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
        if OneWoW_Bags.BagTypes and OneWoW_Bags.BagTypes:IsPlayerBag(bagID) then
            OpenOurBags()
        end
    end)

    hooksecurefunc("CloseBag", function(bagID)
        if OneWoW_Bags.BagTypes and OneWoW_Bags.BagTypes:IsPlayerBag(bagID) then
            CloseOurBags()
        end
    end)

    if EventRegistry then
        EventRegistry:RegisterCallback("ContainerFrame.OpenAllBags", OpenOurBags, self)
        EventRegistry:RegisterCallback("ContainerFrame.CloseAllBags", CloseOurBags, self)
    end
end

_G["1WoW_Bags_OnAddonCompartmentClick"] = function(addonName, buttonName)
    if OneWoW_Bags.GUI then
        OneWoW_Bags.GUI:Toggle()
    end
end

_G["1WoW_Bags_OnAddonCompartmentEnter"] = function(addonName, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("|cFFFFD100OneWoW|r - |cFF00FF00Bags|r", 1, 1, 1)
    GameTooltip:AddLine("Click to toggle bags", 0.7, 0.7, 0.7)
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
