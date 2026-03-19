local ADDON_NAME, OneWoW_DirectDeposit = ...

_G.OneWoW_DirectDeposit = OneWoW_DirectDeposit

local L = OneWoW_DirectDeposit.L

OneWoW_DirectDeposit.wownotesDetected = false
OneWoW_DirectDeposit.oneWoWHubActive = false

local OneWoW_GUI = LibStub("OneWoW_GUI-1.0", true)
if not OneWoW_GUI then return end

local function DetectOneWoW()
    if _G.OneWoW then
        OneWoW_DirectDeposit.oneWoWHubActive = true
    end
end

local function ApplyTheme()
    OneWoW_GUI:ApplyTheme(OneWoW_DirectDeposit)
end

local function ApplyLanguage()
    local lang
    local hub = _G.OneWoW
    if hub and hub.db and hub.db.global then
        lang = hub.db.global.language or "enUS"
    else
        lang = OneWoW_DirectDeposit.db and OneWoW_DirectDeposit.db.global.language or "enUS"
    end
    if lang == "esMX" then lang = "esES" end
    local localeData = OneWoW_DirectDeposit.Locales[lang] or OneWoW_DirectDeposit.Locales["enUS"]
    local fallback = OneWoW_DirectDeposit.Locales["enUS"]
    for k, v in pairs(fallback) do
        L[k] = localeData[k] or v
    end
end


OneWoW_DirectDeposit.ApplyTheme = ApplyTheme
OneWoW_DirectDeposit.ApplyLanguage = ApplyLanguage

function OneWoW_DirectDeposit:ReinitForLanguage(langCode)
    self.db.global.language = langCode
    ApplyLanguage()
    if self.GUI then
        self.GUI:FullReset()
        C_Timer.After(0.1, function()
            self.GUI:Show()
        end)
    end
end

function OneWoW_DirectDeposit:ImportFromWoWNotes()
    if not _G.WoWNotes then
        return false, L["IMPORT_NOT_INSTALLED"]
    end

    local wn_db = _G.WoWNotes.db
    if not wn_db or not wn_db.global or not wn_db.global.directDeposit then
        return false, L["IMPORT_NO_DATA"]
    end

    local wn_global = wn_db.global.directDeposit
    local ow_global = self.db.global.directDeposit

    local importCount = 0
    local newItemList = {}

    print("|cFFFFD100DirectDeposit:|r Starting import from WoWNotes")

    if wn_global.itemList then
        print("|cFFFFD100DirectDeposit:|r WoWNotes itemList found, processing...")
        for itemIDStr, itemData in pairs(wn_global.itemList) do
            if itemData and itemData.itemID and itemData.itemID > 0 then
                local itemIDKey = tostring(itemData.itemID)
                newItemList[itemIDKey] = {
                    itemID = itemData.itemID,
                    bankType = itemData.bankType,
                    itemName = itemData.itemName,
                    bindingInfo = itemData.bindingInfo,
                    addedTime = itemData.addedTime
                }
                importCount = importCount + 1
                print("|cFFFFD100DirectDeposit:|r Imported item: " .. itemIDKey .. " (" .. (itemData.itemName or "Unknown") .. ")")
            elseif itemData and not itemData.itemID then
                print("|cFFFF0000DirectDeposit:|r Skipping entry with missing itemID")
            end
        end
    end

    print("|cFFFFD100DirectDeposit:|r Import complete. Clearing old itemList and setting new one...")
    ow_global.itemList = nil
    ow_global.itemList = newItemList

    print("|cFFFFD100DirectDeposit:|r Final itemList keys:")
    local finalKeys = {}
    for key, _ in pairs(ow_global.itemList) do
        table.insert(finalKeys, tostring(key))
    end
    print("|cFFFFD100DirectDeposit:|r " .. table.concat(finalKeys, ", "))

    if wn_global.itemDepositEnabled then
        ow_global.itemDepositEnabled = true
    end

    return true, importCount
end

function OneWoW_DirectDeposit:ValidateAndCleanItemList()
    local itemList = self.db.global.directDeposit.itemList
    if not itemList then return true end

    print("|cFFFFD100DirectDeposit:|r Validating itemList structure...")
    local cleanedList = {}
    local removedCount = 0

    for key, itemData in pairs(itemList) do
        local isStringKey = type(key) == "string"
        local itemIDNum = tonumber(key)

        if itemData and itemIDNum and itemIDNum > 0 then
            local cleanKey = tostring(itemIDNum)
            cleanedList[cleanKey] = itemData
            if not isStringKey then
                removedCount = removedCount + 1
                print("|cFFFF8800DirectDeposit:|r Converted numeric key " .. key .. " to string key")
            end
        else
            removedCount = removedCount + 1
            print("|cFFFF0000DirectDeposit:|r Removed invalid entry with key: " .. tostring(key))
        end
    end

    if removedCount > 0 then
        print("|cFFFF8800DirectDeposit:|r Cleaned " .. removedCount .. " invalid entries from itemList")
        self.db.global.directDeposit.itemList = cleanedList
    end

    return true
end

local function CheckForWoWNotes()
    if _G.WoWNotes then
        OneWoW_DirectDeposit.wownotesDetected = true
        return true
    end
    return false
end

function OneWoW_DirectDeposit:OnAddonLoaded(loadedAddon)
    if loadedAddon ~= ADDON_NAME then return end

    CheckForWoWNotes()

    self:InitializeDatabase()

    local g = self.db and self.db.global or {}
    OneWoW_GUI:MigrateSettings({
        theme = g.theme,
        language = g.language,
        minimap = g.minimap,
    })

    ApplyTheme()
    ApplyLanguage()
    self:InitializeModules()
    self:RegisterSlashCommands()

    OneWoW_GUI:RegisterSettingsCallback("OnThemeChanged", self, function()
        ApplyTheme()
        if self.GUI and self.GUI.FullReset then
            local wasShown = self.GUI:GetMainWindow() and self.GUI:GetMainWindow():IsShown()
            self.GUI:FullReset()
            if wasShown then
                C_Timer.After(0.1, function()
                    if self.GUI and self.GUI.Show then self.GUI:Show() end
                end)
            end
        end
    end)

    OneWoW_GUI:RegisterSettingsCallback("OnMinimapChanged", self, function(owner, hidden)
        if owner.Minimap then owner.Minimap:SetShown(not hidden) end
    end)
    OneWoW_GUI:RegisterSettingsCallback("OnIconThemeChanged", self, function(owner)
        if owner.Minimap then owner.Minimap:UpdateIcon() end
        if owner.GUI and owner.GUI.GetMainWindow then
            local mw = owner.GUI:GetMainWindow()
            if mw and mw.brandIcon then
                mw.brandIcon:SetTexture(OneWoW_GUI:GetBrandIcon(
                    OneWoW_GUI:GetSetting("minimap.theme") or "horde"))
            end
        end
    end)

    local _ver = OneWoW_GUI:GetAddonVersion(ADDON_NAME)
    if _G.OneWoW and _G.OneWoW.RegisterLoadComponent then
        _G.OneWoW:RegisterLoadComponent("DirectDeposit", _ver, "/1wdd")
    else
        OneWoW_DirectDeposit._pendingLoadVer = _ver
    end
end

function OneWoW_DirectDeposit:InitializeModules()
    if OneWoW_DirectDeposit.DirectDeposit then
        OneWoW_DirectDeposit.DirectDeposit:Initialize()
    end

end

function OneWoW_DirectDeposit:RegisterSlashCommands()
    local existingDD = SlashCmdList["DD"]

    if not existingDD then
        SLASH_ONEWOW_DIRECTDEPOSIT1 = "/dd"
        SLASH_ONEWOW_DIRECTDEPOSIT2 = "/directdeposit"
        SLASH_ONEWOW_DIRECTDEPOSIT3 = "/directdep"
    else
        print("|cFFFFD100Direct Deposit:|r |cFFFF8800/dd is already in use by another addon. Use /directdeposit or /directdep instead.|r")
        SLASH_ONEWOW_DIRECTDEPOSIT1 = "/directdeposit"
        SLASH_ONEWOW_DIRECTDEPOSIT2 = "/directdep"
    end

    SlashCmdList["ONEWOW_DIRECTDEPOSIT"] = function(msg)
        if OneWoW_DirectDeposit.GUI then
            OneWoW_DirectDeposit.GUI:Toggle()
        end
    end

    SLASH_ONEWOW_DD_TOGGLE1 = "/1wdd"
    SlashCmdList["ONEWOW_DD_TOGGLE"] = function(msg)
        if OneWoW_DirectDeposit.GUI then
            OneWoW_DirectDeposit.GUI:Toggle()
        end
    end

    SLASH_WOWNOTES_DDEPOSIT1 = "/ddeposit"
    SlashCmdList["WOWNOTES_DDEPOSIT"] = function(msg)
        local lowerMsg = strlower(strtrim(msg or ""))

        if lowerMsg == "pause" or lowerMsg == "stop" then
            if OneWoW_DirectDeposit.DirectDeposit:StopDeposit() then
            else
                print("|cFFFFD100Direct Deposit:|r |cFFFF8800No deposit in progress.|r")
            end
        elseif lowerMsg == "clean" then
            OneWoW_DirectDeposit:ValidateAndCleanItemList()
            print("|cFFFFD100Direct Deposit:|r |cFF00FF00Item list cleaned and validated.|r")
        else
            OneWoW_DirectDeposit.DirectDeposit:ManualDeposit()
        end
    end
end

_G["1WoW_DirectDeposit_OnAddonCompartmentClick"] = function(addonName, buttonName)
    if OneWoW_DirectDeposit.GUI then
        OneWoW_DirectDeposit.GUI:Toggle()
    end
end

_G["1WoW_DirectDeposit_OnAddonCompartmentEnter"] = function(addonName, button)
    GameTooltip:SetOwner(button, "ANCHOR_LEFT")
    GameTooltip:SetText("|cFFFFD100Direct Deposit|r", 1, 1, 1)
    GameTooltip:AddLine("Click to toggle settings", 0.7, 0.7, 0.7)

    local enabled = OneWoW_DirectDeposit.db and OneWoW_DirectDeposit.db.global.directDeposit.enabled
    if enabled then
        local targetGold = OneWoW_DirectDeposit.db.global.directDeposit.targetGold or 0
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFF00FF00Enabled|r", 0.2, 1, 0.2)
        if targetGold > 0 then
            GameTooltip:AddLine("Target: " .. targetGold .. "g", 1, 0.82, 0)
        end
    else
        GameTooltip:AddLine(" ", 1, 1, 1)
        GameTooltip:AddLine("|cFFFF0000Disabled|r", 1, 0.3, 0.3)
    end

    GameTooltip:Show()
end

_G["1WoW_DirectDeposit_OnAddonCompartmentLeave"] = function(addonName, button)
    GameTooltip:Hide()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loadedAddon = ...
        OneWoW_DirectDeposit:OnAddonLoaded(loadedAddon)
    elseif event == "PLAYER_LOGIN" then
        CheckForWoWNotes()
        DetectOneWoW()
        if not OneWoW_DirectDeposit.oneWoWHubActive then
            OneWoW_DirectDeposit.Minimap = OneWoW_GUI:CreateMinimapLauncher("OneWoW_DirectDeposit", {
                label = "Direct Deposit",
                onClick = function()
                    if OneWoW_DirectDeposit.GUI then OneWoW_DirectDeposit.GUI:Toggle() end
                end,
                onRightClick = function()
                    if OneWoW_DirectDeposit.GUI then
                        OneWoW_DirectDeposit.GUI:Show()
                        OneWoW_DirectDeposit.GUI:SelectTab(3)
                    end
                end,
                onTooltip = function(frame)
                    GameTooltip:SetOwner(frame, "ANCHOR_LEFT")
                    GameTooltip:AddLine("|cFFFFD100OneWoW|r - Direct Deposit", 1, 0.82, 0, 1)
                    local L = OneWoW_DirectDeposit.L
                    if L and L["MINIMAP_TOOLTIP_HINT"] then
                        GameTooltip:AddLine(L["MINIMAP_TOOLTIP_HINT"], 0.7, 0.7, 0.8, 1)
                    end
                    GameTooltip:Show()
                end,
            })
            if OneWoW_DirectDeposit._pendingLoadVer then
                print("|cFF00FF00OneWoW|r: |cFFFFFFFFDirect Deposit|r |cFF888888\226\128\147 v." .. OneWoW_DirectDeposit._pendingLoadVer .. " \226\128\147|r |cFF00FF00Loaded|r - /1wdd")
            end
        end
        if _G.OneWoW then
            _G.OneWoW:RegisterMinimap("OneWoW_DirectDeposit", (_G.OneWoW.L and _G.OneWoW.L["CTX_OPEN_DD"]) or "Open Direct Deposit", nil, function()
                if OneWoW_DirectDeposit.GUI then OneWoW_DirectDeposit.GUI:Toggle() end
            end)
        end
    end
end)
